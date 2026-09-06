# frozen_string_literal: true

return unless ENV["COVERAGE"]

require "simplecov"

SimpleCov.start do
  add_filter "/test/"
  enable_coverage :branch
  minimum_coverage line: 95, branch: 80
end
