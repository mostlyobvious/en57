# frozen_string_literal: true

require "pg"

module En57
  class PgAdapter
    def initialize(connection_uri)
      @connection_uri = connection_uri
    end

    def with_connection
      @connection ||= PG.connect(@connection_uri)
      yield @connection
    end

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
