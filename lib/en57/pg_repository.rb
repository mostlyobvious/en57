# frozen_string_literal: true

require "pg"

module En57
  class PgRepository
    def initialize(connection, serializer)
      @connection = connection
      @serializer = serializer
      @record_encoder = PG::TextEncoder::Record.new
      @array_encoder = PG::TextEncoder::Array.new
    end

    def append(events)
      event_records =
        events.map do |event|
          serialized, description = @serializer.dump(event.data)
          @record_encoder.encode(
            [
              event.id,
              event.type,
              serialized,
              description,
              JSON.generate(event.tags),
            ],
          )
        end

      @connection.exec_params(
        "SELECT append_events($1::event_with_tags[])",
        [@array_encoder.encode(event_records)],
      )
    end

    def read(query)
      criteria =
        query.items.map do |item|
          JSON.generate(types: item.types, tags: item.tags)
        end

      @connection
        .exec_params(
          "SELECT id, type, data, meta, tags FROM read_events($1::jsonb[])",
          [@array_encoder.encode(criteria)],
        )
        .map do |row|
          Event.new(
            id: row.fetch("id"),
            type: row.fetch("type"),
            data: @serializer.load(row.fetch("data"), row.fetch("meta")),
            tags: JSON.parse(row.fetch("tags"), symbolize_names: true),
          )
        end
    end
  end
end
