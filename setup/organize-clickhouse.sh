#!/bin/bash

# ClickHouse 项目文件组织脚本
# 自动将新建的文件整理到合适的目录结构中

set -e

# 颜色定义
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# 脚本信息
echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   ClickHouse 项目结构组织工具                          ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo -e "${BLUE}工作目录: ${SCRIPT_DIR}${NC}"
echo ""

# 检查是否在正确的目录
if [ ! -f "parsers.cloudbuild.yaml" ]; then
    echo -e "${RED}❌ 错误: 未找到 parsers.cloudbuild.yaml${NC}"
    echo "请确保在 bq-workers 目录中运行此脚本"
    exit 1
fi

# 步骤 1: 创建新目录
echo -e "${YELLOW}📁 步骤 1: 创建目录结构${NC}"

mkdir -p docs
echo -e "${GREEN}  ✅ 创建 docs/${NC}"

mkdir -p db
echo -e "${GREEN}  ✅ 创建 db/${NC}"

mkdir -p lib
echo -e "${GREEN}  ✅ 创建 lib/${NC}"

mkdir -p examples
echo -e "${GREEN}  ✅ 创建 examples/${NC}"

echo ""

# 步骤 2: 移动文档文件
echo -e "${YELLOW}📚 步骤 2: 组织文档${NC}"

if [ -f "README_CLICKHOUSE.md" ]; then
    mv README_CLICKHOUSE.md docs/
    echo -e "${GREEN}  ✅ 移动 README_CLICKHOUSE.md → docs/${NC}"
else
    echo -e "${YELLOW}  ⊘ README_CLICKHOUSE.md 不存在${NC}"
fi

if [ -f "CLICKHOUSE_QUICKSTART.md" ]; then
    mv CLICKHOUSE_QUICKSTART.md docs/
    echo -e "${GREEN}  ✅ 移动 CLICKHOUSE_QUICKSTART.md → docs/${NC}"
else
    echo -e "${YELLOW}  ⊘ CLICKHOUSE_QUICKSTART.md 不存在${NC}"
fi

if [ -f "CLICKHOUSE_FILES_SUMMARY.md" ]; then
    mv CLICKHOUSE_FILES_SUMMARY.md docs/
    echo -e "${GREEN}  ✅ 移动 CLICKHOUSE_FILES_SUMMARY.md → docs/${NC}"
else
    echo -e "${YELLOW}  ⊘ CLICKHOUSE_FILES_SUMMARY.md 不存在${NC}"
fi

if [ -f "DIRECTORY_STRUCTURE.md" ]; then
    mv DIRECTORY_STRUCTURE.md docs/
    echo -e "${GREEN}  ✅ 移动 DIRECTORY_STRUCTURE.md → docs/${NC}"
else
    echo -e "${YELLOW}  ⊘ DIRECTORY_STRUCTURE.md 不存在${NC}"
fi

echo ""

# 步骤 3: 移动数据库文件
echo -e "${YELLOW}🗄️  步骤 3: 组织数据库文件${NC}"

if [ -f "clickhouse_schema.sql" ]; then
    mv clickhouse_schema.sql db/
    echo -e "${GREEN}  ✅ 移动 clickhouse_schema.sql → db/${NC}"
else
    echo -e "${YELLOW}  ⊘ clickhouse_schema.sql 不存在${NC}"
fi

echo ""

# 步骤 4: 移动库文件
echo -e "${YELLOW}📚 步骤 4: 组织共享库${NC}"

if [ -f "clickhouse_client.py" ]; then
    mv clickhouse_client.py lib/
    echo -e "${GREEN}  ✅ 移动 clickhouse_client.py → lib/${NC}"
else
    echo -e "${YELLOW}  ⊘ clickhouse_client.py 不存在${NC}"
fi

echo ""

# 步骤 5: 移动示例代码
echo -e "${YELLOW}💡 步骤 5: 组织示例代码${NC}"

if [ -f "github_parser_clickhouse.py" ]; then
    mv github_parser_clickhouse.py examples/
    echo -e "${GREEN}  ✅ 移动 github_parser_clickhouse.py → examples/${NC}"
else
    echo -e "${YELLOW}  ⊘ github_parser_clickhouse.py 不存在${NC}"
fi

echo ""

# 步骤 6: 验证根目录文件
echo -e "${YELLOW}📋 步骤 6: 验证根目录文件${NC}"

if [ -f "docker-compose.clickhouse.yml" ]; then
    echo -e "${GREEN}  ✅ docker-compose.clickhouse.yml (保持在根目录)${NC}"
else
    echo -e "${YELLOW}  ⊘ docker-compose.clickhouse.yml 不存在${NC}"
fi

if [ -f "requirements-clickhouse.txt" ]; then
    echo -e "${GREEN}  ✅ requirements-clickhouse.txt (保持在根目录)${NC}"
else
    echo -e "${YELLOW}  ⊘ requirements-clickhouse.txt 不存在${NC}"
fi

echo ""

# 步骤 7: 创建 README 文件
echo -e "${YELLOW}📝 步骤 7: 创建目录 README 文件${NC}"

# docs/README.md
cat > docs/README.md << 'EOF'
# 📚 ClickHouse DORA 指标系统 - 文档

## 快速导航

- **[README_CLICKHOUSE.md](./README_CLICKHOUSE.md)** - 项目总览
- **[CLICKHOUSE_QUICKSTART.md](./CLICKHOUSE_QUICKSTART.md)** - 👈 **从这里开始部署**
- **[CLICKHOUSE_FILES_SUMMARY.md](./CLICKHOUSE_FILES_SUMMARY.md)** - 文件清单
- **[DIRECTORY_STRUCTURE.md](./DIRECTORY_STRUCTURE.md)** - 目录结构说明

## 重要提示

1. 首先阅读 README_CLICKHOUSE.md 了解项目
2. 然后按照 CLICKHOUSE_QUICKSTART.md 部署
3. 遇到问题查看 CLICKHOUSE_FILES_SUMMARY.md
EOF
echo -e "${GREEN}  ✅ 创建 docs/README.md${NC}"

# db/README.md
cat > db/README.md << 'EOF'
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

参考 ../docs/CLICKHOUSE_QUICKSTART.md 中的"SQL 查询示例"部分
EOF
echo -e "${GREEN}  ✅ 创建 db/README.md${NC}"

# lib/README.md
cat > lib/README.md << 'EOF'
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

参考 ../examples/github_parser_clickhouse.py
EOF
echo -e "${GREEN}  ✅ 创建 lib/README.md${NC}"

# examples/README.md
cat > examples/README.md << 'EOF'
# 💡 集成示例

## Parser 集成

### 1. GitHub Parser
```bash
# 使用示例代码替换现有的 main.py
cp github_parser_clickhouse.py ../github-parser/main.py
```

### 2. 其他 Parser
可以使用相同的逻辑替换其他 Parser：
- argocd-parser
- cloud-build-parser
- circleci-parser
- gitlab-parser
- pagerduty-parser
- tekton-parser

### 3. Python 脚本集成
```python
import sys
sys.path.insert(0, '../lib')

from clickhouse_client import ClickHouseMetricsClient

client = ClickHouseMetricsClient()
# 使用 client...
```

详细示例参考 `github_parser_clickhouse.py`
EOF
echo -e "${GREEN}  ✅ 创建 examples/README.md${NC}"

echo ""

# 步骤 8: 显示最终结构
echo -e "${YELLOW}📂 步骤 8: 最终结构${NC}"
echo ""

echo -e "${BLUE}bq-workers/${NC}"
echo -e "${GREEN}├── 📄 README.md${NC}"
echo -e "${GREEN}├── 📄 docker-compose.clickhouse.yml${NC}"
echo -e "${GREEN}├── 📄 requirements-clickhouse.txt${NC}"
echo -e "${GREEN}│${NC}"
echo -e "${BLUE}├── 📚 docs/${NC}"
echo -e "${GREEN}│   ├── README.md${NC}"
echo -e "${GREEN}│   ├── README_CLICKHOUSE.md${NC}"
echo -e "${GREEN}│   ├── CLICKHOUSE_QUICKSTART.md${NC}"
echo -e "${GREEN}│   ├── CLICKHOUSE_FILES_SUMMARY.md${NC}"
echo -e "${GREEN}│   └── DIRECTORY_STRUCTURE.md${NC}"
echo -e "${GREEN}│${NC}"
echo -e "${BLUE}├── 🗄️  db/${NC}"
echo -e "${GREEN}│   ├── README.md${NC}"
echo -e "${GREEN}│   └── clickhouse_schema.sql${NC}"
echo -e "${GREEN}│${NC}"
echo -e "${BLUE}├── 📦 lib/${NC}"
echo -e "${GREEN}│   ├── README.md${NC}"
echo -e "${GREEN}│   └── clickhouse_client.py${NC}"
echo -e "${GREEN}│${NC}"
echo -e "${BLUE}├── 💡 examples/${NC}"
echo -e "${GREEN}│   ├── README.md${NC}"
echo -e "${GREEN}│   └── github_parser_clickhouse.py${NC}"
echo -e "${GREEN}│${NC}"
echo -e "${BLUE}├── argocd-parser/${NC}"
echo -e "${BLUE}├── github-parser/${NC}"
echo -e "${BLUE}├── cloud-build-parser/${NC}"
echo -e "${BLUE}├── circleci-parser/${NC}"
echo -e "${BLUE}├── gitlab-parser/${NC}"
echo -e "${BLUE}├── pagerduty-parser/${NC}"
echo -e "${BLUE}├── tekton-parser/${NC}"
echo -e "${BLUE}└── new-source-template/${NC}"

echo ""

# 步骤 9: 验证所有文件
echo -e "${YELLOW}✅ 步骤 9: 验证检查${NC}"
echo ""

check_file() {
    if [ -f "$1" ]; then
        echo -e "${GREEN}  ✅ $1${NC}"
        return 0
    else
        echo -e "${RED}  ❌ $1${NC}"
        return 1
    fi
}

check_file "docs/README.md"
check_file "docs/README_CLICKHOUSE.md"
check_file "docs/CLICKHOUSE_QUICKSTART.md"
check_file "db/README.md"
check_file "db/clickhouse_schema.sql"
check_file "lib/README.md"
check_file "lib/clickhouse_client.py"
check_file "examples/README.md"
check_file "examples/github_parser_clickhouse.py"
check_file "docker-compose.clickhouse.yml"
check_file "requirements-clickhouse.txt"

echo ""

# 完成
echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                  ✅ 组织完成！                        ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${YELLOW}📖 下一步:${NC}"
echo -e "  1. 查看文档: ${BLUE}cat docs/README.md${NC}"
echo -e "  2. 启动系统: ${BLUE}docker-compose -f docker-compose.clickhouse.yml up -d${NC}"
echo -e "  3. 查看日志: ${BLUE}docker-compose -f docker-compose.clickhouse.yml logs -f${NC}"
echo ""

echo -e "${GREEN}准备好了吗？开始部署吧！🚀${NC}"
