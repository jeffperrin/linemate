# frozen_string_literal: true

require "logger"

module Linemate
  Event = Struct.new(:name, :sql, :binds, :duration, :error) do
    def duration_ms
      (duration * 1000).round(2)
    end
  end

  module Instrumentation
    Subscription = Struct.new(:name, :block)

    MUTEX = Mutex.new

    def subscribe(name = nil, &block)
      raise ArgumentError, "subscribe requires a block" unless block

      subscription = Subscription.new(name&.to_sym, block)
      MUTEX.synchronize { subscriptions << subscription }
      subscription
    end

    def unsubscribe(subscription)
      MUTEX.synchronize { subscriptions.delete(subscription) }
      nil
    end

    def logger=(logger)
      unsubscribe(@log_subscription) if @log_subscription
      @log_subscription = logger && subscribe(:sql) do |event|
        message = "#{event.duration_ms}ms  #{event.sql}"
        message += "  #{event.binds.inspect}" unless event.binds.empty?
        event.error ? logger.error("#{message}  #{event.error.class}: #{event.error.message}") : logger.debug(message)
      end
    end

    def instrument(name, sql, binds)
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      result = yield
    rescue => error
      publish(name, sql, binds, started, error)
      raise
    else
      publish(name, sql, binds, started, nil)
      result
    end

    private

    def subscriptions
      @subscriptions ||= []
    end

    def publish(name, sql, binds, started, error)
      listeners = MUTEX.synchronize { subscriptions.select { |s| s.name.nil? || s.name == name } }
      return if listeners.empty?

      duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
      event = Event.new(name: name, sql: sql, binds: binds, duration: duration, error: error)
      listeners.each { |s| s.block.call(event) }
    end
  end

  extend Instrumentation
end
