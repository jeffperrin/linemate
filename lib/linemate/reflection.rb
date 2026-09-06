# frozen_string_literal: true

module Linemate
  class Reflection
    attr_reader :macro, :name, :owner, :foreign_key

    def initialize(macro:, name:, owner:, target:, foreign_key:, primary_key: nil)
      @macro = macro
      @name = name.to_sym
      @owner = owner
      @target = target
      @foreign_key = foreign_key.to_sym
      @primary_key = primary_key&.to_sym
    end

    def klass
      @klass ||= @target.is_a?(::Class) ? @target : Object.const_get(@target.to_s)
    end

    def primary_key
      @primary_key || (belongs_to? ? klass.primary_key : owner.primary_key) ||
        raise(AssociationError, "#{owner}.#{name}: no primary key available")
    end

    def belongs_to? = macro == :belongs_to

    def collection? = macro == :has_many

    def target_name
      @target.is_a?(::Class) ? @target.name : @target.to_s
    end

    def inspect
      "#<Reflection #{macro} #{name} => #{target_name} via #{foreign_key}>"
    end
  end
end
