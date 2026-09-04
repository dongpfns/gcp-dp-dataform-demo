"""範囲洗替（P2）のウィンドウ計算（v2/21_transform.md 4.3）。

このモジュールはウィンドウ幅とその丸め方の**唯一の定義**であり、
変換層（dataform_project/includes/audit_columns.js の windowStart()）と
必ず同じ月数・同じ丸め方に保つこと。ずれると重複INSERTまたは誤削除になる。

外部依存を持たないモジュールにしてあるのは、
「ウィンドウ境界の丸め」を単体テストで機械的に検証できるようにするため。
ここがずれると境界月の月初数日が重複INSERTされ、再現性の低い障害になる。
"""

from __future__ import annotations

from datetime import date

# 範囲洗替（P2）のウィンドウ幅（月数）。
# 「ソースが遡って訂正しうる最大期間」より長く取る（v2/20_ingestion.md 3.3）。
WINDOW_MONTHS = 14


def window_start(today: date, months: int = WINDOW_MONTHS) -> date:
    """ウィンドウ開始日を「月境界」に丸めて返す。

    日単位で切る（today - 425日 のような計算）と、境界月の月初数日だけが
    範囲外に落ち、SILVERのMERGEで NOT MATCHED → INSERT となって重複する。
    境界は毎日動くため再現性の低い障害になる。

    Args:
        today: 基準日
        months: ウィンドウ幅（月数）。既定は WINDOW_MONTHS

    Returns:
        月初日（day は必ず 1）
    """
    total = today.year * 12 + (today.month - 1) - months
    return date(total // 12, total % 12 + 1, 1)
