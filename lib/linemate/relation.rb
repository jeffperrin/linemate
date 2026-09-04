# frozen_string_literal: true

require_relative "sql_builder"

module Linemate
  # A lazy, immutable, chainable query. Every chain method returns a new
  # Relation; nothing hits the database until a terminal method runs.
  class Relation
    include Enumerable

    # Returned by +where+ with no arguments so that +where.not(...)+ works.
    class WhereChain
      def initialize(relation)
        @relation = relation
      end

      def not(conditions, *binds)
        fragment, fragment_binds = @relation.send(:build_where, conditions, binds)
        @relation.send(:spawn, where: @relation.where_clauses + [["NOT (#{fragment})", fragment_binds]])
      end
    end

    attr_reader :model, :where_clauses, :order_clauses, :limit_value, :offset_value, :select_values

    def initialize(model, where: [], order: [], limit: nil, offset: nil, select: [])
      @model = model
      @where_clauses = where.freeze
      @order_clauses = order.freeze
      @limit_value = limit
      @offset_value = offset
      @select_values = select.freeze
      @records = nil
    end

    # -- chaining -----------------------------------------------------------

    # where(name: "Leafs")            => "name" = ?
    # where(id: [1, 2])               => "id" IN (?, ?)
    # where(captain_id: nil)          => "captain_id" IS NULL
    # where(goals: 10..20)            => "goals" BETWEEN ? AND ?
    # where("goals > ?", 20)          => raw fragment with binds
    # where.not(position: "G")        => NOT ("position" = ?)
    def where(conditions = nil, *binds)
      return WhereChain.new(self) if conditions.nil?

      spawn(where: where_clauses + [build_where(conditions, binds)])
    end

    # order(:goals) / order(goals: :desc) / order("RANDOM()")
    def order(*args)
      spawn(order: order_clauses + build_order(args))
    end

    def reorder(*args)
      spawn(order: build_order(args))
    end

    def limit(value)
      spawn(limit: value && Integer(value))
    end

    def offset(value)
      spawn(offset: value && Integer(value))
    end

    def select(*columns)
      spawn(select: select_values + columns.map { |c| column_or_raw(c) })
    end

    # unscope(:where, :order, :limit, :offset, :select)
    def unscope(*parts)
      changes = {}
      parts.each do |part|
        case part
        when :where then changes[:where] = []
        when :order then changes[:order] = []
        when :limit then changes[:limit] = nil
        when :offset then changes[:offset] = nil
        when :select then changes[:select] = []
        else raise ArgumentError, "unknown scope #{part.inspect}"
        end
      end
      spawn(**changes)
    end

    def reverse_order
      reversed = order_clauses.map do |clause|
        if clause.end_with?(" ASC")
          clause.sub(/ ASC\z/, " DESC")
        elsif clause.end_with?(" DESC")
          clause.sub(/ DESC\z/, " ASC")
        else
          raise ArgumentError, "cannot reverse raw order clause #{clause.inspect}"
        end
      end
      spawn(order: reversed)
    end

    # -- terminals ----------------------------------------------------------

    def to_a
      @records ||= connection.select_all(*sql).map { |row| model.instantiate(row) }
    end
    alias_method :records, :to_a

    def each(&block)
      to_a.each(&block)
    end

    def loaded?
      !@records.nil?
    end

    def reload
      @records = nil
      self
    end

    def first(count = nil)
      rel = ordered_by_pk_if_needed
      count ? rel.limit(count).to_a : rel.limit(1).to_a.first
    end

    def last(count = nil)
      rel = ordered_by_pk_if_needed.reverse_order
      count ? rel.limit(count).to_a.reverse : rel.limit(1).to_a.first
    end

    def find(id)
      pk = primary_key!
      where(pk => id).first ||
        raise(RecordNotFound, "Couldn't find #{model} with #{pk}=#{id.inspect}")
    end

    def find_by(conditions, *binds)
      where(conditions, *binds).first
    end

    def exists?
      !connection.select_value(*unscope(:order, :select).limit(1).spawn(select: ["1"]).sql).nil?
    end

    def empty?
      loaded? ? to_a.empty? : !exists?
    end

    def size
      loaded? ? to_a.size : count
    end

    def count
      Integer(connection.select_value(*aggregate("COUNT(*)")))
    end

    def sum(column)
      value = connection.select_value(*aggregate("SUM(#{column_or_raw(column)})"))
      value.nil? ? 0 : value
    end

    def minimum(column)
      deserialize(column, connection.select_value(*aggregate("MIN(#{column_or_raw(column)})")))
    end

    def maximum(column)
      deserialize(column, connection.select_value(*aggregate("MAX(#{column_or_raw(column)})")))
    end

    # pluck(:name) => ["a", "b"]; pluck(:id, :name) => [[1, "a"], [2, "b"]]
    def pluck(*columns)
      rows = connection.select_rows(*unscope(:select).spawn(select: columns.map { |c| column_or_raw(c) }).sql)
      rows = rows.map do |row|
        columns.each_with_index.map { |col, i| deserialize(col, row[i]) }
      end
      (columns.size == 1) ? rows.map(&:first) : rows
    end

    # -- sql ----------------------------------------------------------------

    # => [sql, binds]
    def sql
      builder.select_sql
    end

    def to_sql
      sql.first
    end

    def inspect
      "#<#{self.class.name} #{model} #{to_sql}>"
    end

    protected

    def spawn(**changes)
      self.class.new(
        model,
        where: changes.fetch(:where, where_clauses),
        order: changes.fetch(:order, order_clauses),
        limit: changes.fetch(:limit, limit_value),
        offset: changes.fetch(:offset, offset_value),
        select: changes.fetch(:select, select_values)
      )
    end

    def builder
      SQLBuilder.new(
        table: model.table,
        select: select_values,
        where: where_clauses,
        order: order_clauses,
        limit: limit_value,
        offset: offset_value
      )
    end

    private

    def aggregate(expression)
      unscope(:order, :select).builder.aggregate_sql(expression)
    end

    def connection
      Linemate.connection
    end

    def primary_key!
      model.primary_key || raise(Error, "#{model} has no primary key")
    end

    def ordered_by_pk_if_needed
      return self unless order_clauses.empty?
      return self unless model.primary_key

      order(model.primary_key)
    end

    def quote(name) = SQLBuilder.quote_identifier(name)

    # Symbols must be declared columns; strings pass through as raw SQL.
    def column_or_raw(value)
      case value
      when ::Symbol then quote(model.column(value).name)
      when ::String then value
      else raise ArgumentError, "expected a column symbol or SQL string, got #{value.inspect}"
      end
    end

    def deserialize(column, value)
      column.is_a?(::Symbol) ? model.column(column).type.deserialize(value) : value
    end

    def build_where(conditions, binds)
      case conditions
      when ::Hash
        raise ArgumentError, "binds are not allowed with hash conditions" unless binds.empty?

        parts = conditions.map { |name, value| hash_condition(model.column(name), value) }
        [parts.map(&:first).join(" AND "), parts.flat_map(&:last)]
      when ::String
        [conditions, binds]
      else
        raise ArgumentError, "where expects a Hash or SQL string, got #{conditions.inspect}"
      end
    end

    def hash_condition(column, value)
      name = quote(column.name)
      type = column.type
      case value
      when nil
        ["#{name} IS NULL", []]
      when ::Array
        return ["1 = 0", []] if value.empty?

        ["#{name} IN (#{(["?"] * value.size).join(", ")})", value.map { |v| type.serialize(v) }]
      when ::Range
        range_condition(name, type, value)
      else
        ["#{name} = ?", [type.serialize(value)]]
      end
    end

    def range_condition(name, type, range)
      if range.begin.nil?
        op = range.exclude_end? ? "<" : "<="
        ["#{name} #{op} ?", [type.serialize(range.end)]]
      elsif range.end.nil?
        ["#{name} >= ?", [type.serialize(range.begin)]]
      elsif range.exclude_end?
        ["#{name} >= ? AND #{name} < ?", [type.serialize(range.begin), type.serialize(range.end)]]
      else
        ["#{name} BETWEEN ? AND ?", [type.serialize(range.begin), type.serialize(range.end)]]
      end
    end

    def build_order(args)
      args.flat_map do |arg|
        case arg
        when ::Symbol
          ["#{column_or_raw(arg)} ASC"]
        when ::Hash
          arg.map do |name, direction|
            dir = direction.to_s.upcase
            raise ArgumentError, "order direction must be :asc or :desc" unless %w[ASC DESC].include?(dir)

            "#{column_or_raw(name)} #{dir}"
          end
        when ::String
          [arg]
        else
          raise ArgumentError, "cannot order by #{arg.inspect}"
        end
      end
    end
  end
end
