import hashlib
import json
from typing import Any, Dict

from common import parse_timestamp
from .base import BaseParser


class ArgoCDParser(BaseParser):
    name = "argocd"
    default_topic = "fourkeys-argocd"
    topic_env = "KAFKA_ARGOCD_TOPIC"
    default_group = "fourkeys-argocd-parser"
    group_env = "KAFKA_ARGOCD_GROUP"

    def build_event(
        self, metadata: Dict[str, Any], headers: Dict[str, str], msg_id: str
    ) -> Dict[str, Any]:
        metadata_json = json.dumps(metadata)
        signature = hashlib.sha1(metadata_json.encode("utf-8")).hexdigest()
        event = {
            "event_type": "deployment",
            "id": str(metadata.get("id", msg_id)),
            "metadata": metadata_json,
            "time_created": parse_timestamp(metadata.get("time")),
            "signature": signature,
            "msg_id": msg_id,
            "source": "argocdmock" if headers.get("Mock") else "argocd",
        }
        return event
