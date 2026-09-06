# frozen_string_literal: true

require "test_helper"

class HockeyIntegrationTest < Minitest::Test
  include Hockey

  def setup
    Hockey.setup!
  end

  def teardown
    Linemate.disconnect
  end

  def test_find_and_find_by
    leafs = Team.find(1)
    assert_equal "Maple Leafs", leafs.name
    assert_equal true, leafs.active
    assert leafs.persisted?

    assert_equal 4, Team.find_by(name: "Whalers").id
    assert_nil Team.find_by(name: "Nordiques")
    assert_raises(Linemate::RecordNotFound) { Team.find(99) }
  end

  def test_undeclared_table_columns_are_ignored
    refute Team.column?(:arena)
    refute Team.find(1).attributes.key?(:arena)
  end

  def test_all_is_lazy
    rel = Team.all
    refute rel.loaded?
    assert_equal 5, rel.count
    assert_equal 5, rel.to_a.size
    assert rel.loaded?
  end

  def test_query_chain
    names = Player.where(position: "C").where("goals > ?", 40).order(goals: :desc).limit(5).pluck(:name)
    assert_equal ["Auston Matthews", "Nathan MacKinnon", "Sidney Crosby"], names
  end

  def test_where_not_and_ranges
    assert_equal 1, Team.where.not(active: true).count
    assert_equal ["Brad Marchand", "Sidney Crosby", "Evgeni Malkin"],
      Player.where(born_on: Date.new(1986, 1, 1)..Date.new(1989, 12, 31)).order(:id).pluck(:name)
    assert_equal ["Free Agent"], Player.where(team_id: nil).pluck(:name)
  end

  def test_counts_and_aggregates
    assert_equal 5, Team.count
    assert_equal 3, Team.where(division_id: [1, 2]).where(active: true).count
    assert_equal 319, Player.sum(:goals)
    assert_equal 89, Player.maximum(:assists)
    assert_equal Date.new(1986, 7, 31), Player.minimum(:born_on)
    assert_equal Time.utc(2024, 10, 20, 1), Game.maximum(:played_at)
  end

  def test_first_and_last
    assert_equal "Maple Leafs", Team.first.name
    assert_equal "Avalanche", Team.last.name
    assert_equal "Nathan MacKinnon", Player.order(:assists).last.name
    assert_equal ["Maple Leafs", "Bruins"], Team.first(2).map(&:name)
  end

  def test_types_round_trip
    league = League.find(1)
    assert_equal Date.new(1917, 11, 26), league.founded_on
    assert_equal Time.utc(2020, 1, 1), league.created_at
    assert league.created_at.utc?

    game = Game.find(1)
    assert_equal true, game.overtime
    assert_equal false, Game.find(2).overtime
    assert_equal Time.utc(2024, 10, 9, 23), game.played_at
  end

  def test_belongs_to_chain
    crosby = Player.find(6)
    assert_equal "Penguins", crosby.team.name
    assert_equal "Metropolitan", crosby.team.division.name
    assert_equal "NHL", crosby.team.division.league.name
    assert_equal "NHL", crosby.team.league.name
    assert_nil Player.find(10).team
  end

  def test_has_many_relations_chain
    leafs = Team.find(1)
    assert_equal 3, leafs.players.count
    assert_equal ["Auston Matthews"], leafs.players.where(position: "C").pluck(:name)
    assert_equal ["Mitch Marner", "Morgan Rielly", "Auston Matthews"],
      leafs.players.order(assists: :desc).pluck(:name)
    assert_equal 1, leafs.home_games.count
    assert_equal 2, leafs.away_games.count
    assert_equal [1, 2, 3], League.find(1).divisions.pluck(:id)
    assert_equal 5, League.find(1).teams.count
    assert_empty League.find(2).teams.to_a
  end

  def test_has_one
    assert_equal "Auston Matthews", Team.find(1).captain.name
    assert_nil Team.find(4).captain
  end

  def test_belongs_to_with_as
    game = Game.find(3)
    assert_equal "Penguins", game.home_team.name
    assert_equal "Maple Leafs", game.away_team.name
  end

  def test_model_methods_and_equality
    matthews = Player.find(1)
    assert_equal 107, matthews.points
    assert_equal matthews, Team.find(1).players.find(1)
    assert_equal 1, [matthews, Player.find(1)].uniq.size
  end

  def test_pluck_multiple_columns
    assert_equal [[1, "Maple Leafs", true], [4, "Whalers", false]],
      Team.where(id: [1, 4]).order(:id).pluck(:id, :name, :active)
  end

  def test_reflections
    assert_equal %i[division league players captain home_games away_games], Team.reflections.keys
    assert_same Player, Team.reflect_on_association(:players).klass
  end

  def test_columns_are_introspectable
    assert_equal %i[id name position goals assists born_on team_id captain_of_id], Player.column_names
    assert_equal "INTEGER", Player.column(:goals).sql_type
    assert_equal "TEXT", Player.column(:born_on).sql_type
    assert Player.column(:born_on).null?
    assert_equal :id, Player.primary_key
    assert_equal "roster", Player.table
  end

  def test_to_sql_is_bound_not_interpolated
    rel = Player.where(name: "Robert'); DROP TABLE roster; --")
    assert_equal 'SELECT * FROM "roster" WHERE ("name" = ?)', rel.to_sql
    assert_empty rel.to_a
    assert_equal 10, Player.count
  end

  def test_create_update_destroy_round_trip
    leafs = Team.find(1)
    rookie = Player.create(name: "Easton Cowan", position: "LW", team_id: leafs.id, born_on: Date.new(2005, 5, 20))
    assert_equal 4, leafs.players.reload.count
    assert_equal "Maple Leafs", rookie.team.name

    rookie.update(goals: 1, assists: 2)
    assert_equal 3, Player.find(rookie.id).points

    rookie.destroy
    assert_equal 10, Player.count
    assert_nil Player.find_by(name: "Easton Cowan")
  end

  def test_foreign_keys_are_enforced
    assert_raises(SQLite3::ConstraintException) { Player.create(name: "Ghost", position: "G", team_id: 999) }
  end
end
