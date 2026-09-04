# dataform_project

Dataformの定義一式。準拠する規約は [`../../v2/21_transform.md`](../../v2/21_transform.md) 5節。

## ⚠️ 別リポジトリへの切り出しが必要

Dataformは `google_dataform_repository.git_remote_settings` で指定したGitHubリポジトリを
**そのままコンパイル**する。サブディレクトリ指定はできないため、このフォルダは
**単独のリポジトリ `{owner}/{system}-dataform` として存在している必要がある**。

本デモではレビューのしやすさを優先して同居させており、`make dataform-push` が
`git subtree push` でこのフォルダだけを別リポジトリへ反映する。

```bash
make dataform-push DATAFORM_REMOTE=git@github.com:your-org/example-dataform.git
```

## ディレクトリ

```text
definitions/            すべての .sqlx はこの配下に置く
├── sources/            BRONZEの declaration（参照定義）
├── silver/{domain}/
├── gold/{consumer}/
└── assertions/         データ品質チェック
includes/               共通JS（definitions/ 外に置く数少ない例外）
workflow_settings.yaml  プロジェクト設定・vars 既定値
```

**`definitions/` 外の `.sqlx` はコンパイルされず、テストが素通りする事故になる。**
CI（`dataform-ci.yml`）がこれを機械的に検査している。

## ブランチと環境

| ブランチ | Release Config | 環境 |
| :--- | :--- | :--- |
| `main` | `rc-prd` | `example-prd` |
| `staging` | `rc-stg` | `example-stg` |
| `develop` | `rc-dev` | `example-dev` |

Dataformに「デプロイ」工程は存在しない。マージした時点で次回のコンパイル対象が新しいコードになる。
CIの役割は**デプロイではなく検証（コンパイル + dry-run）**。
