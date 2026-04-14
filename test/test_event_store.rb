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
      ["INSERT INTO events (type, data) VALUES ($1, $2)", ["CredditToppedUp", '{"amount":100}']]
    )
    connection.expect(
      :exec_params,
      nil,
      ["INSERT INTO events (type, data) VALUES ($1, $2)", ["CredditToppedUp", '{"amount":50}']]
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
end
