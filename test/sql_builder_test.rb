# frozen_string_literal: true

require "test_helper"

class SQLBuilderTest < Minitest::Test
  B = Linemate::SQLBuilder

  def test_plain_select
    assert_equal ['SELECT * FROM "teams"', []], B.new(table: "teams").select_sql
  end

  def test_quotes_identifiers
    assert_equal '"we""ird"', B.quote_identifier('we"ird')
  end

  def test_select_list
    sql, = B.new(table: "teams", select: ['"id"', "COUNT(*)"]).select_sql
    assert_equal 'SELECT "id", COUNT(*) FROM "teams"', sql
  end

  def test_where_clauses_are_anded_and_parenthesised
    sql, binds = B.new(table: "t", where: [['"a" = ?', [1]], ['"b" IN (?, ?)', [2, 3]]]).select_sql
    assert_equal 'SELECT * FROM "t" WHERE ("a" = ?) AND ("b" IN (?, ?))', sql
    assert_equal [1, 2, 3], binds
  end

  def test_order_limit_offset
    sql, binds = B.new(table: "t", order: ['"a" DESC', '"b" ASC'], limit: 5, offset: 10).select_sql
    assert_equal 'SELECT * FROM "t" ORDER BY "a" DESC, "b" ASC LIMIT ? OFFSET ?', sql
    assert_equal [5, 10], binds
  end

  def test_offset_without_limit
    sql, binds = B.new(table: "t", offset: 3).select_sql
    assert_equal 'SELECT * FROM "t" LIMIT ? OFFSET ?', sql
    assert_equal [-1, 3], binds
  end

  def test_aggregate_wraps_select
    sql, binds = B.new(table: "t", where: [['"a" = ?', [1]]], limit: 2).aggregate_sql("COUNT(*)")
    assert_equal 'SELECT COUNT(*) FROM (SELECT * FROM "t" WHERE ("a" = ?) LIMIT ?) AS "subquery"', sql
    assert_equal [1, 2], binds
  end
end
