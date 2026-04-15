# frozen_string_literal: true

require "test_helper"

module En57
  class TestEventStore < Minitest::Test
    cover EventStore

    def test_append_event
      repository = Minitest::Mock.new
      events = [Event.new(type: "CredditToppedUp", data: { amount: 100 })]
      repository.expect(:append, nil, [events])

      EventStore.new(repository).append(events)

      repository.verify
    end

    def test_read_events
      repository = Minitest::Mock.new
      events = [Event.new(type: "CredditToppedUp", data: { "amount" => 100 })]
      repository.expect(:read, events)

      assert_equal(events, EventStore.new(repository).read)
      repository.verify
    end
  end
end
