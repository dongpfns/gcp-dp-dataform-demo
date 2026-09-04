# =============================================================================
# secret_manager.tf : シークレットの「入れ物」だけを作る
# 規約: v2/30_iam_security.md 5節
#   値（secret_version）はTerraformで投入しない。tfstateに残さないため。
#   投入例:
#     echo -n "$VALUE" | gcloud secrets versions add sec-user-api-key \
#       --data-file=- --project=example-dev
# =============================================================================

locals {
  secrets = {
    "sec-user-api-key" = {
      description = "外部ユーザーAPIのAPIキー。ローテーション: 半年"
      accessors   = ["serviceAccount:${google_service_account.ingest.email}"]
    }
    "sec-dataform-github-token" = {
      description = "Dataformが example-dataform リポジトリを読むためのGitHubトークン（読み取り専用）。ローテーション: 半年"
      accessors   = []
    }
    "sec-notification-webhook-url" = {
      description = "Slack Incoming Webhook URL（cf-slack-notifier が使用）。ローテーション: 不要"
      accessors   = ["serviceAccount:${google_service_account.workflow.email}"]
    }
  }
}

resource "google_secret_manager_secret" "this" {
  for_each = local.secrets

  secret_id = each.key

  replication {
    user_managed {
      replicas {
        location = var.region
      }
    }
  }

  labels = { layer = "common" }

  lifecycle {
    # 値のバージョンはTerraform管理外で追加されるため、差分を無視する
    ignore_changes = [labels]
  }
}

# シークレット単位で権限を付与する（プロジェクトレベルの secretAccessor は禁止）
locals {
  secret_accessor_pairs = flatten([
    for secret_id, cfg in local.secrets : [
      for member in cfg.accessors : {
        key       = "${secret_id}|${member}"
        secret_id = secret_id
        member    = member
      }
    ]
  ])
}

resource "google_secret_manager_secret_iam_member" "accessor" {
  for_each = { for p in local.secret_accessor_pairs : p.key => p }

  secret_id = google_secret_manager_secret.this[each.value.secret_id].id
  role      = "roles/secretmanager.secretAccessor"
  member    = each.value.member
}
