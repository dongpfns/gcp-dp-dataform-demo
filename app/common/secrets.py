"""Secret Manager からの認証情報取得（v2/30_iam_security.md 5節）。

- 認証情報を環境変数へ直書きしない／コードに埋め込まない
- アクセス権はシークレット単位で付与する
"""

from __future__ import annotations

from functools import lru_cache

from google.cloud import secretmanager


@lru_cache(maxsize=32)
def get_secret(project_id: str, secret_id: str, version: str = "latest") -> str:
    """シークレットの値を取得する（同一実行内はキャッシュする）。"""
    client = secretmanager.SecretManagerServiceClient()
    name = f"projects/{project_id}/secrets/{secret_id}/versions/{version}"
    response = client.access_secret_version(request={"name": name})
    return response.payload.data.decode("utf-8")
