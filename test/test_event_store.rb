# frozen_string_literal: true

require "test_helper"

class TestEventStore < Minitest::Test
  cover En57::EventStore

  Event = Data.define(:type, :data)

  def test_append_event
    connection = Minitest::Mock.new
    connection.expect(
      :exec_params,
      nil,
      [
        "INSERT INTO events (type, data) VALUES ($1, $2), ($3, $4)",
        %w[CredditToppedUp {"amount":100} CredditToppedUp {"amount":50}]
      ]
    )

    event_store = En57::EventStore.new(connection)
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

    event_store = En57::EventStore.new(connection)

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
