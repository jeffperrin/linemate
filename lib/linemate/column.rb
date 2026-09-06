# frozen_string_literal: true

module Linemate
  class Column
    attr_reader :name, :type, :default

    def initialize(name, type, null: false, default: nil, primary: false)
      @name = name.to_sym
      @type = type
      @null = null
      @default = default
      @primary = primary
    end

    def null?
      @null
    end

    def primary?
      @primary
    end

    def sql_type
      @type.respond_to?(:sql_type) ? @type.sql_type : "TEXT"
    end

    def inspect
      flags = []
      flags << "primary" if primary?
      flags << "null" if null?
      flags << "default=#{default.inspect}" unless default.nil?
      "#<Column #{name} #{type_name}#{" " + flags.join(" ") unless flags.empty?}>"
    end

    def type_name
      @type.respond_to?(:name) ? @type.name.to_s.split("::").last : @type.inspect
    end
  end
end
