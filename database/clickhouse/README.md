# 🗄️ ClickHouse 数据库配置

## 包含的文件

### Schema 定义
- `schema.sql` - 完整的 ClickHouse 数据库结构定义
  - 5 个表 (events, deployments, changes, incidents, services)
  - 9 个视图用于数据聚合和查询
  - 自动分区和 TTL 配置
  - 数据跳过索引优化

### 迁移脚本
- `migration/` - 数据库版本控制和升级脚本

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
