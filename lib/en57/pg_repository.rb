# frozen_string_literal: true

# rbs_inline: enabled

module En57
  class PgRepository
    #: (untyped connection, _Serializer serializer) -> void
    def initialize(connection, serializer)
      @connection = connection
      @serializer = serializer
    end

    #: (Array[_Event] events) -> void
    def append(events)
      record_encoder = PG::TextEncoder::Record.new
      array_encoder = PG::TextEncoder::Array.new

      @connection.exec_params(
        "SELECT append_events($1::event[])",
        [
          array_encoder.encode(
            events.map do |event|
              serialized, description = @serializer.dump(event.data)
              record_encoder.encode([event.type, serialized, description])
            end,
          ),
        ],
      )
    end

    #: () -> Array[Event]
    def read
      @connection
        .exec_params("SELECT type, data, metadata FROM read_events()", [])
        .map do |row|
          Event.new(
            type: row.fetch("type"),
            data: @serializer.load(row.fetch("data"), row.fetch("metadata")),
          )
        end
    end
  end
end
