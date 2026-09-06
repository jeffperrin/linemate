# frozen_string_literal: true

require "forwardable"
require_relative "relation"

module Linemate
  module Querying
    extend Forwardable

    def all
      current_scope || Relation.new(self)
    end

    def scoping(relation)
      previous = current_scope
      current_scopes[self] = relation
      yield
    ensure
      current_scopes[self] = previous
    end

    def current_scope
      current_scopes[self]
    end

    def_delegators :all,
      :where, :order, :reorder, :limit, :offset, :select, :unscope,
      :find, :find_by, :first, :last, :exists?, :count, :sum, :minimum,
      :maximum, :pluck, :to_a

    def connection
      Linemate.connection
    end

    private

    def current_scopes
      Thread.current.thread_variable_get(:linemate_scopes) ||
        Thread.current.thread_variable_set(:linemate_scopes, {})
    end
  end
end
