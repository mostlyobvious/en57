# frozen_string_literal: true

require "pg"
require_relative "version"

module En57
  class Migrator
    MigrationError = Class.new(StandardError)

    Status = Data.define(:current, :target, :state, :method, :pending, :warning)

    def initialize(connection_string)
      @connection_string = connection_string
    end

    def status
      current = current_version

      Status.new(
        current:,
        target: SCHEMA_VERSION,
        state: state_for(current),
        method: (current == :fresh ? :none : :version_table),
        pending: pending_for(current),
        warning: warning_for(current),
      )
    end

    def migrate!
      current = current_version
      raise partial_migration_error if current == :partial
      if current == :unversioned
        raise MigrationError, "Cannot infer En57 schema version"
      end
      return if current == SCHEMA_VERSION

      if current == :fresh
        install_fresh_schema
      else
        raise MigrationError,
              "No En57 schema diff from #{current} to #{SCHEMA_VERSION}"
      end
    end

    alias migrate migrate!

    private

    def state_for(current)
      case current
      when SCHEMA_VERSION
        :up_to_date
      when :partial
        :partial
      else
        :pending
      end
    end

    def pending_for(current)
      if current == SCHEMA_VERSION || current == :partial
        []
      else
        [schema_path(SCHEMA_VERSION)]
      end
    end

    def warning_for(current)
      return unless current == :partial

      "Previous En57 migration did not complete cleanly. " \
        "Inspect the database and resolve manually, then run: " \
        "UPDATE public.en57_schema_info SET in_progress = false WHERE id = 1;"
    end

    def current_version
      with_connection do |connection|
        next :fresh unless schema_info_table?(connection)

        result =
          connection.exec(
            "SELECT schema_version, in_progress FROM public.en57_schema_info WHERE id = 1",
          )
        next :unversioned if result.ntuples.zero?

        row = result.first
        next :partial if row.fetch("in_progress") == "t"

        row.fetch("schema_version")
      end
    end

    def install_fresh_schema
      with_connection do |connection|
        ensure_schema_info_table(connection)
        mark_in_progress(connection)

        connection.transaction do |transaction|
          transaction.exec(File.read(schema_path(SCHEMA_VERSION)))
          record_version(transaction)
        end
      end
    end

    def ensure_schema_info_table(connection)
      connection.exec(<<~SQL)
        CREATE TABLE IF NOT EXISTS public.en57_schema_info (
          id integer PRIMARY KEY,
          schema_version varchar(20) NOT NULL,
          in_progress boolean NOT NULL DEFAULT false,
          started_at timestamp,
          applied_at timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
        )
      SQL
    end

    def mark_in_progress(connection)
      connection.exec_params(<<~SQL, [SCHEMA_VERSION])
        INSERT INTO public.en57_schema_info (id, schema_version, in_progress, started_at)
        VALUES (1, $1, true, CURRENT_TIMESTAMP)
        ON CONFLICT (id) DO UPDATE
        SET in_progress = true,
            started_at = CURRENT_TIMESTAMP
      SQL
    end

    def record_version(connection)
      connection.exec_params(<<~SQL, [SCHEMA_VERSION])
        UPDATE public.en57_schema_info
        SET schema_version = $1,
            in_progress = false,
            applied_at = CURRENT_TIMESTAMP
        WHERE id = 1
      SQL
    end

    def schema_info_table?(connection)
      connection
        .exec_params(
          "SELECT to_regclass($1)::text",
          ["public.en57_schema_info"],
        )
        .first
        .fetch("to_regclass")
    end

    def schema_path(version)
      File.expand_path("../../db/schema/#{version}.sql", __dir__)
    end

    def partial_migration_error
      MigrationError.new(warning_for(:partial))
    end

    def with_connection
      connection = PG.connect(@connection_string)
      yield connection
    ensure
      connection&.close
    end
  end
end
