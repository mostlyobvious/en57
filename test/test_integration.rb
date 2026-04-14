# frozen_string_literal: true

require "test_helper"
require "pg"

module En57
  class TestIntegration < Minitest::Test
    def setup
      @connection = PG.connect(ENV.fetch("DATABASE_URL", "postgres:///en57_test"))
      @connection.exec("CREATE TABLE IF NOT EXISTS events (type TEXT NOT NULL, data JSONB NOT NULL)")
      @connection.exec("TRUNCATE events")
      @event_store = EventStore.new(@connection)
    end

    def teardown
      @connection&.close
    end

    def test_happy_path
      @event_store.append(
        [
          Event.new(type: "CredditToppedUp", data: {amount: 100}),
          Event.new(type: "CredditToppedUp", data: {amount: 50})
        ]
      )

      assert_equal(
        [
          Event.new(type: "CredditToppedUp", data: {"amount" => 100}),
          Event.new(type: "CredditToppedUp", data: {"amount" => 50})
        ],
        @event_store.read
      )
    end
  end
end
