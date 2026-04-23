CREATE TABLE events (
    position bigint GENERATED ALWAYS AS IDENTITY,
    id uuid PRIMARY KEY,
    type text NOT NULL,
    data jsonb NOT NULL,
    meta jsonb NOT NULL
);

CREATE TYPE event AS (
    id uuid,
    type text,
    data jsonb,
    meta jsonb
);

CREATE FUNCTION append_events (new_events event[])
    RETURNS void
    LANGUAGE SQL
    AS $$
    INSERT INTO events (id, type, data, meta)
    SELECT
        e.id,
        e.type,
        e.data,
        e.meta
    FROM
        unnest(new_events) AS e;
$$;

CREATE FUNCTION read_events ()
    RETURNS SETOF event
    LANGUAGE SQL
    AS $$
    SELECT
        id,
        type,
        data,
        meta
    FROM
        events
    ORDER BY
        position;
$$;
