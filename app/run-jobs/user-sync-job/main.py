"""crj-user-sync : 外部APIからユーザーデータを取得し、GCS raw → BRONZE へロードする Cloud Run Job。

規約:
    v2/20_ingestion.md      取込方式（ELT原則・必ずGCSに原本を落とす・冪等性）
    v2/22_orchestration.md  Cloud Run Jobs 実装規約

取込パターン: P1（全件洗替）
    ユーザーを全件取得しBRONZEを毎回洗い替えるため、SILVER側で物理削除の検知（CDC）が可能。

パラメータは環境変数で受け取る（Workflows が overrides で注入する）:
    GCP_PROJECT_ID / ENV / RAW_BUCKET / ETL_BATCH_ID / ETL_TS / OBJECT
"""

from __future__ import annotations

import os
import sys
from datetime import datetime, timezone
from typing import Iterator

import requests

from common import bq, gcs
from common import logging_util as log
from common.retry import RetryableError, call_with_retry, raise_for_status
from common.secrets import get_secret

COMPONENT = "user-sync-job"
SOURCE_SYSTEM = "user_api"
BRONZE_DATASET = "bronze_user_api"
BRONZE_TABLE = "user"

PROJECT_ID = os.environ["GCP_PROJECT_ID"]
RAW_BUCKET = os.environ["RAW_BUCKET"]
RUN_ID = os.environ.get("ETL_BATCH_ID") or "manual-" + datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")

API_BASE_URL = os.environ.get("API_BASE_URL", "https://api.example.com/v1")
PAGE_SIZE = int(os.environ.get("PAGE_SIZE", "500"))

CONNECT_TIMEOUT_S = 10
READ_TIMEOUT_S = 60

SCHEMA_FILE = os.path.join(os.path.dirname(__file__), "schema.json")


def _fetch_users(api_key: str) -> Iterator[dict]:
    """ページングしながら全件返す。

    ページングを実装しないと1ページ目しか取れない（取りこぼしの典型例）。
    """
    page = 1
    headers = {"Authorization": f"Bearer {api_key}"}

    while True:
        def _get() -> requests.Response:
            return requests.get(
                f"{API_BASE_URL}/users",
                params={"page": page, "per_page": PAGE_SIZE},
                headers=headers,
                timeout=(CONNECT_TIMEOUT_S, READ_TIMEOUT_S),
            )

        response = call_with_retry(_get)
        raise_for_status(response)
        body = response.json()

        items = body.get("items", [])
        yield from items

        if len(items) < PAGE_SIZE:
            return
        page += 1


def _add_ingest_metadata(records: Iterator[dict], source_uri: str) -> Iterator[dict]:
    """BRONZEの監査項目を付与する（v2/11_naming_bigquery.md 4.2）。

    _bronze_ingested_at は「1回の実行で1つの値」に固定する。
    """
    ingested_at = os.environ.get("ETL_TS") or datetime.now(timezone.utc).isoformat()
    for record in records:
        record["_bronze_ingested_at"] = ingested_at
        record["_bronze_source_uri"] = source_uri
        yield record


def main() -> int:
    obj = os.environ.get("OBJECT", BRONZE_TABLE)
    target_date = os.environ.get("TARGET_DATE") or datetime.now(timezone.utc).strftime("%Y-%m-%d")
    started = datetime.now(timezone.utc)

    log.info(COMPONENT, "ingest_started", RUN_ID, object=obj, target_date=target_date)

    try:
        api_key = get_secret(PROJECT_ID, "sec-user-api-key")

        object_path = gcs.build_object_path(SOURCE_SYSTEM, obj, target_date, RUN_ID)
        source_uri = f"{API_BASE_URL}/users"

        records = _add_ingest_metadata(_fetch_users(api_key), source_uri)
        gcs_uri, record_count = gcs.upload_jsonl(RAW_BUCKET, object_path, records)

        # 0件は「正常」ではなく「要判定」（v2/20_ingestion.md 2.2 ルール6）
        if record_count == 0:
            raise RetryableError(f"{obj}: 取得件数が0件でした（想定外）")

        loaded = bq.load_jsonl_from_gcs(
            project_id=PROJECT_ID,
            dataset_id=BRONZE_DATASET,
            table_id=BRONZE_TABLE,
            gcs_uri=gcs_uri,
            schema=bq.load_schema(SCHEMA_FILE),
            pattern="P1",  # 全件洗替 → WRITE_TRUNCATE
        )

        duration_ms = int((datetime.now(timezone.utc) - started).total_seconds() * 1000)
        log.info(
            COMPONENT, "load_completed", RUN_ID,
            object=obj, record_count=loaded, duration_ms=duration_ms, gcs_uri=gcs_uri,
        )
        return 0

    except Exception as exc:  # noqa: BLE001
        log.error(COMPONENT, "ingest_failed", RUN_ID, object=obj, error=str(exc))
        raise


if __name__ == "__main__":
    sys.exit(main())
