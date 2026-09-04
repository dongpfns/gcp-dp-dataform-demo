"""BigQueryへのロード（v2/13_naming_storage.md 3節）。

- 本番のBRONZEはロードジョブで実体化する（外部テーブルのみに依存しない）
- スキーマ自動検出は開発時のみ。本番はスキーマJSONを明示指定する
- write_disposition は取込パターン（v2/20_ingestion.md 3節）に従って明示する
"""

from __future__ import annotations

import json
from pathlib import Path

from google.cloud import bigquery

# 取込パターンと write_disposition の対応（v2/20_ingestion.md 3.1）
WRITE_DISPOSITION_BY_PATTERN = {
    "P1": bigquery.WriteDisposition.WRITE_TRUNCATE,  # 全件洗替
    "P2": bigquery.WriteDisposition.WRITE_TRUNCATE,  # 範囲洗替（対象パーティションのみ）
    "P3": bigquery.WriteDisposition.WRITE_APPEND,    # 差分追記
    "P4": bigquery.WriteDisposition.WRITE_APPEND,    # 差分マージ
    "P5": bigquery.WriteDisposition.WRITE_APPEND,    # CDCログ
}


def load_schema(schema_path: str | Path) -> list[bigquery.SchemaField]:
    """スキーマJSONを読み込む（autodetect を使わないため）。"""
    raw = json.loads(Path(schema_path).read_text(encoding="utf-8"))
    return [
        bigquery.SchemaField(
            name=f["name"],
            field_type=f["type"],
            mode=f.get("mode", "NULLABLE"),
            description=f.get("description"),
        )
        for f in raw
    ]


def load_jsonl_from_gcs(
    *,
    project_id: str,
    dataset_id: str,
    table_id: str,
    gcs_uri: str,
    schema: list[bigquery.SchemaField],
    pattern: str = "P1",
    partition_field: str | None = None,
    partition_decorator: str | None = None,
) -> int:
    """GCS上のJSONL(.gz)をBigQueryへロードする。

    Args:
        pattern: 取込パターン（P1〜P5）。write_disposition を決める。
        partition_decorator: P2（範囲洗替）でパーティションを指定する場合に
            "20260901" のような値を渡す。テーブル名に $ で連結される。

    Returns:
        ロードされた行数
    """
    client = bigquery.Client(project=project_id)

    destination = f"{project_id}.{dataset_id}.{table_id}"
    if partition_decorator:
        destination = f"{destination}${partition_decorator}"

    job_config = bigquery.LoadJobConfig(
        source_format=bigquery.SourceFormat.NEWLINE_DELIMITED_JSON,
        schema=schema,
        write_disposition=WRITE_DISPOSITION_BY_PATTERN[pattern],
        # スキーマにない列が来たら失敗させる（黙って落とさない）
        ignore_unknown_values=False,
        max_bad_records=0,
    )

    if partition_field and not partition_decorator:
        job_config.time_partitioning = bigquery.TimePartitioning(
            type_=bigquery.TimePartitioningType.MONTH,
            field=partition_field,
        )

    job = client.load_table_from_uri(gcs_uri, destination, job_config=job_config)
    job.result()  # 完了を待つ

    return job.output_rows or 0
