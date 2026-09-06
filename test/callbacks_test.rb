# frozen_string_literal: true

require "test_helper"

class CallbacksTest < Minitest::Test
  class Team < Linemate::Model
    col :id, Int
    col :name, String
    col :slug, String, null: true
    col :saves, Int, default: 0

    attr_reader :log

    before_save :slugify
    before_save { log << :before_save }
    after_save { log << :after_save }
    before_create { log << :before_create }
    after_create { log << :after_create }
    before_update { log << :before_update }
    after_update { log << [:after_update, saved_changes.keys] }
    before_destroy { log << :before_destroy }
    after_destroy { log << :after_destroy }

    def initialize(*)
      super
      @log = []
    end

    def slugify
      self.slug = name.downcase.tr(" ", "-")
    end
  end

  class Guarded < Team
    table "teams"
    before_save { throw :abort if name == "nope" }
    before_destroy { throw :abort if name == "keep" }
  end

  def setup
    Linemate.connect(":memory:")
    Team.create_table
  end

  def teardown
    Linemate.disconnect
  end

  def test_create_runs_save_and_create_callbacks_in_order
    team = Team.create(name: "Maple Leafs")
    assert_equal "maple-leafs", Team.find(team.id).slug
    assert_equal %i[before_save before_create after_create after_save], team.log
  end

  def test_update_runs_save_and_update_callbacks
    team = Team.create(name: "Leafs")
    team.log.clear
    team.update(name: "Maple Leafs")
    assert_equal [:before_save, :before_update, [:after_update, %i[name slug]], :after_save], team.log
  end

  def test_destroy_callbacks
    team = Team.create(name: "Leafs")
    team.log.clear
    assert_same team, team.destroy
    assert_equal %i[before_destroy after_destroy], team.log
  end

  def test_abort_halts_save_and_skips_after_callbacks
    team = Guarded.new(name: "nope")
    refute team.save
    assert team.new_record?
    assert_equal 0, Guarded.count
    assert_equal [:before_save], team.log
  end

  def test_abort_halts_destroy
    team = Guarded.create(name: "keep")
    team.log.clear
    assert_equal false, team.destroy
    refute team.destroyed?
    assert_equal 1, Guarded.count
    assert_equal [:before_destroy], team.log
  end

  def test_subclass_inherits_without_leaking_back
    assert_equal 2, Team.callbacks[:before_save].size
    assert_equal 3, Guarded.callbacks[:before_save].size
    guarded = Guarded.create(name: "Marlies")
    assert_equal "marlies", guarded.slug
  end
end
