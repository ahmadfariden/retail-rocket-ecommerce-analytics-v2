-- ============================================================
-- Milestone: 10_data_mart.sql
-- 5 Marts (satu per halaman dashboard) + Export Parquet
-- Depends on: 09_analytical_dataset.sql
-- ============================================================

-- ============================================================
-- MART 1: mart_overview_daily -> Halaman 1 (Overview)
-- ============================================================
CREATE OR REPLACE TABLE mart_overview_daily AS
SELECT
    CAST(event_datetime AS DATE) AS event_date,
    COUNT(*) FILTER (WHERE event = 'view') AS n_view,
    COUNT(*) FILTER (WHERE event = 'addtocart') AS n_addtocart,
    COUNT(*) FILTER (WHERE event = 'transaction') AS n_transaction,
    COUNT(DISTINCT visitorid) AS unique_visitors
FROM fact_events
GROUP BY event_date
ORDER BY event_date;

COPY mart_overview_daily TO 'data/processed/mart_overview_daily.parquet' (FORMAT PARQUET);


-- ============================================================
-- MART 2a: mart_funnel_by_category -> Halaman 2 (Funnel & Conversion)
-- ============================================================
CREATE OR REPLACE TABLE mart_funnel_by_category AS
SELECT
    root_category,
    COUNT(DISTINCT visitorid) FILTER (WHERE event = 'view') AS visitors_view,
    COUNT(DISTINCT visitorid) FILTER (WHERE event = 'addtocart') AS visitors_cart,
    COUNT(DISTINCT visitorid) FILTER (WHERE event = 'transaction') AS visitors_txn,
    ROUND(100.0 * COUNT(DISTINCT visitorid) FILTER (WHERE event = 'addtocart')
          / NULLIF(COUNT(DISTINCT visitorid) FILTER (WHERE event = 'view'), 0), 2) AS pct_view_to_cart,
    ROUND(100.0 * COUNT(DISTINCT visitorid) FILTER (WHERE event = 'transaction')
          / NULLIF(COUNT(DISTINCT visitorid) FILTER (WHERE event = 'addtocart'), 0), 2) AS pct_cart_to_txn
FROM vw_events_with_root_category
GROUP BY root_category
HAVING COUNT(DISTINCT visitorid) FILTER (WHERE event = 'view') >= 100  -- stabilitas statistik
ORDER BY visitors_view DESC;

COPY mart_funnel_by_category TO 'data/processed/mart_funnel_by_category.parquet' (FORMAT PARQUET);


-- ============================================================
-- MART 2b: mart_time_to_convert -> Halaman 2 (Funnel & Conversion)
-- ============================================================
CREATE OR REPLACE TABLE mart_time_to_convert AS
SELECT
    visitorid,
    first_view_at,
    first_txn_at,
    minutes_to_convert
FROM visitor_time_to_convert;

COPY mart_time_to_convert TO 'data/processed/mart_time_to_convert.parquet' (FORMAT PARQUET);


-- ============================================================
-- MART 3a: mart_item_performance -> Halaman 3 (Product & Category Performance)
-- ============================================================
CREATE OR REPLACE TABLE mart_item_performance AS
WITH item_stats AS (
    SELECT
        itemid,
        COALESCE(MAX(root_category), -1) AS root_category,
        COUNT(DISTINCT visitorid) FILTER (WHERE event = 'view') AS visitors_view,
        COUNT(DISTINCT visitorid) FILTER (WHERE event = 'addtocart') AS visitors_addtocart,
        COUNT(DISTINCT visitorid) FILTER (WHERE event = 'transaction') AS visitors_transaction
    FROM vw_events_with_root_category
    GROUP BY itemid
)
SELECT
    s.itemid,
    s.root_category,
    s.visitors_view,
    s.visitors_addtocart,
    s.visitors_transaction,
    ROUND(100.0 * s.visitors_transaction / NULLIF(s.visitors_view, 0), 2) AS view_to_txn_rate,
    ROUND(100.0 * s.visitors_transaction / NULLIF(s.visitors_addtocart, 0), 2) AS cart_to_txn_rate,
    di.price_analytics
FROM item_stats s
LEFT JOIN dim_item di ON s.itemid = di.itemid
WHERE s.visitors_view >= 10;  -- LOCKED threshold

COPY mart_item_performance TO 'data/processed/mart_item_performance.parquet' (FORMAT PARQUET);


-- ============================================================
-- MART 3b: mart_category_performance -> Halaman 3 (Product & Category Performance)
-- REVISED: tambah categoryid + depth, bukan cuma root_category, supaya drill-down
-- root -> sub-kategori bisa dipakai di Power BI (hierarchy: root_category -> categoryid)
-- ============================================================
CREATE OR REPLACE TABLE mart_category_performance AS
SELECT
    e.categoryid,
    COALESCE(dc.root_category, -1) AS root_category,
    COALESCE(dc.depth, 0) AS depth,
    COUNT(DISTINCT e.itemid) AS n_items,
    COUNT(DISTINCT e.visitorid) FILTER (WHERE e.event = 'view') AS visitors_view,
    COUNT(DISTINCT e.visitorid) FILTER (WHERE e.event = 'addtocart') AS visitors_cart,
    COUNT(DISTINCT e.visitorid) FILTER (WHERE e.event = 'transaction') AS visitors_txn
FROM fact_events e
LEFT JOIN dim_category dc ON e.categoryid = dc.categoryid
GROUP BY e.categoryid, root_category, depth
ORDER BY visitors_view DESC;

COPY mart_category_performance TO 'data/processed/mart_category_performance.parquet' (FORMAT PARQUET);


-- ============================================================
-- MART 4a: mart_visitor_segment -> Halaman 4 (Visitor Behavior & Segmentation)
-- ============================================================
CREATE OR REPLACE TABLE mart_visitor_segment AS
WITH session_per_visitor AS (
    SELECT visitorid, COUNT(DISTINCT session_id) AS n_sessions
    FROM fact_events
    GROUP BY visitorid
)
SELECT
    vs.segment,
    COUNT(*) AS n_visitors,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_of_total,
    ROUND(AVG(sp.n_sessions), 2) AS avg_sessions_per_visitor,
    COUNT(*) FILTER (WHERE sp.n_sessions > 1) AS n_repeat_visitors,
    ROUND(100.0 * COUNT(*) FILTER (WHERE sp.n_sessions > 1) / COUNT(*), 2) AS pct_repeat_visitors
FROM visitor_segment vs
JOIN session_per_visitor sp ON vs.visitorid = sp.visitorid
GROUP BY vs.segment;

COPY mart_visitor_segment TO 'data/processed/mart_visitor_segment.parquet' (FORMAT PARQUET);


-- ============================================================
-- MART 4b: mart_activity_by_hour -> Halaman 4 (Visitor Behavior & Segmentation)
-- ============================================================
CREATE OR REPLACE TABLE mart_activity_by_hour AS
SELECT
    EXTRACT(HOUR FROM event_datetime) AS hour_of_day,
    COUNT(*) AS n_events,
    COUNT(DISTINCT visitorid) AS unique_visitors
FROM fact_events
GROUP BY hour_of_day
ORDER BY hour_of_day;

COPY mart_activity_by_hour TO 'data/processed/mart_activity_by_hour.parquet' (FORMAT PARQUET);


-- ============================================================
-- MART 5: mart_data_quality_summary -> Halaman 5 (Data Quality & Methodology)
-- LOCKED: kuantitatif saja, teks assumptions/definitions taruh statis di Power BI
-- ============================================================
CREATE OR REPLACE TABLE mart_data_quality_summary AS
SELECT metric, value FROM (
    VALUES
        ('raw_events_count', 2756101),
        ('clean_events_count', 2572482),
        ('duplicate_rows_removed', 460),
        ('bot_visitors_identified', 1037),
        ('bot_view_events_excluded', 183619),
        ('items_without_category_pct_pointintime', 23.78),
        ('orphan_transactions_pct', 4.58),
        ('price_outliers_capped_count', 1709),
        ('price_p99_cap_value', 1142145.37)
) AS t(metric, value);

COPY mart_data_quality_summary TO 'data/processed/mart_data_quality_summary.parquet' (FORMAT PARQUET);


-- ---------- Final sanity check: semua mart ada isinya ----------
SELECT 'mart_overview_daily' AS mart_name, COUNT(*) AS n_rows FROM mart_overview_daily
UNION ALL SELECT 'mart_funnel_by_category', COUNT(*) FROM mart_funnel_by_category
UNION ALL SELECT 'mart_time_to_convert', COUNT(*) FROM mart_time_to_convert
UNION ALL SELECT 'mart_item_performance', COUNT(*) FROM mart_item_performance
UNION ALL SELECT 'mart_category_performance', COUNT(*) FROM mart_category_performance
UNION ALL SELECT 'mart_visitor_segment', COUNT(*) FROM mart_visitor_segment
UNION ALL SELECT 'mart_activity_by_hour', COUNT(*) FROM mart_activity_by_hour
UNION ALL SELECT 'mart_data_quality_summary', COUNT(*) FROM mart_data_quality_summary;

-- TODO: 9 file parquet siap di data/processed/, tinggal di-load ke Power BI

-- ============================================================
-- MART 1b: kpi_summary -> Halaman 1 (Overview) -- KPI card angka headline
-- (Ditambahkan belakangan: dibutuhkan supaya Total Unique Visitors & Overall
-- Conversion Rate akurat, tidak double-count seperti kalau SUM harian)
-- ============================================================
COPY kpi_summary TO 'data/processed/kpi_summary.parquet' (FORMAT PARQUET);
