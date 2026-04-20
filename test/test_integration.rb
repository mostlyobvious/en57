# frozen_string_literal: true

require "test_helper"
require "pg"
require "pg_ephemeral"

module En57
  class TestIntegration < Minitest::Test
    def test_happy_path
      PgEphemeral.with_connection do |connection|
        event_store =
          EventStore.new(PgRepository.new(connection, JsonSerializer.new))

        event_store.append(
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
          event_store.read,
        )
      end
    end
  end
end
