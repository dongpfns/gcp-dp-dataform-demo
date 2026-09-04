// =============================================================================
// 監査項目の共通関数（v2/11_naming_bigquery.md 4.2 / v2/21_transform.md 5.3）
//
// タイムスタンプとバッチIDはコンパイル変数（vars）として外部から注入する。
// .sqlx 内で CURRENT_TIMESTAMP() を直書きすると、ステートメントを跨いだときに
// 値がずれる（同一実行のはずのレコードで etl_updated_at が食い違う）。
// =============================================================================

/**
 * 新規・既存を問わず一律に発行してよい監査列を返す。
 * etl_loaded_at（初回挿入時のみ）は呼び出し側で incremental() 分岐により組み立てる。
 */
function auditColumns(sourceSystem) {
  return `
    TIMESTAMP('${dataform.projectConfig.vars.etl_ts}') AS etl_updated_at,
    '${sourceSystem}' AS etl_source_system,
    '${dataform.projectConfig.vars.batch_id}' AS etl_batch_id,
    FALSE AS is_deleted
  `;
}

/** 初回挿入時の etl_loaded_at。 */
function loadedAt() {
  return `TIMESTAMP('${dataform.projectConfig.vars.etl_ts}')`;
}

/**
 * 範囲洗替（P2）のウィンドウ開始日を返す。
 *
 * ★必ず月境界に丸める（v2/21_transform.md 4.3 / v2/90 落とし穴 #3）。
 *   日単位で切ると境界月の月初数日だけが範囲外に落ち、
 *   NOT MATCHED → INSERT となって重複行になる。境界が毎日動くため再現性が低い。
 * ★この式を「ソース側 WHERE」「ON句（updatePartitionFilter）」
 *   「削除検知の WHERE」の3か所すべてで使う。
 * ★月数は取込側（app/common/window.py の WINDOW_MONTHS）と必ず一致させる。
 */
function windowStart() {
  const months = dataform.projectConfig.vars.window_months;
  return `DATE_TRUNC(DATE_SUB(CURRENT_DATE('Asia/Tokyo'), INTERVAL ${months} MONTH), MONTH)`;
}

module.exports = { auditColumns, loadedAt, windowStart };
