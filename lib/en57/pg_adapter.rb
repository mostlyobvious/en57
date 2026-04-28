# frozen_string_literal: true

require "pg"

module En57
  class PgAdapter
    def initialize(connection_or_pool)
      @with_connection =
        if connection_or_pool.respond_to?(:with)
          connection_or_pool.public_method(:with)
        else
          mutex = Mutex.new
          ->(&block) { mutex.synchronize { block.call(connection_or_pool) } }
        end
    end

    def with_connection =
      @with_connection.call { |connection| yield connection }

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

  class EventStore
    def self.for_pg(connection_uri)
      new(Repository.new(PgAdapter.new(PG.connect(connection_uri)), JsonSerializer.new))
    end
  end

  if defined?(ConnectionPool)
    class EventStore
      def self.for_pooled_pg(connection_uri, max_connections: 5)
        new(
          Repository.new(
            PgAdapter.new(
              ConnectionPool.new(size: max_connections) do
                PG.connect(connection_uri)
              end,
            ),
            JsonSerializer.new,
          ),
        )
      end
    end
  end
end
