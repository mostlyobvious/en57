CREATE TABLE IF NOT EXISTS events (
  type TEXT NOT NULL,
  data JSONB NOT NULL
);

CREATE OR REPLACE FUNCTION append_events(events JSONB) RETURNS void
LANGUAGE SQL AS $$
  INSERT INTO events (type, data)
  SELECT e->>'type', e->'data'
  FROM jsonb_array_elements(events) AS e;
$$;
