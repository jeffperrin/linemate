# frozen_string_literal: true

require "test_helper"
require "stringio"

class InstrumentationTest < Minitest::Test
  include Hockey

  def setup
    Hockey.setup!
    @subscriptions = []
  end

  def teardown
    @subscriptions.each { |s| Linemate.unsubscribe(s) }
    Linemate.logger = nil
    Linemate.disconnect
  end

  def subscribe(name = nil, &block)
    @subscriptions << Linemate.subscribe(name, &block)
    @subscriptions.last
  end

  def test_sql_events_carry_statement_binds_and_duration
    events = []
    subscribe(:sql) { |e| events << e }
    Team.where(city: "Toronto").count

    assert_equal 1, events.size
    event = events.first
    assert_equal :sql, event.name
    assert_includes event.sql, 'SELECT COUNT(*) FROM (SELECT * FROM "teams" WHERE ("city" = ?))'
    assert_equal ["Toronto"], event.binds
    assert_kind_of Float, event.duration
    assert_operator event.duration, :>=, 0
    assert_equal (event.duration * 1000).round(2), event.duration_ms
    assert_nil event.error
  end

  def test_every_connection_method_is_instrumented
    sqls = []
    subscribe { |e| sqls << e.sql }
    conn = Linemate.connection
    conn.execute("SELECT 1")
    conn.select_all("SELECT 2")
    conn.select_one("SELECT 3")
    conn.select_rows("SELECT 4")
    conn.select_value("SELECT 5")
    assert_equal ["SELECT 1", "SELECT 2", "SELECT 3", "SELECT 4", "SELECT 5"], sqls
  end

  def test_errors_are_published_then_reraised
    events = []
    subscribe { |e| events << e }
    assert_raises(SQLite3::SQLException) { Linemate.connection.execute("SELECT * FROM nowhere") }
    assert_kind_of SQLite3::SQLException, events.first.error
  end

  def test_name_filter_and_unsubscribe
    matched = []
    ignored = []
    subscribe(:sql) { |e| matched << e }
    subscribe(:other) { |e| ignored << e }
    all = subscribe { |e| matched << e }
    Team.count
    assert_equal 2, matched.size
    assert_empty ignored

    Linemate.unsubscribe(all)
    Team.count
    assert_equal 3, matched.size
  end

  def test_subscribe_requires_a_block
    assert_raises(ArgumentError) { Linemate.subscribe(:sql) }
  end

  def test_no_subscribers_costs_nothing_visible
    assert_equal 5, Team.count
  end

  def test_logger_logs_statements_and_errors
    io = StringIO.new
    Linemate.logger = Logger.new(io, level: Logger::DEBUG)
    Team.where(id: 1).pluck(:name)
    Linemate.connection.execute("SELECT 1")
    assert_raises(SQLite3::SQLException) { Linemate.connection.execute("BAD SQL") }

    log = io.string
    assert_equal 2, log.scan("DEBUG").size
    assert_equal 1, log.scan("ERROR").size
    assert_match(/DEBUG.*ms  SELECT "name" FROM "teams" WHERE \("id" = \?\)  \[1\]/, log)
    assert_match(/DEBUG.*ms  SELECT 1$/, log)
    assert_match(/ERROR.*BAD SQL  SQLite3::SQLException/, log)
  end

  def test_replacing_or_clearing_the_logger_removes_the_old_subscription
    first = StringIO.new
    second = StringIO.new
    Linemate.logger = Logger.new(first)
    Linemate.logger = Logger.new(second)
    Team.count
    assert_empty first.string
    refute_empty second.string

    Linemate.logger = nil
    Team.count
    assert_equal 1, second.string.scan("DEBUG").size
  end
end
