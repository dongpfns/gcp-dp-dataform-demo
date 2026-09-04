-- =============================================================================
-- GOLD層の異常値検知（v2/60_nonfunctional.md 6節）
-- 収支が想定外のマイナスになっていないかを確認する。
-- 分類: 業務ルール / 失敗時: 警告
-- =============================================================================
SELECT
  IF(COUNT(*) = 0, 'PASS', 'WARN') AS status,
  CAST(COUNT(*) AS NUMERIC) AS actual_value,
  CAST(0 AS NUMERIC) AS threshold_value
FROM `@project_id.gold_bi_tool.v_1d_daily_pnl`
WHERE business_date >= DATE_SUB(CURRENT_DATE('Asia/Tokyo'), INTERVAL 7 DAY)
  AND kpi_gross_profit_jpy < -1000000;
