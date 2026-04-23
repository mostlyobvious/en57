# frozen_string_literal: true

require "test_helper"
require "pg"
require "pg_ephemeral"

module En57
  class TestIntegration < Minitest::Test
    SERVER = PgEphemeral.start
    CONNECTION = PG.connect(SERVER.url)

    Minitest.after_run do
      CONNECTION.close
      SERVER.shutdown
    end

    def one = @one ||= SecureRandom.uuid
    def two = @two ||= SecureRandom.uuid

    def setup
      CONNECTION.exec("TRUNCATE TABLE tags, events RESTART IDENTITY CASCADE")
    end

    def test_happy_path
      event_store = EventStore.new(PgRepository.new(CONNECTION, JsonSerializer.new))

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
        event_store.read.each.to_a,
      )
    end

    def test_tags_round_trip
      event_store = EventStore.new(PgRepository.new(CONNECTION, JsonSerializer.new))

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
        event_store.read.each.to_a,
      )
    end

    def test_read_filters_by_tags
      event_store = EventStore.new(PgRepository.new(CONNECTION, JsonSerializer.new))

      event_store.append(
        [
          Event.new(
            id: one,
            type: "OrderPlaced",
            data: { total: 42 },
            tags: { order_id: "123", tenant_id: "acme" },
          ),
          Event.new(
            id: two,
            type: "OrderPlaced",
            data: { total: 99 },
            tags: { order_id: "456", tenant_id: "acme" },
          ),
        ],
      )

      assert_equal(
        [
          Event.new(
            id: one,
            type: "OrderPlaced",
            data: { total: 42 },
            tags: { order_id: "123", tenant_id: "acme" },
          ),
        ],
        event_store.read.with_tag(order_id: "123", tenant_id: "acme").each.to_a,
      )
    end
  end
end
