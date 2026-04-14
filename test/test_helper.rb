# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

ENV["RBS_TEST_TARGET"] ||= "En57::*"
ENV["RBS_TEST_LOGLEVEL"] ||= "error"
require "rbs/test/setup"

require "en57"

require "minitest/autorun"
require "minitest/mock"
require "mutant/minitest/coverage"
