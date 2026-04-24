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

CREATE INDEX events_type_idx ON events (type);
CREATE INDEX tags_key_value_event_id_idx ON tags (key, value, event_id);

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

CREATE FUNCTION read_events (criteria jsonb[])
    RETURNS SETOF event_with_tags
    LANGUAGE SQL
    AS $$
    WITH parsed_criteria AS (
        SELECT
            c,
            c -> 'tags' AS tags,
            ARRAY(
                SELECT
                    jsonb_array_elements_text(c -> 'types')) AS types
        FROM
            unnest(criteria) AS c),
    filtered_events AS (
        SELECT
            e.position,
            e.id,
            e.type,
            e.data,
            e.meta
        FROM
            events AS e
        WHERE
            cardinality(criteria) = 0
            OR EXISTS (
                SELECT
                    1
                FROM
                    parsed_criteria AS pc
                WHERE
                    (pc.c -> 'types' IS NULL
                        OR e.type = ANY(pc.types))
                    AND NOT EXISTS (
                        SELECT
                            1
                        FROM
                            jsonb_each_text(COALESCE(pc.tags, '{}'::jsonb)) AS req (key, value)
                        WHERE
                            NOT EXISTS (
                                SELECT
                                    1
                                FROM
                                    tags AS t
                                WHERE
                                    t.event_id = e.id
                                    AND t.key = req.key
                                    AND t.value = req.value))))
    SELECT
        e.id,
        e.type,
        e.data,
        e.meta,
        COALESCE(t.tags, '{}'::jsonb) AS tags
    FROM
        filtered_events AS e
        LEFT JOIN LATERAL (
            SELECT
                jsonb_object_agg(t.key, t.value) AS tags
            FROM
                tags AS t
            WHERE
                t.event_id = e.id) AS t ON TRUE
    ORDER BY
        e.position;
$$;

