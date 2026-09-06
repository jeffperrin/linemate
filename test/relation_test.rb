# frozen_string_literal: true

require "test_helper"

class RelationTest < Minitest::Test
  class Player < Linemate::Model
    col :id, Int
    col :name, String
    col :position, String
    col :goals, Int, default: 0
    col :active, Boolean, default: true
    col :born_on, Date, null: true
  end

  ROWS = [
    [1, "Gretzky", "C", 92, 1, "1961-01-26"],
    [2, "Orr", "D", 46, 0, "1948-03-20"],
    [3, "Howe", "RW", 49, 0, nil],
    [4, "Hasek", "G", 0, 1, "1965-01-29"],
    [5, "Crosby", "C", 44, 1, "1987-08-07"]
  ].freeze

  def setup
    Linemate.connect(":memory:")
    conn = Linemate.connection
    conn.execute("CREATE TABLE players (id INTEGER PRIMARY KEY, name TEXT, position TEXT, goals INTEGER, active INTEGER, born_on TEXT, extra TEXT)")
    ROWS.each { |r| conn.execute("INSERT INTO players (id, name, position, goals, active, born_on) VALUES (?, ?, ?, ?, ?, ?)", r) }
  end

  def teardown
    Linemate.disconnect
  end

  def test_all_is_lazy_and_chaining_returns_new_relations
    rel = Player.all
    refute rel.loaded?
    other = rel.where(position: "C")
    refute_same rel, other
    assert_empty rel.where_clauses
    assert_equal 5, rel.count
    assert_equal 2, other.count
  end

  def test_to_a_is_cached_until_reload
    rel = Player.where(position: "C")
    a = rel.to_a
    assert rel.loaded?
    assert_same a, rel.to_a
    Linemate.connection.execute("DELETE FROM players WHERE id = 5")
    assert_equal 2, rel.to_a.size
    assert_equal 1, rel.reload.to_a.size
  end

  def test_where_hash_equality_casts_values
    assert_equal %w[Gretzky Hasek Crosby], Player.where(active: "t").pluck(:name)
    assert_equal ["Orr"], Player.where(born_on: Date.new(1948, 3, 20)).pluck(:name)
    assert_equal ["Orr"], Player.where(born_on: "1948-03-20").pluck(:name)
  end

  def test_where_hash_array_nil_range
    assert_equal %w[Gretzky Howe], Player.where(id: [1, 3]).pluck(:name)
    assert_equal [], Player.where(id: []).to_a
    assert_equal ["Howe"], Player.where(born_on: nil).pluck(:name)
    assert_equal %w[Orr Howe Crosby], Player.where(goals: 44..49).order(:id).pluck(:name)
    assert_equal %w[Orr Crosby], Player.where(goals: 44...49).order(:id).pluck(:name)
    assert_equal %w[Gretzky Howe], Player.where(goals: 49..).order(:id).pluck(:name)
    assert_equal %w[Hasek Crosby], Player.where(goals: ..44).order(:id).pluck(:name)
  end

  def test_where_fragment_with_binds
    assert_equal %w[Gretzky Howe], Player.where("goals > ?", 46).order(:id).pluck(:name)
  end

  def test_where_multiple_keys_and_chained
    assert_equal ["Crosby"], Player.where(position: "C", active: true).where("goals < ?", 50).pluck(:name)
  end

  def test_where_not
    assert_equal %w[Orr Howe Hasek], Player.where.not(position: "C").order(:id).pluck(:name)
    assert_equal %w[Gretzky Orr Hasek Crosby], Player.where.not(born_on: nil).order(:id).pluck(:name)
    assert_equal %w[Orr Howe Hasek Crosby], Player.where.not("goals > ?", 50).order(:id).pluck(:name)
  end

  def test_where_unknown_column_raises
    assert_raises(Linemate::UnknownColumn) { Player.where(assists: 1) }
    assert_raises(ArgumentError) { Player.where(42) }
  end

  def test_order_forms
    assert_equal %w[Gretzky Howe Orr Crosby Hasek], Player.order(goals: :desc).pluck(:name)
    assert_equal %w[Crosby Gretzky Hasek Howe Orr], Player.order(:name).pluck(:name)
    assert_equal %w[Gretzky Crosby Orr Hasek Howe], Player.order(:position, goals: :desc).pluck(:name)
    assert_equal %w[Gretzky Crosby Hasek Howe Orr], Player.order("length(name) DESC, name").pluck(:name)
    assert_raises(ArgumentError) { Player.order(goals: :sideways) }
  end

  def test_reorder_unscope_limit_offset
    rel = Player.order(:name).limit(2).offset(1)
    assert_equal %w[Gretzky Hasek], rel.pluck(:name)
    assert_equal %w[Howe Orr], rel.reorder(goals: :desc).pluck(:name)
    assert_equal %w[Gretzky Hasek Howe Orr], rel.unscope(:limit).pluck(:name)
    assert_equal %w[Crosby Gretzky], rel.unscope(:offset).pluck(:name)
    assert_equal %w[Orr Howe], rel.unscope(:order).pluck(:name)
    assert_raises(ArgumentError) { rel.unscope(:everything) }
  end

  def test_offset_without_limit
    assert_equal %w[Hasek Crosby], Player.order(:id).offset(3).pluck(:name)
  end

  def test_select_limits_loaded_columns
    p = Player.select(:id, :name).first
    assert_equal "Gretzky", p.name
    assert_nil p.goals
    assert_nil p.position
  end

  def test_first_and_last_default_to_primary_key_order
    assert_equal "Gretzky", Player.first.name
    assert_equal "Crosby", Player.last.name
    assert_equal %w[Gretzky Orr], Player.first(2).map(&:name)
    assert_equal %w[Hasek Crosby], Player.last(2).map(&:name)
  end

  def test_first_and_last_respect_order
    assert_equal "Hasek", Player.order(goals: :desc).last.name
    assert_equal "Crosby", Player.order(:name).first.name
    assert_raises(ArgumentError) { Player.order("RANDOM()").last }
  end

  def test_find
    assert_equal "Orr", Player.find(2).name
    assert_equal "Orr", Player.find("2").name
    err = assert_raises(Linemate::RecordNotFound) { Player.find(99) }
    assert_match(/id=99/, err.message)
    assert_raises(Linemate::RecordNotFound) { Player.where(position: "G").find(1) }
  end

  def test_find_by
    assert_equal 1, Player.find_by(name: "Gretzky").id
    assert_nil Player.find_by(name: "Lemieux")
    assert_equal "Gretzky", Player.find_by("goals > ?", 90).name
  end

  def test_exists_empty_size
    assert Player.where(position: "G").exists?
    refute Player.where(position: "LW").exists?
    assert Player.where(position: "LW").empty?
    rel = Player.where(position: "C")
    assert_equal 2, rel.size
    rel.to_a
    assert_equal 2, rel.size
  end

  def test_count_and_aggregates
    assert_equal 5, Player.count
    assert_equal 2, Player.limit(2).count
    assert_equal 231, Player.sum(:goals)
    assert_equal 0, Player.where(position: "LW").sum(:goals)
    assert_equal 92, Player.maximum(:goals)
    assert_equal 0, Player.minimum(:goals)
    assert_equal Date.new(1948, 3, 20), Player.minimum(:born_on)
    assert_equal Date.new(1987, 8, 7), Player.maximum(:born_on)
  end

  def test_pluck
    assert_equal [[1, "Gretzky"], [2, "Orr"]], Player.order(:id).limit(2).pluck(:id, :name)
    assert_equal [true, false], Player.order(:id).limit(2).pluck(:active)
    assert_equal [Date.new(1961, 1, 26)], Player.limit(1).pluck(:born_on)
    assert_equal [7], Player.limit(1).pluck("length(name)")
    assert_raises(Linemate::UnknownColumn) { Player.pluck(:assists) }
  end

  def test_records_are_persisted_and_typed
    p = Player.find(1)
    assert p.persisted?
    assert_equal true, p.active
    assert_equal Date.new(1961, 1, 26), p.born_on
    assert_equal Player.find(1), p
  end

  def test_enumerable
    assert_equal %w[Gretzky Crosby], Player.where(position: "C").map(&:name)
    assert Player.all.any? { |p| p.goals.zero? }
  end

  def test_to_sql
    rel = Player.where(position: "C").where.not(active: false).order(goals: :desc).limit(3)
    assert_equal 'SELECT * FROM "players" WHERE ("position" = ?) AND (NOT ("active" = ?)) ORDER BY "goals" DESC LIMIT ?', rel.to_sql
    assert_equal ["C", 0, 3], rel.sql.last
    assert_match(/#<Linemate::Relation RelationTest::Player SELECT/, rel.inspect)
  end
end

class RelationEdgeCasesTest < Minitest::Test
  class Note < Linemate::Model
    col :id, Int
    col :body, String
  end

  class Log < Linemate::Model
    col :message, String
  end

  def setup
    Linemate.connect(":memory:")
    Note.create_table
    Log.create_table
    Linemate.connection.execute("INSERT INTO notes (body) VALUES ('a'), ('b')")
    Linemate.connection.execute("INSERT INTO logs (message) VALUES ('x'), ('y')")
  end

  def teardown
    Linemate.disconnect
  end

  def test_unscope_where
    assert_equal 2, Note.where(body: "a").unscope(:where).count
  end

  def test_empty_when_loaded
    rel = Note.where(body: "zzz")
    rel.to_a
    assert rel.empty?
    loaded = Note.all.tap(&:to_a)
    refute loaded.empty?
  end

  def test_first_without_primary_key_keeps_insertion_order
    assert_equal "x", Log.first.message
    assert_raises(Linemate::Error) { Log.find(1) }
  end

  def test_rejects_non_column_arguments
    assert_raises(ArgumentError) { Note.select(42) }
    assert_raises(ArgumentError) { Note.order(42) }
    assert_raises(ArgumentError) { Note.where({body: "a"}, 1) }
  end

  def test_exclusive_endless_range
    assert_equal ['"id" < ?', [2]], Note.where(id: ...2).where_clauses.first
    assert_equal ["a"], Note.where(id: ...2).pluck(:body)
  end
end

class RelationScopeTest < Minitest::Test
  class Team < Linemate::Model
    col :id, Int
    col :name, String
    col :city, String
    col :active, Boolean, default: true

    def self.active
      where(active: true)
    end

    def self.in(city)
      where(city: city)
    end

    def self.roster_size
      count
    end
  end

  def setup
    Linemate.connect(":memory:")
    Team.create_table
    Team.create(name: "Leafs", city: "Toronto")
    Team.create(name: "Marlies", city: "Toronto", active: false)
    Team.create(name: "Bruins", city: "Boston")
  end

  def teardown
    Linemate.disconnect
  end

  def test_class_scopes_chain_off_relations
    assert_equal ["Leafs"], Team.in("Toronto").active.pluck(:name)
    assert_equal ["Leafs"], Team.active.in("Toronto").pluck(:name)
    assert_equal ["Leafs"], Team.where(city: "Toronto").active.order(:name).pluck(:name)
    assert_equal 2, Team.where(city: "Toronto").roster_size
  end

  def test_scope_is_restored_after_the_call
    Team.where(city: "Toronto").active
    assert_equal 3, Team.count
    assert_nil Team.current_scope
  end

  def test_scope_is_restored_when_the_scope_raises
    assert_raises(Linemate::UnknownColumn) { Team.where(city: "Toronto").where(nope: 1) }
    assert_nil Team.current_scope
    assert_equal 3, Team.count
  end

  def test_respond_to_and_unknown_methods
    assert_respond_to Team.all, :active
    refute_respond_to Team.all, :nonsense
    assert_raises(NoMethodError) { Team.all.nonsense }
  end

  def test_enumerable_find_and_select_with_blocks
    assert_equal "Marlies", Team.all.find { |t| !t.active }.name
    assert_equal ["Leafs", "Bruins"], Team.order(:id).select(&:active).map(&:name)
    assert_equal ["Leafs"], Team.in("Toronto").select { |t| t.active }.map(&:name)
    assert_equal "Leafs", Team.find(1).name
  end
end
