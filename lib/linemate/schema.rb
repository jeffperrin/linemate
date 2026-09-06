# frozen_string_literal: true

module Linemate
  module Schema
    def create_table(if_not_exists: false)
      connection.execute(create_table_sql(if_not_exists: if_not_exists))
      self
    end

    def drop_table(if_exists: true)
      connection.execute(%(DROP TABLE #{"IF EXISTS " if if_exists}#{quote(table)}))
      self
    end

    def table_exists?
      !connection.select_value("SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ?", [table]).nil?
    end

    def create_table_sql(if_not_exists: false)
      definitions = columns.map { |column| column_definition(column) } + foreign_key_definitions
      %(CREATE TABLE #{"IF NOT EXISTS " if if_not_exists}#{quote(table)} (\n  #{definitions.join(",\n  ")}\n))
    end

    private

    def column_definition(column)
      parts = [quote(column.name), column.sql_type]
      if column.name == primary_key
        parts << "PRIMARY KEY"
      else
        parts << "NOT NULL" unless column.null?
        parts << "DEFAULT #{literal(column.type.serialize(column.default))}" unless column.default.nil? || column.default.respond_to?(:call)
      end
      parts.join(" ")
    end

    def foreign_key_definitions
      reflections.values.select(&:belongs_to?).map do |reflection|
        %(FOREIGN KEY (#{quote(reflection.foreign_key)}) REFERENCES #{quote(reflection.klass.table)} (#{quote(reflection.primary_key)}))
      end
    end

    def literal(value)
      case value
      when ::Integer, ::Float then value.to_s
      when SQLite3::Blob then "X'#{value.unpack1("H*")}'"
      when ::String then "'#{value.gsub("'", "''")}'"
      else raise ArgumentError, "cannot express #{value.inspect} as a SQL default"
      end
    end

    def quote(name)
      SQLBuilder.quote_identifier(name)
    end
  end
end
