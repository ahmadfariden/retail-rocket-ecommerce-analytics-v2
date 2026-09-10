-- ============================================================
-- Milestone: 07_transformation.sql
-- Feature Creation (session mapping), Aggregation, Business Metrics, Derived Columns
-- Depends on: 06_star_schema.sql (fact_events must exist in this session)
-- ============================================================

-- ---------- 1. Session Mapping ----------
-- Definisi standar e-commerce: sesi baru dimulai kalau gap antar event > 30 menit
-- dari visitor yang sama. Pakai window function LAG untuk deteksi gap.
CREATE OR REPLACE TABLE fact_events AS
WITH with_gap AS (
    SELECT
        *,
        LAG(event_datetime) OVER (PARTITION BY visitorid ORDER BY timestamp) AS prev_event_datetime
    FROM fact_events
),
with_session_flag AS (
    SELECT
        *,
        CASE
            WHEN prev_event_datetime IS NULL THEN 1
            WHEN DATE_DIFF('minute', prev_event_datetime, event_datetime) > 30 THEN 1
            ELSE 0
        END AS is_new_session
    FROM with_gap
)
SELECT
    *,
    SUM(is_new_session) OVER (
        PARTITION BY visitorid ORDER BY timestamp
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS session_seq,
    visitorid || '-' || CAST(SUM(is_new_session) OVER (
        PARTITION BY visitorid ORDER BY timestamp
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS VARCHAR) AS session_id
FROM with_session_flag;

-- Sanity check: berapa total sesi, rata-rata event per sesi
SELECT
    COUNT(DISTINCT session_id) AS total_sessions,
    COUNT(*) AS total_events,
    ROUND(COUNT(*) * 1.0 / COUNT(DISTINCT session_id), 2) AS avg_events_per_session
FROM fact_events;


-- ---------- 2. Derived column: time_to_convert per visitor (first view -> first transaction) ----------
CREATE OR REPLACE TABLE visitor_time_to_convert AS
WITH first_view AS (
    SELECT visitorid, MIN(event_datetime) AS first_view_at
    FROM fact_events
    WHERE event = 'view'
    GROUP BY visitorid
),
first_txn AS (
    SELECT visitorid, MIN(event_datetime) AS first_txn_at
    FROM fact_events
    WHERE event = 'transaction'
    GROUP BY visitorid
)
SELECT
    v.visitorid,
    v.first_view_at,
    t.first_txn_at,
    DATE_DIFF('minute', v.first_view_at, t.first_txn_at) AS minutes_to_convert
FROM first_view v
JOIN first_txn t ON v.visitorid = t.visitorid
WHERE t.first_txn_at >= v.first_view_at;  -- guard: transaksi harus setelah view pertama

SELECT
    COUNT(*) AS converting_visitors,
    ROUND(AVG(minutes_to_convert), 1) AS avg_minutes_to_convert,
    ROUND(MEDIAN(minutes_to_convert), 1) AS median_minutes_to_convert
FROM visitor_time_to_convert;


-- ---------- 3. Business Metric: visitor segment (Buyer > Cart-adder > Browser-only) ----------
-- LOCKED decision: mutually exclusive, highest funnel stage achieved
CREATE OR REPLACE TABLE visitor_segment AS
SELECT
    visitorid,
    CASE
        WHEN MAX(CASE WHEN event = 'transaction' THEN 1 ELSE 0 END) = 1 THEN 'Buyer'
        WHEN MAX(CASE WHEN event = 'addtocart' THEN 1 ELSE 0 END) = 1 THEN 'Cart-adder'
        ELSE 'Browser-only'
    END AS segment
FROM fact_events
GROUP BY visitorid;

-- Reconciliation check: total per segment harus = total unique visitor
SELECT segment, COUNT(*) AS n_visitors
FROM visitor_segment
GROUP BY segment
ORDER BY n_visitors DESC;

SELECT COUNT(*) AS total_visitors FROM visitor_segment;
SELECT COUNT(DISTINCT visitorid) AS total_unique_visitors_in_fact FROM fact_events;

-- TODO:
-- 1. session_id di fact_events siap dipakai untuk EDA (milestone 08)
-- 2. visitor_time_to_convert & visitor_segment jadi basis mart_time_to_convert & mart_visitor_segment (milestone 10)
