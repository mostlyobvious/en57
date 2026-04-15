# frozen_string_literal: true

require "test_helper"
require "pg"

module En57
  class TestIntegration < Minitest::Test
    def setup
      @connection = PG.connect(ENV.fetch("DATABASE_URL"))
      @connection.exec(File.read(File.expand_path("../db/schema.sql", __dir__)))
      @connection.exec("TRUNCATE events")
      @event_store =
        EventStore.new(PgRepository.new(@connection, JsonSerializer.new))
    end

    def teardown
      @connection&.close
    end

    def test_happy_path
      @event_store.append(
        [
          Event.new(type: "CredditToppedUp", data: { amount: 100 }),
          Event.new(type: "CredditToppedUp", data: { "amount" => 50 }),
        ],
      )

      assert_equal(
        [
          Event.new(type: "CredditToppedUp", data: { amount: 100 }),
          Event.new(type: "CredditToppedUp", data: { "amount" => 50 }),
        ],
        @event_store.read,
      )
    end
  end
end
