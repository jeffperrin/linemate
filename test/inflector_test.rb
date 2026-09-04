# frozen_string_literal: true

require "test_helper"

class InflectorTest < Minitest::Test
  I = Linemate::Inflector

  def test_pluralize
    {
      "team" => "teams", "player" => "players", "division" => "divisions",
      "match" => "matches", "box" => "boxes", "bus" => "buses",
      "jersey" => "jerseys", "penalty" => "penalties", "series" => "series",
      "person" => "people", "child" => "children", "leaf" => "leaves",
      "status" => "statuses", "analysis" => "analyses"
    }.each { |s, p| assert_equal p, I.pluralize(s), s }
  end

  def test_singularize
    {
      "teams" => "team", "matches" => "match", "buses" => "bus",
      "penalties" => "penalty", "series" => "series", "people" => "person",
      "leaves" => "leaf", "statuses" => "status", "analyses" => "analysis",
      "games" => "game"
    }.each { |p, s| assert_equal s, I.singularize(p), p }
  end

  def test_underscore
    assert_equal "team", I.underscore("Team")
    assert_equal "home_game", I.underscore("HomeGame")
    assert_equal "nhl_team", I.underscore("NHLTeam")
    assert_equal "team", I.underscore("Hockey::Team")
  end

  def test_camelize
    assert_equal "HomeGame", I.camelize("home_game")
    assert_equal "Team", I.camelize(:team)
  end

  def test_tableize
    assert_equal "home_games", I.tableize("HomeGame")
    assert_equal "people", I.tableize("Person")
  end
end
