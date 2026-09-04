# frozen_string_literal: true

require_relative "reflection"

module Linemate
  # Read-only associations. The target class is passed directly, in the
  # same spirit as +col+:
  #
  #   belongs_to League                     # reader :league, key :league_id
  #   belongs_to Team, as: :home_team       # reader :home_team, key :home_team_id
  #   has_many :players, "Player"           # string resolved on first use
  #   has_one :captain, "Player", foreign_key: :captain_of_team_id
  module Associations
    module ClassMethods
      def belongs_to(target, as: nil, foreign_key: nil, primary_key: nil)
        name = (as || Inflector.underscore(target_name(target))).to_sym
        foreign_key = (foreign_key || :"#{name}_id").to_sym
        unless column?(foreign_key)
          raise AssociationError,
            "#{self}.belongs_to #{name}: declare `col :#{foreign_key}, Int` before the association"
        end

        add_reflection Reflection.new(
          macro: :belongs_to, name: name, owner: self, target: target,
          foreign_key: foreign_key, primary_key: primary_key
        )
        define_association_reader(name) do |reflection|
          key = self[reflection.foreign_key]
          key.nil? ? nil : reflection.klass.find_by(reflection.primary_key => key)
        end
      end

      def has_many(name, target, foreign_key: nil, primary_key: nil)
        reflection = add_reflection Reflection.new(
          macro: :has_many, name: name, owner: self, target: target,
          foreign_key: foreign_key || default_owner_key, primary_key: primary_key
        )
        define_association_reader(reflection.name) do |r|
          r.klass.where(r.foreign_key => self[r.primary_key])
        end
      end

      def has_one(name, target, foreign_key: nil, primary_key: nil)
        reflection = add_reflection Reflection.new(
          macro: :has_one, name: name, owner: self, target: target,
          foreign_key: foreign_key || default_owner_key, primary_key: primary_key
        )
        define_association_reader(reflection.name) do |r|
          r.klass.where(r.foreign_key => self[r.primary_key]).first
        end
      end

      def reflections
        @reflections ||= {}
      end

      def reflect_on_association(name)
        reflections[name.to_sym]
      end

      private

      def target_name(target)
        target.is_a?(::Class) ? target.name : target.to_s
      end

      def default_owner_key
        raise AssociationError, "anonymous models must pass foreign_key:" if name.nil?

        :"#{Inflector.underscore(name)}_id"
      end

      def add_reflection(reflection)
        if reflections.key?(reflection.name) || column?(reflection.name)
          raise AssociationError, "#{self} already defines #{reflection.name}"
        end

        reflections[reflection.name] = reflection
      end

      # The reader caches its result per instance; +reload_associations+
      # clears the cache.
      def define_association_reader(name, &loader)
        attribute_methods_module.module_eval do
          define_method(name) do
            cache = (@association_cache ||= {})
            return cache[name] if cache.key?(name)

            cache[name] = instance_exec(self.class.reflect_on_association(name), &loader)
          end
        end
      end
    end

    def self.included(base)
      base.extend(ClassMethods)
    end

    def reload_associations
      @association_cache = {}
      self
    end
  end
end
