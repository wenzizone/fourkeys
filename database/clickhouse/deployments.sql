-- Ensure database exists
CREATE DATABASE IF NOT EXISTS fourkeys;

-- Structured table for deployment events
CREATE TABLE IF NOT EXISTS fourkeys.deployments
(
    event_type String,
    deployment_id String,
    workflow_id String,
    project_slug String,
    pipeline_id String,
    workflow_name String,
    workflow_status String,
    job_id String,
    job_name String,
    job_status String,
    duration_seconds Int32,
    url String,
    time_created DateTime,
    raw_metadata String,
    inserted_at DateTime DEFAULT now()
)
ENGINE = MergeTree
ORDER BY (project_slug, deployment_id, time_created);

DROP VIEW IF EXISTS fourkeys.mv_deployments;

CREATE MATERIALIZED VIEW fourkeys.mv_deployments
TO fourkeys.deployments
AS
SELECT
    event_type,
    coalesce(JSONExtractString(metadata, 'id'), msg_id) AS deployment_id,
    JSONExtractString(metadata, 'workflow', 'id') AS workflow_id,
    coalesce(
        JSONExtractString(metadata, 'workflow', 'project_slug'),
        JSONExtractString(metadata, 'application', 'project')
    ) AS project_slug,
    JSONExtractString(metadata, 'pipeline_id') AS pipeline_id,
    coalesce(
        JSONExtractString(metadata, 'workflow', 'name'),
        JSONExtractString(metadata, 'application', 'name')
    ) AS workflow_name,
    coalesce(
        JSONExtractString(metadata, 'workflow', 'status'),
        JSONExtractString(metadata, 'application', 'health', 'status'),
        JSONExtractString(metadata, 'application', 'sync', 'status')
    ) AS workflow_status,
    JSONExtractString(metadata, 'job', 'id') AS job_id,
    JSONExtractString(metadata, 'job', 'name') AS job_name,
    JSONExtractString(metadata, 'job', 'status') AS job_status,
    coalesce(
        toInt32OrZero(JSONExtractString(metadata, 'duration')),
        toInt32OrZero(JSONExtractString(metadata, 'metrics', 'deployDurationSeconds'))
    ) AS duration_seconds,
    coalesce(
        JSONExtractString(metadata, 'workflow', 'url'),
        JSONExtractString(metadata, 'application', 'sync', 'comparedTo', 'source', 'repoURL')
    ) AS url,
    time_created,
    metadata AS raw_metadata,
    now() AS inserted_at
FROM (
    SELECT
        event_type,
        metadata,
        time_created,
        source,
        msg_id
    FROM fourkeys.events_raw
) AS raw
WHERE (
        source = 'circleci'
        AND event_type IN ('workflow-completed', 'job-completed')
    )
   OR (
        source = 'argocd'
        AND event_type = 'deployment'
    );
