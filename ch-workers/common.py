import json
import os
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional

from clickhouse_driver import Client
from confluent_kafka import Consumer


def parse_timestamp(raw_value: Any) -> datetime:
    if isinstance(raw_value, datetime):
        result = raw_value
    elif isinstance(raw_value, (int, float)):
        result = datetime.fromtimestamp(raw_value, tz=timezone.utc)
    elif isinstance(raw_value, str):
        cleaned = raw_value.strip()
        if cleaned.endswith("Z"):
            cleaned = cleaned[:-1] + "+00:00"
        try:
            result = datetime.fromisoformat(cleaned)
        except ValueError:
            result = datetime.now(timezone.utc)
    else:
        result = datetime.now(timezone.utc)

    if result.tzinfo:
        return result.astimezone(timezone.utc).replace(tzinfo=None)
    return result


def decode_headers(headers: Optional[List]) -> Dict[str, str]:
    if not headers:
        return {}
    decoded: Dict[str, str] = {}
    for key, value in headers:
        decoded[str(key)] = value.decode("utf-8") if value is not None else ""
    return decoded


def build_msg_id(msg) -> str:
    return f"{msg.topic()}:{msg.partition()}:{msg.offset()}"


class ClickHouseWriter:
    def __init__(self) -> None:
        host = os.getenv("CLICKHOUSE_HOST", "127.0.0.1")
        port = int(os.getenv("CLICKHOUSE_PORT", "9000"))
        user = os.getenv("CLICKHOUSE_USER", "default")
        password = os.getenv("CLICKHOUSE_PASSWORD", "")
        database = os.getenv("CLICKHOUSE_DATABASE", "fourkeys")
        self.table = os.getenv("CLICKHOUSE_TABLE", "events_raw")
        self.client = Client(
            host=host,
            port=port,
            user=user,
            password=password,
            database=database,
        )

    def insert_event(self, event: Dict[str, Any]) -> None:
        query = (
            f"INSERT INTO {self.table} "
            "(event_type, id, metadata, time_created, signature, msg_id, source) "
            "VALUES"
        )
        values = (
            event["event_type"],
            event["id"],
            event["metadata"],
            event["time_created"],
            event["signature"],
            event["msg_id"],
            event["source"],
        )
        self.client.execute(query, [values])


def build_consumer(group_id: str) -> Consumer:
    bootstrap = os.getenv("KAFKA_BOOTSTRAP_SERVERS")
    if not bootstrap:
        raise RuntimeError("KAFKA_BOOTSTRAP_SERVERS environment variable must be set.")

    config = {
        "bootstrap.servers": bootstrap,
        "group.id": group_id,
        "auto.offset.reset": os.getenv("KAFKA_AUTO_OFFSET_RESET", "earliest"),
        "enable.auto.commit": False,
        "broker.address.family": "v4",
    }
    return Consumer(config)


def load_payload(msg) -> Dict[str, Any]:
    payload = msg.value()
    if payload is None:
        raise RuntimeError("Received empty Kafka payload")
    return json.loads(payload.decode("utf-8"))
