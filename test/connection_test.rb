# frozen_string_literal: true

require "test_helper"

class ConnectionTest < Minitest::Test
  def setup
    Linemate.connect(":memory:")
  end

  def teardown
    Linemate.disconnect
  end

  def test_raises_before_connect
    Linemate.instance_variable_set(:@config, nil)
    assert_raises(Linemate::ConnectionNotEstablished) { Linemate.connection }
  ensure
    Linemate.connect(":memory:")
  end

  def test_connection_is_cached_per_thread
    assert_same Linemate.connection, Linemate.connection
  end

  def test_each_thread_gets_its_own_handle
    main = Linemate.connection
    other = Thread.new {
      conn = Linemate.connection
      Linemate.disconnect
      conn
    }.value
    refute_same main, other
  end

  def test_reopens_after_fork
    skip "fork not supported" unless Process.respond_to?(:fork)
    parent = Linemate.connection
    SQLite3::ForkSafety.suppress_warnings!
    reader, writer = IO.pipe
    pid = fork do
      reader.close
      writer.puts(Linemate.connection.equal?(parent) ? "same" : "different")
      writer.close
      exit!(0)
    end
    writer.close
    Process.wait(pid)
    assert_equal "different", reader.read.strip
  end

  def test_execute_and_select
    conn = Linemate.connection
    conn.execute("CREATE TABLE t (id INTEGER PRIMARY KEY, name TEXT)")
    conn.execute("INSERT INTO t (name) VALUES (?)", ["a"])
    conn.execute("INSERT INTO t (name) VALUES (?)", ["b"])

    assert_equal 2, conn.select_value("SELECT COUNT(*) FROM t")
    assert_equal({"id" => 1, "name" => "a"}, conn.select_one("SELECT * FROM t ORDER BY id"))
    assert_equal %w[a b], conn.select_all("SELECT name FROM t ORDER BY id").map { |r| r["name"] }
    assert_equal [[1, "a"], [2, "b"]], conn.select_rows("SELECT id, name FROM t ORDER BY id")
    assert_equal({"id" => 1, "name" => "a"}, conn.select_one("SELECT * FROM t ORDER BY id"))
  end

  def test_foreign_keys_enabled
    assert_equal 1, Linemate.connection.select_value("PRAGMA foreign_keys")
  end

  def test_transaction_rolls_back_on_error
    conn = Linemate.connection
    conn.execute("CREATE TABLE t (id INTEGER PRIMARY KEY)")
    assert_raises(RuntimeError) do
      conn.transaction do
        conn.execute("INSERT INTO t DEFAULT VALUES")
        raise "boom"
      end
    end
    assert_equal 0, conn.select_value("SELECT COUNT(*) FROM t")
  end

  def test_disconnect_closes_handle
    conn = Linemate.connection
    Linemate.disconnect
    assert conn.closed?
    refute_same conn, Linemate.connection
  end
end
