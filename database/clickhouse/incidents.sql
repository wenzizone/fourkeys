-- Ensure database exists
CREATE DATABASE IF NOT EXISTS fourkeys;

-- Table for incident records (for MTTR / Change Failure Rate)
CREATE TABLE IF NOT EXISTS fourkeys.incidents
(
    incident_id String,
    incident_type String,
    service String,
    severity String,
    time_detected DateTime,
    time_resolved DateTime,
    resolution_minutes Int32,
    related_deployment String,
    raw_metadata String,
    inserted_at DateTime DEFAULT now()
)
ENGINE = MergeTree
ORDER BY (service, incident_id, time_detected);

DROP VIEW IF EXISTS fourkeys.mv_incidents;

CREATE MATERIALIZED VIEW fourkeys.mv_incidents
TO fourkeys.incidents
AS
SELECT
    JSONExtractString(metadata, 'incident_id') AS incident_id,
    JSONExtractString(metadata, 'type') AS incident_type,
    JSONExtractString(metadata, 'service') AS service,
    JSONExtractString(metadata, 'severity') AS severity,
    parseDateTimeBestEffortOrNull(JSONExtractString(metadata, 'time_detected')) AS time_detected,
    parseDateTimeBestEffortOrNull(JSONExtractString(metadata, 'time_resolved')) AS time_resolved,
    toInt32OrZero(
        ifNull(
            dateDiff('minute',
                parseDateTimeBestEffortOrNull(JSONExtractString(metadata, 'time_detected')),
                parseDateTimeBestEffortOrNull(JSONExtractString(metadata, 'time_resolved'))
            ),
        0)
    ) AS resolution_minutes,
    JSONExtractString(metadata, 'related_deployment') AS related_deployment,
    metadata AS raw_metadata,
    now() AS inserted_at
FROM fourkeys.events_raw
WHERE source = 'pagerduty'
  AND event_type = 'incident';
