# Copyright 2020 Google LLC
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

import os
import sys
import hmac
import threading
from hashlib import sha1, sha256
from typing import Callable, Dict, TYPE_CHECKING

from flask import abort, Flask, request
if TYPE_CHECKING:
    from confluent_kafka import Producer as KafkaProducer  # pragma: no cover

try:  # pragma: no cover - fallback for environments without confluent-kafka
    from confluent_kafka import KafkaException, Producer as ConfluentProducer
except ModuleNotFoundError:  # pragma: no cover
    ConfluentProducer = None

    class KafkaException(Exception):
        """Fallback KafkaException when confluent-kafka is not installed."""

        pass

KAFKA_BOOTSTRAP_SERVERS = os.environ.get("KAFKA_BOOTSTRAP_SERVERS")
KAFKA_TOPIC_PREFIX = os.environ.get("KAFKA_TOPIC_PREFIX", "")

app = Flask(__name__)
_producer = None


class EventSource:
    """Simple wrapper for signature header and verification callback."""

    def __init__(self, signature_header: str, verification_func: Callable[[str, bytes], bool]):
        self.signature = signature_header
        self.verification = verification_func


def _get_env_secret(var_name: str) -> str:
    """Return required secret from environment variables."""
    secret = os.environ.get(var_name)
    if not secret:
        raise RuntimeError(f"{var_name} environment variable must be set.")
    return secret


def github_verification(signature: str, body: bytes) -> bool:
    """Validate GitHub webhook signature using HMAC SHA1."""
    if not signature:
        return False
    secret = _get_env_secret("GITHUB_SECRET").encode("utf-8")
    expected_signature = "sha1=" + hmac.new(secret, body, sha1).hexdigest()
    return hmac.compare_digest(signature, expected_signature)


def circleci_verification(signature: str, body: bytes) -> bool:
    """Validate CircleCI webhook signature using HMAC SHA256."""
    if not signature:
        return False
    secret = _get_env_secret("CIRCLECI_SECRET").encode("utf-8")
    expected_signature = "v1=" + hmac.new(secret, body, sha256).hexdigest()
    return hmac.compare_digest(signature, expected_signature)


def pagerduty_verification(signature: str, body: bytes) -> bool:
    """Validate PagerDuty webhook signature list using HMAC SHA256."""
    if not signature:
        raise RuntimeError("PagerDuty signature is empty.")
    secret = _get_env_secret("PAGERDUTY_SECRET").encode("utf-8")
    expected_signature = "v1=" + hmac.new(secret, body, sha256).hexdigest()
    signature_list = [item.strip() for item in signature.split(",") if item.strip()]
    if not signature_list:
        raise RuntimeError("PagerDuty signature list is empty.")
    return any(hmac.compare_digest(item, expected_signature) for item in signature_list)


def _token_verification(signature: str, _: bytes, env_var: str) -> bool:
    """Compare header token against environment variable value."""
    if not signature:
        raise RuntimeError("Token is empty.")
    expected = _get_env_secret(env_var)
    return hmac.compare_digest(signature, expected)


def gitlab_verification(signature: str, body: bytes) -> bool:
    return _token_verification(signature, body, "GITLAB_TOKEN")


def tekton_verification(signature: str, body: bytes) -> bool:
    return _token_verification(signature, body, "TEKTON_SECRET")


def get_source(headers: Dict[str, str]) -> str:
    """Determine event source from request headers."""
    if "X-Gitlab-Event" in headers:
        return "gitlab"
    ce_type = headers.get("Ce-Type", "").lower()
    ce_source = headers.get("Ce-Source", "").lower()
    if "argocd" in ce_type or "argocd" in ce_source:
        return "argocd"
    if "tekton" in ce_type:
        return "tekton"
    if "GitHub-Hookshot" in headers.get("User-Agent", ""):
        return "github"
    if "Circleci-Event-Type" in headers:
        return "circleci"
    if "X-Pagerduty-Signature" in headers:
        return "pagerduty"
    return headers.get("User-Agent")


AUTHORIZED_SOURCES = {
    "github": EventSource("X-Hub-Signature", github_verification),
    "gitlab": EventSource("X-Gitlab-Token", gitlab_verification),
    "tekton": EventSource("tekton-secret", tekton_verification),
    "argocd": EventSource(
        "tekton-secret",
        lambda sig, body: _token_verification(
            sig,
            body,
            "ARGOCD_SECRET" if os.environ.get("ARGOCD_SECRET") else "TEKTON_SECRET",
        ),
    ),
    "circleci": EventSource("Circleci-Signature", circleci_verification),
    "pagerduty": EventSource("X-Pagerduty-Signature", pagerduty_verification),
}


def get_producer() -> "KafkaProducer":
    global _producer
    if _producer is None:
        if not KAFKA_BOOTSTRAP_SERVERS:
            raise RuntimeError(
                "KAFKA_BOOTSTRAP_SERVERS environment variable must be set."
            )

        if ConfluentProducer is None:
            raise RuntimeError(
                "confluent-kafka package is required to publish events. "
                "Install dependencies with pip before running the handler."
            )

        bootstrap_servers = [
            server.strip()
            for server in KAFKA_BOOTSTRAP_SERVERS.split(",")
            if server.strip()
        ]
        if not bootstrap_servers:
            raise RuntimeError(
                "KAFKA_BOOTSTRAP_SERVERS did not contain any valid hosts."
            )
        _producer = ConfluentProducer(
            {
                "bootstrap.servers": ",".join(bootstrap_servers),
                "broker.address.family": "v4",
            }
        )
    return _producer


def build_topic_name(source: str) -> str:
    return f"{KAFKA_TOPIC_PREFIX}{source}"


@app.route("/", methods=["GET", "POST"])
def index():
    """
    Receives event data from a webhook, checks if the source is authorized,
    verifies its signature, and then sends the data to Kafka.
    """

    # Check if the source is authorized
    source = get_source(request.headers)

    if source not in AUTHORIZED_SOURCES:
        abort(403, f"Source not authorized: {source}")

    auth_source = AUTHORIZED_SOURCES[source]
    signature_sources = {**request.headers, **request.args}
    signature = signature_sources.get(auth_source.signature, None)
    if signature is None:
        lowered_target = auth_source.signature.lower()
        for key, value in signature_sources.items():
            if str(key).lower() == lowered_target:
                signature = value
                break

    if not signature:
        abort(403, "Signature not found in request headers")

    body = request.data

    # Verify the signature
    verify_signature = auth_source.verification
    try:
        if not verify_signature(signature, body):
            abort(403, "Signature does not match expected signature")
    except RuntimeError as err:
        abort(500, str(err))

    # Remove the Auth header so we do not publish it to Kafka
    message_headers = dict(request.headers)
    if "Authorization" in message_headers:
        del message_headers["Authorization"]

    publish_to_kafka(source, body, message_headers)

    # Flush the stdout to avoid log buffering.
    sys.stdout.flush()
    return "", 204


def publish_to_kafka(source, msg, headers):
    """Publish the message to Kafka."""
    try:
        producer = get_producer()
        topic = build_topic_name(source)
        kafka_headers = [
            (str(k), str(v).encode("utf-8")) for k, v in headers.items()
        ]
        delivery_event = threading.Event()
        delivery_result = {}

        def _delivery_callback(err, delivered_msg):
            delivery_result["err"] = err
            delivery_result["msg"] = delivered_msg
            delivery_event.set()

        producer.produce(
            topic=topic,
            value=msg,
            headers=kafka_headers,
            on_delivery=_delivery_callback,
        )
        remaining = 10.0
        poll_interval = 0.1
        while not delivery_event.is_set() and remaining > 0:
            producer.poll(poll_interval)
            remaining -= poll_interval
        if not delivery_event.is_set():
            raise TimeoutError("Timed out waiting for Kafka delivery acknowledgement.")

        if delivery_result.get("err") is not None:
            raise KafkaException(delivery_result["err"])

        record_metadata = delivery_result["msg"]
        print(
            f"Published message to {record_metadata.topic()} partition "
            f"{record_metadata.partition()} offset {record_metadata.offset()}"
        )
    except (KafkaException, Exception) as err:
        entry = dict(severity="WARNING", message=str(err))
        print(entry)
        raise


if __name__ == "__main__":
    PORT = int(os.getenv("PORT")) if os.getenv("PORT") else 8080
    print(os.environ["GITHUB_SECRET"])
    # This is used when running locally. Gunicorn is used to run the
    # application on Cloud Run. See entrypoint in Dockerfile.
    app.run(host="127.0.0.1", port=PORT, debug=True)
