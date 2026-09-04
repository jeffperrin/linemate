# frozen_string_literal: true

require "test_helper"

class AssociationsTest < Minitest::Test
  class League < Linemate::Model
    col :id, Int
    col :name, String
    has_many :divisions, "AssociationsTest::Division"
    has_many :teams, "AssociationsTest::Team", foreign_key: :league_id
  end

  class Division < Linemate::Model
    col :id, Int
    col :name, String
    col :league_id, Int
    belongs_to League
    has_many :teams, "AssociationsTest::Team"
  end

  class Team < Linemate::Model
    col :id, Int
    col :name, String
    col :division_id, Int
    col :league_id, Int
    belongs_to Division
    has_many :players, "AssociationsTest::Player"
    has_one :captain, "AssociationsTest::Player", foreign_key: :captain_of_id
    has_many :home_games, "AssociationsTest::Game", foreign_key: :home_team_id
  end

  class Player < Linemate::Model
    table "roster"
    col :id, Int
    col :name, String
    col :position, String
    col :team_id, Int, null: true
    col :captain_of_id, Int, null: true
    belongs_to Team
  end

  class Game < Linemate::Model
    col :id, Int
    col :home_team_id, Int
    col :away_team_id, Int
    belongs_to Team, as: :home_team
    belongs_to Team, as: :away_team
  end

  def setup
    Linemate.connect(":memory:")
    c = Linemate.connection
    c.execute("CREATE TABLE leagues (id INTEGER PRIMARY KEY, name TEXT)")
    c.execute("CREATE TABLE divisions (id INTEGER PRIMARY KEY, name TEXT, league_id INTEGER)")
    c.execute("CREATE TABLE teams (id INTEGER PRIMARY KEY, name TEXT, division_id INTEGER, league_id INTEGER)")
    c.execute("CREATE TABLE roster (id INTEGER PRIMARY KEY, name TEXT, position TEXT, team_id INTEGER, captain_of_id INTEGER)")
    c.execute("CREATE TABLE games (id INTEGER PRIMARY KEY, home_team_id INTEGER, away_team_id INTEGER)")
    c.execute("INSERT INTO leagues VALUES (1, 'NHL')")
    c.execute("INSERT INTO divisions VALUES (1, 'Atlantic', 1), (2, 'Metropolitan', 1)")
    c.execute("INSERT INTO teams VALUES (1, 'Leafs', 1, 1), (2, 'Bruins', 1, 1), (3, 'Penguins', 2, 1)")
    c.execute("INSERT INTO roster VALUES (1, 'Matthews', 'C', 1, 1), (2, 'Marner', 'RW', 1, NULL), (3, 'Crosby', 'C', 3, 3), (4, 'Free Agent', 'D', NULL, NULL)")
    c.execute("INSERT INTO games VALUES (1, 1, 2), (2, 2, 1), (3, 3, 1)")
  end

  def teardown
    Linemate.disconnect
  end

  def test_belongs_to_defaults
    r = Player.reflect_on_association(:team)
    assert_equal :belongs_to, r.macro
    assert_equal :team_id, r.foreign_key
    assert_equal :id, r.primary_key
    assert_same Team, r.klass
    assert_equal "Leafs", Player.find(1).team.name
  end

  def test_belongs_to_nil_when_key_nil
    assert_nil Player.find(4).team
  end

  def test_belongs_to_with_as
    g = Game.find(3)
    assert_equal "Penguins", g.home_team.name
    assert_equal "Leafs", g.away_team.name
    assert_equal :away_team_id, Game.reflect_on_association(:away_team).foreign_key
  end

  def test_belongs_to_requires_declared_foreign_key
    err = assert_raises(Linemate::AssociationError) do
      Class.new(Linemate::Model) { belongs_to AssociationsTest::League }
    end
    assert_match(/col :league_id, Int/, err.message)
  end

  def test_has_many_defaults_and_chaining
    r = Team.reflect_on_association(:players)
    assert_equal :has_many, r.macro
    assert_equal :team_id, r.foreign_key
    assert_equal :id, r.primary_key
    team = Team.find(1)
    assert_kind_of Linemate::Relation, team.players
    assert_equal %w[Matthews Marner], team.players.order(:id).pluck(:name)
    assert_equal 1, team.players.where(position: "C").count
    assert_empty Team.find(2).players.to_a
  end

  def test_has_many_custom_foreign_key
    assert_equal [1], Team.find(1).home_games.pluck(:id)
    assert_equal [2], Team.find(2).home_games.pluck(:id)
    assert_equal 3, League.find(1).teams.count
  end

  def test_has_one
    assert_equal "Matthews", Team.find(1).captain.name
    assert_nil Team.find(2).captain
  end

  def test_chain_through_belongs_to
    assert_equal "NHL", Player.find(3).team.division.league.name
  end

  def test_string_targets_resolve_lazily
    assert_equal "AssociationsTest::Division", League.reflect_on_association(:divisions).target_name
    assert_same Division, League.reflect_on_association(:divisions).klass
    assert_equal %w[Atlantic Metropolitan], League.find(1).divisions.order(:id).pluck(:name)
  end

  def test_readers_are_cached_until_reload
    p = Player.find(1)
    team = p.team
    assert_same team, p.team
    p.reload_associations
    refute_same team, p.team

    t = Team.find(1)
    assert_same t.players, t.players
  end

  def test_duplicate_names_raise
    assert_raises(Linemate::AssociationError) do
      Class.new(Linemate::Model) do
        col :id, Linemate::Types::Int
        col :team_id, Linemate::Types::Int
        belongs_to AssociationsTest::Team
        belongs_to AssociationsTest::Team
      end
    end
    assert_raises(Linemate::AssociationError) do
      Class.new(Linemate::Model) do
        col :id, Linemate::Types::Int
        col :players, Linemate::Types::String
        has_many :players, "AssociationsTest::Player", foreign_key: :team_id
      end
    end
  end

  def test_subclass_inherits_reflections
    sub = Class.new(Player)
    assert sub.reflect_on_association(:team)
    sub.has_many :games, "AssociationsTest::Game", foreign_key: :home_team_id
    assert_nil Player.reflect_on_association(:games)
  end

  def test_reflection_inspect
    assert_equal "#<Reflection has_many players => AssociationsTest::Player via team_id>",
      Team.reflect_on_association(:players).inspect
  end
end
