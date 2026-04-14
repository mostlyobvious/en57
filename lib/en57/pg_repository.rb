# frozen_string_literal: true

# rbs_inline: enabled

module En57
  class PgRepository
    #: (untyped connection, untyped serializer) -> void
    def initialize(connection, serializer)
      @connection = connection
      @serializer = serializer
    end

    #: (Array[_Event] events) -> void
    def append(events)
      payload = events.map { |event| {type: event.type, data: event.data} }
      @connection.exec_params("SELECT append_events($1)", [@serializer.dump(payload)])
    end

    #: () -> Array[Event]
    def read
      @connection.exec_params("SELECT type, data FROM read_events()", []).map do |row|
        Event.new(type: row.fetch("type"), data: @serializer.load(row.fetch("data")))
      end
    end
  end
end
