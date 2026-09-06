# frozen_string_literal: true

module Linemate
  module Dirty
    def changes
      @attributes.each_with_object({}) do |(name, value), result|
        result[name] = [@original_attributes[name], value] if @original_attributes[name] != value
      end
    end

    def changed
      changes.keys
    end

    def changed?
      !changes.empty?
    end

    def attribute_changed?(name)
      changes.key?(name.to_sym)
    end

    def attribute_was(name)
      @original_attributes[name.to_sym]
    end

    def saved_changes
      @saved_changes || {}
    end

    private

    def changes_applied
      @saved_changes = changes
      clear_changes
    end

    def clear_changes
      @original_attributes = @attributes.dup
    end
  end
end
