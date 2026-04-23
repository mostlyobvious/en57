CREATE TABLE events (
    position bigint GENERATED ALWAYS AS IDENTITY,
    id uuid PRIMARY KEY,
    type text NOT NULL,
    data jsonb NOT NULL,
    meta jsonb NOT NULL
);

CREATE TABLE tags (
    event_id uuid NOT NULL REFERENCES events (id) ON DELETE CASCADE,
    key text NOT NULL,
    value text NOT NULL,
    PRIMARY KEY (event_id, key)
);

CREATE TYPE event_with_tags AS (
    id uuid,
    type text,
    data jsonb,
    meta jsonb,
    tags jsonb
);

CREATE FUNCTION append_events (new_events event_with_tags[])
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

    INSERT INTO tags (event_id, key, value)
    SELECT
        e.id,
        t.key,
        t.value
    FROM
        unnest(new_events) AS e
        CROSS JOIN LATERAL jsonb_each_text(COALESCE(e.tags, '{}'::jsonb)) AS t;
$$;

CREATE FUNCTION read_events (tag_filters jsonb[])
    RETURNS SETOF event_with_tags
    LANGUAGE SQL
    AS $$
    WITH filtered_events AS (
        SELECT
            e.position,
            e.id,
            e.type,
            e.data,
            e.meta
        FROM
            events AS e
        WHERE
            cardinality(tag_filters) = 0
            OR EXISTS (
                SELECT
                    1
                FROM
                    unnest(tag_filters) AS filter
                WHERE
                    filter = '{}'::jsonb
                    OR NOT EXISTS (
                        SELECT
                            1
                        FROM
                            jsonb_each_text(filter) AS f (key, value)
                        WHERE
                            NOT EXISTS (
                                SELECT
                                    1
                                FROM
                                    tags AS t
                                WHERE
                                    t.event_id = e.id
                                    AND t.key = f.key
                                    AND t.value = f.value
                            )
                    )
            )
    )
    SELECT
        e.id,
        e.type,
        e.data,
        e.meta,
        COALESCE(
            (
                SELECT
                    jsonb_object_agg(t.key, t.value)
                FROM
                    tags AS t
                WHERE
                    t.event_id = e.id
            ),
            '{}'::jsonb
        )
    FROM
        filtered_events AS e
    ORDER BY
        e.position;
$$;
