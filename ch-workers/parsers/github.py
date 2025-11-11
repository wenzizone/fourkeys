import json
from typing import Any, Dict, Tuple

from common import parse_timestamp
from .base import BaseParser

SUPPORTED_EVENTS = {
    "push",
    "pull_request",
    "pull_request_review",
    "pull_request_review_comment",
    "issues",
    "issue_comment",
    "check_run",
    "check_suite",
    "status",
    "deployment_status",
    "release",
}


class GitHubParser(BaseParser):
    name = "github"
    default_topic = "fourkeys-github"
    topic_env = "KAFKA_GITHUB_TOPIC"
    default_group = "fourkeys-github-parser"
    group_env = "KAFKA_GITHUB_GROUP"

    def build_event(
        self, metadata: Dict[str, Any], headers: Dict[str, str], msg_id: str
    ) -> Dict[str, Any]:
        event_type = headers.get("X-GitHub-Event") or headers.get("X-Github-Event")
        if not event_type:
            raise RuntimeError("Missing X-GitHub-Event header")
        if event_type not in SUPPORTED_EVENTS:
            raise RuntimeError(f"Unsupported GitHub event: '{event_type}'")

        signature = headers.get("X-Hub-Signature", "")
        time_created, event_id = extract_event_metadata(event_type, metadata)
        if not event_id:
            event_id = msg_id

        event = {
            "event_type": event_type,
            "id": event_id,
            "metadata": json.dumps(metadata),
            "time_created": parse_timestamp(time_created),
            "signature": signature,
            "msg_id": msg_id,
            "source": "github",
        }
        return event


def extract_event_metadata(event_type: str, metadata: Dict[str, Any]) -> Tuple[Any, Any]:
    if event_type == "push":
        head_commit = metadata.get("head_commit", {}) or {}
        identifier = head_commit.get("id") or metadata.get("after") or metadata.get("before")
        return head_commit.get("timestamp"), identifier
    if event_type == "pull_request":
        repository = metadata.get("repository", {}) or {}
        return (
            metadata.get("pull_request", {}).get("updated_at"),
            f"{repository.get('name','')}/{metadata.get('number')}",
        )
    if event_type == "pull_request_review":
        review = metadata.get("review", {}) or {}
        return review.get("submitted_at"), review.get("id")
    if event_type == "pull_request_review_comment":
        comment = metadata.get("comment", {}) or {}
        return comment.get("updated_at"), comment.get("id")
    if event_type == "issues":
        issue = metadata.get("issue", {}) or {}
        repository = metadata.get("repository", {}) or {}
        return issue.get("updated_at"), f"{repository.get('name','')}/{issue.get('number')}"
    if event_type == "issue_comment":
        comment = metadata.get("comment", {}) or {}
        return comment.get("updated_at"), comment.get("id")
    if event_type == "check_run":
        check_run = metadata.get("check_run", {}) or {}
        return (
            check_run.get("completed_at") or check_run.get("started_at"),
            check_run.get("id"),
        )
    if event_type == "check_suite":
        check_suite = metadata.get("check_suite", {}) or {}
        return (
            check_suite.get("updated_at") or check_suite.get("created_at"),
            check_suite.get("id"),
        )
    if event_type == "deployment_status":
        deployment_status = metadata.get("deployment_status", {}) or {}
        return deployment_status.get("updated_at"), deployment_status.get("id")
    if event_type == "status":
        return metadata.get("updated_at"), metadata.get("id")
    if event_type == "release":
        release = metadata.get("release", {}) or {}
        return (
            release.get("published_at") or release.get("created_at"),
            release.get("id"),
        )
    raise RuntimeError(f"Unsupported GitHub event: '{event_type}'")
