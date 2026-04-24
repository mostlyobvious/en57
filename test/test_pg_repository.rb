# frozen_string_literal: true

require "test_helper"

module En57
  class TestPgRepository < Minitest::Test
    cover PgRepository

    def ids = @ids ||= Hash.new { |h, k| h[k] = SecureRandom.uuid }

    def array_encoder = @array_encoder ||= PG::TextEncoder::Array.new

    def record_encoder = @record_encoder ||= PG::TextEncoder::Record.new

    def test_append_event_with_tags
      expected_events =
        array_encoder.encode(
          [
            record_encoder.encode(
              [
                ids[0],
                "CredditToppedUp",
                '{"amount":100}',
                '{"amount":{"k":"Symbol"}}',
                '{"order_id":"123"}',
              ],
            ),
            record_encoder.encode(
              [
                ids[1],
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
            id: ids[0],
            type: "CredditToppedUp",
            data: {
              amount: 100,
            },
            tags: {
              order_id: "123",
            },
          ),
          Event.new(
            id: ids[1],
            type: "CredditToppedUp",
            data: {
              amount: 50,
            },
            tags: {
              order_id: "234",
            },
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
            "id" => ids[0],
            "type" => "CredditToppedUp",
            "data" => '{"amount":100}',
            "meta" => "{}",
            "tags" => '{"order_id":"123"}',
          },
          {
            "id" => ids[1],
            "type" => "CredditToppedUp",
            "data" => '{"amount":50}',
            "meta" => "{}",
            "tags" => '{"order_id":"234"}',
          },
        ],
        [
          "SELECT id, type, data, meta, tags FROM read_events($1::jsonb[])",
          [array_encoder.encode([])],
        ],
      )

      repository = PgRepository.new(connection, JsonSerializer.new)

      assert_equal(
        [
          Event.new(
            id: ids[0],
            type: "CredditToppedUp",
            data: {
              "amount" => 100,
            },
            tags: {
              order_id: "123",
            },
          ),
          Event.new(
            id: ids[1],
            type: "CredditToppedUp",
            data: {
              "amount" => 50,
            },
            tags: {
              order_id: "234",
            },
          ),
        ],
        repository.read(Query.all),
      )
      connection.verify
    end

    def test_read_events_filtered_by_tags
      query =
        Query.new(
          criteria: [Query::Criteria.new(types: [], tags: { order_id: "123" })],
        )
      connection = Minitest::Mock.new
      connection.expect(
        :exec_params,
        [
          {
            "id" => ids[0],
            "type" => "CredditToppedUp",
            "data" => '{"amount":100}',
            "meta" => "{}",
            "tags" => '{"order_id":"123"}',
          },
        ],
        [
          "SELECT id, type, data, meta, tags FROM read_events($1::jsonb[])",
          [array_encoder.encode(['{"types":[],"tags":{"order_id":"123"}}'])],
        ],
      )

      repository = PgRepository.new(connection, JsonSerializer.new)

      assert_equal(
        [
          Event.new(
            id: ids[0],
            type: "CredditToppedUp",
            data: {
              "amount" => 100,
            },
            tags: {
              order_id: "123",
            },
          ),
        ],
        repository.read(query),
      )
      connection.verify
    end

    def test_read_events_with_wildcard_query_item
      query = Query.new(criteria: [Query::Criteria.new(types: [], tags: {})])
      connection = Minitest::Mock.new
      connection.expect(
        :exec_params,
        [
          {
            "id" => ids[0],
            "type" => "CredditToppedUp",
            "data" => '{"amount":100}',
            "meta" => "{}",
            "tags" => '{"order_id":"123"}',
          },
        ],
        [
          "SELECT id, type, data, meta, tags FROM read_events($1::jsonb[])",
          [array_encoder.encode(['{"types":[],"tags":{}}'])],
        ],
      )

      repository = PgRepository.new(connection, JsonSerializer.new)

      assert_equal(
        [
          Event.new(
            id: ids[0],
            type: "CredditToppedUp",
            data: {
              "amount" => 100,
            },
            tags: {
              order_id: "123",
            },
          ),
        ],
        repository.read(query),
      )
      connection.verify
    end

    def test_read_events_with_or_tag_predicates
      query =
        Query.new(
          criteria: [
            Query::Criteria.new(types: [], tags: { order_id: "123" }),
            Query::Criteria.new(types: [], tags: { order_id: "456" }),
          ],
        )
      connection = Minitest::Mock.new
      connection.expect(
        :exec_params,
        [
          {
            "id" => ids[0],
            "type" => "CredditToppedUp",
            "data" => '{"amount":100}',
            "meta" => "{}",
            "tags" => '{"order_id":"123"}',
          },
        ],
        [
          "SELECT id, type, data, meta, tags FROM read_events($1::jsonb[])",
          [
            array_encoder.encode(
              [
                '{"types":[],"tags":{"order_id":"123"}}',
                '{"types":[],"tags":{"order_id":"456"}}',
              ],
            ),
          ],
        ],
      )

      repository = PgRepository.new(connection, JsonSerializer.new)

      assert_equal(
        [
          Event.new(
            id: ids[0],
            type: "CredditToppedUp",
            data: {
              "amount" => 100,
            },
            tags: {
              order_id: "123",
            },
          ),
        ],
        repository.read(query),
      )
      connection.verify
    end

    def test_read_events_filtered_by_type
      query =
        Query.new(
          criteria: [Query::Criteria.new(types: ["OrderPlaced"], tags: {})],
        )
      connection = Minitest::Mock.new
      connection.expect(
        :exec_params,
        [
          {
            "id" => ids[0],
            "type" => "OrderPlaced",
            "data" => '{"amount":100}',
            "meta" => "{}",
            "tags" => "{}",
          },
        ],
        [
          "SELECT id, type, data, meta, tags FROM read_events($1::jsonb[])",
          [array_encoder.encode(['{"types":["OrderPlaced"],"tags":{}}'])],
        ],
      )

      repository = PgRepository.new(connection, JsonSerializer.new)

      assert_equal(
        [
          Event.new(
            id: ids[0],
            type: "OrderPlaced",
            data: {
              "amount" => 100,
            },
            tags: {
            },
          ),
        ],
        repository.read(query),
      )
      connection.verify
    end
  end
end
