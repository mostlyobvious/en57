# frozen_string_literal: true

# rbs_inline: enabled

require "json"

module En57
  class EventStore
    #: (untyped connection) -> void
    def initialize(connection)
      @connection = connection
    end

    #: (Array[_Event] events) -> void
    def append(events)
      payload = events.map { |event| {type: event.type, data: event.data} }
      @connection.exec_params("SELECT append_events($1)", [JSON.generate(payload)])
    end

    #: () -> Array[Event]
    def read
      @connection.exec_params("SELECT type, data FROM events", []).map do |row|
        Event.new(type: row.fetch("type"), data: JSON.parse(row.fetch("data")))
      end
    end
  end
end
