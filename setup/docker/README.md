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
