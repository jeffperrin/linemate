# frozen_string_literal: true

require_relative "coverage_setup"

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "linemate"

require "minitest/autorun"

require_relative "support/models"
require_relative "support/schema"
require_relative "support/seed"
