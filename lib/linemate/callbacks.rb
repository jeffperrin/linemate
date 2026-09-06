# frozen_string_literal: true

module Linemate
  module Callbacks
    EVENTS = %i[save create update destroy].freeze

    module ClassMethods
      def callbacks
        @callbacks ||= Hash.new { |hash, key| hash[key] = [] }
      end

      EVENTS.each do |event|
        define_method(:"before_#{event}") { |method = nil, &block| callbacks[:"before_#{event}"] << (method || block) }
        define_method(:"after_#{event}") { |method = nil, &block| callbacks[:"after_#{event}"] << (method || block) }
      end
    end

    def self.included(base)
      base.extend(ClassMethods)
    end

    private

    def run_callbacks(event)
      catch(:abort) do
        invoke_callbacks(:"before_#{event}")
        yield
        invoke_callbacks(:"after_#{event}")
        return true
      end
      false
    end

    def invoke_callbacks(key)
      self.class.callbacks[key].each do |callback|
        callback.is_a?(::Symbol) ? send(callback) : instance_exec(&callback)
      end
    end
  end
end
