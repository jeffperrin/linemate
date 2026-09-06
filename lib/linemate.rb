# frozen_string_literal: true

require_relative "linemate/version"
require_relative "linemate/errors"
require_relative "linemate/connection"
require_relative "linemate/model"

module Linemate
  THREAD_KEY = :linemate_connection

  class << self
    def connect(path, **options)
      @config = {path: path, options: options}
      disconnect
      self
    end

    def connection
      raise ConnectionNotEstablished, "call Linemate.connect first" unless @config

      conn = Thread.current.thread_variable_get(THREAD_KEY)
      if conn.nil? || conn.pid != Process.pid || conn.closed?
        conn = Connection.new(@config[:path], **@config[:options])
        Thread.current.thread_variable_set(THREAD_KEY, conn)
      end
      conn
    end

    def connected?
      !@config.nil?
    end

    def disconnect
      conn = Thread.current.thread_variable_get(THREAD_KEY)
      conn&.close if conn && conn.pid == Process.pid
      Thread.current.thread_variable_set(THREAD_KEY, nil)
      nil
    end

    attr_reader :config
  end
end
