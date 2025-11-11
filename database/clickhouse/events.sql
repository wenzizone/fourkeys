CREATE DATABASE IF NOT EXISTS fourkeys;

CREATE TABLE IF NOT EXISTS fourkeys.events
(
    event_id String,
    event_type String,
    time_created DateTime,
    metadata String,
    signature String,
    msg_id String,
    source String,
    inserted_at DateTime DEFAULT now()
)
ENGINE = MergeTree
ORDER BY (source, event_type, time_created);

DROP VIEW IF EXISTS fourkeys.mv_events;

CREATE MATERIALIZED VIEW fourkeys.mv_events
TO fourkeys.events
AS
SELECT
    id AS event_id,
    event_type,
    time_created,
    metadata,
    signature,
    msg_id,
    source,
    now() AS inserted_at
FROM fourkeys.events_raw;
