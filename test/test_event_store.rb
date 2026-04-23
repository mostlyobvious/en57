# frozen_string_literal: true

require "test_helper"

module En57
  class TestEventStore < Minitest::Test
    cover EventStore

    def test_append_event
      repository = Minitest::Mock.new
      events = [
        Event.new(
          id: SecureRandom.uuid,
          type: "CredditToppedUp",
          data: {
            amount: 100,
          },
        ),
      ]
      repository.expect(:append, nil, [events])

      EventStore.new(repository).append(events)

      repository.verify
    end

    def test_read_returns_scope_for_query_all
      repository = Minitest::Mock.new
      events = [
        Event.new(
          id: SecureRandom.uuid,
          type: "CredditToppedUp",
          data: {
            "amount" => 100,
          },
        ),
      ]
      repository.expect(:read, events, [Query.all])

      result = EventStore.new(repository).read

      assert_instance_of(Scope, result)
      assert_instance_of(Enumerator, result.each)
      assert_equal(events, result.each.to_a)
      repository.verify
    end
  end
end
