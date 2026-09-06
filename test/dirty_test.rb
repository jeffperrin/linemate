# frozen_string_literal: true

require "test_helper"

class DirtyTest < Minitest::Test
  class Team < Linemate::Model
    col :id, Int
    col :name, String
    col :city, String, null: true
    col :active, Boolean, default: true
  end

  def setup
    Linemate.connect(":memory:")
    Team.create_table
  end

  def teardown
    Linemate.disconnect
  end

  def test_new_record_tracks_assignments_not_defaults
    team = Team.new(name: "Leafs")
    assert team.changed?
    assert_equal [:name], team.changed
    assert_equal({name: [nil, "Leafs"]}, team.changes)
    refute team.active_changed?
    assert_nil team.name_was
  end

  def test_loaded_record_is_clean
    Team.create(name: "Leafs")
    team = Team.find(1)
    refute team.changed?
    assert_empty team.changes
  end

  def test_changes_and_was
    team = Team.create(name: "Leafs")
    team.name = "Maple Leafs"
    team.city = "Toronto"
    assert_equal({name: ["Leafs", "Maple Leafs"], city: [nil, "Toronto"]}, team.changes)
    assert team.name_changed?
    assert team.attribute_changed?("city")
    assert_equal "Leafs", team.name_was
    assert_equal "Leafs", team.attribute_was(:name)
  end

  def test_reverting_a_value_clears_the_change
    team = Team.create(name: "Leafs")
    team.name = "x"
    team.name = "Leafs"
    refute team.changed?
  end

  def test_save_records_saved_changes_and_clears_changes
    team = Team.create(name: "Leafs")
    assert_equal({id: [nil, 1], name: [nil, "Leafs"]}, team.saved_changes)
    team.name = "Maple Leafs"
    team.save
    refute team.changed?
    assert_equal({name: ["Leafs", "Maple Leafs"]}, team.saved_changes)
    assert_equal "Maple Leafs", Team.find(1).name
  end

  def test_update_writes_only_changed_columns
    team = Team.create(name: "Leafs", city: "Toronto")
    Linemate.connection.execute("UPDATE teams SET city = 'Elsewhere'")
    team.update(name: "Maple Leafs")
    assert_equal "Elsewhere", Team.find(1).city
  end

  def test_save_without_changes_runs_no_sql
    team = Team.create(name: "Leafs")
    Linemate.connection.execute("DROP TABLE teams")
    assert team.save
    assert_empty team.saved_changes
  end

  def test_reload_clears_changes
    team = Team.create(name: "Leafs")
    team.name = "x"
    team.reload
    refute team.changed?
    assert_equal "Leafs", team.name
  end
end
