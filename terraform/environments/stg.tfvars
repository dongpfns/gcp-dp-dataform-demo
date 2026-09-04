system                     = "example"
env                        = "stg"
gcp_project_id             = "example-stg"
region                     = "asia-northeast1"
bq_location                = "asia-northeast1"
owner                      = "data-platform-team"

# 変換基盤：Dataform（参照するGitHubリポジトリとブランチ）
dataform_github_owner      = "your-org"
dataform_repo_name         = "example-dataform"
dataform_git_branch        = "staging"

user_sync_image_tag        = "bootstrap"
user_api_base_url          = "https://api.example.com/v1"

fact_partition_granularity = "MONTH"
enable_deletion_protection = true

schedule_daily_cron        = "0 5 * * *"
notification_email         = "data-platform@example.com"
budget_amount_jpy          = 50000
