# frozen_string_literal: true

require "test_helper"

module En57
  class TestRepository < Minitest::Test
    cover Repository

    def test_append_wraps_write_in_serializable_transaction
      expected_events =
        array_encoder.encode(
          [
            record_encoder.encode(
              [
                ids[0],
                "CreditsToppedUp",
                '{"amount":100}',
                '{"amount":{"k":"Symbol"}}',
                "{order_id:123}",
              ],
            ),
            record_encoder.encode(
              [
                ids[1],
                "CreditsToppedUp",
                '{"amount":50}',
                '{"amount":{"k":"Symbol"}}',
                "{order_id:234}",
              ],
            ),
          ],
        )
      with_connection_to(connection_uri) do |connection|
        connection.expect(:exec, nil, ["BEGIN ISOLATION LEVEL SERIALIZABLE"])
        connection.expect(
          :exec_params,
          nil,
          [
            "SELECT append_events($1::event_with_tags[], $2::jsonb)",
            [expected_events, "{}"],
          ],
        )
        connection.expect(:exec, nil, ["COMMIT"])

        Repository.new(
          PgAdapter.new(connection_uri),
          JsonSerializer.new,
        ).append(
          [
            Event.new(
              id: ids[0],
              type: "CreditsToppedUp",
              data: {
                amount: 100,
              },
              tags: ["order_id:123"],
            ),
            Event.new(
              id: ids[1],
              type: "CreditsToppedUp",
              data: {
                amount: 50,
              },
              tags: ["order_id:234"],
            ),
          ],
          fail_if: Query.all,
        )
      end
    end

    def test_append_passes_fail_if_and_after_conditions
      with_connection_to(connection_uri) do |connection|
        connection.expect(:exec, nil, ["BEGIN ISOLATION LEVEL SERIALIZABLE"])
        connection.expect(
          :exec_params,
          nil,
          [
            "SELECT append_events($1::event_with_tags[], $2::jsonb)",
            [
              array_encoder.encode([]),
              '{"fail_if_events_match":[{"types":["OrderPlaced"],"after":42}]}',
            ],
          ],
        )
        connection.expect(:exec, nil, ["COMMIT"])

        Repository.new(
          PgAdapter.new(connection_uri),
          JsonSerializer.new,
        ).append(
          [],
          fail_if:
            Query.new(
              criteria: [
                Query::Criteria.new(
                  types: ["OrderPlaced"],
                  tags: [],
                  after: 42,
                ),
              ],
            ),
        )
      end
    end

    def test_append_rolls_back_transaction_on_pg_failure
      with_connection_to(connection_uri) do |connection|
        connection.expect(:exec, nil, ["BEGIN ISOLATION LEVEL SERIALIZABLE"])
        connection.expect(:exec, nil, ["ROLLBACK"])
        connection.expect(:exec_params, nil) do |sql, params|
          assert_equal(
            "SELECT append_events($1::event_with_tags[], $2::jsonb)",
            sql,
          )
          assert_equal([array_encoder.encode([]), "{}"], params)
          raise PG::Error, "boom"
        end

        assert_raises(PG::Error) do
          Repository.new(
            PgAdapter.new(connection_uri),
            JsonSerializer.new,
          ).append([], fail_if: Query.all)
        end
      end
    end

    def test_append_raises_append_condition_violated_from_pg_result_sqlstate
      with_connection_to(connection_uri) do |connection|
        connection.expect(:exec, nil, ["BEGIN ISOLATION LEVEL SERIALIZABLE"])
        connection.expect(:exec, nil, ["ROLLBACK"])
        connection.expect(:exec_params, nil) do
          raise pg_error(result_sqlstate: "P0001")
        end

        assert_raises(AppendConditionViolated) do
          Repository.new(
            PgAdapter.new(connection_uri),
            JsonSerializer.new,
          ).append([], fail_if: Query.all)
        end
      end
    end

    def test_append_raises_append_condition_violated_from_pg_error_sqlstate
      with_connection_to(connection_uri) do |connection|
        connection.expect(:exec, nil, ["BEGIN ISOLATION LEVEL SERIALIZABLE"])
        connection.expect(:exec, nil, ["ROLLBACK"])
        connection.expect(:exec_params, nil) do
          raise pg_error(sqlstate: "P0001")
        end

        assert_raises(AppendConditionViolated) do
          Repository.new(
            PgAdapter.new(connection_uri),
            JsonSerializer.new,
          ).append([], fail_if: Query.all)
        end
      end
    end

    def test_append_raises_append_condition_violated_from_serialization_failure_result_sqlstate
      with_connection_to(connection_uri) do |connection|
        connection.expect(:exec, nil, ["BEGIN ISOLATION LEVEL SERIALIZABLE"])
        connection.expect(:exec, nil, ["ROLLBACK"])
        connection.expect(:exec_params, nil) do
          raise pg_error(result_sqlstate: "40001")
        end

        assert_raises(AppendConditionViolated) do
          Repository.new(
            PgAdapter.new(connection_uri),
            JsonSerializer.new,
          ).append([], fail_if: Query.all)
        end
      end
    end

    def test_append_raises_append_condition_violated_from_serialization_failure_sqlstate
      with_connection_to(connection_uri) do |connection|
        connection.expect(:exec, nil, ["BEGIN ISOLATION LEVEL SERIALIZABLE"])
        connection.expect(:exec, nil, ["ROLLBACK"])
        connection.expect(:exec_params, nil) do
          raise pg_error(sqlstate: "40001")
        end

        assert_raises(AppendConditionViolated) do
          Repository.new(
            PgAdapter.new(connection_uri),
            JsonSerializer.new,
          ).append([], fail_if: Query.all)
        end
      end
    end

    def test_append_reraises_pg_error_for_non_append_condition_sqlstate
      with_connection_to(connection_uri) do |connection|
        connection.expect(:exec, nil, ["BEGIN ISOLATION LEVEL SERIALIZABLE"])
        connection.expect(:exec, nil, ["ROLLBACK"])
        connection.expect(:exec_params, nil) do
          raise pg_error(sqlstate: "23505")
        end

        assert_raises(PG::Error) do
          Repository.new(
            PgAdapter.new(connection_uri),
            JsonSerializer.new,
          ).append([], fail_if: Query.all)
        end
      end
    end

    def test_append_rolls_back_transaction_on_failure
      with_connection_to(connection_uri) do |connection|
        connection.expect(:exec, nil, ["BEGIN ISOLATION LEVEL SERIALIZABLE"])
        connection.expect(:exec, nil, ["ROLLBACK"])
        connection.expect(:exec_params, nil) { raise RuntimeError, "boom" }

        assert_raises(RuntimeError) do
          Repository.new(
            PgAdapter.new(connection_uri),
            JsonSerializer.new,
          ).append([], fail_if: Query.all)
        end
      end
    end

    def test_read_events_with_tags
      with_connection_to(connection_uri) do |connection|
        connection.expect(
          :exec_params,
          [
            {
              "id" => ids[0],
              "type" => "CreditsToppedUp",
              "data" => '{"amount":100}',
              "meta" => "{}",
              "tags" => "{order_id:123}",
            },
            {
              "id" => ids[1],
              "type" => "CreditsToppedUp",
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

        assert_equal(
          [
            Event.new(
              id: ids[0],
              type: "CreditsToppedUp",
              data: {
                "amount" => 100,
              },
              tags: ["order_id:123"],
            ),
            Event.new(
              id: ids[1],
              type: "CreditsToppedUp",
              data: {
                "amount" => 50,
              },
              tags: ["order_id:234"],
            ),
          ],
          Repository.new(
            PgAdapter.new(connection_uri),
            JsonSerializer.new,
          ).read(Query.all),
        )
      end
    end

    def test_read_events_filtered_by_tags
      query =
        Query.new(
          criteria: [Query::Criteria.new(types: [], tags: ["order_id:123"])],
        )
      with_connection_to(connection_uri) do |connection|
        connection.expect(
          :exec_params,
          [
            {
              "id" => ids[0],
              "type" => "CreditsToppedUp",
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

        assert_equal(
          [
            Event.new(
              id: ids[0],
              type: "CreditsToppedUp",
              data: {
                "amount" => 100,
              },
              tags: ["order_id:123"],
            ),
          ],
          Repository.new(
            PgAdapter.new(connection_uri),
            JsonSerializer.new,
          ).read(query),
        )
      end
    end

    def test_read_events_with_wildcard_query_item
      query = Query.new(criteria: [Query::Criteria.new(types: [], tags: [])])
      with_connection_to(connection_uri) do |connection|
        connection.expect(
          :exec_params,
          [
            {
              "id" => ids[0],
              "type" => "CreditsToppedUp",
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

        assert_equal(
          [
            Event.new(
              id: ids[0],
              type: "CreditsToppedUp",
              data: {
                "amount" => 100,
              },
              tags: ["order_id:123"],
            ),
          ],
          Repository.new(
            PgAdapter.new(connection_uri),
            JsonSerializer.new,
          ).read(query),
        )
      end
    end

    def test_read_events_with_or_tag_predicates
      query =
        Query.new(
          criteria: [
            Query::Criteria.new(types: [], tags: ["order_id:123"]),
            Query::Criteria.new(types: [], tags: ["order_id:456"]),
          ],
        )
      with_connection_to(connection_uri) do |connection|
        connection.expect(
          :exec_params,
          [
            {
              "id" => ids[0],
              "type" => "CreditsToppedUp",
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

        assert_equal(
          [
            Event.new(
              id: ids[0],
              type: "CreditsToppedUp",
              data: {
                "amount" => 100,
              },
              tags: ["order_id:123"],
            ),
          ],
          Repository.new(
            PgAdapter.new(connection_uri),
            JsonSerializer.new,
          ).read(query),
        )
      end
    end

    def test_read_events_filtered_by_after
      query =
        Query.new(
          criteria: [Query::Criteria.new(types: [], tags: [], after: 42)],
        )
      with_connection_to(connection_uri) do |connection|
        connection.expect(
          :exec_params,
          [],
          [
            "SELECT id, type, data, meta, tags FROM read_events($1::jsonb[])",
            [array_encoder.encode(['{"after":42}'])],
          ],
        )

        assert_equal(
          [],
          Repository.new(
            PgAdapter.new(connection_uri),
            JsonSerializer.new,
          ).read(query),
        )
      end
    end

    def test_read_events_filtered_by_type
      query =
        Query.new(
          criteria: [Query::Criteria.new(types: ["OrderPlaced"], tags: [])],
        )
      with_connection_to(connection_uri) do |connection|
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
          Repository.new(
            PgAdapter.new(connection_uri),
            JsonSerializer.new,
          ).read(query),
        )
      end
    end

    private

    def ids = @ids ||= Hash.new { |h, k| h[k] = SecureRandom.uuid_v7 }

    def connection_uri = "postgres://localhost:5432/en57_test"

    def with_connection_to(connection_uri)
      connection = Minitest::Mock.new

      PG.stub(
        :connect,
        ->(actual_connection_uri) do
          assert_equal(connection_uri, actual_connection_uri)
          connection
        end,
      ) { yield connection }
      connection.verify
    end

    def array_encoder = @array_encoder ||= PG::TextEncoder::Array.new

    def record_encoder = @record_encoder ||= PG::TextEncoder::Record.new

    def pg_error(result_sqlstate: nil, sqlstate: nil)
      error = PG::Error.new("boom")
      result = Object.new
      result.define_singleton_method(:error_field) do |field|
        field == PG::Result::PG_DIAG_SQLSTATE ? result_sqlstate : nil
      end
      error.define_singleton_method(:result) do
        result_sqlstate.nil? ? nil : result
      end
      error.define_singleton_method(:sqlstate) { sqlstate }
      error
    end
  end
end
