#!/bin/bash

# ╔════════════════════════════════════════════════════════════════════════════╗
# ║                   ClickHouse 文件迁移脚本 - 推荐方案                        ║
# ║  将所有 ClickHouse 文件按照项目级别组织，而不是放在 bq-workers 目录中      ║
# ╚════════════════════════════════════════════════════════════════════════════╝

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 日志函数
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[!]${NC} $1"; }
log_error() { echo -e "${RED}[✗]${NC} $1"; }

# 标题
echo -e "${BLUE}╔════════════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║             ClickHouse 文件迁移 - 按推荐方案重新组织文件                   ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# 获取脚本所在目录（fourkeys 根目录）
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
log_info "工作目录: $SCRIPT_DIR"
echo ""

# 验证是否在正确的目录
if [ ! -f "$SCRIPT_DIR/README.md" ] || [ ! -d "$SCRIPT_DIR/bq-workers" ]; then
    log_error "错误：未找到 Four Keys 项目根目录"
    log_error "请确保在 /Users/hliu/Program/wenzizone/fourkeys 中运行此脚本"
    exit 1
fi

log_success "找到 Four Keys 项目"
echo ""

# ══════════════════════════════════════════════════════════════════════════
# 步骤 1: 创建目录结构
# ══════════════════════════════════════════════════════════════════════════

log_info "步骤 1: 创建目录结构"
echo ""

mkdir -p "$SCRIPT_DIR/database/clickhouse/migration"
log_success "创建 database/clickhouse/migration"

mkdir -p "$SCRIPT_DIR/setup/docker"
log_success "创建 setup/docker"

mkdir -p "$SCRIPT_DIR/queries/clickhouse"
log_success "创建 queries/clickhouse"

mkdir -p "$SCRIPT_DIR/docs"
log_success "创建 docs"

mkdir -p "$SCRIPT_DIR/terraform/modules/clickhouse"
log_success "创建 terraform/modules/clickhouse"

echo ""

# ══════════════════════════════════════════════════════════════════════════
# 步骤 2: 移动共享库
# ══════════════════════════════════════════════════════════════════════════

log_info "步骤 2: 移动共享库到 shared/"
echo ""

if [ -f "$SCRIPT_DIR/bq-workers/clickhouse_client.py" ]; then
    mv "$SCRIPT_DIR/bq-workers/clickhouse_client.py" "$SCRIPT_DIR/shared/"
    log_success "移动 clickhouse_client.py → shared/"
else
    log_warning "clickhouse_client.py 不存在"
fi

echo ""

# ══════════════════════════════════════════════════════════════════════════
# 步骤 3: 移动数据库文件
# ══════════════════════════════════════════════════════════════════════════

log_info "步骤 3: 移动数据库文件到 database/clickhouse/"
echo ""

if [ -f "$SCRIPT_DIR/bq-workers/clickhouse_schema.sql" ]; then
    mv "$SCRIPT_DIR/bq-workers/clickhouse_schema.sql" "$SCRIPT_DIR/database/clickhouse/schema.sql"
    log_success "移动 clickhouse_schema.sql → database/clickhouse/schema.sql"
else
    log_warning "clickhouse_schema.sql 不存在"
fi

echo ""

# ══════════════════════════════════════════════════════════════════════════
# 步骤 4: 移动部署脚本
# ══════════════════════════════════════════════════════════════════════════

log_info "步骤 4: 移动部署脚本到 setup/docker/"
echo ""

if [ -f "$SCRIPT_DIR/bq-workers/docker-compose.clickhouse.yml" ]; then
    mv "$SCRIPT_DIR/bq-workers/docker-compose.clickhouse.yml" "$SCRIPT_DIR/setup/docker/"
    log_success "移动 docker-compose.clickhouse.yml → setup/docker/"
else
    log_warning "docker-compose.clickhouse.yml 不存在"
fi

if [ -f "$SCRIPT_DIR/bq-workers/organize-clickhouse.sh" ]; then
    mv "$SCRIPT_DIR/bq-workers/organize-clickhouse.sh" "$SCRIPT_DIR/setup/"
    chmod +x "$SCRIPT_DIR/setup/organize-clickhouse.sh"
    log_success "移动 organize-clickhouse.sh → setup/ (已授予执行权限)"
else
    log_warning "organize-clickhouse.sh 不存在"
fi

if [ -f "$SCRIPT_DIR/bq-workers/requirements-clickhouse.txt" ]; then
    mv "$SCRIPT_DIR/bq-workers/requirements-clickhouse.txt" "$SCRIPT_DIR/setup/"
    log_success "移动 requirements-clickhouse.txt → setup/"
else
    log_warning "requirements-clickhouse.txt 不存在"
fi

echo ""

# ══════════════════════════════════════════════════════════════════════════
# 步骤 5: 移动文档
# ══════════════════════════════════════════════════════════════════════════

log_info "步骤 5: 移动文档到 docs/"
echo ""

if [ -f "$SCRIPT_DIR/bq-workers/README_CLICKHOUSE.md" ]; then
    mv "$SCRIPT_DIR/bq-workers/README_CLICKHOUSE.md" "$SCRIPT_DIR/docs/"
    log_success "移动 README_CLICKHOUSE.md → docs/"
else
    log_warning "README_CLICKHOUSE.md 不存在"
fi

if [ -f "$SCRIPT_DIR/bq-workers/CLICKHOUSE_QUICKSTART.md" ]; then
    mv "$SCRIPT_DIR/bq-workers/CLICKHOUSE_QUICKSTART.md" "$SCRIPT_DIR/docs/"
    log_success "移动 CLICKHOUSE_QUICKSTART.md → docs/"
else
    log_warning "CLICKHOUSE_QUICKSTART.md 不存在"
fi

if [ -f "$SCRIPT_DIR/bq-workers/CLICKHOUSE_FILES_SUMMARY.md" ]; then
    mv "$SCRIPT_DIR/bq-workers/CLICKHOUSE_FILES_SUMMARY.md" "$SCRIPT_DIR/docs/"
    log_success "移动 CLICKHOUSE_FILES_SUMMARY.md → docs/"
else
    log_warning "CLICKHOUSE_FILES_SUMMARY.md 不存在"
fi

if [ -f "$SCRIPT_DIR/bq-workers/DIRECTORY_STRUCTURE.md" ]; then
    mv "$SCRIPT_DIR/bq-workers/DIRECTORY_STRUCTURE.md" "$SCRIPT_DIR/docs/CLICKHOUSE_DIRECTORY_STRUCTURE.md"
    log_success "移动 DIRECTORY_STRUCTURE.md → docs/CLICKHOUSE_DIRECTORY_STRUCTURE.md"
else
    log_warning "DIRECTORY_STRUCTURE.md 不存在"
fi

echo ""

# ══════════════════════════════════════════════════════════════════════════
# 步骤 6: 更新 Parser 导入语句
# ══════════════════════════════════════════════════════════════════════════

log_info "步骤 6: 更新 Parser 导入语句"
echo ""

UPDATED_COUNT=0

for parser_dir in "$SCRIPT_DIR/bq-workers"/*/; do
    if [ -d "$parser_dir" ] && [ -f "$parser_dir/main.py" ]; then
        parser_name=$(basename "$parser_dir")
        
        # 检查是否需要更新
        if grep -q "from clickhouse_client import\|import clickhouse_client" "$parser_dir/main.py"; then
            # 更新导入语句
            sed -i.bak 's/from clickhouse_client import/from shared.clickhouse_client import/g' "$parser_dir/main.py"
            sed -i.bak 's/import clickhouse_client/from shared import clickhouse_client/g' "$parser_dir/main.py"
            
            # 删除备份文件
            rm -f "$parser_dir/main.py.bak"
            
            log_success "更新 $parser_name/main.py 的导入语句"
            ((UPDATED_COUNT++))
        fi
    fi
done

if [ $UPDATED_COUNT -eq 0 ]; then
    log_warning "没有需要更新导入语句的 Parser"
else
    log_success "共更新 $UPDATED_COUNT 个 Parser 的导入语句"
fi

echo ""

# ══════════════════════════════════════════════════════════════════════════
# 步骤 7: 创建目录 README 文件
# ══════════════════════════════════════════════════════════════════════════

log_info "步骤 7: 创建目录 README 文件"
echo ""

# database/clickhouse/README.md
cat > "$SCRIPT_DIR/database/clickhouse/README.md" << 'EOF'
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
EOF
log_success "创建 database/clickhouse/README.md"

# setup/docker/README.md
cat > "$SCRIPT_DIR/setup/docker/README.md" << 'EOF'
# 🐳 ClickHouse Docker Compose 配置

## 包含的文件

### Docker Compose
- `docker-compose.clickhouse.yml` - 完整的 ClickHouse 栈编排
  - ClickHouse 服务器
  - Grafana 仪表板
  - 所有 Parser 服务
  - 自动网络和卷配置

## 快速启动

```bash
# 进入项目根目录
cd ../..

# 启动所有服务
docker-compose -f setup/docker/docker-compose.clickhouse.yml up -d

# 查看日志
docker-compose -f setup/docker/docker-compose.clickhouse.yml logs -f

# 停止所有服务
docker-compose -f setup/docker/docker-compose.clickhouse.yml down
```

## 访问地址

- Grafana 仪表板: http://localhost:3000 (admin/admin123)
- ClickHouse HTTP: http://localhost:8123
- ClickHouse Native: localhost:9000
- GitHub Parser: http://localhost:8080
- ArgoCD Parser: http://localhost:8081

## 相关文档

- 完整部署指南：`../../docs/CLICKHOUSE_QUICKSTART.md`
- 配置详情：`../../docs/README_CLICKHOUSE.md`
EOF
log_success "创建 setup/docker/README.md"

# shared/README.md (如果不存在)
if [ ! -f "$SCRIPT_DIR/shared/README.md" ]; then
    cat > "$SCRIPT_DIR/shared/README.md" << 'EOF'
# 📚 共享库

## 包含的模块

### BigQuery 支持 (原有)
- `shared.py` - BigQuery 数据插入和操作

### ClickHouse 支持 (新增)
- `clickhouse_client.py` - ClickHouse 数据操作客户端库

## 使用方式

### Python 导入
```python
from shared.clickhouse_client import ClickHouseMetricsClient

client = ClickHouseMetricsClient(
    host='localhost',
    port=9000,
    database='fourkeys'
)

# 插入事件
client.insert_event({...})

# 查询数据
deployments = client.get_deployment_frequency(days=30)
```

### Parser 使用
```python
# 在 bq-workers/*/main.py 中
from shared.clickhouse_client import ClickHouseMetricsClient
```

## API 文档

详见 `../../shared/clickhouse_client.py` 的源代码注释。

## 相关文档

- 客户端库详情：`../../docs/README_CLICKHOUSE.md`
- 集成示例：`../../docs/CLICKHOUSE_QUICKSTART.md`
EOF
    log_success "创建 shared/README.md"
fi

# docs/README.md (如果不存在)
if [ ! -f "$SCRIPT_DIR/docs/README.md" ]; then
    cat > "$SCRIPT_DIR/docs/README.md" << 'EOF'
# 📚 ClickHouse 文档

## 快速导航

### 🚀 开始使用
1. **[README_CLICKHOUSE.md](./README_CLICKHOUSE.md)** - 项目总览和快速概览
2. **[CLICKHOUSE_QUICKSTART.md](./CLICKHOUSE_QUICKSTART.md)** - 👈 **从这里开始部署**

### 📖 详细文档
- **[CLICKHOUSE_FILES_SUMMARY.md](./CLICKHOUSE_FILES_SUMMARY.md)** - 文件清单和集成指南
- **[CLICKHOUSE_DIRECTORY_STRUCTURE.md](./CLICKHOUSE_DIRECTORY_STRUCTURE.md)** - 目录结构说明

### 💡 迁移指南
- **[CLICKHOUSE_PLACEMENT_ANALYSIS.md](../CLICKHOUSE_PLACEMENT_ANALYSIS.md)** - 文件放置分析

## 重要提示

1. 首先阅读 README_CLICKHOUSE.md 了解项目概况
2. 然后按照 CLICKHOUSE_QUICKSTART.md 进行部署
3. 遇到问题查看相应的详细文档

## 相关资源

- 数据库配置：`../database/clickhouse/`
- 部署脚本：`../setup/docker/`
- Python 客户端：`../shared/clickhouse_client.py`
- SQL 查询：`../queries/clickhouse/`
EOF
    log_success "创建 docs/README.md"
fi

echo ""

# ══════════════════════════════════════════════════════════════════════════
# 步骤 8: 验证迁移
# ══════════════════════════════════════════════════════════════════════════

log_info "步骤 8: 验证迁移"
echo ""

verify_file() {
    if [ -f "$1" ]; then
        echo -e "${GREEN}  ✅${NC} $2"
        return 0
    else
        echo -e "${RED}  ❌${NC} $2"
        return 1
    fi
}

verify_file "$SCRIPT_DIR/shared/clickhouse_client.py" "shared/clickhouse_client.py"
verify_file "$SCRIPT_DIR/database/clickhouse/schema.sql" "database/clickhouse/schema.sql"
verify_file "$SCRIPT_DIR/setup/docker/docker-compose.clickhouse.yml" "setup/docker/docker-compose.clickhouse.yml"
verify_file "$SCRIPT_DIR/docs/README_CLICKHOUSE.md" "docs/README_CLICKHOUSE.md"
verify_file "$SCRIPT_DIR/docs/CLICKHOUSE_QUICKSTART.md" "docs/CLICKHOUSE_QUICKSTART.md"
verify_file "$SCRIPT_DIR/database/clickhouse/README.md" "database/clickhouse/README.md (新建)"

echo ""

# ══════════════════════════════════════════════════════════════════════════
# 步骤 9: 显示最终结构
# ══════════════════════════════════════════════════════════════════════════

log_info "步骤 9: 新的项目结构"
echo ""

cat << 'EOF'
fourkeys/
├── bq-workers/                   ✓ Parser 服务（保持不变）
│   ├── github-parser/
│   ├── argocd-parser/
│   └── ...
│
├── shared/                        ✓ 共享库
│   ├── shared.py
│   ├── clickhouse_client.py       ← 已移入
│   └── README.md
│
├── database/                      ✓ 数据库配置（新建）
│   └── clickhouse/
│       ├── schema.sql             ← 已移入
│       ├── config.yaml
│       ├── migration/
│       └── README.md
│
├── setup/                         ✓ 部署脚本
│   ├── docker/
│   │   ├── docker-compose.clickhouse.yml ← 已移入
│   │   └── README.md
│   ├── organize-clickhouse.sh     ← 已移入
│   ├── requirements-clickhouse.txt ← 已移入
│   └── ...
│
├── queries/                       ✓ SQL 查询
│   ├── changes.sql                # BigQuery
│   ├── clickhouse/                # 新增目录
│   │   └── README.md
│   └── ...
│
├── docs/                          ✓ 文档（新建）
│   ├── README_CLICKHOUSE.md       ← 已移入
│   ├── CLICKHOUSE_QUICKSTART.md   ← 已移入
│   ├── CLICKHOUSE_FILES_SUMMARY.md ← 已移入
│   ├── CLICKHOUSE_DIRECTORY_STRUCTURE.md ← 已移入
│   ├── README.md
│   └── ...
│
├── terraform/                     ✓ IaC 配置
│   └── modules/
│       └── clickhouse/            # 新增模块
│           └── README.md
│
└── CLICKHOUSE_PLACEMENT_ANALYSIS.md ✓ 迁移分析文档
EOF

echo ""

# ══════════════════════════════════════════════════════════════════════════
# 完成
# ══════════════════════════════════════════════════════════════════════════

log_success "迁移完成！"
echo ""
echo -e "${BLUE}╔════════════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                        ✓ 所有文件已成功迁移                              ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════════════════╝${NC}"
echo ""

log_info "后续步骤:"
echo "  1️⃣ 进入项目根目录"
echo "     cd /Users/hliu/Program/wenzizone/fourkeys"
echo ""
echo "  2️⃣ 查看新的文档结构"
echo "     cat docs/README.md"
echo ""
echo "  3️⃣ 启动 ClickHouse 栈"
echo "     docker-compose -f setup/docker/docker-compose.clickhouse.yml up -d"
echo ""
echo "  4️⃣ 访问 Grafana 仪表板"
echo "     http://localhost:3000"
echo ""

log_success "迁移脚本执行完成！"
