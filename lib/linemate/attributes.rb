# frozen_string_literal: true

module Linemate
  module Attributes
    module ClassMethods
      def instantiate(row)
        record = allocate
        record.send(:init_from_row, row)
        record
      end

      private

      def overridable_methods
        @overridable_methods ||= Module.new.tap { |m| include m }
      end

      def define_attribute_methods(column)
        name = column.name
        overridable_methods.module_eval do
          define_method(name) { read_attribute(name) }
          define_method(:"#{name}=") { |value| write_attribute(name, value) }
          define_method(:"#{name}_changed?") { attribute_changed?(name) }
          define_method(:"#{name}_was") { attribute_was(name) }
        end
      end
    end

    def self.included(base)
      base.extend(ClassMethods)
    end

    def initialize(attributes = {})
      @attributes = {}
      @new_record = true
      self.class.columns.each do |column|
        default = column.default
        default = default.call if default.respond_to?(:call)
        @attributes[column.name] = default.nil? ? nil : column.type.cast(default)
      end
      clear_changes
      attributes.each { |name, value| write_attribute(name, value) }
    end

    def read_attribute(name)
      name = name.to_sym
      raise UnknownColumn, "#{self.class} has no column #{name.inspect}" unless self.class.column?(name)

      @attributes[name]
    end
    alias_method :[], :read_attribute

    def write_attribute(name, value)
      column = self.class.column(name)
      if value.nil?
        unless column.null? || column.name == self.class.primary_key
          raise NotNullViolation, "#{self.class}##{column.name} cannot be nil"
        end
        @attributes[column.name] = nil
      else
        @attributes[column.name] = column.type.cast(value)
      end
    end
    alias_method :[]=, :write_attribute

    def attributes
      @attributes.dup
    end

    def attribute_names
      self.class.column_names
    end

    def id
      pk = self.class.primary_key
      pk && @attributes[pk]
    end

    def persisted?
      !@new_record
    end

    def new_record?
      @new_record
    end

    def ==(other)
      other.instance_of?(self.class) && persisted? && other.persisted? && !id.nil? && id == other.id
    end
    alias_method :eql?, :==

    def hash
      (persisted? && !id.nil?) ? [self.class, id].hash : super
    end

    def inspect
      pairs = @attributes.map { |k, v| "#{k}: #{v.inspect}" }
      "#<#{self.class.name} #{pairs.join(", ")}>"
    end

    private

    def init_from_row(row)
      @attributes = {}
      @new_record = false
      self.class.columns.each do |column|
        raw = row.key?(column.name) ? row[column.name] : row[column.name.to_s]
        @attributes[column.name] = column.type.deserialize(raw)
      end
      clear_changes
    end
  end
end
