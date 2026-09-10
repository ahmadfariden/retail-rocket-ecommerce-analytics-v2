-- ============================================================
-- Milestone: 03_profiling.sql
-- Structure Analysis, Missing Values, Duplicates, Bot/Anomaly Profiling
-- ============================================================

-- ---------- 1. Missing values check ----------
SELECT
    COUNT(*) AS total_rows,
    COUNT(*) - COUNT(timestamp) AS missing_timestamp,
    COUNT(*) - COUNT(visitorid) AS missing_visitorid,
    COUNT(*) - COUNT(event) AS missing_event,
    COUNT(*) - COUNT(itemid) AS missing_itemid,
    COUNT(*) FILTER (WHERE transactionid IS NULL) AS missing_transactionid  -- expected: NULL kecuali event = transaction
FROM raw_events;

-- ---------- 2. Duplicate check ----------
SELECT COUNT(*) AS total_rows, COUNT(DISTINCT (timestamp, visitorid, event, itemid, transactionid)) AS distinct_rows
FROM raw_events;

-- ---------- 3. Event type distribution ----------
SELECT event, COUNT(*) AS n_rows
FROM raw_events
GROUP BY event
ORDER BY n_rows DESC;

-- ---------- 4. Bot / Anomaly Traffic Profiling ----------
-- Distribusi jumlah event per visitor -- cari visitor dengan volume ekstrem
WITH visitor_event_count AS (
    SELECT visitorid, COUNT(*) AS n_events
    FROM raw_events
    GROUP BY visitorid
)
SELECT
    MIN(n_events) AS min_events,
    MAX(n_events) AS max_events,
    AVG(n_events) AS avg_events,
    MEDIAN(n_events) AS median_events,
    APPROX_QUANTILE(n_events, 0.95) AS p95_events,
    APPROX_QUANTILE(n_events, 0.99) AS p99_events,
    APPROX_QUANTILE(n_events, 0.999) AS p999_events
FROM visitor_event_count;

-- Top 20 visitor paling aktif -- cek apakah masuk akal atau bot
WITH visitor_event_count AS (
    SELECT visitorid, COUNT(*) AS n_events
    FROM raw_events
    GROUP BY visitorid
)
SELECT * FROM visitor_event_count
ORDER BY n_events DESC
LIMIT 20;

-- Berapa banyak visitor yang di atas p99 -- kandidat threshold bot filter
WITH visitor_event_count AS (
    SELECT visitorid, COUNT(*) AS n_events
    FROM raw_events
    GROUP BY visitorid
),
p99 AS (
    SELECT APPROX_QUANTILE(n_events, 0.99) AS threshold FROM visitor_event_count
)
SELECT
    (SELECT threshold FROM p99) AS p99_threshold,
    COUNT(*) AS n_visitors_above_p99,
    SUM(n_events) AS total_events_from_these_visitors
FROM visitor_event_count, p99
WHERE n_events > (SELECT threshold FROM p99);

-- ---------- 5. LOCKED: Bot threshold = p999 (>55 events) ----------
-- Alasan: p99 (>13 events) terlalu agresif, membuang ~16.9% total events dari
-- visitor yang sebenarnya wajar (active browser, bukan bot). p999 lebih konservatif,
-- hanya membuang outlier ekstrem (gap jelas dari visitor lain: 7757 vs 4328 di posisi 2).
WITH visitor_event_count AS (
    SELECT visitorid, COUNT(*) AS n_events
    FROM raw_events
    GROUP BY visitorid
)
SELECT
    COUNT(*) AS n_visitors_above_p999,
    SUM(n_events) AS total_events_from_these_visitors,
    ROUND(100.0 * SUM(n_events) / (SELECT COUNT(*) FROM raw_events), 2) AS pct_of_total_events
FROM visitor_event_count
WHERE n_events > 55;

-- TODO setelah profiling:
-- 1. [DONE] Threshold final bot filter = p999 (>55 events) -- LOCKED
-- 2. Catat di docs/assumptions.md -- DONE
-- 3. Lanjut milestone 04 (Data Cleaning): drop 460 duplicate rows + exclude visitor > 55 events
