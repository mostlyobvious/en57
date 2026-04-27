# frozen_string_literal: true

require "pg"

module En57
  class SequelAdapter
    def initialize(database)
      @database = database
    end

    def with_connection(&block)
      @database.synchronize(&block)
    end

    def with_serializable_transaction
      @database.transaction(isolation: :serializable) do
        @database.synchronize { |connection| yield connection }
      end
    rescue StandardError => e
      if defined?(Sequel::DatabaseError) && e.is_a?(Sequel::DatabaseError) &&
           e.wrapped_exception.is_a?(PG::Error)
        raise e.wrapped_exception
      end

      raise
    end
  end
end
