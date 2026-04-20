# frozen_string_literal: true

require "test_helper"

module En57
  class TestPgRepository < Minitest::Test
    cover PgRepository

    def test_append_event
      record_encoder = PG::TextEncoder::Record.new
      expected_array =
        PG::TextEncoder::Array.new.encode(
          [
            record_encoder.encode(
              %w[CredditToppedUp {"amount":100} {"amount":{"k":"Symbol"}}],
            ),
            record_encoder.encode(
              %w[CredditToppedUp {"amount":50} {"amount":{"k":"Symbol"}}],
            ),
          ],
        )
      connection = Minitest::Mock.new
      connection.expect(
        :exec_params,
        nil,
        ["SELECT append_events($1::event[])", [expected_array]],
      )

      repository = PgRepository.new(connection, JsonSerializer.new)
      repository.append(
        [
          Event.new(type: "CredditToppedUp", data: { amount: 100 }),
          Event.new(type: "CredditToppedUp", data: { amount: 50 }),
        ],
      )

      connection.verify
    end

    def test_read_events
      connection = Minitest::Mock.new
      connection.expect(
        :exec_params,
        [
          {
            "type" => "CredditToppedUp",
            "data" => '{"amount":100}',
            "meta" => "{}",
          },
          {
            "type" => "CredditToppedUp",
            "data" => '{"amount":50}',
            "meta" => "{}",
          },
        ],
        ["SELECT type, data, meta FROM read_events()", []],
      )

      repository = PgRepository.new(connection, JsonSerializer.new)

      assert_equal(
        [
          Event.new(type: "CredditToppedUp", data: { "amount" => 100 }),
          Event.new(type: "CredditToppedUp", data: { "amount" => 50 }),
        ],
        repository.read,
      )
      connection.verify
    end
  end
end
