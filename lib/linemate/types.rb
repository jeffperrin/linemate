# frozen_string_literal: true

require "date"
require "time"
require "json"

module Linemate
  module Types
    module Int
      extend self

      def cast(value)
        case value
        when ::Integer then value
        when ::Float then value.to_i
        when ::String then Integer(value, 10)
        when true then 1
        when false then 0
        else raise TypeError, "cannot cast #{value.inspect} to Int"
        end
      end

      def serialize(value) = cast(value)

      def deserialize(value) = value&.to_i

      def sql_type = "INTEGER"
    end
    Integer = Int

    module Float
      extend self

      def cast(value)
        case value
        when ::Numeric then value.to_f
        when ::String then Float(value)
        else raise TypeError, "cannot cast #{value.inspect} to Float"
        end
      end

      def serialize(value) = cast(value)

      def deserialize(value) = value&.to_f

      def sql_type = "REAL"
    end

    module String
      extend self

      def cast(value)
        case value
        when ::String then value
        when ::Symbol, ::Numeric then value.to_s
        else raise TypeError, "cannot cast #{value.inspect} to String"
        end
      end

      def serialize(value) = cast(value)

      def deserialize(value) = value&.to_s

      def sql_type = "TEXT"
    end

    module Boolean
      extend self

      TRUE_VALUES = [true, 1, "1", "t", "true", "T", "TRUE", "yes", "y"].freeze
      FALSE_VALUES = [false, 0, "0", "f", "false", "F", "FALSE", "no", "n"].freeze

      def cast(value)
        return true if TRUE_VALUES.include?(value)
        return false if FALSE_VALUES.include?(value)

        raise TypeError, "cannot cast #{value.inspect} to Boolean"
      end

      def serialize(value) = cast(value) ? 1 : 0

      def deserialize(value) = value.nil? ? nil : cast(value)

      def sql_type = "INTEGER"
    end

    module Date
      extend self

      def cast(value)
        case value
        when ::Date then value.is_a?(::DateTime) ? value.to_date : value
        when ::Time then value.to_date
        when ::String then ::Date.iso8601(value)
        else raise TypeError, "cannot cast #{value.inspect} to Date"
        end
      end

      def serialize(value) = cast(value).iso8601

      def deserialize(value) = value.nil? ? nil : ::Date.iso8601(value.to_s)

      def sql_type = "TEXT"
    end

    module DateTime
      extend self

      def cast(value)
        case value
        when ::Time then value.utc
        when ::DateTime then value.to_time.utc
        when ::Date then ::Time.utc(value.year, value.month, value.day)
        when ::String then ::Time.iso8601(value).utc
        else raise TypeError, "cannot cast #{value.inspect} to DateTime"
        end
      end

      def serialize(value) = cast(value).iso8601(6)

      def deserialize(value) = value.nil? ? nil : ::Time.iso8601(value.to_s).utc

      def sql_type = "TEXT"
    end

    module Blob
      extend self

      def cast(value)
        raise TypeError, "cannot cast #{value.inspect} to Blob" unless value.is_a?(::String)

        value.b
      end

      def serialize(value) = SQLite3::Blob.new(cast(value))

      def deserialize(value) = value&.to_s&.b

      def sql_type = "BLOB"
    end

    module JSON
      extend self

      def cast(value) = value

      def serialize(value) = ::JSON.generate(value)

      def deserialize(value)
        return nil if value.nil?

        ::JSON.parse(value.to_s)
      end

      def sql_type = "TEXT"
    end
  end
end
