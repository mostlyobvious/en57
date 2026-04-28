# frozen_string_literal: true

require "connection_pool"
require "pg"

module En57
  class PgAdapter
    def initialize(connection_uri, max_connections: 5)
      @connection_pool =
        ConnectionPool.new(size: max_connections) { PG.connect(connection_uri) }
    end

    def with_connection =
      @connection_pool.with { |connection| yield connection }

    def with_serializable_transaction
      with_connection do |connection|
        connection.exec("BEGIN ISOLATION LEVEL SERIALIZABLE")
        yield connection
        connection.exec("COMMIT")
      rescue StandardError
        connection.exec("ROLLBACK")
        raise
      end
    end
  end
end
