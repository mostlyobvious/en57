# frozen_string_literal: true

require "test_helper"

module En57
  class TestSequelAdapter < Minitest::Test
    cover SequelAdapter

    def test_with_connection_synchronizes_and_yields_connection
      with_mock_adapter do |database, connection, adapter|
        database.expect(:synchronize, :selected) do |&block|
          block.call(connection)
          true
        end
        connection.expect(:exec, :selected, ["SELECT 1"])

        assert_equal :selected,
                     adapter.with_connection { |conn| conn.exec("SELECT 1") }
      end
    end

    def test_with_serializable_transaction_synchronizes_inside_transaction
      with_mock_adapter do |database, connection, adapter|
        database.expect(:transaction, :committed) do |options, &block|
          assert_equal({ isolation: :serializable }, options)
          block.call
          true
        end
        database.expect(:synchronize, :written) do |&block|
          block.call(connection)
          true
        end
        connection.expect(
          :exec_params,
          :written,
          ["SELECT append_events()", []],
        )

        assert_equal(
          :committed,
          adapter.with_serializable_transaction do |conn|
            assert_equal :written,
                         conn.exec_params("SELECT append_events()", [])
          end,
        )
      end
    end

    def test_with_serializable_transaction_unwraps_pg_errors
      pg_error = PG::Error.new("boom")
      sequel_error = Sequel::DatabaseError.new("wrapped")
      sequel_error.wrapped_exception = pg_error

      raised =
        assert_raises(PG::Error) do
          with_mock_adapter do |database, _connection, adapter|
            database.expect(:transaction, nil) do |options, &block|
              assert_equal({ isolation: :serializable }, options)
              block.call
              true
            end
            database.expect(:synchronize, nil) { raise sequel_error }

            adapter.with_serializable_transaction { flunk "not yielded" }
          end
        end

      assert_same pg_error, raised
    end

    private

    def with_mock_adapter
      database = Minitest::Mock.new
      connection = Minitest::Mock.new

      yield database, connection, SequelAdapter.new(database)

      database.verify
      connection.verify
    end
  end
end
