# frozen_string_literal: true

require "json"

module En57
  class EventStore
    def initialize(connection)
      @connection = connection
    end

    def append(events)
      placeholders = events.each_index.map { |i| "($#{i * 2 + 1}, $#{i * 2 + 2})" }.join(", ")
      params = events.flat_map { |event| [event.type, JSON.generate(event.data)] }
      @connection.exec_params(
        "INSERT INTO events (type, data) VALUES #{placeholders}",
        params
      )
    end
  end
end
