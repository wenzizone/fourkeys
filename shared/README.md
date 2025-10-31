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
