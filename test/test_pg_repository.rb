# frozen_string_literal: true

require "test_helper"

module En57
  class TestPgRepository < Minitest::Test
    cover PgRepository

    def ids = @ids ||= Hash.new { |h, k| h[k] = SecureRandom.uuid }

    def array_encoder = @array_encoder ||= PG::TextEncoder::Array.new

    def record_encoder = @record_encoder ||= PG::TextEncoder::Record.new

    def spy_connection
      Class
        .new do
          attr_accessor :error
          attr_reader :calls

          def initialize
            @calls = []
          end

          def exec(sql)
            @calls << [:exec, sql]
          end

          def exec_params(sql, params)
            @calls << [:exec_params, sql, params]
            raise error if error
          end
        end
        .new
    end

    def pg_error(result_sqlstate: nil, sqlstate: nil)
      error = PG::Error.new("boom")
      result = Object.new
      result.define_singleton_method(:error_field) do |field|
        field == PG::Result::PG_DIAG_SQLSTATE ? result_sqlstate : nil
      end
      error.define_singleton_method(:result) { result_sqlstate.nil? ? nil : result }
      error.define_singleton_method(:sqlstate) { sqlstate }
      error
    end

    def test_append_wraps_write_in_serializable_transaction
      expected_events =
        array_encoder.encode(
          [
            record_encoder.encode(
              [
                ids[0],
                "CredditToppedUp",
                '{"amount":100}',
                '{"amount":{"k":"Symbol"}}',
                "{order_id:123}",
              ],
            ),
            record_encoder.encode(
              [
                ids[1],
                "CredditToppedUp",
                '{"amount":50}',
                '{"amount":{"k":"Symbol"}}',
                "{order_id:234}",
              ],
            ),
          ],
        )
      connection = spy_connection

      repository = PgRepository.new(connection, JsonSerializer.new)
      repository.append(
        [
          Event.new(
            id: ids[0],
            type: "CredditToppedUp",
            data: {
              amount: 100,
            },
            tags: ["order_id:123"],
          ),
          Event.new(
            id: ids[1],
            type: "CredditToppedUp",
            data: {
              amount: 50,
            },
            tags: ["order_id:234"],
          ),
        ],
        fail_if: Query.all,
        after: nil,
      )

      assert_equal(
        [
          [:exec, "BEGIN ISOLATION LEVEL SERIALIZABLE"],
          [
            :exec_params,
            "SELECT append_events($1::event_with_tags[], $2::jsonb)",
            [expected_events, "{}"],
          ],
          [:exec, "COMMIT"],
        ],
        connection.calls,
      )
    end

    def test_append_passes_fail_if_and_after_conditions
      connection = spy_connection

      repository = PgRepository.new(connection, JsonSerializer.new)
      repository.append(
        [],
        fail_if:
          Query.new(
            criteria: [Query::Criteria.new(types: ["OrderPlaced"], tags: [])],
          ),
        after: 42,
      )

      assert_equal(
        {
          "fail_if_events_match" => [{ "types" => ["OrderPlaced"] }],
          "after" => 42,
        },
        JSON.parse(connection.calls[1][2][1]),
      )
    end

    def test_append_rolls_back_transaction_on_pg_failure
      connection = spy_connection
      connection.error = PG::Error.new("boom")

      repository = PgRepository.new(connection, JsonSerializer.new)

      assert_raises(PG::Error) do
        repository.append([], fail_if: Query.all, after: nil)
      end
      assert_equal(
        [
          [:exec, "BEGIN ISOLATION LEVEL SERIALIZABLE"],
          [
            :exec_params,
            "SELECT append_events($1::event_with_tags[], $2::jsonb)",
            [array_encoder.encode([]), "{}"],
          ],
          [:exec, "ROLLBACK"],
        ],
        connection.calls,
      )
    end

    def test_append_raises_append_condition_violated_from_pg_result_sqlstate
      connection = spy_connection
      connection.error = pg_error(result_sqlstate: "P0001")

      repository = PgRepository.new(connection, JsonSerializer.new)

      assert_raises(AppendConditionViolated) do
        repository.append([], fail_if: Query.all, after: nil)
      end
    end

    def test_append_raises_append_condition_violated_from_pg_error_sqlstate
      connection = spy_connection
      connection.error = pg_error(sqlstate: "P0001")

      repository = PgRepository.new(connection, JsonSerializer.new)

      assert_raises(AppendConditionViolated) do
        repository.append([], fail_if: Query.all, after: nil)
      end
    end

    def test_append_reraises_pg_error_for_non_append_condition_sqlstate
      connection = spy_connection
      connection.error = pg_error(sqlstate: "23505")

      repository = PgRepository.new(connection, JsonSerializer.new)

      assert_raises(PG::Error) do
        repository.append([], fail_if: Query.all, after: nil)
      end
    end

    def test_append_rolls_back_transaction_on_failure
      connection = spy_connection
      connection.error = RuntimeError.new("boom")

      repository = PgRepository.new(connection, JsonSerializer.new)

      assert_raises(RuntimeError) do
        repository.append([], fail_if: Query.all, after: nil)
      end
      assert_equal(
        [
          [:exec, "BEGIN ISOLATION LEVEL SERIALIZABLE"],
          [
            :exec_params,
            "SELECT append_events($1::event_with_tags[], $2::jsonb)",
            [array_encoder.encode([]), "{}"],
          ],
          [:exec, "ROLLBACK"],
        ],
        connection.calls,
      )
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
            "tags" => "{order_id:123}",
          },
          {
            "id" => ids[1],
            "type" => "CredditToppedUp",
            "data" => '{"amount":50}',
            "meta" => "{}",
            "tags" => "{order_id:234}",
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
            tags: ["order_id:123"],
          ),
          Event.new(
            id: ids[1],
            type: "CredditToppedUp",
            data: {
              "amount" => 50,
            },
            tags: ["order_id:234"],
          ),
        ],
        repository.read(Query.all),
      )
      connection.verify
    end

    def test_read_events_filtered_by_tags
      query =
        Query.new(
          criteria: [Query::Criteria.new(types: [], tags: ["order_id:123"])],
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
            "tags" => "{order_id:123}",
          },
        ],
        [
          "SELECT id, type, data, meta, tags FROM read_events($1::jsonb[])",
          [array_encoder.encode(['{"tags":["order_id:123"]}'])],
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
            tags: ["order_id:123"],
          ),
        ],
        repository.read(query),
      )
      connection.verify
    end

    def test_read_events_with_wildcard_query_item
      query = Query.new(criteria: [Query::Criteria.new(types: [], tags: [])])
      connection = Minitest::Mock.new
      connection.expect(
        :exec_params,
        [
          {
            "id" => ids[0],
            "type" => "CredditToppedUp",
            "data" => '{"amount":100}',
            "meta" => "{}",
            "tags" => "{order_id:123}",
          },
        ],
        [
          "SELECT id, type, data, meta, tags FROM read_events($1::jsonb[])",
          [array_encoder.encode(["{}"])],
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
            tags: ["order_id:123"],
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
            Query::Criteria.new(types: [], tags: ["order_id:123"]),
            Query::Criteria.new(types: [], tags: ["order_id:456"]),
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
            "tags" => "{order_id:123}",
          },
        ],
        [
          "SELECT id, type, data, meta, tags FROM read_events($1::jsonb[])",
          [
            array_encoder.encode(
              %w[{"tags":["order_id:123"]} {"tags":["order_id:456"]}],
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
            tags: ["order_id:123"],
          ),
        ],
        repository.read(query),
      )
      connection.verify
    end

    def test_read_events_filtered_by_type
      query =
        Query.new(
          criteria: [Query::Criteria.new(types: ["OrderPlaced"], tags: [])],
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
          [array_encoder.encode(['{"types":["OrderPlaced"]}'])],
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
            tags: [],
          ),
        ],
        repository.read(query),
      )
      connection.verify
    end
  end
end
