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

      event_records =
        events.map do |event|
          serialized, description = @serializer.dump(event.data)
          record_encoder.encode(
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
        [array_encoder.encode(event_records)],
      )
    end

    def read(query)
      array_encoder = PG::TextEncoder::Array.new
      tag_filters = query.items.map { |item| JSON.generate(item.tags) }
      type_filters = query.items.map { |item| JSON.generate(item.types) }

      @connection
        .exec_params(
          "SELECT id, type, data, meta, tags FROM read_events($1::jsonb[], $2::jsonb[])",
          [array_encoder.encode(tag_filters), array_encoder.encode(type_filters)],
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
