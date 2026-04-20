SET client_min_messages = warning;

CREATE TABLE IF NOT EXISTS events (
    type TEXT NOT NULL,
    data jsonb NOT NULL,
    meta jsonb NOT NULL
);

DO $$
BEGIN
    CREATE TYPE event AS (
        type TEXT,
        data jsonb,
        meta jsonb
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
    INSERT INTO events (type, data, meta)
    SELECT
        e.type,
        e.data,
        e.meta
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
        meta
    FROM
        events;
$$;

