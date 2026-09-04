# frozen_string_literal: true

require "sqlite3"

module Linemate
  # Thin wrapper around a single SQLite3::Database handle. One instance is
  # owned by exactly one thread; see Linemate.connection.
  class Connection
    attr_reader :database, :pid

    def initialize(path, **options)
      @pid = Process.pid
      @database = SQLite3::Database.new(path, results_as_hash: true, **options)
      @database.busy_timeout = 5000
      @database.execute("PRAGMA journal_mode = WAL") unless path == ":memory:"
      @database.execute("PRAGMA foreign_keys = ON")
    end

    def execute(sql, binds = [])
      @database.execute(sql, binds)
    end

    def select_all(sql, binds = [])
      @database.execute(sql, binds)
    end

    def select_one(sql, binds = [])
      @database.execute(sql, binds).first
    end

    def select_value(sql, binds = [])
      row = @database.execute(sql, binds).first
      row&.values&.first
    end

    def transaction(&block)
      @database.transaction(&block)
    end

    def close
      @database.close unless @database.closed?
    end

    def closed?
      @database.closed?
    end
  end
end
