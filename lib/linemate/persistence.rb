# frozen_string_literal: true

module Linemate
  module Persistence
    module ClassMethods
      def create(attributes = {})
        new(attributes).tap(&:save)
      end
    end

    def self.included(base)
      base.extend(ClassMethods)
    end

    def save
      raise Error, "cannot save a destroyed #{self.class}" if destroyed?

      check_required_attributes
      event = new_record? ? :create : :update
      run_callbacks(:save) do
        run_callbacks(event) do
          (event == :create) ? insert_row : update_row
          changes_applied
        end || throw(:abort)
      end
    end

    def update(attributes)
      assign_attributes(attributes)
      save
    end

    def assign_attributes(attributes)
      attributes.each { |name, value| write_attribute(name, value) }
      self
    end

    def destroy
      run_callbacks(:destroy) do
        connection.execute(%(DELETE FROM #{quoted_table} WHERE #{quoted(primary_key)} = ?), [id]) if persisted?
        @destroyed = true
      end && self
    end

    def destroyed?
      @destroyed == true
    end

    def reload
      row = connection.select_one(%(SELECT * FROM #{quoted_table} WHERE #{quoted(primary_key)} = ?), [id])
      raise RecordNotFound, "Couldn't find #{self.class} with #{primary_key}=#{id.inspect}" unless row

      init_from_row(row)
      reload_associations
    end

    private

    def insert_row
      columns = self.class.columns.reject { |c| c.name == self.class.primary_key && id.nil? }
      names = columns.map { |c| quoted(c.name) }.join(", ")
      placeholders = (["?"] * columns.size).join(", ")
      connection.execute(%(INSERT INTO #{quoted_table} (#{names}) VALUES (#{placeholders})), columns.map { |c| serialized(c) })
      assign_generated_id
      @new_record = false
    end

    def update_row
      columns = changed.map { |name| self.class.column(name) }
      return if columns.empty?

      assignments = columns.map { |c| "#{quoted(c.name)} = ?" }.join(", ")
      connection.execute(%(UPDATE #{quoted_table} SET #{assignments} WHERE #{quoted(primary_key)} = ?), columns.map { |c| serialized(c) } + [id])
    end

    def assign_generated_id
      pk = self.class.primary_key
      return unless pk && id.nil?

      @attributes[pk] = self.class.column(pk).type.deserialize(connection.last_insert_row_id)
    end

    def check_required_attributes
      missing = self.class.columns.select { |c| !c.null? && c.name != self.class.primary_key && @attributes[c.name].nil? }
      return if missing.empty?

      raise NotNullViolation, "#{self.class} requires #{missing.map(&:name).join(", ")}"
    end

    def serialized(column)
      value = @attributes[column.name]
      value.nil? ? nil : column.type.serialize(value)
    end

    def primary_key
      self.class.primary_key || raise(Error, "#{self.class} has no primary key")
    end

    def quoted_table
      quoted(self.class.table)
    end

    def quoted(name)
      SQLBuilder.quote_identifier(name)
    end

    def connection
      self.class.connection
    end
  end
end
