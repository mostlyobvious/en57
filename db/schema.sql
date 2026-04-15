CREATE TABLE IF NOT EXISTS events (
  type TEXT NOT NULL,
  data JSONB NOT NULL
);

DO $$ BEGIN
  CREATE TYPE event_input AS (type TEXT, data JSONB);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

CREATE OR REPLACE FUNCTION append_events(events event_input[]) RETURNS void
LANGUAGE SQL AS $$
  INSERT INTO events (type, data)
  SELECT e.type, e.data FROM unnest(events) AS e;
$$;

CREATE OR REPLACE FUNCTION read_events() RETURNS TABLE(type TEXT, data JSONB)
LANGUAGE SQL AS $$
  SELECT type, data FROM events;
$$;
