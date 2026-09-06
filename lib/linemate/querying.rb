# frozen_string_literal: true

require "forwardable"
require_relative "relation"

module Linemate
  module Querying
    extend Forwardable

    def all
      Relation.new(self)
    end

    def_delegators :all,
      :where, :order, :reorder, :limit, :offset, :select, :unscope,
      :find, :find_by, :first, :last, :exists?, :count, :sum, :minimum,
      :maximum, :pluck, :to_a

    def connection
      Linemate.connection
    end
  end
end
