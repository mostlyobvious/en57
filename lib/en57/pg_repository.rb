# frozen_string_literal: true

require "pg"

module En57
  class PgRepository
    def initialize(connection_uri, serializer)
      @connection_uri = connection_uri
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

      with_serializable_transaction do |connection|
        connection.exec_params(
          "SELECT append_events($1::event_with_tags[], $2::jsonb)",
          [
            @array_encoder.encode(event_records),
            JSON.generate(append_condition),
          ],
        )
      end
    rescue PG::Error => e
      sqlstate =
        e.result&.error_field(PG::Result::PG_DIAG_SQLSTATE) ||
          (e.sqlstate if e.respond_to?(:sqlstate))
      raise AppendConditionViolated if sqlstate == "P0001"

      raise
    end

    def read(query)
      criteria = query.encoded_criteria.map { |item| JSON.generate(item) }

      with_connection do |connection|
        connection.exec_params(
          "SELECT id, type, data, meta, tags FROM read_events($1::jsonb[])",
          [@array_encoder.encode(criteria)],
        )
      end.map do |row|
        Event.new(
          id: row.fetch("id"),
          type: row.fetch("type"),
          data: @serializer.load(row.fetch("data"), row.fetch("meta")),
          tags: @array_decoder.decode(row.fetch("tags")),
        )
      end
    end

    private

    def with_serializable_transaction
      with_connection do |connection|
        connection.exec("BEGIN ISOLATION LEVEL SERIALIZABLE")
        yield connection
        connection.exec("COMMIT")
      rescue StandardError
        connection.exec("ROLLBACK")
        raise
      end
    end

    def with_connection
      @connection ||= PG.connect(@connection_uri)
      yield @connection
    end
  end
end
