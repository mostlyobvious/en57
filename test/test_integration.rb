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

    def with_event_store
      yield(EventStore.new(PgRepository.new(CONNECTION, JsonSerializer.new)))
    end

    def setup
      CONNECTION.exec("TRUNCATE TABLE tags, events RESTART IDENTITY CASCADE")
    end

    def test_happy_path
      with_event_store do |event_store|
        event_store.append(
          [
            Event.new(id: one, type: "CredditToppedUp", data: { amount: 100 }),
            Event.new(id: two, type: "CredditToppedUp", data: { "amount" => 50 }),
          ],
        )

        assert_equal(
          [
            Event.new(id: one, type: "CredditToppedUp", data: { amount: 100 }),
            Event.new(id: two, type: "CredditToppedUp", data: { "amount" => 50 }),
          ],
          event_store.read.each.to_a,
        )
      end
    end

    def test_tags_round_trip
      with_event_store do |event_store|
        event_store.append(
          [
            Event.new(
              id: one,
              type: "OrderPlaced",
              data: {
                total: 42,
              },
              tags: {
                order_id: "123",
              },
            ),
          ],
        )

        assert_equal(
          [
            Event.new(
              id: one,
              type: "OrderPlaced",
              data: {
                total: 42,
              },
              tags: {
                order_id: "123",
              },
            ),
          ],
          event_store.read.each.to_a,
        )
      end
    end

    def test_read_filters_by_tags
      with_event_store do |event_store|
        event_store.append(
          [
            Event.new(
              id: one,
              type: "OrderPlaced",
              data: {
                total: 42,
              },
              tags: {
                order_id: "123",
                tenant_id: "acme",
              },
            ),
            Event.new(
              id: two,
              type: "OrderPlaced",
              data: {
                total: 99,
              },
              tags: {
                order_id: "456",
                tenant_id: "acme",
              },
            ),
          ],
        )

        assert_equal(
          [
            Event.new(
              id: one,
              type: "OrderPlaced",
              data: {
                total: 42,
              },
              tags: {
                order_id: "123",
                tenant_id: "acme",
              },
            ),
          ],
          event_store.read.with_tag(order_id: "123", tenant_id: "acme").each.to_a,
        )
      end
    end

    def test_read_filters_by_type
      with_event_store do |event_store|
        event_store.append(
          [
            Event.new(
              id: one,
              type: "OrderPlaced",
              data: {
                total: 42,
              },
              tags: {
              },
            ),
            Event.new(
              id: two,
              type: "PriceChanged",
              data: {
                value: 99,
              },
              tags: {
              },
            ),
          ],
        )

        assert_equal(
          [
            Event.new(
              id: one,
              type: "OrderPlaced",
              data: {
                total: 42,
              },
              tags: {
              },
            ),
          ],
          event_store.read.of_type("OrderPlaced").each.to_a,
        )
      end
    end

    def test_read_filters_by_any_of_types
      with_event_store do |event_store|
        three = SecureRandom.uuid

        event_store.append(
          [
            Event.new(
              id: one,
              type: "OrderPlaced",
              data: {
                total: 42,
              },
              tags: {
              },
            ),
            Event.new(
              id: two,
              type: "PriceChanged",
              data: {
                value: 99,
              },
              tags: {
              },
            ),
            Event.new(
              id: three,
              type: "OrderCancelled",
              data: {
                reason: "dup",
              },
              tags: {
              },
            ),
          ],
        )

        assert_equal(
          [
            Event.new(
              id: one,
              type: "OrderPlaced",
              data: {
                total: 42,
              },
              tags: {
              },
            ),
            Event.new(
              id: three,
              type: "OrderCancelled",
              data: {
                reason: "dup",
              },
              tags: {
              },
            ),
          ],
          event_store.read.of_type("OrderPlaced", "OrderCancelled").each.to_a,
        )
      end
    end

    def test_read_filters_by_type_and_tag_on_same_item
      with_event_store do |event_store|
        three = SecureRandom.uuid

        event_store.append(
          [
            Event.new(
              id: one,
              type: "OrderPlaced",
              data: {
                total: 42,
              },
              tags: {
                order_id: "123",
              },
            ),
            Event.new(
              id: two,
              type: "OrderPlaced",
              data: {
                total: 99,
              },
              tags: {
                order_id: "456",
              },
            ),
            Event.new(
              id: three,
              type: "PriceChanged",
              data: {
                value: 10,
              },
              tags: {
                order_id: "123",
              },
            ),
          ],
        )

        assert_equal(
          [
            Event.new(
              id: one,
              type: "OrderPlaced",
              data: {
                total: 42,
              },
              tags: {
                order_id: "123",
              },
            ),
          ],
          event_store
            .read
            .of_type("OrderPlaced")
            .with_tag(order_id: "123")
            .each
            .to_a,
        )
      end
    end

    def test_read_or_combines_scopes_as_disjunction
      with_event_store do |event_store|
        three = SecureRandom.uuid
        four = SecureRandom.uuid

        event_store.append(
          [
            Event.new(
              id: one,
              type: "OrderPlaced",
              data: {
                total: 42,
              },
              tags: {
                order_id: "123",
              },
            ),
            Event.new(
              id: two,
              type: "OrderPlaced",
              data: {
                total: 99,
              },
              tags: {
                order_id: "456",
              },
            ),
            Event.new(
              id: three,
              type: "PriceChanged",
              data: {
                value: 10,
              },
              tags: {
                order_id: "999",
              },
            ),
            Event.new(
              id: four,
              type: "InventoryAdjusted",
              data: {
                delta: 1,
              },
              tags: {
                sku: "A1",
              },
            ),
          ],
        )

        orders = event_store.read.of_type("OrderPlaced").with_tag(order_id: "123")
        prices = event_store.read.of_type("PriceChanged")

        assert_equal(
          [
            Event.new(
              id: one,
              type: "OrderPlaced",
              data: {
                total: 42,
              },
              tags: {
                order_id: "123",
              },
            ),
            Event.new(
              id: three,
              type: "PriceChanged",
              data: {
                value: 10,
              },
              tags: {
                order_id: "999",
              },
            ),
          ],
          (orders | prices).each.to_a,
        )
      end
    end
  end
end
