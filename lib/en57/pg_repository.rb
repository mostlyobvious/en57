# frozen_string_literal: true

module En57
  class PgRepository
    def initialize(connection, serializer)
      @connection = connection
      @serializer = serializer
    end

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

    def read
      @connection
        .exec_params("SELECT type, data, meta FROM read_events()", [])
        .map do |row|
          Event.new(
            type: row.fetch("type"),
            data: @serializer.load(row.fetch("data"), row.fetch("meta")),
          )
        end
    end
  end
end
