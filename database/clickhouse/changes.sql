-- Ensure database exists
CREATE DATABASE IF NOT EXISTS fourkeys;

-- Target table for normalized change events
CREATE TABLE IF NOT EXISTS fourkeys.changes
(
    event_type String,
    change_id String,
    repository String,
    branch String,
    author_name String,
    author_email String,
    commit_sha String,
    pr_number UInt32,
    message String,
    time_created DateTime,
    raw_metadata String,
    inserted_at DateTime DEFAULT now()
)
ENGINE = MergeTree
ORDER BY (repository, change_id, time_created);

-- Drop old view if present
DROP VIEW IF EXISTS fourkeys.mv_changes;

-- Materialized view that ingests GitHub events from events_raw
CREATE MATERIALIZED VIEW fourkeys.mv_changes
TO fourkeys.changes
AS
SELECT
    event_type,
    coalesce(
        id,
        JSONExtractString(metadata, 'repository', 'name') || '/' || toString(JSONExtractUInt(metadata, 'number')),
        buildMsgId
    ) AS change_id,
    coalesce(
        JSONExtractString(metadata, 'repository', 'full_name'),
        JSONExtractString(metadata, 'repository', 'name'),
        'unknown'
    ) AS repository,
    coalesce(
        JSONExtractString(metadata, 'ref'),
        JSONExtractString(metadata, 'pull_request', 'head', 'ref'),
        JSONExtractString(metadata, 'pull_request', 'base', 'ref'),
        'main'
    ) AS branch,
    coalesce(
        JSONExtractString(metadata, 'head_commit', 'author', 'name'),
        JSONExtractString(metadata, 'pull_request', 'user', 'login'),
        JSONExtractString(metadata, 'sender', 'login'),
        ''
    ) AS author_name,
    coalesce(
        JSONExtractString(metadata, 'head_commit', 'author', 'email'),
        JSONExtractString(metadata, 'pull_request', 'user', 'email'),
        ''
    ) AS author_email,
    coalesce(
        JSONExtractString(metadata, 'head_commit', 'id'),
        JSONExtractString(metadata, 'pull_request', 'head', 'sha'),
        JSONExtractString(metadata, 'pull_request', 'base', 'sha'),
        ''
    ) AS commit_sha,
    toUInt32OrZero(JSONExtractString(metadata, 'number')) AS pr_number,
    coalesce(
        JSONExtractString(metadata, 'head_commit', 'message'),
        JSONExtractString(metadata, 'pull_request', 'title'),
        JSONExtractString(metadata, 'pull_request', 'body'),
        ''
    ) AS message,
    time_created,
    metadata AS raw_metadata,
    now() AS inserted_at
FROM (
    SELECT
        event_type,
        id,
        metadata,
        time_created,
        source,
        msg_id AS buildMsgId
    FROM fourkeys.events_raw
) AS raw
WHERE source LIKE 'github%'
  AND event_type IN ('push', 'pull_request');
