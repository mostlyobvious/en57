# frozen_string_literal: true

require "minitest/autorun"
require "minitest/mock"
require "mutant/minitest/coverage"

require "en57"
require "securerandom"
require "concurrent-ruby"
require "pg_ephemeral"

module En57
  SERVER = PgEphemeral.start
  CONNECTION = PG.connect(SERVER.url)

  Minitest.after_run do
    CONNECTION.close
    SERVER.shutdown
  end
end
