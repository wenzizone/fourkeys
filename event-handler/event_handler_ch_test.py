# Copyright 2020 Google, LLC.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import os
import hmac
from hashlib import sha1
from unittest import mock

import event_handler

import pytest


@pytest.fixture
def client():
    event_handler.app.testing = True
    return event_handler.app.test_client()


def test_unauthorized_source(client):
    r = client.post("/", data="Hello")
    assert r.status_code == 403

    r = client.get("/", data="Hello")
    assert r.status_code == 403


def test_missing_signature(client):
    r = client.post("/", headers={"User-Agent": "GitHub-Hookshot"})
    assert r.status_code == 403


@mock.patch.dict(os.environ, {"GITHUB_SECRET": "foo"}, clear=False)
def test_unverified_signature(client):
    r = client.post(
        "/",
        headers={
            "User-Agent": "GitHub-Hookshot",
            "X-Hub-Signature": "foobar",
        },
    )

    assert r.status_code == 403


@mock.patch(
    "event_handler.publish_to_kafka", mock.MagicMock(return_value=True)
)
@mock.patch.dict(os.environ, {"GITHUB_SECRET": "foo"}, clear=False)
def test_verified_signature(client):
    secret = os.environ["GITHUB_SECRET"].encode("utf-8")
    signature = "sha1=" + hmac.new(secret, b"Hello", sha1).hexdigest()
    r = client.post(
        "/",
        data="Hello",
        headers={"User-Agent": "GitHub-Hookshot", "X-Hub-Signature": signature},
    )
    assert r.status_code == 204


@mock.patch.dict(os.environ, {"GITHUB_SECRET": "foo"}, clear=False)
def test_data_sent_to_kafka(client):
    secret = os.environ["GITHUB_SECRET"].encode("utf-8")
    signature = "sha1=" + hmac.new(secret, b"Hello", sha1).hexdigest()
    headers = {
        "User-Agent": "GitHub-Hookshot",
        "Host": "localhost",
        "Content-Length": "5",
        "X-Hub-Signature": signature,
    }

    with mock.patch.object(
        event_handler, "publish_to_kafka", return_value=True
    ) as mocked_publish:
        r = client.post("/", data="Hello", headers=headers)
        mocked_publish.assert_called_with("github", b"Hello", headers)
        assert r.status_code == 204
