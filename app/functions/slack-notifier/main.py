"""cf-slack-notifier : パイプラインの失敗を Slack へ通知する。

規約:
    v2/22_orchestration.md 7節  通知
    v2/30_iam_security.md 5節   Webhook URL は Secret Manager から取得する

トリガー: Pub/Sub（ps-pipeline-failed）
通知本文には必ず run_id と Cloud Logging へのURLを含める。
"""

from __future__ import annotations

import base64
import json
import os
from functools import lru_cache

import functions_framework
import requests
from cloudevents.http import CloudEvent
from google.cloud import secretmanager

PROJECT_ID = os.environ["GCP_PROJECT_ID"]
ENV = os.environ.get("ENV", "dev")
SECRET_ID = os.environ.get("WEBHOOK_SECRET_ID", "sec-notification-webhook-url")
COMPONENT = "slack-notifier"

TIMEOUT_S = (5, 15)


@lru_cache(maxsize=1)
def _webhook_url() -> str:
    client = secretmanager.SecretManagerServiceClient()
    name = f"projects/{PROJECT_ID}/secrets/{SECRET_ID}/versions/latest"
    return client.access_secret_version(request={"name": name}).payload.data.decode("utf-8")


def _log(severity: str, event: str, run_id: str, **fields) -> None:
    payload = {"severity": severity, "run_id": run_id, "component": COMPONENT, "event": event}
    payload.update(fields)
    print(json.dumps(payload, ensure_ascii=False, default=str), flush=True)


def _build_message(body: dict) -> dict:
    run_id = body.get("run_id", "unknown")
    log_url = body.get("log_url") or (
        "https://console.cloud.google.com/logs/query"
        f";query=jsonPayload.run_id%3D%22{run_id}%22?project={PROJECT_ID}"
    )

    return {
        "text": f"[{ENV}] パイプライン失敗: {body.get('workflow_name', 'unknown')}",
        "blocks": [
            {
                "type": "section",
                "text": {
                    "type": "mrkdwn",
                    "text": (
                        f"*:rotating_light: パイプライン失敗* `{ENV}`\n"
                        f"• ワークフロー: `{body.get('workflow_name', 'unknown')}`\n"
                        f"• run_id: `{run_id}`\n"
                        f"• 失敗ステップ: `{body.get('step', 'unknown')}`\n"
                        f"• エラー: ```{str(body.get('error', ''))[:800]}```"
                    ),
                },
            },
            {
                "type": "actions",
                "elements": [
                    {
                        "type": "button",
                        "text": {"type": "plain_text", "text": "Cloud Logging を開く"},
                        "url": log_url,
                    }
                ],
            },
        ],
    }


@functions_framework.cloud_event
def main(cloud_event: CloudEvent) -> None:
    raw = base64.b64decode(cloud_event.data["message"]["data"]).decode("utf-8")
    body = json.loads(raw)
    run_id = body.get("run_id", "unknown")

    response = requests.post(_webhook_url(), json=_build_message(body), timeout=TIMEOUT_S)
    response.raise_for_status()

    _log("INFO", "notified", run_id, workflow_name=body.get("workflow_name"))
