# frozen_string_literal: true

require "minitest/autorun"
require "minitest/mock"
require "mutant/minitest/coverage"

require "en57"
require "securerandom"
require "concurrent-ruby"
require "pg_ephemeral"
require "sequel"

module En57
  class IntegrationTest < Minitest::Test
    SERVER = PgEphemeral.start
    CONNECTION = PG.connect(SERVER.url)
    SEQUEL_DB = Sequel.connect(SERVER.url)
    ADAPTERS = {
      pg: -> { PgAdapter.new(SERVER.url) },
      sequel: -> { SequelAdapter.new(SEQUEL_DB) },
    }

    def setup =
      CONNECTION.exec("TRUNCATE TABLE tags, events RESTART IDENTITY CASCADE")

    Minitest.after_run do
      SEQUEL_DB.disconnect
      CONNECTION.close
      SERVER.shutdown
    end
  end
end
