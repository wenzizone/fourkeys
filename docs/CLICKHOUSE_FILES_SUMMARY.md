# ClickHouse DORA 指标系统 - 文件清单

为你创建的完整文件列表及说明

## 📁 新增文件清单

### 1. **核心数据库文件**

#### `clickhouse_schema.sql` ✨ 最重要
- **描述**: ClickHouse 完整的 SQL schema 定义
- **包含内容**:
  - 5 个主要表 (events, deployments, changes, incidents, services)
  - 4 个物化视图用于预聚合
  - 5 个查询视图用于 Grafana/仪表板
  - 1 个四个关键指标概览视图
  - 索引和优化配置
  - 示例数据插入

- **如何使用**:
  ```bash
  # Docker Compose 会自动执行此文件
  docker-compose -f docker-compose.clickhouse.yml up
  
  # 或手动执行
  docker exec -i bq-workers_clickhouse_1 clickhouse-client < clickhouse_schema.sql
  ```

### 2. **Python 客户端库**

#### `clickhouse_client.py` 🐍
- **描述**: 完整的 ClickHouse 客户端库，用于应用集成
- **主要类**: `ClickHouseMetricsClient`
- **核心功能**:
  - `insert_event()` - 插入单个事件
  - `insert_deployment()` - 插入部署记录
  - `insert_change()` - 插入变更记录（Lead Time）
  - `insert_incident()` - 插入事件/告警（MTTR）
  - `batch_insert_events()` - 批量插入
  - `get_deployment_frequency()` - 查询部署频率
  - `get_lead_time()` - 查询 Lead Time
  - `get_change_failure_rate()` - 查询变更失败率
  - `get_mttr()` - 查询平均恢复时间
  - `get_four_keys_overview()` - 查询四个关键指标

- **依赖**:
  ```bash
  pip install clickhouse-driver
  ```

- **使用示例**:
  ```python
  from clickhouse_client import ClickHouseMetricsClient
  
  client = ClickHouseMetricsClient(host='localhost')
  client.insert_event({...})
  data = client.get_deployment_frequency(days=30)
  ```

### 3. **改进的 Parser**

#### `github_parser_clickhouse.py` 🔄
- **描述**: 改进的 GitHub Parser，支持 ClickHouse 后端
- **改动**:
  - 替换 BigQuery → ClickHouse
  - 添加 `/health` 健康检查端点
  - 支持 Pub/Sub 和直接 Webhook 格式
  - 完整的错误处理和日志记录

- **环境变量**:
  ```bash
  CLICKHOUSE_HOST=localhost
  CLICKHOUSE_PORT=9000
  CLICKHOUSE_DB=fourkeys
  CLICKHOUSE_USER=default
  CLICKHOUSE_PASSWORD=
  PORT=8080
  ```

- **可复制此逻辑到其他 Parser**:
  - `argocd_parser_clickhouse.py`
  - `cloud_build_parser_clickhouse.py`
  - `circleci_parser_clickhouse.py`

### 4. **部署配置**

#### `docker-compose.clickhouse.yml` 🐳
- **描述**: 完整的 Docker Compose 配置
- **包含服务**:
  - ClickHouse (OLAP 数据库)
  - Zookeeper (Kafka 协调器)
  - Kafka (消息队列)
  - 4 个 Parser 服务 (GitHub, ArgoCD, CloudBuild, CircleCI)
  - Grafana (仪表板)
  - ClickHouse 客户端 (调试工具)

- **一键启动**:
  ```bash
  docker-compose -f docker-compose.clickhouse.yml up -d
  ```

- **关键特性**:
  - 自动化数据库初始化
  - 健康检查
  - 网络隔离
  - 数据卷持久化
  - 依赖管理

### 5. **文档和指南**

#### `CLICKHOUSE_QUICKSTART.md` 📚
- **内容**:
  1. 系统架构图
  2. 成本对比分析
  3. 前置要求检查清单
  4. 7 步快速开始指南
  5. 环境变量配置
  6. 生产环境建议
  7. Python 集成示例
  8. SQL 查询示例
  9. 12 个常见故障排查
  10. 性能优化方案
  11. 维护和备份指南
  12. 升级和扩展方案

---

## 📊 文件关系图

```
┌─────────────────────────────────────────────┐
│   clickhouse_schema.sql                     │ 数据库结构
│   - 5 个表                                   │
│   - 9 个视图                                 │
└────────────────┬────────────────────────────┘
                 │
                 │ 使用
                 ↓
    ┌──────────────────────────┐
    │  clickhouse_client.py    │ Python 客户端库
    │  ClickHouseMetricsClient │ 数据访问层
    └──────────────┬───────────┘
                   │
         ┌─────────┼─────────┐
         │         │         │
         ↓         ↓         ↓
    ┌─────────┐ ┌─────────┐ ┌──────────┐
    │ Parser  │ │ Grafana │ │  Python  │
    │应用代码 │ │ 仪表板  │ │  脚本    │
    └─────────┘ └─────────┘ └──────────┘
         │         │
         └────┬────┘
              │
              ↓
    ┌─────────────────────┐
    │ docker-compose.yml  │ 编排配置
    │ 一键启动所有服务    │
    └─────────────────────┘
```

---

## 🚀 快速开始命令

```bash
# 1. 复制所有文件到 bq-workers 目录
cp clickhouse_*.* ./bq-workers/
cp docker-compose.clickhouse.yml ./bq-workers/
cp CLICKHOUSE_*.md ./bq-workers/

# 2. 进入目录
cd ./bq-workers

# 3. 启动所有服务
docker-compose -f docker-compose.clickhouse.yml up -d

# 4. 等待服务启动（约 30-60 秒）
docker-compose -f docker-compose.clickhouse.yml ps

# 5. 访问服务
Grafana:  http://localhost:3000        (admin/admin123)
ClickHouse HTTP: http://localhost:8123
ClickHouse Native: localhost:9000

# 6. 测试数据流
curl -X POST http://localhost:8080/health

# 7. 验证数据
docker exec -it bq-workers_clickhouse_1 clickhouse-client
> SELECT COUNT(*) FROM events;
```

---

## 🔧 集成到现有 Parser

以 GitHub Parser 为例：

### 方案 A: 全量替换（推荐）
```bash
# 1. 备份原文件
mv argocd-parser/main.py argocd-parser/main.py.bak

# 2. 复制新文件
cp clickhouse_client.py argocd-parser/
cp github_parser_clickhouse.py argocd-parser/main.py

# 3. 更新 requirements.txt
echo "clickhouse-driver==0.4.7" >> argocd-parser/requirements.txt
```

### 方案 B: 保留 shared 库
```python
# 在 github_parser_clickhouse.py 中添加
from shared import create_unique_id

# 使用 ClickHouse 客户端替换 BigQuery 部分
def insert_row_into_clickhouse(event):
    client = ClickHouseMetricsClient()
    client.insert_event(event)
```

---

## 📋 文件对应表

| 文件 | 大小 | 行数 | 用途 |
|------|------|------|------|
| `clickhouse_schema.sql` | ~12KB | 300+ | 数据库 schema |
| `clickhouse_client.py` | ~25KB | 600+ | Python 客户端 |
| `github_parser_clickhouse.py` | ~15KB | 350+ | 改进的 Parser |
| `docker-compose.clickhouse.yml` | ~10KB | 250+ | 部署编排 |
| `CLICKHOUSE_QUICKSTART.md` | ~50KB | 1000+ | 完整指南 |

**总计**: ~112KB, 2500+ 行代码

---

## ✅ 验证清单

部署完成后检查以下项目：

```bash
# 1. ✅ 所有容器都在运行
docker-compose -f docker-compose.clickhouse.yml ps

# 2. ✅ ClickHouse 数据库已初始化
docker exec bq-workers_clickhouse_1 clickhouse-client -q "SHOW TABLES"

# 3. ✅ 表结构正确
docker exec bq-workers_clickhouse_1 clickhouse-client -q "DESCRIBE TABLE events"

# 4. ✅ 视图已创建
docker exec bq-workers_clickhouse_1 clickhouse-client -q "SHOW VIEWS"

# 5. ✅ Parser 健康状态
curl http://localhost:8080/health
curl http://localhost:8081/health

# 6. ✅ Grafana 可访问
curl http://localhost:3000

# 7. ✅ 能插入数据
curl -X POST http://localhost:8080 -H "Content-Type: application/json" -d '{...}'

# 8. ✅ 能查询数据
docker exec bq-workers_clickhouse_1 clickhouse-client -q "SELECT COUNT(*) FROM events"
```

---

## 📖 下一步

1. **阅读 CLICKHOUSE_QUICKSTART.md** 获取详细指南
2. **运行 Docker Compose** 启动完整系统
3. **配置 Grafana** 创建仪表板
4. **集成现有 Parser** 或部署新的
5. **监控性能** 和优化查询

---

## 🎯 成本节省

| 项目 | GCP 方案 | 开源方案 | 节省 |
|------|---------|--------|------|
| Pub/Sub | $25-50/月 | 自建 Kafka | 100% |
| Cloud Run | $50-100/月 | Docker | 100% |
| BigQuery | $100-500+/月 | ClickHouse | 90%+ |
| **总计** | **$175-650/月** | **$50-200/月** | **70-85%** |

**一年节省: $1,800-7,200 💰**

---

## 📞 技术支持

遇到问题？

1. 查看 `CLICKHOUSE_QUICKSTART.md` 中的故障排查章节
2. 检查 Docker 日志: `docker-compose logs [service]`
3. 进入容器调试: `docker exec -it [container] bash`
4. 参考 ClickHouse 官方文档: https://clickhouse.com/docs

---

**祝你部署顺利！🚀**

创建时间: 2024
版本: 1.0
