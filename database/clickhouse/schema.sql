-- Base schema for Four Keys ClickHouse deployment

CREATE DATABASE IF NOT EXISTS fourkeys;

CREATE TABLE IF NOT EXISTS fourkeys.events_raw
(
    event_type String,
    id String,
    metadata String,
    time_created DateTime,
    signature String,
    msg_id String,
    source String,
    inserted_at DateTime DEFAULT now()
)
ENGINE = MergeTree
ORDER BY (event_type, id, time_created);

CREATE TABLE IF NOT EXISTS fourkeys.events_enriched
(
    events_raw_signature String,
    enriched_metadata String,
    inserted_at DateTime DEFAULT now()
)
ENGINE = MergeTree
ORDER BY events_raw_signature;
