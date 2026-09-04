# frozen_string_literal: true

require "test_helper"

class ModelTest < Minitest::Test
  class Team < Linemate::Model
    col :id, Integer
    col :name, String
    col :active, Integer, default: 1
    col :motto, String, null: true
  end

  class HomeGame < Linemate::Model
  end

  class Player < Linemate::Model
    table "roster"
    col :number, Integer, primary: true
    col :name, String
  end

  class Skater < Player
    col :shoots, String
  end

  def test_table_inferred_from_class_name
    assert_equal "teams", Team.table
    assert_equal "home_games", HomeGame.table_name
  end

  def test_table_override
    assert_equal "roster", Player.table
  end

  def test_columns_in_declaration_order
    assert_equal %i[id name active motto], Team.column_names
  end

  def test_column_attributes
    c = Team.column(:motto)
    assert_equal :motto, c.name
    assert_same Linemate::Types::String, c.type
    assert c.null?
    refute c.primary?

    assert_equal 1, Team.column(:active).default
    refute Team.column(:name).null?
  end

  def test_unknown_column_raises
    err = assert_raises(Linemate::UnknownColumn) { Team.column(:goals) }
    assert_match(/no column :goals/, err.message)
    refute Team.column?(:goals)
    assert Team.column?("name")
  end

  def test_duplicate_column_raises
    assert_raises(ArgumentError) do
      Class.new(Linemate::Model) do
        col :id, Integer
        col :id, Integer
      end
    end
  end

  def test_primary_key_defaults_to_id
    assert_equal :id, Team.primary_key
  end

  def test_primary_key_override
    assert_equal :number, Player.primary_key
  end

  def test_primary_key_nil_without_id
    assert_nil HomeGame.primary_key
  end

  def test_subclass_inherits_columns_without_leaking_back
    assert_equal %i[number name shoots], Skater.column_names
    assert_equal %i[number name], Player.column_names
    assert_equal "skaters", Skater.table
  end

  def test_sql_type_delegates_to_type
    type = Struct.new(:sql_type).new("INTEGER")
    assert_equal "INTEGER", Linemate::Column.new(:n, type).sql_type
    assert_equal "TEXT", Linemate::Column.new(:n, String).sql_type
  end

  def test_column_inspect
    assert_equal "#<Column id Int>", Team.column(:id).inspect
    assert_equal "#<Column motto String null>", Team.column(:motto).inspect
    assert_equal "#<Column number Int primary>", Player.column(:number).inspect
  end
end
