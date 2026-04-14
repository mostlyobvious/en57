# frozen_string_literal: true

# rbs_inline: enabled

require "json"

module En57
  # @rbs!
  #   interface _Event
  #     def type: () -> String
  #     def data: () -> untyped
  #   end

  class EventStore
    #: (untyped connection) -> void
    def initialize(connection)
      @connection = connection
    end

    #: (Array[_Event] events) -> void
    def append(events)
      placeholders = events.each_index.map { |i| "($#{i * 2 + 1}, $#{i * 2 + 2})" }.join(", ")
      params = events.flat_map { |event| [event.type, JSON.generate(event.data)] }
      @connection.exec_params(
        "INSERT INTO events (type, data) VALUES #{placeholders}",
        params
      )
    end

    #: () -> Array[Event]
    def read
      @connection.exec_params("SELECT type, data FROM events", []).map do |row|
        Event.new(type: row.fetch("type"), data: JSON.parse(row.fetch("data")))
      end
    end
  end
end
