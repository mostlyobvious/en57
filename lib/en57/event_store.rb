# frozen_string_literal: true

require "json"

module En57
  class EventStore
    def initialize(connection)
      @connection = connection
    end

    def append(event)
      @connection.exec_params(
        "INSERT INTO events (type, data) VALUES ($1, $2)",
        [event.type, JSON.generate(event.data)]
      )
    end
  end
end
