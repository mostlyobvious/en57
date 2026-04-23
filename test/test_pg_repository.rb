# frozen_string_literal: true

require "test_helper"

module En57
  class TestPgRepository < Minitest::Test
    cover PgRepository

    def one = @one ||= SecureRandom.uuid
    def two = @two ||= SecureRandom.uuid

    def test_append_event_with_tags
      record_encoder = PG::TextEncoder::Record.new
      array_encoder = PG::TextEncoder::Array.new
      expected_events =
        array_encoder.encode(
          [
            record_encoder.encode(
              [
                one,
                "CredditToppedUp",
                '{"amount":100}',
                '{"amount":{"k":"Symbol"}}',
                '{"order_id":"123"}',
              ],
            ),
            record_encoder.encode(
              [
                two,
                "CredditToppedUp",
                '{"amount":50}',
                '{"amount":{"k":"Symbol"}}',
                '{"order_id":"234"}',
              ],
            ),
          ],
        )
      connection = Minitest::Mock.new
      connection.expect(
        :exec_params,
        nil,
        ["SELECT append_events($1::event_with_tags[])", [expected_events]],
      )

      repository = PgRepository.new(connection, JsonSerializer.new)
      repository.append(
        [
          Event.new(
            id: one,
            type: "CredditToppedUp",
            data: { amount: 100 },
            tags: { order_id: "123" },
          ),
          Event.new(
            id: two,
            type: "CredditToppedUp",
            data: { amount: 50 },
            tags: { order_id: "234" },
          ),
        ],
      )

      connection.verify
    end

    def test_read_events_with_tags
      connection = Minitest::Mock.new
      connection.expect(
        :exec_params,
        [
          {
            "id" => one,
            "type" => "CredditToppedUp",
            "data" => '{"amount":100}',
            "meta" => "{}",
            "tags" => '{"order_id":"123"}',
          },
          {
            "id" => two,
            "type" => "CredditToppedUp",
            "data" => '{"amount":50}',
            "meta" => "{}",
            "tags" => '{"order_id":"234"}',
          },
        ],
        ["SELECT id, type, data, meta, tags FROM read_events()", []],
      )

      repository = PgRepository.new(connection, JsonSerializer.new)

      assert_equal(
        [
          Event.new(
            id: one,
            type: "CredditToppedUp",
            data: {
              "amount" => 100,
            },
            tags: { order_id: "123" },
          ),
          Event.new(
            id: two,
            type: "CredditToppedUp",
            data: { "amount" => 50 },
            tags: { order_id: "234" },
          ),
        ],
        repository.read,
      )
      connection.verify
    end
  end
end
