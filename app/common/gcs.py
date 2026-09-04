"""GCSへの書き込み（v2/13_naming_storage.md 2節）。

- 既存オブジェクトを上書きしない（再実行は新しい run_id の下に書く）
- 1ファイルは 128MB〜1GB を目安に分割する

パスの組み立ては common.paths.build_object_path に分離してある
（GCP依存なしで単体テストできるようにするため）。ここから再エクスポートする。
"""

from __future__ import annotations

import gzip
import io
import json
from typing import Iterable, Iterator

from google.cloud import storage

from common.paths import build_object_path

__all__ = ["build_object_path", "upload_jsonl", "chunked"]


def upload_jsonl(
    bucket_name: str,
    object_path: str,
    records: Iterable[dict],
    *,
    compress: bool = True,
) -> tuple[str, int]:
    """レコード列をJSONL（既定でgzip圧縮）としてGCSへアップロードする。

    Returns:
        (gcs_uri, record_count)
    """
    client = storage.Client()
    bucket = client.bucket(bucket_name)
    blob = bucket.blob(object_path)

    buf = io.BytesIO()
    count = 0
    writer = gzip.GzipFile(fileobj=buf, mode="wb") if compress else buf

    try:
        for record in records:
            line = json.dumps(record, ensure_ascii=False, default=str) + "\n"
            writer.write(line.encode("utf-8"))
            count += 1
    finally:
        if compress:
            writer.close()

    buf.seek(0)
    content_type = "application/gzip" if compress else "application/x-ndjson"

    # if_generation_match=0 : 既存オブジェクトがある場合は失敗させる（上書き禁止）
    blob.upload_from_file(buf, content_type=content_type, if_generation_match=0)

    return f"gs://{bucket_name}/{object_path}", count


def chunked(iterable: Iterable[dict], size: int) -> Iterator[list[dict]]:
    """レコード列を size 件ずつのリストに分割する（大量データの分割アップロード用）。"""
    chunk: list[dict] = []
    for item in iterable:
        chunk.append(item)
        if len(chunk) >= size:
            yield chunk
            chunk = []
    if chunk:
        yield chunk
