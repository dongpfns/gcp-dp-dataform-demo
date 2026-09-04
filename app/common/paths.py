"""GCSオブジェクトパスの組み立て（v2/13_naming_storage.md 2.1）。

外部依存を持たないモジュールにしてあるのは、パス規約を単体テストで
機械的に検証できるようにするため。

パス規約:
    {source_system}/{object}/dt=YYYY-MM-DD/{run_id}/{object}_{YYYYMMDDTHHMMSSZ}.{ext}
"""

from __future__ import annotations

from datetime import datetime, timezone


def build_object_path(
    source_system: str,
    obj: str,
    target_date: str,
    run_id: str,
    ext: str = "jsonl.gz",
    now: datetime | None = None,
) -> str:
    """規約に沿ったGCSオブジェクトパス（バケット名を除く）を組み立てる。

    Args:
        source_system: 連携元システム。BRONZEデータセット bronze_{source_system} と一致させる
        obj: 対象オブジェクト名。BRONZEテーブル名と対応させる
        target_date: データの対象日（YYYY-MM-DD）。**処理実行日ではない**
        run_id: パイプライン実行ID。再実行時の切り分けと上書き防止に使う
        ext: 拡張子（jsonl.gz / csv / json）
    """
    ts = (now or datetime.now(timezone.utc)).strftime("%Y%m%dT%H%M%SZ")
    return f"{source_system}/{obj}/dt={target_date}/{run_id}/{obj}_{ts}.{ext}"
