# frozen_string_literal: true

require "bundler/gem_tasks"
require "minitest/test_task"

Minitest::TestTask.create do |t|
  t.test_prelude = %(require "./test/coverage_setup")
end

require "standard/rake"

task default: %i[test standard]
