-- =============================================================================
-- E-COMMERCE ANALYSIS WITH SQL
-- Platform: Google BigQuery | Dialect: GoogleSQL
-- Dataset: bigquery-public-data.google_analytics_sample
-- Scope: selected observation periods in 2017, specified in each query.
-- Run each SELECT independently by selecting its complete query block.
-- Product revenue is reported in the dataset's currency units, not millions.
-- These queries have not been executed on BigQuery during file preparation.
-- =============================================================================


-- =============================================================================
-- Q01 | January-March 2017 | Output: one row per month (YYYYMM).
-- Visits follow SUM(totals.visits), not COUNT(*) of exported rows.
SELECT
  FORMAT_DATE('%Y%m', PARSE_DATE('%Y%m%d', date)) AS month,
  SUM(COALESCE(totals.visits, 0)) AS visits,
  SUM(COALESCE(totals.pageviews, 0)) AS pageviews,
  SUM(COALESCE(totals.transactions, 0)) AS transactions
FROM `bigquery-public-data.google_analytics_sample.ga_sessions_2017*`
WHERE _TABLE_SUFFIX BETWEEN '0101' AND '0331'
GROUP BY month
ORDER BY month;


-- =============================================================================
-- Q02 | July 2017 | Output: one row per traffic source.
-- Keep the percentage numeric. SAFE_DIVIDE returns NULL for a zero denominator.
SELECT
  trafficSource.source AS source,
  SUM(COALESCE(totals.visits, 0)) AS visits,
  SUM(COALESCE(totals.bounces, 0)) AS bounces,
  ROUND(100 * SAFE_DIVIDE(
    SUM(COALESCE(totals.bounces, 0)),
    SUM(COALESCE(totals.visits, 0))
  ), 2) AS bounce_rate_pct
FROM `bigquery-public-data.google_analytics_sample.ga_sessions_201707*`
WHERE _TABLE_SUFFIX BETWEEN '01' AND '31'
GROUP BY source
ORDER BY visits DESC, source;


-- =============================================================================
-- Q03 | June 2017 | Output: time_type x period x source.
-- Month periods use YYYYMM; week periods use YYYYWW (%W, Monday-based).
-- Product revenue is expressed in the dataset's currency units.
-- Boundary weeks contain only dates included in the June observation window.
WITH month_data AS (
  SELECT
    'Month' AS time_type,
    FORMAT_DATE('%Y%m', PARSE_DATE('%Y%m%d', s.date)) AS period,
    s.trafficSource.source AS source,
    SUM(CAST(p.productRevenue AS NUMERIC)) / 1000000 AS revenue
  FROM `bigquery-public-data.google_analytics_sample.ga_sessions_201706*` AS s
  CROSS JOIN UNNEST(s.hits) AS h
  CROSS JOIN UNNEST(h.product) AS p
  WHERE _TABLE_SUFFIX BETWEEN '01' AND '30'
    AND p.productRevenue IS NOT NULL
  GROUP BY period, source
), week_data AS (
  SELECT
    'Week' AS time_type,
    FORMAT_DATE('%Y%W', PARSE_DATE('%Y%m%d', s.date)) AS period,
    s.trafficSource.source AS source,
    SUM(CAST(p.productRevenue AS NUMERIC)) / 1000000 AS revenue
  FROM `bigquery-public-data.google_analytics_sample.ga_sessions_201706*` AS s
  CROSS JOIN UNNEST(s.hits) AS h
  CROSS JOIN UNNEST(h.product) AS p
  WHERE _TABLE_SUFFIX BETWEEN '01' AND '30'
    AND p.productRevenue IS NOT NULL
  GROUP BY period, source
)
SELECT time_type, period, source, revenue
FROM month_data
UNION ALL
SELECT time_type, period, source, revenue
FROM week_data
ORDER BY time_type, period, revenue DESC, source;


-- =============================================================================
-- Q04 | Available 2017 dates; check actual date coverage before reporting.
-- Output: one row per source, limited to sources with >= 50 transactions.
-- Denominator: counted visits (totals.visits = 1).
-- Includes the original transactions-per-visit idea under an explicit name.
WITH source_metrics AS (
  SELECT
    trafficSource.source AS source,
    COUNT(*) AS visits,
    COUNTIF(COALESCE(totals.transactions, 0) > 0) AS purchasing_sessions,
    SUM(COALESCE(totals.transactions, 0)) AS transactions
  FROM `bigquery-public-data.google_analytics_sample.ga_sessions_2017*`
  WHERE _TABLE_SUFFIX BETWEEN '0101' AND '1231'
    AND COALESCE(totals.visits, 0) = 1
  GROUP BY source
  HAVING SUM(COALESCE(totals.transactions, 0)) >= 50
)
SELECT
  source, visits, purchasing_sessions, transactions,
  ROUND(100 * SAFE_DIVIDE(purchasing_sessions, visits), 2)
    AS purchase_session_rate_pct,
  ROUND(100 * SAFE_DIVIDE(transactions, visits), 2)
    AS transactions_per_100_sessions
FROM source_metrics
ORDER BY purchase_session_rate_pct DESC, visits DESC, source;


-- =============================================================================
-- Q05 | June-July 2017 | Output: month x purchaser type.
-- Segment each visitor ID once per month using ALL their observed session rows.
-- A purchaser has >= 1 transaction in that month. No product UNNEST is needed.
-- Rows missing a visitor ID are excluded; check their count before reporting.
WITH user_month AS (
  SELECT
    DATE_TRUNC(PARSE_DATE('%Y%m%d', date), MONTH) AS month,
    fullVisitorId AS visitor_id,
    SUM(COALESCE(totals.pageviews, 0)) AS pageviews,
    SUM(COALESCE(totals.transactions, 0)) AS transactions
  FROM `bigquery-public-data.google_analytics_sample.ga_sessions_2017*`
  WHERE _TABLE_SUFFIX BETWEEN '0601' AND '0731'
    AND fullVisitorId IS NOT NULL
  GROUP BY month, visitor_id
)
SELECT
  month,
  IF(transactions > 0, 'purchaser', 'non_purchaser') AS purchaser_type,
  COUNT(*) AS visitor_ids,
  SUM(pageviews) AS total_pageviews,
  ROUND(AVG(pageviews), 2) AS avg_pageviews_per_visitor
FROM user_month
GROUP BY month, purchaser_type
ORDER BY month, purchaser_type;


-- =============================================================================
-- Q06 | July 2017 | Output: one monthly row.
-- Aggregate session transactions by visitor first; do not UNNEST products.
WITH user_month AS (
  SELECT
    DATE_TRUNC(PARSE_DATE('%Y%m%d', date), MONTH) AS month,
    fullVisitorId AS visitor_id,
    SUM(COALESCE(totals.transactions, 0)) AS transactions
  FROM `bigquery-public-data.google_analytics_sample.ga_sessions_2017*`
  WHERE _TABLE_SUFFIX BETWEEN '0701' AND '0731'
    AND fullVisitorId IS NOT NULL
  GROUP BY month, visitor_id
)
SELECT
  month,
  COUNT(*) AS purchaser_visitor_ids,
  SUM(transactions) AS transactions,
  ROUND(SAFE_DIVIDE(SUM(transactions), COUNT(*)), 2)
    AS avg_transactions_per_purchaser
FROM user_month
WHERE transactions > 0
GROUP BY month
ORDER BY month;


-- =============================================================================
-- Q07 | Available 2017 dates; check actual date coverage before reporting.
-- Output: one row per device category. All amounts/percentages remain numeric.
WITH device_revenue AS (
  SELECT
    s.device.deviceCategory AS device,
    SUM(CAST(p.productRevenue AS NUMERIC)) / 1000000 AS product_revenue
  FROM `bigquery-public-data.google_analytics_sample.ga_sessions_2017*` AS s
  CROSS JOIN UNNEST(s.hits) AS h
  CROSS JOIN UNNEST(h.product) AS p
  WHERE _TABLE_SUFFIX BETWEEN '0101' AND '1231'
    AND p.productRevenue IS NOT NULL
  GROUP BY device
), with_total AS (
  SELECT device, product_revenue,
    SUM(product_revenue) OVER () AS total_product_revenue
  FROM device_revenue
)
SELECT
  device, product_revenue, total_product_revenue,
  ROUND(100 * SAFE_DIVIDE(product_revenue, total_product_revenue), 2)
    AS revenue_share_pct
FROM with_total
ORDER BY revenue_share_pct DESC, device;


-- =============================================================================
-- Q08 | July 2017 | Output: one row per other product name.
-- A distinct buyer list prevents multiplying rows when a buyer bought the target repeatedly.
-- Same visitor ID in the month does NOT imply the same order or purchase sequence.
WITH buyer_list AS (
  SELECT DISTINCT s.fullVisitorId
  FROM `bigquery-public-data.google_analytics_sample.ga_sessions_201707*` AS s
  CROSS JOIN UNNEST(s.hits) AS h
  CROSS JOIN UNNEST(h.product) AS p
  WHERE _TABLE_SUFFIX BETWEEN '01' AND '31'
    AND p.v2ProductName = "YouTube Men's Vintage Henley"
    AND COALESCE(s.totals.transactions, 0) > 0
    AND s.fullVisitorId IS NOT NULL
    AND p.productRevenue IS NOT NULL
)
SELECT
  p.v2ProductName AS other_purchased_products,
  SUM(COALESCE(p.productQuantity, 0)) AS quantity,
  COUNT(DISTINCT s.fullVisitorId) AS buyer_visitor_ids
FROM `bigquery-public-data.google_analytics_sample.ga_sessions_201707*` AS s
INNER JOIN buyer_list USING (fullVisitorId)
CROSS JOIN UNNEST(s.hits) AS h
CROSS JOIN UNNEST(h.product) AS p
WHERE _TABLE_SUFFIX BETWEEN '01' AND '31'
  AND p.v2ProductName != "YouTube Men's Vintage Henley"
  AND p.productRevenue IS NOT NULL
  AND COALESCE(s.totals.transactions, 0) > 0
GROUP BY other_purchased_products
ORDER BY quantity DESC, other_purchased_products;


-- =============================================================================
-- Q09 | January-March 2017 | Output: month x product name.
-- Counts product-action records, NOT distinct users or a sequential cohort funnel.
-- Multiple occurrences can be counted. Ratios may exceed 100%.
-- Exclude list impressions accompanying another product action.
WITH product_actions AS (
  SELECT
    DATE_TRUNC(PARSE_DATE('%Y%m%d', s.date), MONTH) AS month,
    p.v2ProductName AS product_name,
    h.eCommerceAction.action_type AS action_type,
    p.productRevenue AS product_revenue_raw
  FROM `bigquery-public-data.google_analytics_sample.ga_sessions_2017*` AS s
  CROSS JOIN UNNEST(s.hits) AS h
  CROSS JOIN UNNEST(h.product) AS p
  WHERE _TABLE_SUFFIX BETWEEN '0101' AND '0331'
    AND h.eCommerceAction.action_type IN ('2', '3', '6')
    AND COALESCE(p.isImpression, FALSE) = FALSE
    AND p.v2ProductName IS NOT NULL
), counts AS (
  SELECT
    month, product_name,
    COUNTIF(action_type = '2') AS product_detail_view_records,
    COUNTIF(action_type = '3') AS add_to_cart_records,
    COUNTIF(action_type = '6' AND product_revenue_raw IS NOT NULL)
      AS purchase_product_records
  FROM product_actions
  GROUP BY month, product_name
)
SELECT
  month, product_name,
  product_detail_view_records, add_to_cart_records, purchase_product_records,
  ROUND(100 * SAFE_DIVIDE(add_to_cart_records, product_detail_view_records), 2)
    AS add_to_cart_to_view_pct,
  ROUND(100 * SAFE_DIVIDE(purchase_product_records, product_detail_view_records), 2)
    AS purchase_to_view_pct
FROM counts
ORDER BY month, product_detail_view_records DESC, product_name;


-- =============================================================================
-- Q10 | May-July 2017 | Output: one row per Monday-start week.
-- The last week can be partial because the observation window ends on July 31.
WITH weekly AS (
  SELECT
    DATE_TRUNC(PARSE_DATE('%Y%m%d', s.date), WEEK(MONDAY)) AS week_start,
    SUM(CAST(p.productRevenue AS NUMERIC)) / 1000000 AS weekly_product_revenue
  FROM `bigquery-public-data.google_analytics_sample.ga_sessions_2017*` AS s
  CROSS JOIN UNNEST(s.hits) AS h
  CROSS JOIN UNNEST(h.product) AS p
  WHERE _TABLE_SUFFIX BETWEEN '0501' AND '0731'
    AND p.productRevenue IS NOT NULL
  GROUP BY week_start
)
SELECT
  week_start,
  weekly_product_revenue,
  SUM(weekly_product_revenue) OVER (
    ORDER BY week_start
    ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
  ) AS cumulative_product_revenue
FROM weekly
ORDER BY week_start;
