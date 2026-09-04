# frozen_string_literal: true

module Linemate
  # Turns the pieces of a Relation into SQL text plus an array of binds.
  # Pure: no database access, no knowledge of models. Identifiers are
  # double-quoted; values are never interpolated.
  class SQLBuilder
    def self.quote_identifier(name)
      %("#{name.to_s.gsub('"', '""')}")
    end

    # where:  array of [sql_fragment, binds]
    # order:  array of sql fragments
    # select: array of sql fragments (empty means *)
    def initialize(table:, select: [], where: [], order: [], limit: nil, offset: nil)
      @table = table
      @select = select
      @where = where
      @order = order
      @limit = limit
      @offset = offset
    end

    # => [sql, binds]
    def select_sql
      binds = []
      sql = "SELECT #{select_list} FROM #{quote(@table)}"
      unless @where.empty?
        sql << " WHERE " << @where.map { |fragment, fragment_binds|
          binds.concat(fragment_binds)
          "(#{fragment})"
        }.join(" AND ")
      end
      sql << " ORDER BY " << @order.join(", ") unless @order.empty?
      if @limit
        sql << " LIMIT ?"
        binds << @limit
      elsif @offset
        # SQLite requires LIMIT before OFFSET; -1 means no limit.
        sql << " LIMIT -1"
      end
      if @offset
        sql << " OFFSET ?"
        binds << @offset
      end
      [sql, binds]
    end

    # An aggregate over the full relation, limit and offset included, by
    # wrapping the select in a subquery. => [sql, binds]
    def aggregate_sql(expression)
      inner, binds = select_sql
      ["SELECT #{expression} FROM (#{inner}) AS #{quote("subquery")}", binds]
    end

    private

    def quote(name) = self.class.quote_identifier(name)

    def select_list
      @select.empty? ? "*" : @select.join(", ")
    end
  end
end
