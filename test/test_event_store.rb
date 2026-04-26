# frozen_string_literal: true

require "test_helper"

module En57
  class TestEventStore < Minitest::Test
    cover EventStore

    def test_append_event
      event = Event.new(type: "CreditsToppedUp")

      with_repository do |repository|
        repository.expect(
          :append,
          nil,
          [[event]],
          fail_if: Query.all,
          after: nil,
        )

        EventStore.new(repository).append([event])
      end
    end

    def test_read_returns_scope_for_query_all
      event = Event.new(type: "CreditsToppedUp")

      with_repository do |repository|
        repository.expect(:read, [event], [Query.all])

        result = EventStore.new(repository).read

        assert_instance_of(Scope, result)
        assert_equal([event], result.each.to_a)
      end
    end

    def test_return_self_from_append
      event = Event.new(type: "CreditsToppedUp")

      with_repository do |repository|
        repository.expect(
          :append,
          nil,
          [[event]],
          fail_if: Query.all,
          after: nil,
        )

        event_store = EventStore.new(repository)

        assert_equal(event_store, event_store.append([event]))
      end
    end

    def test_append_forwards_options
      event = Event.new(type: "CreditsToppedUp")

      with_repository do |repository|
        repository.expect(
          :append,
          nil,
          [[event]],
          fail_if: Query.all,
          after: 42,
        )

        EventStore.new(repository).append([event], after: 42)
      end
    end

    def test_append_accepts_scope_for_fail_if
      event = Event.new(type: "CreditsToppedUp")

      with_repository do |repository|
        event_store = EventStore.new(repository)
        fail_if = event_store.read.with_tag("order_id:123")
        repository.expect(
          :append,
          nil,
          [[event]],
          fail_if: fail_if.to_query,
          after: nil,
        )

        event_store.append([event], fail_if:)
      end
    end

    def test_append_accepts_query_for_fail_if
      event = Event.new(type: "CreditsToppedUp")

      with_repository do |repository|
        fail_if =
          Query.new(
            criteria: [Query::Criteria.new(types: ["OrderPlaced"], tags: [])],
          )
        repository.expect(:append, nil, [[event]], fail_if:, after: nil)

        EventStore.new(repository).append([event], fail_if:)
      end
    end

    private

    def with_repository
      repository = Minitest::Mock.new
      yield repository
      repository.verify
    end
  end
end
