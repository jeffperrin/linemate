# frozen_string_literal: true

require "test_helper"

class TypesTest < Minitest::Test
  T = Linemate::Types

  def test_int
    assert_equal 5, T::Int.cast("5")
    assert_equal 5, T::Int.cast(5.9)
    assert_equal 1, T::Int.cast(true)
    assert_raises(TypeError) { T::Int.cast(Object.new) }
    assert_raises(ArgumentError) { T::Int.cast("five") }
    assert_equal 7, T::Int.deserialize(7)
    assert_nil T::Int.deserialize(nil)
    assert_equal "INTEGER", T::Int.sql_type
    assert_same T::Int, T::Integer
  end

  def test_float
    assert_equal 1.5, T::Float.cast("1.5")
    assert_equal 2.0, T::Float.cast(2)
    assert_equal "REAL", T::Float.sql_type
  end

  def test_string
    assert_equal "abc", T::String.cast(:abc)
    assert_equal "12", T::String.cast(12)
    assert_raises(TypeError) { T::String.cast([]) }
    assert_equal "TEXT", T::String.sql_type
  end

  def test_boolean
    assert_equal true, T::Boolean.cast("true")
    assert_equal false, T::Boolean.cast(0)
    assert_raises(TypeError) { T::Boolean.cast("maybe") }
    assert_equal 1, T::Boolean.serialize(true)
    assert_equal 0, T::Boolean.serialize("f")
    assert_equal true, T::Boolean.deserialize(1)
    assert_equal false, T::Boolean.deserialize(0)
    assert_nil T::Boolean.deserialize(nil)
  end

  def test_date
    d = ::Date.new(2000, 1, 2)
    assert_equal d, T::Date.cast("2000-01-02")
    assert_equal d, T::Date.cast(Time.utc(2000, 1, 2, 12))
    assert_equal "2000-01-02", T::Date.serialize(d)
    assert_equal d, T::Date.deserialize("2000-01-02")
    assert_equal "TEXT", T::Date.sql_type
  end

  def test_datetime_is_utc
    local = Time.new(2000, 1, 2, 3, 4, 5, "-05:00")
    cast = T::DateTime.cast(local)
    assert cast.utc?
    assert_equal Time.utc(2000, 1, 2, 8, 4, 5), cast
    assert_equal "2000-01-02T08:04:05.000000Z", T::DateTime.serialize(local)

    back = T::DateTime.deserialize("2000-01-02T08:04:05.000000Z")
    assert back.utc?
    assert_equal cast, back

    assert_equal Time.utc(2000, 1, 2), T::DateTime.cast(::Date.new(2000, 1, 2))
    assert_equal cast, T::DateTime.cast("2000-01-02T03:04:05-05:00")
  end

  def test_blob
    assert_equal Encoding::BINARY, T::Blob.cast("x").encoding
    assert_kind_of SQLite3::Blob, T::Blob.serialize("x")
    assert_equal "BLOB", T::Blob.sql_type
  end

  def test_json
    assert_equal '{"a":[1,2]}', T::JSON.serialize({"a" => [1, 2]})
    assert_equal({"a" => [1, 2]}, T::JSON.deserialize('{"a":[1,2]}'))
    assert_equal "TEXT", T::JSON.sql_type
  end

  class Typed < Linemate::Model
    col :id, Int
    col :name, String
    col :born_on, Date
    col :at, DateTime
    col :ok, Boolean
  end

  def test_type_constants_resolve_inside_model_bodies
    klass = Typed
    assert_same T::String, klass.column(:name).type
    assert_same T::Date, klass.column(:born_on).type
    assert_same T::DateTime, klass.column(:at).type
    assert_same T::Boolean, klass.column(:ok).type
  end
end
