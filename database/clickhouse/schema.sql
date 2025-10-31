-- ClickHouse Schema for DORA Four Keys Metrics
-- 优化为列式存储和时序数据分析
-- ====================================================================

-- 1. 核心事件表（分片表）
-- 使用 ReplicatedMergeTree 支持分布式和副本
CREATE TABLE IF NOT EXISTS events ON CLUSTER '{cluster}' (
    event_id String,
    time_created DateTime,
    event_type Enum(
        'push' = 1,
        'pull_request' = 2,
        'pull_request_review' = 3,
        'check_run' = 4,
        'deployment' = 5,
        'deployment_status' = 6,
        'incident' = 7,
        'build' = 8
    ),
    source Enum(
        'github' = 1,
        'gitlab' = 2,
        'argocd' = 3,
        'cloud_build' = 4,
        'circleci' = 5,
        'tekton' = 6,
        'pagerduty' = 7
    ),
    msg_id String,
    signature String,
    metadata String,  -- JSON 格式的元数据
    repository String,  -- 仓库名
    author String,      -- 作者/操作者
    commit_sha String,  -- Commit SHA
    branch String,      -- 分支名
    pr_number UInt32,   -- PR 编号（如果有）
    status Enum(
        'pending' = 1,
        'success' = 2,
        'failure' = 3,
        'cancelled' = 4,
        'created' = 5,
        'resolved' = 6
    ),
    tags Array(String), -- 标签数组
    duration_ms UInt32, -- 持续时间（毫秒）
    created_at DateTime DEFAULT now()
) ENGINE = ReplicatedMergeTree('/clickhouse/tables/{cluster}/{shard}/events', '{replica}')
ORDER BY (source, time_created, event_type)
PARTITION BY toYYYYMM(time_created)
TTL time_created + INTERVAL 1 YEAR;

-- 2. 部署表（特化表）
CREATE TABLE IF NOT EXISTS deployments ON CLUSTER '{cluster}' (
    deploy_id String,
    time_created DateTime,
    service_name String,
    environment Enum('dev' = 1, 'staging' = 2, 'prod' = 3),
    version String,
    commit_sha String,
    author String,
    status Enum('success' = 1, 'failure' = 2, 'in_progress' = 3),
    duration_ms UInt32,
    repository String,
    pr_numbers Array(UInt32),
    metadata String,
    created_at DateTime DEFAULT now()
) ENGINE = ReplicatedMergeTree('/clickhouse/tables/{cluster}/{shard}/deployments', '{replica}')
ORDER BY (environment, time_created, service_name)
PARTITION BY toYYYYMM(time_created)
TTL time_created + INTERVAL 1 YEAR;

-- 3. 变更表（用于计算 Lead Time）
CREATE TABLE IF NOT EXISTS changes ON CLUSTER '{cluster}' (
    change_id String,
    commit_sha String,
    author String,
    repository String,
    commit_time DateTime,
    deployed_time DateTime,
    lead_time_minutes UInt32,  -- 从提交到部署的时间
    pr_number UInt32,
    pr_created_time DateTime,
    pr_merged_time DateTime,
    status Enum('pending' = 1, 'deployed' = 2, 'reverted' = 3),
    metadata String,
    created_at DateTime DEFAULT now()
) ENGINE = ReplicatedMergeTree('/clickhouse/tables/{cluster}/{shard}/changes', '{replica}')
ORDER BY (repository, commit_time)
PARTITION BY toYYYYMM(commit_time)
TTL commit_time + INTERVAL 1 YEAR;

-- 4. 事件表（用于计算 MTTR）
CREATE TABLE IF NOT EXISTS incidents ON CLUSTER '{cluster}' (
    incident_id String,
    time_detected DateTime,
    time_resolved DateTime,
    resolution_time_minutes UInt32,
    severity Enum('critical' = 1, 'high' = 2, 'medium' = 3, 'low' = 4),
    service String,
    root_cause String,
    related_deployment String,
    related_pr_numbers Array(UInt32),
    metadata String,
    created_at DateTime DEFAULT now()
) ENGINE = ReplicatedMergeTree('/clickhouse/tables/{cluster}/{shard}/incidents', '{replica}')
ORDER BY (service, time_detected)
PARTITION BY toYYYYMM(time_detected)
TTL time_detected + INTERVAL 1 YEAR;

-- 5. 字典表（维度数据）
CREATE TABLE IF NOT EXISTS services (
    service_id String,
    service_name String,
    team String,
    repository String,
    language String,
    tags Array(String),
    created_at DateTime
) ENGINE = ReplacingMergeTree()
ORDER BY service_id;

-- ====================================================================
-- 物化视图（预聚合数据）
-- ====================================================================

-- 1. 每日部署频率
CREATE MATERIALIZED VIEW IF NOT EXISTS daily_deployment_frequency ON CLUSTER '{cluster}' AS
SELECT
    toDate(time_created) AS deployment_date,
    environment,
    service_name,
    COUNT(DISTINCT deploy_id) AS deployment_count,
    SUM(CASE WHEN status = 'success' THEN 1 ELSE 0 END) AS successful_deployments,
    SUM(CASE WHEN status = 'failure' THEN 1 ELSE 0 END) AS failed_deployments
FROM deployments
GROUP BY deployment_date, environment, service_name
ENGINE = SummingMergeTree()
ORDER BY (deployment_date, environment, service_name);

-- 2. Lead Time 统计
CREATE MATERIALIZED VIEW IF NOT EXISTS lead_time_stats ON CLUSTER '{cluster}' AS
SELECT
    toDate(deployed_time) AS deployment_date,
    repository,
    quantile(0.5)(lead_time_minutes) AS median_lead_time,
    quantile(0.95)(lead_time_minutes) AS p95_lead_time,
    quantile(0.99)(lead_time_minutes) AS p99_lead_time,
    avg(lead_time_minutes) AS avg_lead_time,
    min(lead_time_minutes) AS min_lead_time,
    max(lead_time_minutes) AS max_lead_time
FROM changes
WHERE status = 'deployed'
GROUP BY deployment_date, repository
ENGINE = SummingMergeTree()
ORDER BY (deployment_date, repository);

-- 3. 变更失败率
CREATE MATERIALIZED VIEW IF NOT EXISTS change_failure_rate ON CLUSTER '{cluster}' AS
SELECT
    toDate(deployed_time) AS deployment_date,
    service_name,
    COUNT(DISTINCT deploy_id) AS total_deployments,
    SUM(CASE WHEN (SELECT COUNT(*) FROM incidents 
                   WHERE related_deployment = deploy_id) > 0 THEN 1 ELSE 0 END) AS failed_deployments
FROM deployments
WHERE environment = 'prod'
GROUP BY deployment_date, service_name
ENGINE = SummingMergeTree()
ORDER BY (deployment_date, service_name);

-- 4. MTTR 统计
CREATE MATERIALIZED VIEW IF NOT EXISTS mttr_stats ON CLUSTER '{cluster}' AS
SELECT
    toDate(time_detected) AS incident_date,
    service,
    COUNT() AS total_incidents,
    quantile(0.5)(resolution_time_minutes) AS median_mttr,
    quantile(0.95)(resolution_time_minutes) AS p95_mttr,
    avg(resolution_time_minutes) AS avg_mttr,
    min(resolution_time_minutes) AS min_mttr,
    max(resolution_time_minutes) AS max_mttr
FROM incidents
GROUP BY incident_date, service
ENGINE = SummingMergeTree()
ORDER BY (incident_date, service);

-- ====================================================================
-- 查询视图（用于 Grafana/仪表板）
-- ====================================================================

-- 1. 部署频率面板
CREATE VIEW deployment_frequency_view AS
SELECT
    deployment_date,
    environment,
    service_name,
    deployment_count,
    successful_deployments,
    failed_deployments,
    ROUND((successful_deployments * 100.0) / deployment_count, 2) AS success_rate
FROM daily_deployment_frequency
ORDER BY deployment_date DESC, environment, service_name;

-- 2. Lead Time 面板
CREATE VIEW lead_time_view AS
SELECT
    deployment_date,
    repository,
    ROUND(median_lead_time / 60, 2) AS median_lead_time_hours,
    ROUND(p95_lead_time / 60, 2) AS p95_lead_time_hours,
    ROUND(p99_lead_time / 60, 2) AS p99_lead_time_hours,
    ROUND(avg_lead_time / 60, 2) AS avg_lead_time_hours
FROM lead_time_stats
ORDER BY deployment_date DESC, repository;

-- 3. 变更失败率面板
CREATE VIEW change_failure_view AS
SELECT
    deployment_date,
    service_name,
    total_deployments,
    failed_deployments,
    ROUND((failed_deployments * 100.0) / total_deployments, 2) AS failure_rate
FROM change_failure_rate
WHERE total_deployments > 0
ORDER BY deployment_date DESC, service_name;

-- 4. MTTR 面板
CREATE VIEW mttr_view AS
SELECT
    incident_date,
    service,
    total_incidents,
    ROUND(median_mttr / 60, 2) AS median_mttr_hours,
    ROUND(p95_mttr / 60, 2) AS p95_mttr_hours,
    ROUND(avg_mttr / 60, 2) AS avg_mttr_hours
FROM mttr_stats
ORDER BY incident_date DESC, service;

-- 5. 四个关键指标概览
CREATE VIEW four_keys_overview AS
SELECT
    now() AS report_time,
    (SELECT COUNT(DISTINCT deploy_id) FROM deployments 
     WHERE toDate(time_created) = today()) AS deployments_today,
    (SELECT quantile(0.5)(lead_time_minutes) FROM changes 
     WHERE status = 'deployed' AND toDate(deployed_time) >= today() - 90) AS median_lead_time_90d,
    (SELECT ROUND((SUM(CASE WHEN total_deployments > 0 THEN failed_deployments * 100.0 / total_deployments ELSE 0 END) 
                   / COUNT()) , 2) FROM change_failure_rate 
     WHERE deployment_date >= today() - 90) AS avg_failure_rate_90d,
    (SELECT quantile(0.5)(resolution_time_minutes) FROM incidents 
     WHERE time_resolved >= now() - INTERVAL 90 DAY) AS median_mttr_90d;

-- ====================================================================
-- 索引和优化
-- ====================================================================

-- 为 events 表添加数据跳过索引
ALTER TABLE events ADD INDEX idx_source source TYPE set(1000) GRANULARITY 3;
ALTER TABLE events ADD INDEX idx_event_type event_type TYPE set(1000) GRANULARITY 3;

-- 为 deployments 表添加数据跳过索引
ALTER TABLE deployments ADD INDEX idx_service service_name TYPE set(1000) GRANULARITY 3;
ALTER TABLE deployments ADD INDEX idx_env environment TYPE set(1000) GRANULARITY 3;

-- ====================================================================
-- 示例数据插入
-- ====================================================================

INSERT INTO events VALUES
(
    generateUUIDv4(),
    now(),
    'push',
    'github',
    'msg-' || toString(rand()),
    'sig-' || toString(rand()),
    '{"commit": "abc123", "author": "user@example.com"}',
    'myrepo',
    'user@example.com',
    'abc123def456',
    'main',
    0,
    'success',
    ['ci', 'deploy'],
    1200,
    now()
);

-- ====================================================================
-- 系统表和设置
-- ====================================================================

-- 检查表大小
-- SELECT name, total_bytes FROM system.tables WHERE database = 'default';

-- 检查合并进度
-- SELECT * FROM system.merges;

-- 优化 ClickHouse 配置（在 config.xml 中添加）
-- <compression>
--     <default_compression_codec>lz4</default_compression_codec>
-- </compression>
