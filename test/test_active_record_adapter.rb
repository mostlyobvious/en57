# frozen_string_literal: true

require "test_helper"

module En57
  class TestActiveRecordAdapter < Minitest::Test
    cover ActiveRecordAdapter

    def test_with_connection_checks_out_connection_and_yields_raw_connection
      with_mock_adapter do |pool, connection, raw_connection, adapter|
        pool.expect(:with_connection, :selected) do |&block|
          block.call(connection)
          true
        end
        connection.expect(:raw_connection, raw_connection)
        raw_connection.expect(:exec, :selected, ["SELECT 1"])

        assert_equal :selected,
                     adapter.with_connection { |conn| conn.exec("SELECT 1") }
      end
    end

    def test_with_serializable_transaction_wraps_block_in_transaction
      with_mock_adapter do |pool, connection, raw_connection, adapter|
        pool.expect(:with_connection, :committed) do |&block|
          block.call(connection)
          true
        end
        connection.expect(:transaction, :committed) do |options, &block|
          assert_equal({ isolation: :serializable }, options)
          block.call
          true
        end
        connection.expect(:raw_connection, raw_connection)
        raw_connection.expect(
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

    def test_with_serializable_transaction_reraises_block_errors
      error = RuntimeError.new("boom")

      raised =
        assert_raises(RuntimeError) do
          with_mock_adapter do |pool, connection, raw_connection, adapter|
            pool.expect(:with_connection, nil) do |&block|
              block.call(connection)
              true
            end
            connection.expect(:transaction, nil) do |options, &block|
              assert_equal({ isolation: :serializable }, options)
              block.call
              true
            end
            connection.expect(:raw_connection, raw_connection)
            raw_connection.expect(:exec_params, nil) do |sql, params|
              assert_equal "SELECT append_events()", sql
              assert_equal [], params
              raise error
            end

            adapter.with_serializable_transaction do |conn|
              conn.exec_params("SELECT append_events()", [])
            end
          end
        end

      assert_same error, raised
    end

    def test_with_serializable_transaction_unwraps_pg_errors
      assert_unwraps_pg_error(PG::Error.new("boom"))
    end

    def test_with_serializable_transaction_unwraps_pg_error_subclasses
      assert_unwraps_pg_error(PG::TRSerializationFailure.new("boom"))
    end

    def test_with_serializable_transaction_reraises_non_pg_active_record_errors
      ar_error = ActiveRecord::StatementInvalid.new("wrapped")
      ar_error.define_singleton_method(:cause) { RuntimeError.new("boom") }

      raised =
        assert_raises(ActiveRecord::StatementInvalid) do
          with_mock_adapter do |pool, connection, _raw_connection, adapter|
            expect_failed_transaction(pool, connection, ar_error)

            adapter.with_serializable_transaction { flunk "not yielded" }
          end
        end

      assert_same ar_error, raised
    end

    private

    def assert_unwraps_pg_error(pg_error)
      ar_error = ActiveRecord::StatementInvalid.new("wrapped")
      ar_error.define_singleton_method(:cause) { pg_error }

      raised =
        assert_raises(PG::Error) do
          with_mock_adapter do |pool, connection, _raw_connection, adapter|
            expect_failed_transaction(pool, connection, ar_error)

            adapter.with_serializable_transaction { flunk "not yielded" }
          end
        end

      assert_same pg_error, raised
    end

    def expect_failed_transaction(pool, connection, error)
      pool.expect(:with_connection, nil) do |&block|
        block.call(connection)
        true
      end
      connection.expect(:transaction, nil) do |options, &_block|
        assert_equal({ isolation: :serializable }, options)
        raise error
      end
    end

    def with_mock_adapter
      pool = Minitest::Mock.new
      connection = Minitest::Mock.new
      raw_connection = Minitest::Mock.new

      yield pool, connection, raw_connection, ActiveRecordAdapter.new(pool)
    ensure
      pool.verify
      connection.verify
      raw_connection.verify
    end
  end
end
