# frozen_string_literal: true

require "test_helper"
require "pg"
require "pg_ephemeral"

module En57
  class TestIntegration < Minitest::Test
    def one = @one ||= SecureRandom.uuid
    def two = @two ||= SecureRandom.uuid

    def test_happy_path
      PgEphemeral.with_connection do |connection|
        event_store =
          EventStore.new(PgRepository.new(connection, JsonSerializer.new))

        event_store.append(
          [
            Event.new(id: one, type: "CredditToppedUp", data: { amount: 100 }),
            Event.new(
              id: two,
              type: "CredditToppedUp",
              data: {
                "amount" => 50,
              },
            ),
          ],
        )

        assert_equal(
          [
            Event.new(id: one, type: "CredditToppedUp", data: { amount: 100 }),
            Event.new(
              id: two,
              type: "CredditToppedUp",
              data: {
                "amount" => 50,
              },
            ),
          ],
          event_store.read,
        )
      end
    end

    def test_tags_round_trip
      PgEphemeral.with_connection do |connection|
        event_store =
          EventStore.new(PgRepository.new(connection, JsonSerializer.new))

        event_store.append(
          [
            Event.new(
              id: one,
              type: "OrderPlaced",
              data: { total: 42 },
              tags: { order_id: "123" },
            ),
          ],
        )

        assert_equal(
          [
            Event.new(
              id: one,
              type: "OrderPlaced",
              data: { total: 42 },
              tags: { order_id: "123" },
            ),
          ],
          event_store.read,
        )
      end
    end
  end
end
