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
      assert_unwraps_pg_error(PG::Error.new("boom"))
    end

    def test_with_serializable_transaction_unwraps_pg_error_subclasses
      assert_unwraps_pg_error(PG::TRSerializationFailure.new("boom"))
    end

    def test_with_serializable_transaction_unwraps_sequel_error_subclasses
      pg_error = PG::Error.new("boom")
      sequel_error = Class.new(Sequel::DatabaseError).new("wrapped")
      sequel_error.wrapped_exception = pg_error

      raised =
        assert_raises(PG::Error) do
          with_mock_adapter do |database, _connection, adapter|
            expect_failed_transaction(database, sequel_error)

            adapter.with_serializable_transaction { flunk "not yielded" }
          end
        end

      assert_same pg_error, raised
    end

    def test_with_serializable_transaction_reraises_non_pg_sequel_errors
      error = RuntimeError.new("boom")
      sequel_error = Sequel::DatabaseError.new("wrapped")
      sequel_error.wrapped_exception = error

      raised =
        assert_raises(Sequel::DatabaseError) do
          with_mock_adapter do |database, _connection, adapter|
            expect_failed_transaction(database, sequel_error)

            adapter.with_serializable_transaction { flunk "not yielded" }
          end
        end

      assert_same sequel_error, raised
    end

    def test_with_serializable_transaction_reraises_plain_errors
      error = RuntimeError.new("boom")

      raised =
        assert_raises(RuntimeError) do
          with_mock_adapter do |database, _connection, adapter|
            expect_failed_transaction(database, error)

            adapter.with_serializable_transaction { flunk "not yielded" }
          end
        end

      assert_same error, raised
    end

    def test_with_serializable_transaction_reraises_without_sequel_loaded
      error = RuntimeError.new("boom")
      sequel = Object.send(:remove_const, :Sequel)

      raised =
        assert_raises(RuntimeError) do
          with_mock_adapter do |database, _connection, adapter|
            expect_failed_transaction(database, error)

            adapter.with_serializable_transaction { flunk "not yielded" }
          end
        end

      assert_same error, raised
    ensure
      Object.const_set(:Sequel, sequel) if sequel
    end

    private

    def assert_unwraps_pg_error(pg_error)
      sequel_error = Sequel::DatabaseError.new("wrapped")
      sequel_error.wrapped_exception = pg_error

      raised =
        assert_raises(PG::Error) do
          with_mock_adapter do |database, _connection, adapter|
            expect_failed_transaction(database, sequel_error)

            adapter.with_serializable_transaction { flunk "not yielded" }
          end
        end

      assert_same pg_error, raised
    end

    def with_mock_adapter
      database = Minitest::Mock.new
      connection = Minitest::Mock.new

      yield database, connection, SequelAdapter.new(database)
    ensure
      database.verify
      connection.verify
    end

    def expect_failed_transaction(database, error)
      database.expect(:transaction, nil) do |options, &block|
        assert_equal({ isolation: :serializable }, options)
        block.call
        true
      end
      database.expect(:synchronize, nil) { raise error }
    end
  end
end
