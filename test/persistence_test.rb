# frozen_string_literal: true

require "test_helper"

class PersistenceTest < Minitest::Test
  class Player < Linemate::Model
    col :id, Int
    col :name, String
    col :position, String
    col :goals, Int, default: 0
    col :active, Boolean, default: true
    col :born_on, Date, null: true
    col :team_id, Int, null: true
  end

  class Code < Linemate::Model
    col :code, String, primary: true
    col :label, String
  end

  class Log < Linemate::Model
    col :message, String
  end

  def setup
    Linemate.connect(":memory:")
    c = Linemate.connection
    c.execute("CREATE TABLE players (id INTEGER PRIMARY KEY, name TEXT NOT NULL, position TEXT NOT NULL, goals INTEGER NOT NULL, active INTEGER NOT NULL, born_on TEXT, team_id INTEGER)")
    c.execute("CREATE TABLE codes (code TEXT PRIMARY KEY, label TEXT NOT NULL)")
    c.execute("CREATE TABLE logs (message TEXT NOT NULL)")
  end

  def teardown
    Linemate.disconnect
  end

  def test_save_inserts_and_assigns_id
    p = Player.new(name: "Matthews", position: "C", born_on: "1997-09-17")
    assert p.new_record?
    assert p.save
    assert p.persisted?
    assert_equal 1, p.id
    assert_equal 1, Player.count

    found = Player.find(1)
    assert_equal "Matthews", found.name
    assert_equal 0, found.goals
    assert_equal true, found.active
    assert_equal Date.new(1997, 9, 17), found.born_on
    assert_nil found.team_id
  end

  def test_create
    p = Player.create(name: "Marner", position: "RW", goals: "26")
    assert p.persisted?
    assert_equal 26, Player.find(p.id).goals
  end

  def test_save_updates_persisted_record
    p = Player.create(name: "Rielly", position: "D")
    p.goals = 7
    p.active = false
    assert p.save
    assert_equal 1, Player.count
    reloaded = Player.find(p.id)
    assert_equal 7, reloaded.goals
    assert_equal false, reloaded.active
  end

  def test_update
    p = Player.create(name: "Tavares", position: "C")
    assert p.update(goals: 38, born_on: Date.new(1990, 9, 20))
    assert_equal [38, Date.new(1990, 9, 20)], Player.find(p.id).then { |r| [r.goals, r.born_on] }
    assert_raises(Linemate::UnknownColumn) { p.update(assists: 1) }
  end

  def test_missing_required_attribute_raises_before_sql
    p = Player.new(name: "Nobody")
    err = assert_raises(Linemate::NotNullViolation) { p.save }
    assert_match(/requires position/, err.message)
    assert_equal 0, Player.count
    assert p.new_record?
  end

  def test_explicit_id_is_kept
    p = Player.new(id: 42, name: "Nylander", position: "RW")
    p.save
    assert_equal 42, p.id
    assert_equal 42, Player.first.id
  end

  def test_destroy
    p = Player.create(name: "Kadri", position: "C")
    other = Player.create(name: "Kerfoot", position: "C")
    assert_same p, p.destroy
    assert p.destroyed?
    assert_equal [other.id], Player.pluck(:id)
    assert_raises(Linemate::Error) { p.save }
  end

  def test_destroy_new_record_is_a_noop
    p = Player.new(name: "x", position: "C").destroy
    assert p.destroyed?
    assert_equal 0, Player.count
  end

  def test_reload
    p = Player.create(name: "Robertson", position: "LW")
    Linemate.connection.execute("UPDATE players SET goals = 99 WHERE id = ?", [p.id])
    p.goals = 1
    assert_same p, p.reload
    assert_equal 99, p.goals
    p.destroy
    assert_raises(Linemate::RecordNotFound) { p.reload }
  end

  def test_string_primary_key
    c = Code.create(code: "TOR", label: "Toronto")
    assert_equal "TOR", c.id
    c.update(label: "Toronto Maple Leafs")
    assert_equal "Toronto Maple Leafs", Code.find("TOR").label
    c.destroy
    assert_nil Code.find_by(code: "TOR")
  end

  def test_model_without_primary_key_can_insert_but_not_update
    log = Log.create(message: "hello")
    assert log.persisted?
    assert_equal ["hello"], Log.pluck(:message)
    assert_raises(Linemate::Error) { log.update(message: "again") }
    assert_raises(Linemate::Error) { log.destroy }
  end

  def test_values_are_bound
    p = Player.create(name: "O'Reilly", position: "C")
    assert_equal "O'Reilly", Player.find(p.id).name
  end
end
