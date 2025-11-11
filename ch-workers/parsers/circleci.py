import json
from typing import Any, Dict

from common import parse_timestamp
from .base import BaseParser

SUPPORTED_EVENTS = {"workflow-completed", "job-completed"}


class CircleCIParser(BaseParser):
    name = "circleci"
    default_topic = "fourkeys-circleci"
    topic_env = "KAFKA_CIRCLECI_TOPIC"
    default_group = "fourkeys-circleci-parser"
    group_env = "KAFKA_CIRCLECI_GROUP"

    def build_event(
        self, metadata: Dict[str, Any], headers: Dict[str, str], msg_id: str
    ) -> Dict[str, Any]:
        event_type = headers.get("Circleci-Event-Type")
        if not event_type:
            raise RuntimeError("Missing Circleci-Event-Type header")
        if event_type not in SUPPORTED_EVENTS:
            raise RuntimeError(f"Unsupported CircleCI event: '{event_type}'")

        signature = headers.get("Circleci-Signature", "")
        event = {
            "event_type": event_type,
            "id": metadata.get("id", msg_id),
            "metadata": json.dumps(metadata),
            "time_created": parse_timestamp(metadata.get("happened_at")),
            "signature": signature,
            "msg_id": msg_id,
            "source": "circleci",
        }
        return event
