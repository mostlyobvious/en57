# frozen_string_literal: true

require "pg"

module En57
  class PgRepository
    def initialize(connection, serializer)
      @connection = connection
      @serializer = serializer
      @record_encoder = PG::TextEncoder::Record.new
      @array_encoder = PG::TextEncoder::Array.new
      @array_decoder = PG::TextDecoder::Array.new
    end

    def append(events, fail_if:, after:)
      event_records =
        events.map do |event|
          serialized, description = @serializer.dump(event.data)
          @record_encoder.encode(
            [
              event.id,
              event.type,
              serialized,
              description,
              @array_encoder.encode(event.tags),
            ],
          )
        end
      append_condition = {}
      fail_if_events_match = fail_if.encoded_criteria
      append_condition[
        :fail_if_events_match
      ] = fail_if_events_match unless fail_if_events_match.empty?
      append_condition[:after] = after unless after.nil?

      @connection.exec("BEGIN ISOLATION LEVEL SERIALIZABLE")
      @connection.exec_params(
        "SELECT append_events($1::event_with_tags[], $2::jsonb)",
        [@array_encoder.encode(event_records), JSON.generate(append_condition)],
      )
      @connection.exec("COMMIT")
    rescue PG::Error => e
      @connection.exec("ROLLBACK")
      sqlstate =
        e.result&.error_field(PG::Result::PG_DIAG_SQLSTATE) ||
          (e.sqlstate if e.respond_to?(:sqlstate))
      raise AppendConditionViolated if sqlstate == "P0001"

      raise
    rescue StandardError
      @connection.exec("ROLLBACK")
      raise
    end

    def read(query)
      criteria = query.encoded_criteria.map { |item| JSON.generate(item) }

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
            tags: @array_decoder.decode(row.fetch("tags")),
          )
        end
    end
  end
end
