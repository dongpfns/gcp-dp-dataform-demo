"""ウィンドウ境界の丸めが正しいことを検証する。

v2/90_review_checklist.md 落とし穴 #3（境界月の月初数日が範囲外に落ちて
重複INSERTされる）を、単体テストで機械的に防ぐ。
"""

from __future__ import annotations

from datetime import date

import pytest

from common.window import window_start


@pytest.mark.parametrize(
    ("today", "months", "expected"),
    [
        # 月境界に丸められること（日は必ず1日になる）
        (date(2026, 9, 4), 14, date(2025, 7, 1)),
        (date(2026, 9, 30), 14, date(2025, 7, 1)),
        (date(2026, 9, 1), 14, date(2025, 7, 1)),
        # 年跨ぎ
        (date(2026, 1, 15), 14, date(2024, 11, 1)),
        (date(2026, 1, 15), 1, date(2025, 12, 1)),
        (date(2026, 1, 15), 12, date(2025, 1, 1)),
        (date(2026, 12, 31), 24, date(2024, 12, 1)),
    ],
)
def test_window_start_is_month_boundary(today: date, months: int, expected: date) -> None:
    assert window_start(today, months) == expected


def test_window_start_is_stable_within_month() -> None:
    """同じ月の中でウィンドウ開始日が動かないこと。

    日単位で切ると境界が毎日動き、再現性の低い障害になる。
    """
    starts = {window_start(date(2026, 9, day), 14) for day in range(1, 31)}
    assert len(starts) == 1


def test_window_start_always_day_one() -> None:
    for month in range(1, 13):
        assert window_start(date(2026, month, 15), 14).day == 1


def test_window_months_matches_transform_layer() -> None:
    """ウィンドウ幅がDataform側の定義と一致していること。

    取込側と変換側でウィンドウ幅がずれていること自体が設計欠陥
    （v2/20_ingestion.md 3.3 / v2/90_review_checklist.md 落とし穴 #7）。
    """
    import re
    from pathlib import Path

    from common.window import WINDOW_MONTHS

    root = Path(__file__).resolve().parents[1]
    checked = 0

    dataform = root / "dataform_project" / "workflow_settings.yaml"
    if dataform.exists():
        assert re.search(rf'window_months:\s*"?{WINDOW_MONTHS}"?', dataform.read_text(encoding="utf-8")), \
            "workflow_settings.yaml のウィンドウ幅が取込側と一致しません"
        checked += 1

    assert checked > 0, "dataform_project/workflow_settings.yaml が見つかりません"
