"""
ClickHouse Client for DORA Four Keys Metrics
支持事件插入、批量操作和复杂查询
"""

import json
import logging
from typing import Dict, List, Optional, Any
from datetime import datetime, timedelta
from uuid import uuid4

import clickhouse_driver
from clickhouse_driver import Client
from clickhouse_driver.util import escape

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class ClickHouseMetricsClient:
    """ClickHouse 客户端，用于 DORA 指标数据管理"""

    def __init__(
        self,
        host: str = 'localhost',
        port: int = 9000,
        database: str = 'fourkeys',
        user: str = 'default',
        password: str = '',
        cluster: Optional[str] = None,
    ):
        """
        初始化 ClickHouse 客户端

        Args:
            host: ClickHouse 服务器地址
            port: ClickHouse 服务端口
            database: 数据库名称
            user: 用户名
            password: 密码
            cluster: 集群名称（分布式部署时使用）
        """
        self.client = Client(
            host=host,
            port=port,
            database=database,
            user=user,
            password=password,
            settings={'use_numpy': True}
        )
        self.cluster = cluster
        self.db = database

    def insert_event(self, event: Dict[str, Any]) -> None:
        """
        插入单个事件

        Args:
            event: 事件字典，包含 event_type, source, timestamp 等
        """
        try:
            query = """
            INSERT INTO events (
                event_id, time_created, event_type, source, msg_id,
                signature, metadata, repository, author, commit_sha,
                branch, pr_number, status, tags, duration_ms, created_at
            ) VALUES
            """
            # 准备数据
            values = (
                str(uuid4()),  # event_id
                datetime.fromisoformat(event.get('time_created', datetime.now().isoformat())),
                event.get('event_type', 'push'),
                event.get('source', 'github'),
                event.get('msg_id', str(uuid4())),
                event.get('signature', ''),
                json.dumps(event.get('metadata', {})),
                event.get('repository', ''),
                event.get('author', ''),
                event.get('commit_sha', ''),
                event.get('branch', 'main'),
                int(event.get('pr_number', 0)),
                event.get('status', 'success'),
                event.get('tags', []),
                int(event.get('duration_ms', 0)),
                datetime.now(),
            )

            self.client.execute(
                f"{query} ({','.join(['%s'] * len(values))})",
                [values]
            )
            logger.info(f"插入事件成功: {event.get('event_id')}")
        except Exception as e:
            logger.error(f"插入事件失败: {e}")
            raise

    def insert_deployment(self, deployment: Dict[str, Any]) -> None:
        """插入部署记录"""
        try:
            query = """
            INSERT INTO deployments (
                deploy_id, time_created, service_name, environment,
                version, commit_sha, author, status, duration_ms,
                repository, pr_numbers, metadata, created_at
            ) VALUES
            """
            values = (
                str(uuid4()),
                datetime.fromisoformat(deployment.get('time_created', datetime.now().isoformat())),
                deployment.get('service_name', ''),
                deployment.get('environment', 'prod'),
                deployment.get('version', ''),
                deployment.get('commit_sha', ''),
                deployment.get('author', ''),
                deployment.get('status', 'success'),
                int(deployment.get('duration_ms', 0)),
                deployment.get('repository', ''),
                deployment.get('pr_numbers', []),
                json.dumps(deployment.get('metadata', {})),
                datetime.now(),
            )

            self.client.execute(
                f"{query} ({','.join(['%s'] * len(values))})",
                [values]
            )
            logger.info(f"插入部署记录成功")
        except Exception as e:
            logger.error(f"插入部署记录失败: {e}")
            raise

    def insert_change(self, change: Dict[str, Any]) -> None:
        """插入变更记录（用于计算 Lead Time）"""
        try:
            query = """
            INSERT INTO changes (
                change_id, commit_sha, author, repository,
                commit_time, deployed_time, lead_time_minutes,
                pr_number, pr_created_time, pr_merged_time,
                status, metadata, created_at
            ) VALUES
            """
            
            commit_time = datetime.fromisoformat(change.get('commit_time', datetime.now().isoformat()))
            deployed_time = datetime.fromisoformat(change.get('deployed_time', datetime.now().isoformat()))
            lead_time = int((deployed_time - commit_time).total_seconds() / 60)
            
            values = (
                str(uuid4()),
                change.get('commit_sha', ''),
                change.get('author', ''),
                change.get('repository', ''),
                commit_time,
                deployed_time,
                lead_time,
                int(change.get('pr_number', 0)),
                datetime.fromisoformat(change.get('pr_created_time', datetime.now().isoformat())),
                datetime.fromisoformat(change.get('pr_merged_time', datetime.now().isoformat())),
                change.get('status', 'deployed'),
                json.dumps(change.get('metadata', {})),
                datetime.now(),
            )

            self.client.execute(
                f"{query} ({','.join(['%s'] * len(values))})",
                [values]
            )
            logger.info(f"插入变更记录成功")
        except Exception as e:
            logger.error(f"插入变更记录失败: {e}")
            raise

    def insert_incident(self, incident: Dict[str, Any]) -> None:
        """插入事件/事件记录（用于计算 MTTR）"""
        try:
            query = """
            INSERT INTO incidents (
                incident_id, time_detected, time_resolved,
                resolution_time_minutes, severity, service,
                root_cause, related_deployment, related_pr_numbers,
                metadata, created_at
            ) VALUES
            """
            
            time_detected = datetime.fromisoformat(incident.get('time_detected', datetime.now().isoformat()))
            time_resolved = datetime.fromisoformat(incident.get('time_resolved', datetime.now().isoformat()))
            mttr = int((time_resolved - time_detected).total_seconds() / 60)
            
            values = (
                str(uuid4()),
                time_detected,
                time_resolved,
                mttr,
                incident.get('severity', 'high'),
                incident.get('service', ''),
                incident.get('root_cause', ''),
                incident.get('related_deployment', ''),
                incident.get('related_pr_numbers', []),
                json.dumps(incident.get('metadata', {})),
                datetime.now(),
            )

            self.client.execute(
                f"{query} ({','.join(['%s'] * len(values))})",
                [values]
            )
            logger.info(f"插入事件记录成功")
        except Exception as e:
            logger.error(f"插入事件记录失败: {e}")
            raise

    def batch_insert_events(self, events: List[Dict[str, Any]]) -> None:
        """批量插入事件"""
        try:
            query = """
            INSERT INTO events (
                event_id, time_created, event_type, source, msg_id,
                signature, metadata, repository, author, commit_sha,
                branch, pr_number, status, tags, duration_ms, created_at
            ) VALUES
            """
            
            values = []
            for event in events:
                values.append((
                    str(uuid4()),
                    datetime.fromisoformat(event.get('time_created', datetime.now().isoformat())),
                    event.get('event_type', 'push'),
                    event.get('source', 'github'),
                    event.get('msg_id', str(uuid4())),
                    event.get('signature', ''),
                    json.dumps(event.get('metadata', {})),
                    event.get('repository', ''),
                    event.get('author', ''),
                    event.get('commit_sha', ''),
                    event.get('branch', 'main'),
                    int(event.get('pr_number', 0)),
                    event.get('status', 'success'),
                    event.get('tags', []),
                    int(event.get('duration_ms', 0)),
                    datetime.now(),
                ))
            
            self.client.execute(
                f"{query} ({','.join(['%s'] * len(values[0]))})",
                values
            )
            logger.info(f"批量插入 {len(events)} 条事件成功")
        except Exception as e:
            logger.error(f"批量插入事件失败: {e}")
            raise

    # ====== 查询方法 ======

    def get_deployment_frequency(self, days: int = 90) -> List[Dict]:
        """获取部署频率数据"""
        query = f"""
        SELECT
            deployment_date,
            environment,
            service_name,
            deployment_count,
            successful_deployments,
            failed_deployments,
            ROUND((successful_deployments * 100.0) / deployment_count, 2) AS success_rate
        FROM daily_deployment_frequency
        WHERE deployment_date >= today() - {days}
        ORDER BY deployment_date DESC
        """
        result = self.client.execute(query)
        return [dict(zip(['date', 'environment', 'service', 'count', 'success', 'failed', 'success_rate'], row)) 
                for row in result]

    def get_lead_time(self, days: int = 90) -> Dict[str, Any]:
        """获取 Lead Time 数据"""
        query = f"""
        SELECT
            deployment_date,
            repository,
            median_lead_time / 60 AS median_hours,
            p95_lead_time / 60 AS p95_hours,
            p99_lead_time / 60 AS p99_hours,
            avg_lead_time / 60 AS avg_hours
        FROM lead_time_stats
        WHERE deployment_date >= today() - {days}
        ORDER BY deployment_date DESC
        """
        result = self.client.execute(query)
        return [dict(zip(['date', 'repo', 'median', 'p95', 'p99', 'avg'], row)) 
                for row in result]

    def get_change_failure_rate(self, days: int = 90) -> List[Dict]:
        """获取变更失败率"""
        query = f"""
        SELECT
            deployment_date,
            service_name,
            total_deployments,
            failed_deployments,
            ROUND((failed_deployments * 100.0) / total_deployments, 2) AS failure_rate
        FROM change_failure_rate
        WHERE deployment_date >= today() - {days} AND total_deployments > 0
        ORDER BY deployment_date DESC
        """
        result = self.client.execute(query)
        return [dict(zip(['date', 'service', 'total', 'failed', 'rate'], row)) 
                for row in result]

    def get_mttr(self, days: int = 90) -> List[Dict]:
        """获取平均恢复时间 (MTTR)"""
        query = f"""
        SELECT
            incident_date,
            service,
            total_incidents,
            ROUND(median_mttr / 60, 2) AS median_hours,
            ROUND(p95_mttr / 60, 2) AS p95_hours,
            ROUND(avg_mttr / 60, 2) AS avg_hours
        FROM mttr_stats
        WHERE incident_date >= today() - {days}
        ORDER BY incident_date DESC
        """
        result = self.client.execute(query)
        return [dict(zip(['date', 'service', 'total', 'median', 'p95', 'avg'], row)) 
                for row in result]

    def get_four_keys_overview(self) -> Dict[str, Any]:
        """获取四个关键指标概览"""
        query = "SELECT * FROM four_keys_overview"
        result = self.client.execute(query)
        if result:
            row = result[0]
            return {
                'report_time': row[0],
                'deployments_today': row[1],
                'median_lead_time_90d': row[2],
                'avg_failure_rate_90d': row[3],
                'median_mttr_90d': row[4],
            }
        return {}

    def health_check(self) -> bool:
        """健康检查"""
        try:
            self.client.execute("SELECT 1")
            return True
        except Exception as e:
            logger.error(f"健康检查失败: {e}")
            return False

    def close(self):
        """关闭连接"""
        try:
            self.client.disconnect()
        except Exception as e:
            logger.error(f"关闭连接失败: {e}")


# 使用示例
if __name__ == "__main__":
    # 初始化客户端
    client = ClickHouseMetricsClient(
        host='localhost',
        port=9000,
        database='fourkeys'
    )

    # 插入事件
    event = {
        'event_type': 'push',
        'source': 'github',
        'repository': 'my-repo',
        'author': 'user@example.com',
        'commit_sha': 'abc123def456',
        'branch': 'main',
        'status': 'success',
        'time_created': datetime.now().isoformat(),
        'metadata': {'url': 'https://github.com/user/repo/commit/abc123'}
    }
    client.insert_event(event)

    # 查询部署频率
    deployment_freq = client.get_deployment_frequency(days=30)
    print("部署频率:", deployment_freq)

    # 查询 Lead Time
    lead_time = client.get_lead_time(days=30)
    print("Lead Time:", lead_time)

    # 查询四个关键指标
    overview = client.get_four_keys_overview()
    print("四个关键指标:", overview)

    client.close()
