# frozen_string_literal: true

module Linemate
  class SQLBuilder
    def self.quote_identifier(name)
      %("#{name.to_s.gsub('"', '""')}")
    end

    def initialize(table:, select: [], where: [], order: [], limit: nil, offset: nil)
      @table = table
      @select = select
      @where = where
      @order = order
      @limit = limit
      @offset = offset
    end

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
      limit = @limit || (-1 if @offset)
      if limit
        sql << " LIMIT ?"
        binds << limit
      end
      if @offset
        sql << " OFFSET ?"
        binds << @offset
      end
      [sql, binds]
    end

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
