# frozen_string_literal: true

require "test_helper"

module En57
  class TestEventStore < Minitest::Test
    cover EventStore

    Event = Data.define(:type, :data)

    def test_append_event
      connection = Minitest::Mock.new
      connection.expect(
        :exec_params,
        nil,
        [
          "SELECT append_events($1)",
          ['[{"type":"CredditToppedUp","data":{"amount":100}},{"type":"CredditToppedUp","data":{"amount":50}}]']
        ]
      )

      event_store = EventStore.new(connection)
      event_store.append(
        [
          Event.new(type: "CredditToppedUp", data: {amount: 100}),
          Event.new(type: "CredditToppedUp", data: {amount: 50})
        ]
      )

      connection.verify
    end

    def test_read_events
      connection = Minitest::Mock.new
      connection.expect(
        :exec_params,
        [
          {"type" => "CredditToppedUp", "data" => '{"amount":100}'},
          {"type" => "CredditToppedUp", "data" => '{"amount":50}'}
        ],
        ["SELECT type, data FROM events", []]
      )

      event_store = EventStore.new(connection)

      assert_equal(
        [
          En57::Event.new(type: "CredditToppedUp", data: {"amount" => 100}),
          En57::Event.new(type: "CredditToppedUp", data: {"amount" => 50})
        ],
        event_store.read
      )
      connection.verify
    end
  end
end
