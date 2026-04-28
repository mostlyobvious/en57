# frozen_string_literal: true

require "minitest/autorun"
require "minitest/mock"
require "mutant/minitest/coverage"

require "sequel"
require "active_record"
require "en57"
require "securerandom"
require "concurrent-ruby"
require "pg_ephemeral"

module En57
  class IntegrationTest < Minitest::Test
    POOL_SIZE = 8
    SERVER = PgEphemeral.start
    CONNECTION = PG.connect(SERVER.url)
    SEQUEL_DB =
      Sequel.connect(
        SERVER.url,
        preconnect: :concurrently,
        max_connections: POOL_SIZE,
      )
    ActiveRecord::Base.establish_connection("#{SERVER.url}&pool=#{POOL_SIZE}")
    AR_POOL = ActiveRecord::Base.connection_pool
    ADAPTERS = {
      pg: -> { PgAdapter.new(SERVER.url, max_connections: POOL_SIZE) },
      sequel: -> { SequelAdapter.new(SEQUEL_DB) },
      active_record: -> { ActiveRecordAdapter.new(AR_POOL) },
    }

    def setup =
      CONNECTION.exec("TRUNCATE TABLE tags, events RESTART IDENTITY CASCADE")

    Minitest.after_run do
      ActiveRecord::Base.connection_pool.disconnect!
      SEQUEL_DB.disconnect
      CONNECTION.close
      SERVER.shutdown
    end
  end
end
