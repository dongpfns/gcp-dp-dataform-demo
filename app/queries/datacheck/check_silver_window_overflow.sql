-- =============================================================================
-- ウィンドウ外更新の検知（v2/21_transform.md 4.3 / v2/90_review_checklist.md #7）
--
-- 範囲洗替（P2）では、MERGEウィンドウの外に更新が届いても取り込まれない。
-- 重複を作るより、反映漏れを検知して手動でフルリフレッシュするほうが安全なため、
-- このチェックを常設する。
--
-- ウィンドウ幅（14か月）は取込側（WINDOW_MONTHS）と必ず同じ値にすること。
-- 分類: 業務ルール / 失敗時: 警告（件数が多ければ手動でフルリフレッシュ）
-- =============================================================================
DECLARE window_months INT64 DEFAULT 14;
DECLARE window_start DATE DEFAULT DATE_TRUNC(
  DATE_SUB(CURRENT_DATE('Asia/Tokyo'), INTERVAL window_months MONTH), MONTH
);

SELECT
  IF(COUNT(*) = 0, 'PASS', 'WARN') AS status,
  CAST(COUNT(*) AS NUMERIC) AS actual_value,
  CAST(0 AS NUMERIC) AS threshold_value
FROM `@project_id.bronze_file_csv.sales_transaction`
WHERE business_date < window_start;
