"""GCSオブジェクトパスが v2/13_naming_storage.md 2.1 の規約に従うことを検証する。"""

from __future__ import annotations

import re

from common.paths import build_object_path

PATTERN = re.compile(
    r"^(?P<source>[a-z0-9_]+)/(?P<object>[a-z0-9_]+)/dt=\d{4}-\d{2}-\d{2}/"
    r"(?P<run_id>[A-Za-z0-9\-]+)/(?P=object)_\d{8}T\d{6}Z\.(jsonl\.gz|csv|json)$"
)


def test_object_path_matches_convention() -> None:
    path = build_object_path(
        source_system="salesforce",
        obj="account",
        target_date="2026-09-04",
        run_id="20260904T060000Z-wf-main-daily",
    )
    assert PATTERN.match(path), path


def test_object_path_includes_run_id() -> None:
    """再実行時に既存オブジェクトを上書きしないよう run_id がパスに含まれること。"""
    path = build_object_path("file_csv", "sales_transaction", "2026-09-04", "run-A")
    assert "/run-A/" in path


def test_hive_partition_uses_target_date_not_today() -> None:
    """dt= は「データの対象日」であり処理実行日ではない。"""
    path = build_object_path("file_csv", "sales_transaction", "2020-01-31", "run-A")
    assert "dt=2020-01-31/" in path
