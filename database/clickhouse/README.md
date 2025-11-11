# 🗄️ ClickHouse 数据库配置

## 包含的文件

### Schema 定义
- `schema.sql` - 初始化基础库和 `events_raw` 表。
- `changes.sql` - 创建 `changes` 明细表及 `mv_changes` 视图（GitHub push / PR 自动入表）。
- `deployments.sql` - 创建 `deployments` 明细表及 `mv_deployments` 视图（CircleCI 与 ArgoCD 部署事件自动入表）。
- `incidents.sql` - 创建 `incidents` 表及 `mv_incidents` 视图（PagerDuty 等事件自动入表）。
- `services.sql` - 基础服务元数据表，可手动维护或后续扩展脚本同步。

当前仓库尚未定义 incidents / services 等其它表，README 先前提到的 “5 表 9 视图” 仅为模板描述，后续可按需补充。

## 使用方式

### Docker Compose 启动
Docker Compose 会自动执行 schema.sql：
```bash
docker-compose -f setup/docker/docker-compose.clickhouse.yml up -d
```

### 手动执行 Schema
```bash
docker exec -i clickhouse clickhouse-client < database/clickhouse/schema.sql
```

## 关键表结构

| 表名 | 用途 | 记录数 |
|------|------|--------|
| `events` | 原生事件数据 | 百万+ |
| `deployments` | 部署记录 | 万+ |
| `changes` | 代码变更 | 万+ |
| `incidents` | 事件/告警 | 万+ |
| `services` | 服务元数据 | 百+ |

## 相关文档

- 部署指南：`../../docs/CLICKHOUSE_QUICKSTART.md`
- 查询示例：`../../queries/clickhouse/`
- Python 客户端：`../../shared/clickhouse_client.py`
