# frozen_string_literal: true

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
end
