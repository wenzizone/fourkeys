CREATE DATABASE IF NOT EXISTS fourkeys;

CREATE TABLE IF NOT EXISTS fourkeys.services
(
    service_name String,
    repo String,
    team String,
    contact String,
    metadata String,
    inserted_at DateTime DEFAULT now()
)
ENGINE = MergeTree
ORDER BY service_name;
