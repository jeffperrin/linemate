# frozen_string_literal: true

require "test_helper"

class SchemaTest < Minitest::Test
  include Hockey

  def setup
    Linemate.connect(":memory:")
  end

  def teardown
    Linemate.disconnect
  end

  def test_create_table_sql
    expected = <<~SQL.chomp
      CREATE TABLE "teams" (
        "id" INTEGER PRIMARY KEY,
        "name" TEXT NOT NULL,
        "city" TEXT NOT NULL,
        "active" INTEGER NOT NULL DEFAULT 1,
        "division_id" INTEGER NOT NULL,
        "league_id" INTEGER NOT NULL,
        FOREIGN KEY ("division_id") REFERENCES "divisions" ("id"),
        FOREIGN KEY ("league_id") REFERENCES "leagues" ("id")
      )
    SQL
    assert_equal expected, Team.create_table_sql
  end

  def test_nullable_string_default_and_custom_table
    sql = Player.create_table_sql(if_not_exists: true)
    assert_includes sql, 'CREATE TABLE IF NOT EXISTS "roster"'
    assert_includes sql, '"goals" INTEGER NOT NULL DEFAULT 0'
    assert_includes sql, '"born_on" TEXT,'
    assert_includes sql, '"team_id" INTEGER,'
    assert_includes sql, 'FOREIGN KEY ("team_id") REFERENCES "teams" ("id")'
  end

  def test_string_primary_key_and_quoted_defaults
    model = Class.new(Linemate::Model) do
      table "codes"
      col :code, Linemate::Types::String, primary: true
      col :label, Linemate::Types::String, default: "it's"
      col :ratio, Linemate::Types::Float, default: 0.5
    end
    expected = <<~SQL.chomp
      CREATE TABLE "codes" (
        "code" TEXT PRIMARY KEY,
        "label" TEXT NOT NULL DEFAULT 'it''s',
        "ratio" REAL NOT NULL DEFAULT 0.5
      )
    SQL
    assert_equal expected, model.create_table_sql
  end

  def test_callable_defaults_are_left_to_ruby
    model = Class.new(Linemate::Model) do
      table "stamps"
      col :id, Linemate::Types::Int
      col :at, Linemate::Types::DateTime, default: -> { Time.now }
    end
    assert_includes model.create_table_sql, %("at" TEXT NOT NULL\n)
  end

  def test_blob_default_is_hex
    model = Class.new(Linemate::Model) do
      table "blobs"
      col :id, Linemate::Types::Int
      col :data, Linemate::Types::Blob, default: "hi"
    end
    assert_includes model.create_table_sql, %("data" BLOB NOT NULL DEFAULT X'6869')
  end

  def test_unsupported_default_raises
    symbolic = Class.new do
      def cast(v) = v
      def serialize(v) = v.to_sym
      def deserialize(v) = v
      def sql_type = "TEXT"
    end
    model = Class.new(Linemate::Model) do
      table "odd"
      col :id, Linemate::Types::Int
      col :mood, symbolic.new, default: "grumpy"
    end
    assert_raises(ArgumentError) { model.create_table_sql }
  end

  def test_create_drop_and_exists
    refute League.table_exists?
    assert_same League, League.create_table
    assert League.table_exists?
    assert_raises(SQLite3::SQLException) { League.create_table }
    League.create_table(if_not_exists: true)
    League.drop_table
    refute League.table_exists?
    League.drop_table
    assert_raises(SQLite3::SQLException) { League.drop_table(if_exists: false) }
  end

  def test_generated_tables_round_trip_records
    [League, Division, Team, Player, Game].each(&:create_table)
    c = Linemate.connection
    c.execute("INSERT INTO leagues (id, name, founded_on, created_at) VALUES (1, 'NHL', '1917-11-26', '2020-01-01T00:00:00.000000Z')")
    c.execute("INSERT INTO divisions (id, name, league_id) VALUES (1, 'Atlantic', 1)")
    c.execute("INSERT INTO teams (id, name, city, division_id, league_id) VALUES (1, 'Maple Leafs', 'Toronto', 1, 1)")
    c.execute("INSERT INTO roster (id, name, position, team_id) VALUES (1, 'Matthews', 'C', 1)")

    team = Team.find(1)
    assert_equal true, team.active
    assert_equal "NHL", team.league.name
    assert_equal ["Matthews"], team.players.pluck(:name)
    assert_equal 0, Player.find(1).goals

    assert_raises(SQLite3::ConstraintException) do
      c.execute("INSERT INTO teams (name, city, division_id, league_id) VALUES ('Ghosts', 'Nowhere', 99, 1)")
    end
  end
end
