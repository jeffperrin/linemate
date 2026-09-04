# frozen_string_literal: true

require_relative "inflector"
require_relative "column"
require_relative "types"
require_relative "attributes"
require_relative "querying"

module Linemate
  # Base class for mapped records. Subclasses declare their columns with
  # +col+ and, optionally, their table with +table+.
  class Model
    include Types
    include Attributes
    extend Querying

    class << self
      # Returns or sets the table name. Defaults to the pluralised,
      # underscored class name: Team => "teams", HomeGame => "home_games".
      def table(name = nil)
        @table = name.to_s if name
        @table ||= Inflector.tableize(self.name)
      end
      alias_method :table_name, :table

      # Declares an attribute.
      #
      #   col :id, Int
      #   col :name, String
      #   col :born_on, Date, null: true
      #
      # A column named :id is the primary key unless another column is
      # declared with primary: true.
      def col(name, type, null: false, default: nil, primary: false)
        name = name.to_sym
        raise ArgumentError, "column #{name} already declared on #{self}" if columns_hash.key?(name)

        column = Column.new(name, type, null: null, default: default, primary: primary)
        columns_hash[name] = column
        define_attribute_methods(column)
        column
      end

      def columns
        columns_hash.values
      end

      def column_names
        columns_hash.keys
      end

      def column(name)
        columns_hash[name.to_sym] || raise(UnknownColumn, "#{self} has no column #{name.inspect}")
      end

      def column?(name)
        columns_hash.key?(name.to_sym)
      end

      def primary_key
        (columns.find(&:primary?) || columns_hash[:id])&.name
      end

      def columns_hash
        @columns_hash ||= {}
      end

      def inherited(subclass)
        super
        parent_columns = columns_hash
        subclass.instance_variable_set(:@columns_hash, parent_columns.dup)
      end
    end
  end
end
