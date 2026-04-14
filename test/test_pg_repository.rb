# frozen_string_literal: true

require "test_helper"

module En57
  class TestPgRepository < Minitest::Test
    cover PgRepository

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

      repository = PgRepository.new(connection, JsonSerializer.new)
      repository.append(
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
        ["SELECT type, data FROM read_events()", []]
      )

      repository = PgRepository.new(connection, JsonSerializer.new)

      assert_equal(
        [
          Event.new(type: "CredditToppedUp", data: {"amount" => 100}),
          Event.new(type: "CredditToppedUp", data: {"amount" => 50})
        ],
        repository.read
      )
      connection.verify
    end
  end
end
