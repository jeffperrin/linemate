# frozen_string_literal: true

require_relative "linemate/version"
require_relative "linemate/errors"
require_relative "linemate/connection"
require_relative "linemate/model"

module Linemate
  THREAD_KEY = :linemate_connection

  class << self
    # Stores the database configuration. No handle is opened until the
    # first call to Linemate.connection on a given thread.
    def connect(path, **options)
      @config = {path: path, options: options}
      disconnect
      self
    end

    # Returns the current thread's connection, opening it on first use.
    # Handles are never shared across threads. A handle opened before a
    # fork is discarded in the child and replaced with a fresh one.
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

    # Closes the current thread's handle, if any. Other threads own their
    # own handles and must call this themselves.
    def disconnect
      conn = Thread.current.thread_variable_get(THREAD_KEY)
      conn.close if conn&.pid == Process.pid
      Thread.current.thread_variable_set(THREAD_KEY, nil)
      nil
    end

    attr_reader :config
  end
end
