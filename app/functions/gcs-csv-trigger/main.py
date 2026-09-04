"""cf-gcs-csv-trigger : GCS raw にCSVが置かれたら BRONZE へロードする。

規約:
    v2/13_naming_storage.md  GCSパス規約
    v2/20_ingestion.md       取込方式（ELT原則・冪等性）
    v2/22_orchestration.md   Cloud Functions 実装規約

トリガー: Eventarc（google.cloud.storage.object.v1.finalized）
対象パス: {source_system}/{object}/dt=YYYY-MM-DD/{run_id}/{object}_{ts}.csv

取込パターン: P2（範囲洗替）
    パーティションデコレータで対象日のパーティションのみを洗い替えるため、
    同じファイルが再送されても重複しない（冪等）。

この関数は共有ライブラリに依存しない自己完結の実装にしてある
（Functionsのソースは単一ディレクトリをZIP化してデプロイするため）。
"""

from __future__ import annotations

import json
import os
import re
from datetime import datetime, timezone

import functions_framework
from cloudevents.http import CloudEvent
from google.cloud import bigquery

PROJECT_ID = os.environ["GCP_PROJECT_ID"]
COMPONENT = "gcs-csv-trigger"

# {source_system}/{object}/dt=YYYY-MM-DD/{run_id}/{file}.csv
PATH_PATTERN = re.compile(
    r"^(?P<source_system>[a-z0-9_]+)/(?P<object>[a-z0-9_]+)/dt=(?P<dt>\d{4}-\d{2}-\d{2})/(?P<run_id>[^/]+)/[^/]+\.csv$"
)

# ソース仕様は設定として明文化する（v2/20_ingestion.md 2.1）
CSV_ENCODING = os.environ.get("CSV_ENCODING", "UTF-8")
CSV_SKIP_ROWS = int(os.environ.get("CSV_SKIP_ROWS", "1"))
CSV_DELIMITER = os.environ.get("CSV_DELIMITER", ",")


def _log(severity: str, event: str, run_id: str, **fields) -> None:
    payload = {"severity": severity, "run_id": run_id, "component": COMPONENT, "event": event}
    payload.update(fields)
    print(json.dumps(payload, ensure_ascii=False, default=str), flush=True)


@functions_framework.cloud_event
def main(cloud_event: CloudEvent) -> None:
    data = cloud_event.data
    bucket = data["bucket"]
    name = data["name"]

    matched = PATH_PATTERN.match(name)
    if not matched:
        # raw 配下の規約外パスは対象外（一時ファイル等）。エラーにはしない。
        _log("DEBUG", "skipped_non_target_path", "n/a", object_name=name)
        return

    source_system = matched.group("source_system")
    obj = matched.group("object")
    dt = matched.group("dt")
    run_id = matched.group("run_id")

    dataset_id = f"bronze_{source_system}"
    # パーティションデコレータ：対象日のパーティションだけを洗い替える
    partition = dt.replace("-", "")
    destination = f"{PROJECT_ID}.{dataset_id}.{obj}${partition}"

    started = datetime.now(timezone.utc)
    _log("INFO", "load_started", run_id, gcs_uri=f"gs://{bucket}/{name}", destination=destination)

    client = bigquery.Client(project=PROJECT_ID)

    # 本番はスキーマ自動検出を使わない（実行ごとに型が変わる事故を防ぐ）
    schema_path = os.path.join(os.path.dirname(__file__), "schemas", f"{obj}.json")
    with open(schema_path, encoding="utf-8") as fp:
        raw_schema = json.load(fp)

    schema = [
        bigquery.SchemaField(
            name=f["name"], field_type=f["type"], mode=f.get("mode", "NULLABLE"), description=f.get("description")
        )
        for f in raw_schema
    ]

    job_config = bigquery.LoadJobConfig(
        source_format=bigquery.SourceFormat.CSV,
        schema=schema,
        skip_leading_rows=CSV_SKIP_ROWS,
        field_delimiter=CSV_DELIMITER,
        encoding=CSV_ENCODING,
        allow_quoted_newlines=True,
        write_disposition=bigquery.WriteDisposition.WRITE_TRUNCATE,  # P2 範囲洗替
        max_bad_records=0,
        ignore_unknown_values=False,
    )

    job = client.load_table_from_uri(f"gs://{bucket}/{name}", destination, job_config=job_config)
    job.result()

    duration_ms = int((datetime.now(timezone.utc) - started).total_seconds() * 1000)
    _log(
        "INFO", "load_completed", run_id,
        record_count=job.output_rows, duration_ms=duration_ms, destination=destination,
    )
