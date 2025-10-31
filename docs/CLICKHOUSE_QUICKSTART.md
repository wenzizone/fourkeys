# ClickHouse DORA 指标系统 - 快速开始指南

完全开源自建方案，替代 GCP BigQuery + Pub/Sub

## 📋 目录

1. [系统架构](#系统架构)
2. [前置要求](#前置要求)
3. [快速开始](#快速开始)
4. [配置指南](#配置指南)
5. [使用示例](#使用示例)
6. [故障排查](#故障排查)
7. [性能优化](#性能优化)

---

## 系统架构

```
┌─────────────────┐
│ GitHub Webhook  │
│ GitLab Webhook  │
│ ArgoCD Event    │
└────────┬────────┘
         │ HTTP POST
         ↓
    ┌─────────────────────┐
    │  Flask Parser Apps  │────┐
    │ (github-parser,     │    │ 直接写入
    │  argocd-parser...)  │────┤
    └─────────────────────┘    │
                               │
                        ┌──────↓──────┐
                        │  ClickHouse │
                        │   (OLAP DB) │
                        └──────┬──────┘
                               │
                ┌──────────────┼──────────────┐
                ↓              ↓              ↓
           ┌─────────┐  ┌─────────┐  ┌─────────┐
           │ Grafana │  │Metabase │  │ Python  │
           │ 仪表板  │  │  仪表板 │  │  查询   │
           └─────────┘  └─────────┘  └─────────┘
```

### 架构优势

| 方面 | GCP 原方案 | 开源方案 |
|------|----------|--------|
| **成本** | 月 $200-600+ | 月 $50-200 |
| **数据所有权** | 云托管 | 完全自控 |
| **锁定风险** | 高 | 无 |
| **扩展性** | 自动 | 手动控制 |
| **学习曲线** | 陡 | 平缓 |

---

## 前置要求

### 系统要求

```bash
# 最低配置
- CPU: 4 核
- 内存: 8GB
- 磁盘: 50GB
- Docker 20.10+
- Docker Compose 2.0+

# 推荐配置（生产）
- CPU: 8+ 核
- 内存: 16GB+
- 磁盘: 200GB+
- SSD 硬盘
```

### 软件依赖

```bash
# 安装 Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# 安装 Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# 验证安装
docker --version
docker-compose --version
```

---

## 快速开始

### 1. 克隆项目并进入目录

```bash
cd /path/to/bq-workers

# 确保有以下文件
ls -la | grep -E "(clickhouse_schema.sql|docker-compose.clickhouse.yml|clickhouse_client.py)"
```

### 2. 启动完整栈（一行命令）

```bash
# 启动所有服务
docker-compose -f docker-compose.clickhouse.yml up -d

# 查看日志
docker-compose -f docker-compose.clickhouse.yml logs -f

# 检查服务状态
docker-compose -f docker-compose.clickhouse.yml ps
```

### 3. 验证服务健康

```bash
# 检查 ClickHouse 是否就绪
curl http://localhost:8123/ping

# 检查 Grafana 是否就绪
curl http://localhost:3000

# 检查 Parser 是否就绪
curl http://localhost:8080/health
```

### 4. 初始化数据库

```bash
# 进入 ClickHouse 客户端
docker exec -it bq-workers_clickhouse_1 clickhouse-client

# 执行以下命令验证表是否已创建
SHOW TABLES;

# 检查事件表结构
DESCRIBE TABLE events;

# 退出
exit
```

### 5. 配置 Grafana 数据源

```bash
# 访问 Grafana: http://localhost:3000
# 用户名: admin
# 密码: admin123

# 步骤:
# 1. 进入 Configuration → Data Sources
# 2. 添加新数据源 → ClickHouse
# 3. 填写以下信息:
#    - Name: ClickHouse
#    - URL: http://clickhouse:8123
#    - Database: fourkeys
#    - 点击 "Save & Test"
```

### 6. 测试数据流

```bash
# 发送测试 Webhook 到 GitHub Parser
curl -X POST http://localhost:8080 \
  -H "Content-Type: application/json" \
  -d '{
    "message": {
      "data": "eyJoZWFkX2NvbW1pdCI6IHsiaWQiOiAiYWJjMTIzIiwgInRpbWVzdGFtcCI6ICIyMDI0LTAxLTAxVDAwOjAwOjAwWiJ9LCAicHVzaGVyIjogeyJlbWFpbCI6ICJ1c2VyQGV4YW1wbGUuY29tIn0sICJyZXBvc2l0b3J5IjogeyJuYW1lIjogIm15LXJlcG8ifSwgInJlZiI6ICJyZWZzL2hlYWRzL21haW4ifQ==",
      "attributes": {
        "headers": "{\"X-Github-Event\": \"push\", \"X-Hub-Signature\": \"sha1=test\"}"
      },
      "message_id": "msg-001"
    }
  }'

# 返回 204 表示成功
```

### 7. 验证数据是否存储

```bash
# 进入 ClickHouse 客户端
docker exec -it bq-workers_clickhouse_1 clickhouse-client

# 查询事件
SELECT * FROM events LIMIT 5;

# 查询部署频率视图
SELECT * FROM deployment_frequency_view LIMIT 10;

# 获取四个关键指标
SELECT * FROM four_keys_overview;
```

---

## 配置指南

### 环境变量

编辑 `docker-compose.clickhouse.yml`，修改以下环境变量：

```yaml
# ClickHouse 配置
CLICKHOUSE_DB: fourkeys
CLICKHOUSE_USER: default
CLICKHOUSE_PASSWORD: ""  # 留空或设置密码

# Parser 配置
CLICKHOUSE_HOST: clickhouse
CLICKHOUSE_PORT: 9000

# Grafana 配置
GF_SECURITY_ADMIN_PASSWORD: admin123  # 修改为强密码
GF_INSTALL_PLUGINS: grafana-piechart-panel
```

### 生产环境建议

```yaml
# 1. 添加认证
CLICKHOUSE_USER: metrics_user
CLICKHOUSE_PASSWORD: "$(openssl rand -base64 32)"

# 2. 增加资源限制
services:
  clickhouse:
    mem_limit: 8g
    cpus: "4"

# 3. 添加备份卷
volumes:
  clickhouse_backup:
    driver: local
    driver_opts:
      type: nfs
      o: "addr=nfs-server,vers=4,soft,timeo=180,bg,tcp,rw"
      device: ":/mnt/backups"

# 4. 启用持久化日志
services:
  clickhouse:
    volumes:
      - ./data/logs:/var/log/clickhouse-server
```

---

## 使用示例

### Python 集成示例

```python
from clickhouse_client import ClickHouseMetricsClient
from datetime import datetime

# 初始化客户端
client = ClickHouseMetricsClient(
    host='localhost',
    port=9000,
    database='fourkeys'
)

# 1. 插入事件
event = {
    'event_type': 'deployment',
    'source': 'argocd',
    'repository': 'my-service',
    'author': 'deploy-bot',
    'commit_sha': 'abc123def456',
    'branch': 'main',
    'status': 'success',
    'time_created': datetime.now().isoformat(),
    'metadata': {
        'url': 'https://github.com/user/repo/commit/abc123',
        'service': 'api-server'
    }
}
client.insert_event(event)

# 2. 查询部署频率
deployment_freq = client.get_deployment_frequency(days=30)
print(f"过去 30 天部署: {deployment_freq}")

# 3. 查询 Lead Time
lead_time = client.get_lead_time(days=30)
print(f"Lead Time 数据: {lead_time}")

# 4. 查询四个关键指标
overview = client.get_four_keys_overview()
print(f"""
四个关键指标:
- 今日部署: {overview['deployments_today']}
- 90天 Lead Time (中位数): {overview['median_lead_time_90d']} 分钟
- 90天变更失败率: {overview['avg_failure_rate_90d']}%
- 90天 MTTR (中位数): {overview['median_mttr_90d']} 分钟
""")

client.close()
```

### SQL 查询示例

```sql
-- 1. 每日部署统计
SELECT
    toDate(time_created) AS day,
    COUNT(*) AS total_events,
    COUNT(DISTINCT commit_sha) AS unique_commits,
    COUNT(CASE WHEN status = 'success' THEN 1 END) AS success_count
FROM events
WHERE toDate(time_created) >= today() - 30
GROUP BY day
ORDER BY day DESC;

-- 2. 按来源统计事件
SELECT
    source,
    event_type,
    COUNT() AS event_count,
    COUNT(DISTINCT repository) AS unique_repos
FROM events
WHERE time_created >= now() - INTERVAL 30 DAY
GROUP BY source, event_type
ORDER BY event_count DESC;

-- 3. 部署失败分析
SELECT
    repository,
    COUNT() AS total_deployments,
    SUM(CASE WHEN status = 'failure' THEN 1 ELSE 0 END) AS failed_deployments,
    ROUND((SUM(CASE WHEN status = 'failure' THEN 1 ELSE 0 END) * 100.0) / COUNT(), 2) AS failure_rate
FROM deployments
WHERE toDate(time_created) >= today() - 30
GROUP BY repository
HAVING total_deployments > 0
ORDER BY failure_rate DESC;

-- 4. Lead Time 百分位数
SELECT
    repository,
    quantile(0.5)(lead_time_minutes) AS p50,
    quantile(0.95)(lead_time_minutes) AS p95,
    quantile(0.99)(lead_time_minutes) AS p99,
    max(lead_time_minutes) AS max_time
FROM changes
WHERE status = 'deployed' AND deployed_time >= now() - INTERVAL 90 DAY
GROUP BY repository;
```

---

## 故障排查

### 问题 1: ClickHouse 无法启动

```bash
# 检查日志
docker logs bq-workers_clickhouse_1

# 常见原因:
# 1. 磁盘空间不足
df -h

# 2. 端口被占用
sudo netstat -tulpn | grep 9000

# 3. 权限问题
sudo chown -R 999:999 /var/lib/clickhouse
```

### 问题 2: Parser 连接不到 ClickHouse

```bash
# 进入 Parser 容器
docker exec -it bq-workers_github_parser_1 bash

# 测试连接
python -c "from clickhouse_driver import Client; c = Client('clickhouse'); print(c.execute('SELECT 1'))"

# 检查网络
ping clickhouse
telnet clickhouse 9000
```

### 问题 3: 数据查询很慢

```bash
# 1. 检查表结构和索引
SHOW CREATE TABLE events;

# 2. 检查分区
SELECT partition, rows FROM system.parts WHERE table = 'events';

# 3. 优化查询计划
EXPLAIN SELECT * FROM events WHERE time_created > now() - INTERVAL 1 DAY;

# 4. 运行优化合并
OPTIMIZE TABLE events;
```

### 问题 4: Grafana 仪表板为空

```bash
# 1. 验证数据源连接
# Grafana UI → Configuration → Data Sources → ClickHouse → Test

# 2. 检查数据是否存在
SELECT COUNT(*) FROM events;

# 3. 检查查询语法
# 使用 Test Query 功能验证

# 4. 查看 Grafana 日志
docker logs bq-workers_grafana_1
```

---

## 性能优化

### 1. ClickHouse 配置优化

```yaml
# docker-compose.yml 中添加配置
clickhouse:
  environment:
    # 增加最大连接数
    MAX_CONNECTIONS: 4096
    # 增加最大内存使用
    MAX_MEMORY_USAGE: "16GB"
    # 启用压缩
    COMPRESSION_CODEC: "lz4"
```

### 2. 数据库优化

```sql
-- 1. 添加 TTL（自动删除过期数据）
ALTER TABLE events
MODIFY TTL time_created + INTERVAL 2 YEAR;

-- 2. 创建汇总表加速查询
CREATE TABLE events_summary ON CLUSTER default AS
SELECT
    toDate(time_created) AS date,
    source,
    event_type,
    COUNT() AS cnt,
    SUM(duration_ms) AS total_duration
FROM events
GROUP BY date, source, event_type;

-- 3. 并行查询优化
SET max_threads = 8;
SET max_insert_threads = 8;
```

### 3. 监控和告警

```python
# 添加监控脚本
import psutil
import time

while True:
    # CPU 使用率
    cpu = psutil.cpu_percent(interval=1)
    
    # 内存使用率
    mem = psutil.virtual_memory().percent
    
    # 磁盘使用率
    disk = psutil.disk_usage('/').percent
    
    if cpu > 80 or mem > 80 or disk > 85:
        # 发送告警
        print(f"告警: CPU={cpu}%, MEM={mem}%, DISK={disk}%")
    
    time.sleep(60)
```

---

## 维护和备份

### 自动备份

```bash
#!/bin/bash
# backup.sh

BACKUP_DIR="/backups/clickhouse"
DATE=$(date +%Y%m%d_%H%M%S)

# 创建备份
docker exec bq-workers_clickhouse_1 \
  clickhouse-backup create "backup_${DATE}"

# 上传到远程存储
aws s3 cp "${BACKUP_DIR}" s3://my-backups/clickhouse/ --recursive

# 只保留最近 30 天的备份
find "${BACKUP_DIR}" -mtime +30 -delete
```

### 恢复数据

```bash
# 列出可用备份
docker exec bq-workers_clickhouse_1 clickhouse-backup list

# 恢复特定备份
docker exec bq-workers_clickhouse_1 \
  clickhouse-backup restore "backup_20240101_120000"
```

---

## 扩展和升级

### 水平扩展（多节点集群）

```yaml
# 使用 ClickHouse Keeper 部署集群
# 参考: https://clickhouse.com/docs/en/deployment-guides/cluster-deployment
```

### 升级 ClickHouse

```bash
# 1. 备份数据
docker exec bq-workers_clickhouse_1 clickhouse-backup create

# 2. 更新版本号
# 修改 docker-compose.yml 中的 image tag

# 3. 重建容器
docker-compose -f docker-compose.clickhouse.yml up -d --force-recreate

# 4. 验证升级
docker exec bq-workers_clickhouse_1 clickhouse-client --version
```

---

## 参考资源

- [ClickHouse 官方文档](https://clickhouse.com/docs/en)
- [ClickHouse Python 驱动](https://github.com/ClickHouse/clickhouse-python)
- [Grafana ClickHouse 插件](https://grafana.com/grafana/plugins/grafana-clickhouse-datasource)
- [Docker Compose 文档](https://docs.docker.com/compose/)

---

## 获取帮助

```bash
# 查看日志
docker-compose -f docker-compose.clickhouse.yml logs [service-name]

# 进入容器调试
docker exec -it bq-workers_[service]_1 bash

# 查看资源使用
docker stats

# 清理所有容器和卷
docker-compose -f docker-compose.clickhouse.yml down -v
```

---

**祝你部署顺利！** 🚀
