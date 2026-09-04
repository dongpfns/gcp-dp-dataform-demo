-- =============================================================================
-- 取込件数の急変検知（v2/20_ingestion.md 5節 / v2/60_nonfunctional.md 6節）
-- 前回実行比で ±50% 以上変動していたら FAIL とする。
-- 分類: 完全性 / 失敗時: 後続を停止
-- =============================================================================
DECLARE threshold_rate NUMERIC DEFAULT 0.5;

WITH runs AS (
  SELECT
    _bronze_ingested_at,
    COUNT(*) AS record_count
  FROM `@project_id.bronze_user_api.user`
  GROUP BY _bronze_ingested_at
  ORDER BY _bronze_ingested_at DESC
  LIMIT 2
),
compared AS (
  SELECT
    MAX(IF(rn = 1, record_count, NULL)) AS current_count,
    MAX(IF(rn = 2, record_count, NULL)) AS previous_count
  FROM (SELECT *, ROW_NUMBER() OVER (ORDER BY _bronze_ingested_at DESC) AS rn FROM runs)
)
SELECT
  CASE
    WHEN previous_count IS NULL THEN 'PASS'  -- 初回実行
    WHEN ABS(current_count - previous_count) / NULLIF(previous_count, 0) > threshold_rate THEN 'FAIL'
    ELSE 'PASS'
  END AS status,
  CAST(current_count AS NUMERIC) AS actual_value,
  CAST(previous_count AS NUMERIC) AS threshold_value
FROM compared;
