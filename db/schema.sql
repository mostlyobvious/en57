SET client_min_messages = warning;

CREATE TABLE IF NOT EXISTS events (
    type TEXT NOT NULL,
    data jsonb NOT NULL,
    metadata jsonb NOT NULL
);

DO $$
BEGIN
    CREATE TYPE event AS (
        type TEXT,
        data jsonb,
        metadata jsonb
);
EXCEPTION
    WHEN duplicate_object THEN
        NULL;
END
$$;

CREATE OR REPLACE FUNCTION append_events (new_events event[])
    RETURNS void
    LANGUAGE SQL
    AS $$
    INSERT INTO events (type, data, metadata)
    SELECT
        e.type,
        e.data,
        e.metadata
    FROM
        unnest(new_events) AS e;
$$;

CREATE OR REPLACE FUNCTION read_events ()
    RETURNS SETOF event
    LANGUAGE SQL
    AS $$
    SELECT
        type,
        data,
        metadata
    FROM
        events;
$$;

