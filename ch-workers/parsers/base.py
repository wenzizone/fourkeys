import os
from abc import ABC, abstractmethod
from typing import Any, Dict

from confluent_kafka import Message

from common import build_msg_id, decode_headers, load_payload


class BaseParser(ABC):
    name: str = ""
    default_topic: str = ""
    topic_env: str = ""
    default_group: str = ""
    group_env: str = ""

    def topic(self) -> str:
        return os.getenv(self.topic_env, self.default_topic)

    def group_id(self) -> str:
        return os.getenv(self.group_env, self.default_group)

    def prepare_event(self, msg: Message) -> Dict[str, Any]:
        metadata = load_payload(msg)
        headers = decode_headers(msg.headers())
        msg_id = build_msg_id(msg)
        return self.build_event(metadata, headers, msg_id)

    @abstractmethod
    def build_event(
        self, metadata: Dict[str, Any], headers: Dict[str, str], msg_id: str
    ) -> Dict[str, Any]:
        ...
