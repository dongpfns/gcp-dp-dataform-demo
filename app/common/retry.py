"""リトライ（v2/20_ingestion.md 2.2 ルール3）。

- 429 / 5xx は指数バックオフで再試行（初回1秒・最大5回・ジッタ付き）
- 429以外の 4xx は即座に失敗させる（再試行しても成功しないため）
"""

from __future__ import annotations

import random
import time
from typing import Callable, Iterable, TypeVar

import requests

T = TypeVar("T")

RETRYABLE_STATUS: frozenset[int] = frozenset({429, 500, 502, 503, 504})


class RetryableError(Exception):
    """再試行してよいエラー。"""


class FatalError(Exception):
    """再試行しても無意味なエラー。即座に失敗させる。"""


def call_with_retry(
    func: Callable[[], T],
    *,
    max_attempts: int = 5,
    base_delay_s: float = 1.0,
    max_delay_s: float = 60.0,
    retryable: Iterable[type[Exception]] = (RetryableError, requests.Timeout, requests.ConnectionError),
) -> T:
    """指数バックオフ + ジッタで func を再試行する。"""
    retryable_types = tuple(retryable)
    last_exc: Exception | None = None

    for attempt in range(1, max_attempts + 1):
        try:
            return func()
        except FatalError:
            raise
        except retryable_types as exc:
            last_exc = exc
            if attempt == max_attempts:
                break
            delay = min(base_delay_s * (2 ** (attempt - 1)), max_delay_s)
            delay += random.uniform(0, delay * 0.25)  # ジッタ
            time.sleep(delay)

    raise RetryableError(f"{max_attempts}回試行しても成功しませんでした: {last_exc}") from last_exc


def raise_for_status(response: requests.Response) -> None:
    """HTTPステータスを再試行可否に振り分けて例外化する。"""
    if response.status_code < 400:
        return
    if response.status_code in RETRYABLE_STATUS:
        raise RetryableError(f"HTTP {response.status_code} (retryable)")
    raise FatalError(f"HTTP {response.status_code}: {response.text[:200]}")
