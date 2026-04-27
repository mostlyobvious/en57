# frozen_string_literal: true

require "test_helper"

module En57
  class TestPgAdapter < Minitest::Test
    cover PgAdapter

    def test_with_connection_connects_once_and_yields_connection
      with_mock_adapter do |connection, adapter, connection_count|
        connection.expect(:exec, :first, ["SELECT 1"])
        connection.expect(:exec, :second, ["SELECT 2"])

        assert_equal :first,
                     adapter.with_connection { |conn| conn.exec("SELECT 1") }
        assert_equal :second,
                     adapter.with_connection { |conn| conn.exec("SELECT 2") }
        assert_equal 1, connection_count.call
      end
    end

    def test_with_connection_uses_five_connections_by_default
      with_connection_count(
        6,
      ) do |connections, acquired, release, connection_count|
        adapter = PgAdapter.new(connection_uri)

        threads =
          6.times.map do
            Thread.new do
              adapter.with_connection do |connection|
                acquired << connection
                release.pop
              end
            end
          end

        assert_equal connections.take(5), 5.times.map { acquired.pop }
        assert_equal 5, connection_count.call
        assert_raises(ThreadError) { acquired.pop(true) }

        release << true
        assert_includes connections.take(5), acquired.pop

        5.times { release << true }
        threads.each(&:value)
      end
    end

    def test_with_connection_honors_max_connections
      with_connection_count(
        3,
      ) do |connections, acquired, release, connection_count|
        adapter = PgAdapter.new(connection_uri, max_connections: 2)

        threads =
          3.times.map do
            Thread.new do
              adapter.with_connection do |connection|
                acquired << connection
                release.pop
              end
            end
          end

        assert_equal connections.take(2), 2.times.map { acquired.pop }
        assert_equal 2, connection_count.call
        assert_raises(ThreadError) { acquired.pop(true) }

        release << true
        assert_includes connections.take(2), acquired.pop

        2.times { release << true }
        threads.each(&:value)
      end
    end

    def test_with_serializable_transaction_commits_on_success
      with_mock_adapter do |connection, adapter|
        connection.expect(:exec, nil, ["BEGIN ISOLATION LEVEL SERIALIZABLE"])
        connection.expect(
          :exec_params,
          :written,
          ["SELECT append_events()", []],
        )
        connection.expect(:exec, nil, ["COMMIT"])

        adapter.with_serializable_transaction do |conn|
          assert_equal :written, conn.exec_params("SELECT append_events()", [])
        end
      end
    end

    def test_with_serializable_transaction_rolls_back_on_failure
      error = RuntimeError.new("boom")

      raised =
        assert_raises(RuntimeError) do
          with_mock_adapter do |connection, adapter|
            connection.expect(
              :exec,
              nil,
              ["BEGIN ISOLATION LEVEL SERIALIZABLE"],
            )
            connection.expect(:exec_params, nil) do |sql, params|
              assert_equal "SELECT append_events()", sql
              assert_equal [], params
              raise error
            end
            connection.expect(:exec, nil, ["ROLLBACK"])

            adapter.with_serializable_transaction do |conn|
              conn.exec_params("SELECT append_events()", [])
            end
          end
        end

      assert_same error, raised
    end

    private

    def connection_uri = "postgres://localhost:5432/en57_test"

    def with_connection_count(size)
      connections = Array.new(size) { Object.new }
      acquired = Queue.new
      release = Queue.new
      connection_count = 0

      PG.stub(
        :connect,
        ->(actual_connection_uri) do
          connection_count += 1
          assert_equal connection_uri, actual_connection_uri
          connections.fetch(connection_count - 1)
        end,
      ) { yield connections, acquired, release, -> { connection_count } }
    end

    def with_mock_adapter
      connection = Minitest::Mock.new
      connection_count = 0

      PG.stub(
        :connect,
        ->(actual_connection_uri) do
          connection_count += 1
          assert_equal connection_uri, actual_connection_uri
          connection
        end,
      ) do
        yield connection, PgAdapter.new(connection_uri), -> { connection_count }
      ensure
        connection.verify
      end
    end
  end
end
