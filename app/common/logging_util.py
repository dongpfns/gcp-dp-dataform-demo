"""構造化ログ（v2/60_nonfunctional.md 5節）。

Cloud Logging は stdout に出力された JSON を構造化ログとして解釈する。
必須フィールド: severity / run_id / component / event
禁止: 個人情報・認証情報・レスポンスボディの全文出力
"""

from __future__ import annotations

import json
import os
import sys
from typing import Any

_LEVELS = {"DEBUG": 10, "INFO": 20, "WARNING": 30, "ERROR": 40}
_MIN_LEVEL = _LEVELS.get(os.environ.get("LOG_LEVEL", "INFO").upper(), 20)


def log(severity: str, component: str, event: str, run_id: str, **fields: Any) -> None:
    """構造化ログを1行のJSONとして出力する。"""
    if _LEVELS.get(severity.upper(), 20) < _MIN_LEVEL:
        return

    payload: dict[str, Any] = {
        "severity": severity.upper(),
        "run_id": run_id,
        "component": component,
        "event": event,
    }
    payload.update(fields)

    stream = sys.stderr if severity.upper() in ("WARNING", "ERROR") else sys.stdout
    print(json.dumps(payload, ensure_ascii=False, default=str), file=stream, flush=True)


def info(component: str, event: str, run_id: str, **fields: Any) -> None:
    log("INFO", component, event, run_id, **fields)


def warning(component: str, event: str, run_id: str, **fields: Any) -> None:
    log("WARNING", component, event, run_id, **fields)


def error(component: str, event: str, run_id: str, **fields: Any) -> None:
    log("ERROR", component, event, run_id, **fields)
