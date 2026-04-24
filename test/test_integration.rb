# frozen_string_literal: true

require "test_helper"
require "pg_ephemeral"

module En57
  class TestIntegration < Minitest::Test
    SERVER = PgEphemeral.start
    CONNECTION = PG.connect(SERVER.url)

    Minitest.after_run do
      CONNECTION.close
      SERVER.shutdown
    end

    def ids = @ids ||= Hash.new { |h, k| h[k] = SecureRandom.uuid }

    def with_event_store =
      yield EventStore.new(PgRepository.new(CONNECTION, JsonSerializer.new))

    def setup =
      CONNECTION.exec("TRUNCATE TABLE tags, events RESTART IDENTITY CASCADE")

    def test_happy_path
      with_event_store do |event_store|
        events = [
          Event.new(id: ids[0], type: "CredditToppedUp", data: { amount: 100 }),
          Event.new(id: ids[1], type: "CredditToppedUp", data: { amount: 50 }),
        ]

        assert_equal(events, event_store.append(events).read.each.to_a)
      end
    end

    def test_append_with_fail_if_and_no_matches_appends_events
      repository = PgRepository.new(CONNECTION, JsonSerializer.new)

      repository.append(
        [Event.new(id: ids[0], type: "OrderPlaced")],
        fail_if:
          Query.new(
            criteria: [Query::Criteria.new(types: ["PriceChanged"], tags: [])],
          ),
      )

      assert_equal(
        [Event.new(id: ids[0], type: "OrderPlaced")],
        repository.read(Query.all),
      )
    end

    def test_append_with_fail_if_and_matches_raises_append_condition_violated
      repository = PgRepository.new(CONNECTION, JsonSerializer.new)
      existing_event = Event.new(id: ids[0], type: "OrderPlaced")
      repository.append([existing_event])

      assert_raises(AppendConditionViolated) do
        repository.append(
          [Event.new(id: ids[1], type: "ShipmentScheduled")],
          fail_if:
            Query.new(
              criteria: [Query::Criteria.new(types: ["OrderPlaced"], tags: [])],
            ),
        )
      end

      assert_equal([existing_event], repository.read(Query.all))
    end

    def test_append_with_after_ignores_matches_at_or_before_cutoff
      repository = PgRepository.new(CONNECTION, JsonSerializer.new)
      existing_event = Event.new(id: ids[0], type: "OrderPlaced")
      repository.append([existing_event])
      after =
        Integer(
          CONNECTION.exec("SELECT max(position) AS position FROM events")[0][
            "position"
          ],
        )

      repository.append(
        [Event.new(id: ids[1], type: "ShipmentScheduled")],
        fail_if:
          Query.new(
            criteria: [Query::Criteria.new(types: ["OrderPlaced"], tags: [])],
          ),
        after:,
      )

      assert_equal(
        [existing_event, Event.new(id: ids[1], type: "ShipmentScheduled")],
        repository.read(Query.all),
      )
    end

    def test_append_with_after_raises_if_match_is_after_cutoff
      repository = PgRepository.new(CONNECTION, JsonSerializer.new)
      existing_event = Event.new(id: ids[0], type: "OrderPlaced")
      repository.append([existing_event])

      assert_raises(AppendConditionViolated) do
        repository.append(
          [Event.new(id: ids[1], type: "ShipmentScheduled")],
          fail_if:
            Query.new(
              criteria: [Query::Criteria.new(types: ["OrderPlaced"], tags: [])],
            ),
          after: 0,
        )
      end

      assert_equal([existing_event], repository.read(Query.all))
    end

    def test_tags_round_trip
      with_event_store do |event_store|
        event =
          Event.new(id: ids[0], type: "OrderPlaced", tags: ["order_id:123"])

        assert_equal([event], event_store.append([event]).read.each.to_a)
      end
    end

    def test_read_filters_by_tags
      with_event_store do |event_store|
        events = [
          Event.new(
            id: ids[0],
            type: "OrderPlaced",
            tags: %w[order_id:123 tenant_id:acme],
          ),
          Event.new(
            id: ids[1],
            type: "OrderPlaced",
            tags: %w[order_id:456 tenant_id:acme],
          ),
        ]

        assert_equal(
          events.take(1),
          event_store
            .append(events)
            .read
            .with_tag("order_id:123", "tenant_id:acme")
            .each
            .to_a,
        )
      end
    end

    def test_read_filters_by_type
      with_event_store do |event_store|
        events = [
          Event.new(id: ids[0], type: "OrderPlaced"),
          Event.new(id: ids[1], type: "PriceChanged"),
        ]

        assert_equal(
          events.take(1),
          event_store.append(events).read.of_type("OrderPlaced").each.to_a,
        )
      end
    end

    def test_read_filters_by_any_of_types
      with_event_store do |event_store|
        events = [
          Event.new(id: ids[0], type: "PriceChanged"),
          Event.new(id: ids[1], type: "OrderPlaced"),
          Event.new(id: ids[2], type: "OrderCancelled"),
        ]

        assert_equal(
          events.drop(1),
          event_store
            .append(events)
            .read
            .of_type("OrderPlaced", "OrderCancelled")
            .each
            .to_a,
        )
      end
    end

    def test_read_filters_by_type_and_tag_on_same_item
      with_event_store do |event_store|
        events = [
          Event.new(id: ids[0], type: "OrderPlaced", tags: ["order_id:123"]),
          Event.new(id: ids[1], type: "OrderPlaced", tags: ["order_id:456"]),
          Event.new(id: ids[2], type: "PriceChanged", tags: ["order_id:123"]),
        ]

        assert_equal(
          events.take(1),
          event_store
            .append(events)
            .read
            .of_type("OrderPlaced")
            .with_tag("order_id:123")
            .each
            .to_a,
        )
      end
    end

    def test_read_or_combines_scopes_as_disjunction
      with_event_store do |event_store|
        events = [
          Event.new(id: ids[0], type: "OrderPlaced", tags: ["order_id:123"]),
          Event.new(id: ids[1], type: "OrderPlaced", tags: ["order_id:456"]),
          Event.new(id: ids[2], type: "PriceChanged", tags: ["order_id:999"]),
          Event.new(id: ids[3], type: "InventoryAdjusted", tags: ["sku:A1"]),
          Event.new(
            id: ids[4],
            type: "ShipmentScheduled",
            tags: ["order_id:123"],
          ),
        ]
        event_store.append(events)

        orders =
          event_store.read.of_type("OrderPlaced").with_tag("order_id:123")
        prices = event_store.read.of_type("PriceChanged")

        assert_equal(events.fetch_values(0, 2), (orders | prices).each.to_a)
      end
    end
  end
end
