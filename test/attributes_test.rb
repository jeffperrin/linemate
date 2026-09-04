# frozen_string_literal: true

require "test_helper"

class AttributesTest < Minitest::Test
  class Player < Linemate::Model
    col :id, Int
    col :name, String
    col :goals, Int, default: 0
    col :active, Boolean, default: true
    col :born_on, Date, null: true
    col :signed_at, DateTime, null: true

    def name
      super.upcase
    end
  end

  def test_new_record_defaults
    p = Player.new(name: "gretzky")
    assert p.new_record?
    refute p.persisted?
    assert_nil p.id
    assert_equal 0, p.goals
    assert_equal true, p.active
    assert_nil p.born_on
  end

  def test_initialize_casts_through_types
    p = Player.new(name: :orr, goals: "4", active: "f", born_on: "1948-03-20")
    assert_equal 4, p.goals
    assert_equal false, p.active
    assert_equal ::Date.new(1948, 3, 20), p.born_on
  end

  def test_unknown_attribute_raises
    assert_raises(Linemate::UnknownColumn) { Player.new(assists: 3) }
    assert_raises(Linemate::UnknownColumn) { Player.new[:assists] }
  end

  def test_nil_on_not_null_column_raises
    p = Player.new(name: "x")
    err = assert_raises(Linemate::NotNullViolation) { p.goals = nil }
    assert_match(/goals cannot be nil/, err.message)
    p.born_on = nil
    p.id = nil
    assert_nil p.id
  end

  def test_accessors_are_real_methods_and_overridable
    p = Player.new(name: "howe")
    assert Player.method_defined?(:name)
    assert Player.method_defined?(:goals=)
    assert_equal "HOWE", p.name
    assert_equal "howe", p[:name]
    p[:goals] = "9"
    assert_equal 9, p.goals
  end

  def test_instantiate_from_row
    row = {"id" => 9, "name" => "hull", "goals" => 50, "active" => 1,
           "born_on" => "1939-01-03", "signed_at" => "1957-10-01T00:00:00.000000Z",
           "undeclared" => "ignored"}
    p = Player.instantiate(row)
    assert p.persisted?
    assert_equal 9, p.id
    assert_equal true, p.active
    assert_equal ::Date.new(1939, 1, 3), p.born_on
    assert_equal Time.utc(1957, 10, 1), p.signed_at
    assert_equal %i[id name goals active born_on signed_at], p.attributes.keys
  end

  def test_equality_and_hash
    a = Player.instantiate("id" => 1, "name" => "a")
    b = Player.instantiate("id" => 1, "name" => "b")
    c = Player.instantiate("id" => 2, "name" => "a")
    assert_equal a, b
    assert_equal a.hash, b.hash
    refute_equal a, c
    refute_equal Player.new(name: "a"), Player.new(name: "a")
    assert_equal 1, [a, b].uniq.size
  end

  def test_inspect
    p = Player.instantiate("id" => 1, "name" => "a", "goals" => 2, "active" => 1)
    assert_equal '#<AttributesTest::Player id: 1, name: "a", goals: 2, active: true, born_on: nil, signed_at: nil>', p.inspect
  end

  def test_attributes_is_a_copy
    p = Player.new(name: "a")
    p.attributes[:name] = "b"
    assert_equal "A", p.name
  end
end
