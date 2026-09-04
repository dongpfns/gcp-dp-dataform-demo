# gcp-dp-dataform-demo

GCPネイティブサービスでデータ基盤を構築するデモプロジェクトの **Dataform構成**。
準拠する開発規約は [`../v2/`](../v2/)。

取込（`crj-user-sync` / `cf-gcs-csv-trigger`）・インフラ・オーケストレーション・CI/CDの骨格は
[`../gcp-dp-demo/`](../gcp-dp-demo/)（dbt構成）と同じで、**変換層だけが Dataform に置き換わっている**。

## 1. なぜデモを分けているか

Dataformは `git_remote_settings` で指定したGitHubリポジトリを**そのままコンパイル**する。
サブディレクトリ指定ができないため、Dataformの定義は**単独のリポジトリとして存在している必要がある**。
「dbt構成にフォルダを1つ足す」では成立しないため、リポジトリを分けている。

本デモではレビューのしやすさを優先して `dataform_project/` を同居させ、
`make dataform-push` が `git subtree push` で別リポジトリへ反映する。

## 2. フォルダ構成

```text
gcp-dp-dataform-demo/
├── .github/workflows/          CI/CD（最小構成）
│   ├── tf-apply.yml            インフラのデプロイ
│   ├── run-job-user-sync.yml   Jobごとに分ける（変更監視を独立させるため）
│   ├── func-gcs-trigger.yml    Functionsごとに分ける
│   └── dataform-ci.yml         Dataformの検証（デプロイではない）
│
├── terraform/
│   ├── dataform.tf             ★本構成の中核
│   ├── modules/                「作り方」（共通のHCL）
│   ├── schemas/                「中身」（テーブルの列定義JSON）
│   └── environments/           環境ごとの変数値
│
├── app/
│   ├── common/                 Jobs用の共有ライブラリ
│   ├── run-jobs/user-sync-job/ 外部APIからユーザーデータを抜くJob → crj-user-sync
│   ├── functions/
│   │   ├── gcs-csv-trigger/    GCSにCSVが置かれたら動く関数 → cf-gcs-csv-trigger
│   │   └── slack-notifier/     失敗をSlackへ通知する関数 → cf-slack-notifier
│   ├── workflows/              Workflows定義（ファイル名＝ワークフロー名）
│   └── queries/datacheck/      データ品質チェックSQL
│
├── dataform_project/           ★別リポジトリへ切り出す前提（1節）
│   ├── definitions/            すべての .sqlx はこの配下（外に置くとコンパイルされない）
│   ├── includes/               共通JS（definitions/ 外に置く数少ない例外）
│   └── workflow_settings.yaml
│
├── bin/
│   ├── dataform-local.sh       ローカルでDataform CLIを実行（vars必須）
│   ├── dataform-push.sh        dataform_project/ を別リポジトリへ subtree push
│   └── gcp-login.sh            認証・プロジェクトの切り替え
│
├── scripts/
│   ├── init-local.sh
│   └── bootstrap-gcp.sh
│
├── tests/
├── Makefile
├── .gitignore
└── README.md
```

## 3. データの流れ

```text
外部ユーザーAPI ──► crj-user-sync ──► GCS raw ──► bronze_user_api.user
                                                          │
CSVファイル ──► GCS raw ──[Eventarc]──► cf-gcs-csv-trigger ──► bronze_file_csv.sales_transaction
                                                          │
                 wf-main-daily（Workflows / Scheduler JST 05:00）
                                                          ▼
                     ① compilationResults.create（vars を注入）
                     ② workflowInvocations.create（tags: silver, gold）
                     ③ 完了までポーリング
                                                          ▼
                        silver_common.d_account            （P1 全件洗替 + 削除検知）
                        silver_sales.f_30m_sales_transaction（P2 範囲洗替 / 月境界）
                        gold_bi_tool.v_1d_daily_pnl / t_1m_monthly_pnl
                                                          │
                                    失敗時 ──► ps-pipeline-failed ──► cf-slack-notifier
```

**Dataformを2段（compile → invoke）で起動している理由**

監査項目の `etl_ts` / `batch_id` は実行のたびに変わる必要があるが、
Dataformの `vars` は**コンパイル時にしか渡せない**（`workflowInvocations` 側には渡せない）。
そのため Dataform内蔵スケジュール（Workflow Config）は使わず、Workflows から2段で起動する。
`terraform/dataform.tf` にも同じ理由をコメントで残してある。

## 4. セットアップ

```bash
make init                 # ローカル環境の初期化
make login ENV=dev
make bootstrap ENV=dev    # tfstate用バケット等（環境ごとに1回）
make secrets ENV=dev      # user APIキー / Slack Webhook / Dataform用GitHubトークン

# Dataform定義を別リポジトリへ反映（初回）
make dataform-push DATAFORM_REMOTE=git@github.com:your-org/example-dataform.git DATAFORM_BRANCH=develop

make plan  ENV=dev
make apply ENV=dev
make run-pipeline ENV=dev
```

`make help` で全コマンドを表示。

## 5. ブランチと環境

| ブランチ | Release Config | 環境 |
| :--- | :--- | :--- |
| `main` | `rc-prd` | `example-prd` |
| `staging` | `rc-stg` | `example-stg` |
| `develop` | `rc-dev` | `example-dev` |

**Dataformに「デプロイ」工程は存在しない。** マージした時点で次回のコンパイル対象が新しいコードになる。

## 6. CI/CD（最小構成）

| ワークフロー | トリガー | 内容 |
| :--- | :--- | :--- |
| `tf-apply.yml` | `terraform/**` `app/workflows/**` `app/functions/**` | `terraform apply`（本番は承認ゲート） |
| `run-job-user-sync.yml` | `app/run-jobs/user-sync-job/**` `app/common/**` | イメージビルド → push（タグ＝コミットSHA）→ Job更新 |
| `func-gcs-trigger.yml` | `app/functions/gcs-csv-trigger/**` | 当該Functionのみを対象にした `terraform apply` |
| `dataform-ci.yml` | `dataform_project/**` | **検証のみ**（`definitions/` 外の `.sqlx` 検査 → compile → dry-run） |

## 7. 置換するプレースホルダ

| 対象 | 現在の値 | 置換先 |
| :--- | :--- | :--- |
| システム識別子 | `example` | 実際のシステム名 |
| GCPプロジェクトID | `example-dev` / `example-stg` / `example-prd` | 実際のプロジェクトID |
| GitHub Organization | `your-org` | 実際のOrganization名 |
| Dataformリポジトリ名 | `example-dataform` | 実際のリポジトリ名 |
| 外部APIのURL | `https://api.example.com/v1` | 実際のエンドポイント |

## 8. 押さえておくポイント

| 箇所 | なぜそう書いてあるか |
| :--- | :--- |
| `terraform/dataform.tf` の `google_project_service_identity` | Dataformのサービスエージェントは API有効化直後に存在しないことがあり、IAM付与が失敗する。明示的に作成する |
| Workflow Config を作っていない | Dataform内蔵スケジュールでは `vars` を実行ごとに変えられず、監査項目が実行単位で確定しない |
| `dataform_project/definitions/` 配下に限定 | 配下外の `.sqlx` はコンパイルされず、**テストが素通りする** |
| `${when(incremental(), ...)}` で囲うソース側条件 | 囲わないと `--full-refresh` がウィンドウ内しか作り直さず、復旧手順が機能しなくなる |
| `d_account.sqlx` の `LEFT JOIN ${self()}` | MERGEは全列を更新するため、外さないと `etl_loaded_at`（初回挿入日時）が毎回上書きされる |
| 3か所の範囲条件 | ①ソースWHERE ②`updatePartitionFilter` ③`post_operations`。1つでも欠けると重複か誤削除になる |
| `wf-main-daily.yaml` の `build_failure_payload` / 引用符 | Workflowsの式を複数行に折り返す、または `": "` を含めると不正なYAMLになる |
| `bin/dataform-local.sh` が `--vars` を必須にしている | 渡さないと `includes/audit_columns.js` が `undefined` を埋め込む |

## 9. バックフィル手順

```bash
# 1. 取込Jobを期間指定で実行
gcloud run jobs execute crj-user-sync --region=asia-northeast1 --project=example-prd \
  --update-env-vars=TARGET_DATE=2026-03-31,ETL_BATCH_ID=backfill-20260331

# 2. Dataformをフルリフレッシュ
#    ソース側条件が ${when(incremental(), ...)} で囲まれていることが前提
bin/dataform-local.sh prd run --tags silver --full-refresh
```
