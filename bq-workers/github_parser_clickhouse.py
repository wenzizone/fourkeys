# Copyright 2020 Google LLC - Modified for ClickHouse
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import base64
import os
import json
import logging
from datetime import datetime

from flask import Flask, request
from clickhouse_driver import Client

# 导入 ClickHouse 客户端（使用上面提供的 clickhouse_client.py）
try:
    from clickhouse_client import ClickHouseMetricsClient
except ImportError:
    # 如果找不到，使用内联定义
    ClickHouseMetricsClient = None

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)

# 初始化 ClickHouse 连接
def init_clickhouse_client():
    """初始化 ClickHouse 客户端"""
    try:
        if ClickHouseMetricsClient:
            return ClickHouseMetricsClient(
                host=os.getenv('CLICKHOUSE_HOST', 'localhost'),
                port=int(os.getenv('CLICKHOUSE_PORT', 9000)),
                database=os.getenv('CLICKHOUSE_DB', 'fourkeys'),
                user=os.getenv('CLICKHOUSE_USER', 'default'),
                password=os.getenv('CLICKHOUSE_PASSWORD', '')
            )
        else:
            # 回退到原生驱动
            return Client(
                host=os.getenv('CLICKHOUSE_HOST', 'localhost'),
                port=int(os.getenv('CLICKHOUSE_PORT', 9000)),
                database=os.getenv('CLICKHOUSE_DB', 'fourkeys'),
                user=os.getenv('CLICKHOUSE_USER', 'default'),
                password=os.getenv('CLICKHOUSE_PASSWORD', '')
            )
    except Exception as e:
        logger.error(f"初始化 ClickHouse 连接失败: {e}")
        raise

# 全局客户端实例
ch_client = init_clickhouse_client()


@app.route("/", methods=["POST"])
def index():
    """
    接收来自 Webhook 的消息
    解析消息，并插入到 ClickHouse
    """
    event = None
    # 检查 JSON 请求
    if not request.is_json:
        raise Exception("期望 JSON 负载")
    envelope = request.get_json()
    logger.info(f"收到信封: {envelope}")

    # 检查消息是否为有效的 Pub/Sub 消息
    # 或者是直接的 Webhook 消息
    if "message" in envelope:
        # Pub/Sub 格式
        msg = envelope["message"]
    else:
        # 直接 Webhook 格式
        msg = envelope

    if "attributes" not in msg:
        raise Exception("缺少 pubsub 属性")

    try:
        attr = msg.get("attributes", {})

        # 提取请求头
        headers = {}
        if "headers" in attr:
            headers = json.loads(attr["headers"])

        # 处理 GitHub 事件
        if "X-Github-Event" in headers:
            event = process_github_event(headers, msg)

        # 插入到 ClickHouse
        if event:
            insert_event_to_clickhouse(event)
            logger.info(f"事件已保存到 ClickHouse")

    except Exception as e:
        entry = {
            "severity": "WARNING",
            "msg": "数据未保存到 ClickHouse",
            "errors": str(e),
            "json_payload": envelope
        }
        logger.error(json.dumps(entry))

    return "", 204


@app.route("/health", methods=["GET"])
def health():
    """健康检查端点"""
    try:
        if hasattr(ch_client, 'health_check'):
            is_healthy = ch_client.health_check()
        else:
            # 原生驱动的健康检查
            ch_client.execute("SELECT 1")
            is_healthy = True
        
        if is_healthy:
            return {"status": "healthy"}, 200
        else:
            return {"status": "unhealthy"}, 503
    except Exception as e:
        logger.error(f"健康检查失败: {e}")
        return {"status": "unhealthy", "error": str(e)}, 503


def process_github_event(headers, msg):
    """
    处理 GitHub 事件并返回标准化事件对象
    
    Args:
        headers: HTTP 请求头
        msg: Pub/Sub 消息
        
    Returns:
        标准化的事件字典
    """
    event_type = headers.get("X-Github-Event")
    signature = headers.get("X-Hub-Signature", "")
    source = "github"

    if "Mock" in headers:
        source += "mock"

    supported_types = {
        "push", "pull_request", "pull_request_review",
        "pull_request_review_comment", "issues",
        "issue_comment", "check_run", "check_suite", "status",
        "deployment_status", "release"
    }

    if event_type not in supported_types:
        raise Exception(f"不支持的 GitHub 事件: '{event_type}'")

    # 解析元数据
    metadata = json.loads(base64.b64decode(msg["data"]).decode("utf-8").strip())

    # 提取时间戳和 ID
    time_created = None
    event_id = None
    repository = ""
    author = ""
    commit_sha = ""
    branch = ""
    pr_number = 0

    if event_type == "push":
        time_created = metadata.get("head_commit", {}).get("timestamp")
        event_id = metadata.get("head_commit", {}).get("id")
        repository = metadata.get("repository", {}).get("name", "")
        author = metadata.get("pusher", {}).get("email", "")
        commit_sha = event_id
        branch = metadata.get("ref", "").split("/")[-1]

    elif event_type == "pull_request":
        time_created = metadata.get("pull_request", {}).get("updated_at")
        event_id = f"{metadata.get('repository', {}).get('name', '')}/{metadata.get('number')}"
        repository = metadata.get("repository", {}).get("name", "")
        author = metadata.get("pull_request", {}).get("user", {}).get("login", "")
        pr_number = metadata.get("number", 0)

    elif event_type == "pull_request_review":
        time_created = metadata.get("review", {}).get("submitted_at")
        event_id = metadata.get("review", {}).get("id")
        author = metadata.get("review", {}).get("user", {}).get("login", "")

    elif event_type == "check_run":
        time_created = metadata.get("check_run", {}).get("completed_at") or \
                      metadata.get("check_run", {}).get("started_at")
        event_id = metadata.get("check_run", {}).get("id")

    elif event_type == "deployment_status":
        time_created = metadata.get("deployment_status", {}).get("updated_at")
        event_id = metadata.get("deployment_status", {}).get("id")

    # 构建标准化事件
    github_event = {
        "event_type": event_type,
        "id": str(event_id),
        "metadata": json.dumps(metadata),
        "time_created": time_created,
        "signature": signature,
        "msg_id": msg.get("message_id", ""),
        "source": source,
        "repository": repository,
        "author": author,
        "commit_sha": commit_sha,
        "branch": branch,
        "pr_number": pr_number,
        "status": metadata.get("status", "success"),
        "tags": ["github"],
    }

    logger.info(f"处理的 GitHub 事件: {github_event}")
    return github_event


def insert_event_to_clickhouse(event):
    """
    将事件插入到 ClickHouse
    
    Args:
        event: 事件字典
    """
    try:
        if hasattr(ch_client, 'insert_event'):
            # 使用 ClickHouseMetricsClient
            ch_client.insert_event(event)
        else:
            # 使用原生驱动
            query = """
            INSERT INTO events (
                event_id, time_created, event_type, source, msg_id,
                signature, metadata, repository, author, commit_sha,
                branch, pr_number, status, tags, duration_ms, created_at
            ) VALUES
            """
            
            import uuid
            values = (
                str(uuid.uuid4()),
                event.get('time_created', datetime.now().isoformat()),
                event.get('event_type', 'push'),
                event.get('source', 'github'),
                event.get('msg_id', ''),
                event.get('signature', ''),
                event.get('metadata', '{}'),
                event.get('repository', ''),
                event.get('author', ''),
                event.get('commit_sha', ''),
                event.get('branch', ''),
                int(event.get('pr_number', 0)),
                event.get('status', 'success'),
                event.get('tags', []),
                0,
                datetime.now().isoformat(),
            )
            
            ch_client.execute(
                f"{query} ({','.join(['%s'] * len(values))})",
                [values]
            )
        
        logger.info("事件已插入到 ClickHouse")
    except Exception as e:
        logger.error(f"插入事件到 ClickHouse 失败: {e}")
        raise


if __name__ == "__main__":
    PORT = int(os.getenv("PORT", 8080))
    
    # 在本地运行时使用
    # Gunicorn 用于在 Cloud Run 上运行
    # 参见 Dockerfile 中的入点
    app.run(host="0.0.0.0", port=PORT, debug=True)
