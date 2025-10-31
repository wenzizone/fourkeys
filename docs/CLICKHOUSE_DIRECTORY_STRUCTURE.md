# bq-workers 项目结构优化方案

## 📁 推荐的目录结构

```
bq-workers/
├── README.md                          # 项目主说明
├── docker-compose.clickhouse.yml      # ✨ Docker 编排（新）
├── requirements-clickhouse.txt        # ✨ Python 依赖（新）
│
├── docs/                              # 📚 文档目录（新建）
│   ├── README_CLICKHOUSE.md           # ClickHouse 项目总览
│   ├── CLICKHOUSE_QUICKSTART.md       # 详细部署指南
│   ├── CLICKHOUSE_FILES_SUMMARY.md    # 文件清单
│   └── DIRECTORY_STRUCTURE.md         # 本文件
│
├── db/                                # 🗄️ 数据库相关（新建）
│   ├── README.md                      # 数据库说明
│   └── clickhouse_schema.sql          # ClickHouse Schema
│
├── lib/                               # 📚 共享库（新建）
│   ├── README.md                      # 库说明
│   └── clickhouse_client.py           # ClickHouse 客户端
│
├── examples/                          # 💡 示例代码（新建）
│   ├── README.md                      # 示例说明
│   └── github_parser_clickhouse.py    # Parser 示例
│
├── parsers.cloudbuild.yaml            # 原有文件
│
├── argocd-parser/                     # 原有目录（可更新）
│   ├── main.py                        # ← 可使用 github_parser_clickhouse.py 的逻辑
│   ├── Dockerfile
│   ├── requirements.txt
│   └── ...
│
├── github-parser/                     # 原有目录
│   └── ...
│
├── cloud-build-parser/                # 原有目录
│   └── ...
│
├── circleci-parser/                   # 原有目录
│   └── ...
│
├── gitlab-parser/                     # 原有目录
│   └── ...
│
├── pagerduty-parser/                  # 原有目录
│   └── ...
│
├── tekton-parser/                     # 原有目录
│   └── ...
│
└── new-source-template/               # 原有目录
    └── ...
```

---

## 📋 文件分类说明

### 🔴 **核心配置文件**（根目录）
| 文件 | 用途 |
|------|------|
| `docker-compose.clickhouse.yml` | 一键启动所有服务 |
| `requirements-clickhouse.txt` | 所有 Python 依赖 |

### 🟠 **文档目录** (`docs/`)
| 文件 | 用途 |
|------|------|
| `README_CLICKHOUSE.md` | 项目总览和快速概览 |
| `CLICKHOUSE_QUICKSTART.md` | **从这里开始**，详细部署指南 |
| `CLICKHOUSE_FILES_SUMMARY.md` | 文件清单和集成方式 |

### 🟡 **数据库** (`db/`)
| 文件 | 用途 |
|------|------|
| `clickhouse_schema.sql` | 数据库 Schema（自动加载） |
| `README.md` | 数据库说明和查询示例 |

### 🟢 **共享库** (`lib/`)
| 文件 | 用途 |
|------|------|
| `clickhouse_client.py` | ClickHouse 客户端库（各 Parser 导入） |
| `README.md` | API 文档和使用示例 |

### 🔵 **示例代码** (`examples/`)
| 文件 | 用途 |
|------|------|
| `github_parser_clickhouse.py` | 改进的 GitHub Parser 示例 |
| `README.md` | 示例说明和集成指南 |

---

## 🔧 目录组织脚本

### 快速组织（运行一次）

```bash
#!/bin/bash
# organize-clickhouse.sh

cd /Users/hliu/Program/wenzizone/fourkeys/bq-workers

# 创建目录
mkdir -p docs db lib examples

# 移动文件到对应目录
echo "📦 组织 ClickHouse 文件..."

# 文档
mv CLICKHOUSE_QUICKSTART.md docs/ 2>/dev/null
mv CLICKHOUSE_FILES_SUMMARY.md docs/ 2>/dev/null
mv README_CLICKHOUSE.md docs/ 2>/dev/null
mv DIRECTORY_STRUCTURE.md docs/ 2>/dev/null

# 数据库
mv clickhouse_schema.sql db/ 2>/dev/null

# 共享库
mv clickhouse_client.py lib/ 2>/dev/null

# 示例代码
mv github_parser_clickhouse.py examples/ 2>/dev/null

# 其他
# docker-compose.clickhouse.yml 和 requirements-clickhouse.txt 保持在根目录

echo "✅ 文件组织完成！"
echo ""
echo "📂 新的目录结构:"
tree -L 2 -I 'node_modules' .
```

---

## 📝 每个目录需要的 README.md

### `docs/README.md`
```markdown
# 📚 ClickHouse DORA 指标系统 - 文档

## 快速导航

- **[README_CLICKHOUSE.md](./README_CLICKHOUSE.md)** - 项目总览
- **[CLICKHOUSE_QUICKSTART.md](./CLICKHOUSE_QUICKSTART.md)** - 👈 从这里开始部署
- **[CLICKHOUSE_FILES_SUMMARY.md](./CLICKHOUSE_FILES_SUMMARY.md)** - 文件清单
- **[DIRECTORY_STRUCTURE.md](./DIRECTORY_STRUCTURE.md)** - 目录结构说明

## 重要提示

1. 首先阅读 README_CLICKHOUSE.md 了解项目
2. 然后按照 CLICKHOUSE_QUICKSTART.md 部署
3. 遇到问题查看 CLICKHOUSE_FILES_SUMMARY.md
```

### `db/README.md`
```markdown
# 🗄️ ClickHouse 数据库 Schema

## 包含的表和视图

### 表 (Tables)
- `events` - 原生事件
- `deployments` - 部署记录
- `changes` - 变更记录 (Lead Time)
- `incidents` - 事件/告警 (MTTR)
- `services` - 维度数据

### 物化视图 (Materialized Views)
- 每日部署统计
- Lead Time 统计
- 变更失败率统计
- MTTR 统计

### 查询视图 (Views)
- deployment_frequency_view
- lead_time_view
- change_failure_view
- mttr_view
- four_keys_overview

## 使用方式

```bash
# Docker Compose 会自动执行
docker-compose -f docker-compose.clickhouse.yml up -d

# 或手动执行
docker exec -i bq-workers_clickhouse_1 clickhouse-client < db/clickhouse_schema.sql
```

## 常用查询

参考 docs/CLICKHOUSE_QUICKSTART.md 中的"SQL 查询示例"部分
```

### `lib/README.md`
```markdown
# 📚 ClickHouse 客户端库

## 类: ClickHouseMetricsClient

### 初始化

```python
from lib.clickhouse_client import ClickHouseMetricsClient

client = ClickHouseMetricsClient(
    host='localhost',
    port=9000,
    database='fourkeys',
    user='default',
    password=''
)
```

### 核心方法

#### 数据插入
- `insert_event()` - 插入事件
- `insert_deployment()` - 插入部署
- `insert_change()` - 插入变更
- `insert_incident()` - 插入事件
- `batch_insert_events()` - 批量插入

#### 数据查询
- `get_deployment_frequency()` - 部署频率
- `get_lead_time()` - Lead Time
- `get_change_failure_rate()` - 失败率
- `get_mttr()` - 恢复时间
- `get_four_keys_overview()` - 四个指标

### 示例

参考 examples/github_parser_clickhouse.py
```

### `examples/README.md`
```markdown
# 💡 集成示例

## Parser 集成

### 1. GitHub Parser
```python
# 使用示例代码替换现有的 main.py
cp examples/github_parser_clickhouse.py github-parser/main.py
```

### 2. 其他 Parser
可以使用相同的逻辑替换其他 Parser：
- argocd-parser
- cloud-build-parser
- circleci-parser
- gitlab-parser
- pagerduty-parser
- tekton-parser

### 3. Python 脚本
```python
from lib.clickhouse_client import ClickHouseMetricsClient

client = ClickHouseMetricsClient()
# 使用 client...
```

详细示例参考 `github_parser_clickhouse.py`
```

---

## 🎯 集成步骤

### 步骤 1: 组织文件
```bash
# 运行提供的脚本
bash organize-clickhouse.sh

# 或手动创建目录
mkdir -p docs db lib examples
```

### 步骤 2: 验证结构
```bash
tree -L 2 -I 'node_modules'
```

### 步骤 3: 启动系统
```bash
# 从根目录运行
docker-compose -f docker-compose.clickhouse.yml up -d
```

### 步骤 4: 验证
```bash
# 检查文档可访问
ls -la docs/

# 检查数据库文件
ls -la db/

# 检查客户端库
ls -la lib/

# 检查示例
ls -la examples/
```

---

## 📌 现有 Parser 如何集成

### 选项 A: 最小改动（推荐）

保持现有结构，在各 Parser 中导入共享库：

```python
# argocd-parser/main.py
import sys
sys.path.insert(0, '../../lib')

from clickhouse_client import ClickHouseMetricsClient

client = ClickHouseMetricsClient()
```

### 选项 B: 完全替换

```bash
# 1. 备份原文件
cp argocd-parser/main.py argocd-parser/main.py.bak

# 2. 复制示例
cp examples/github_parser_clickhouse.py argocd-parser/main.py

# 3. 更新依赖
echo "clickhouse-driver==0.4.7" >> argocd-parser/requirements.txt
```

### 选项 C: 使用 Docker 多阶段构建

```dockerfile
# 在各 Parser 的 Dockerfile 中
FROM python:3.10

# 共享代码
COPY lib/clickhouse_client.py /app/lib/
COPY examples/github_parser_clickhouse.py /app/main.py

# 应用依赖
COPY requirements.txt .
RUN pip install -r requirements.txt
```

---

## 🗂️ 文件映射表

| 原文件 | 新位置 | 说明 |
|--------|--------|------|
| `clickhouse_schema.sql` | `db/` | 数据库 Schema |
| `clickhouse_client.py` | `lib/` | 共享客户端库 |
| `github_parser_clickhouse.py` | `examples/` | Parser 示例 |
| `README_CLICKHOUSE.md` | `docs/` | 项目说明 |
| `CLICKHOUSE_QUICKSTART.md` | `docs/` | 部署指南 |
| `CLICKHOUSE_FILES_SUMMARY.md` | `docs/` | 文件清单 |
| `docker-compose.clickhouse.yml` | 根目录 | Docker 编排 |
| `requirements-clickhouse.txt` | 根目录 | 依赖清单 |

---

## ✅ 检查清单

组织完成后，运行以下检查：

```bash
# 1. 验证文件位置
[ -f docs/README_CLICKHOUSE.md ] && echo "✅ docs/README_CLICKHOUSE.md" || echo "❌ 缺失"
[ -f db/clickhouse_schema.sql ] && echo "✅ db/clickhouse_schema.sql" || echo "❌ 缺失"
[ -f lib/clickhouse_client.py ] && echo "✅ lib/clickhouse_client.py" || echo "❌ 缺失"
[ -f examples/github_parser_clickhouse.py ] && echo "✅ examples/github_parser_clickhouse.py" || echo "❌ 缺失"

# 2. 验证根目录文件
[ -f docker-compose.clickhouse.yml ] && echo "✅ docker-compose.clickhouse.yml" || echo "❌ 缺失"
[ -f requirements-clickhouse.txt ] && echo "✅ requirements-clickhouse.txt" || echo "❌ 缺失"

# 3. 验证原有文件完整
[ -d argocd-parser ] && echo "✅ argocd-parser" || echo "❌ 缺失"
[ -d github-parser ] && echo "✅ github-parser" || echo "❌ 缺失"
```

---

## 📖 访问指南

部署后访问各资源：

| 资源 | 位置 |
|------|------|
| **项目说明** | `docs/README_CLICKHOUSE.md` |
| **部署指南** | `docs/CLICKHOUSE_QUICKSTART.md` |
| **文件清单** | `docs/CLICKHOUSE_FILES_SUMMARY.md` |
| **Schema 定义** | `db/clickhouse_schema.sql` |
| **客户端库** | `lib/clickhouse_client.py` |
| **Parser 示例** | `examples/github_parser_clickhouse.py` |
| **Docker 配置** | `./docker-compose.clickhouse.yml` |
| **依赖清单** | `./requirements-clickhouse.txt` |

---

**组织完成后，整个项目会更清晰易维护！** 🎯
