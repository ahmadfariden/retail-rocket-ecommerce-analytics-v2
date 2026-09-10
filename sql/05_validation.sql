-- ============================================================
-- Milestone: 05_validation.sql
-- Data Completeness Check, Internal Consistency Validation, KPI Reconciliation
-- Depends on: 02_data_collection.sql, 04_cleaning.sql (must be run first in this session)
-- ============================================================

-- ---------- 1. Completeness check on clean_events ----------
SELECT
    COUNT(*) AS total_rows,
    COUNT(*) - COUNT(timestamp) AS missing_timestamp,
    COUNT(*) - COUNT(visitorid) AS missing_visitorid,
    COUNT(*) - COUNT(itemid) AS missing_itemid
FROM clean_events;

-- ---------- 2. Internal Consistency: transaction should have a prior view/addtocart ----------
-- Cek apakah ada transaksi tanpa event pendahulu (view/addtocart) dari visitor+item yang sama,
-- SEBELUM waktu transaksi terjadi. Idealnya jumlah "orphan transaction" ini kecil/nol.
WITH transactions AS (
    SELECT visitorid, itemid, timestamp AS txn_ts
    FROM clean_events
    WHERE event = 'transaction'
),
prior_events AS (
    SELECT t.visitorid, t.itemid, t.txn_ts,
           COUNT(e.timestamp) AS n_prior_events
    FROM transactions t
    LEFT JOIN clean_events e
        ON e.visitorid = t.visitorid
       AND e.itemid = t.itemid
       AND e.event IN ('view', 'addtocart')
       AND e.timestamp <= t.txn_ts
    GROUP BY t.visitorid, t.itemid, t.txn_ts
)
SELECT
    COUNT(*) AS total_transactions,
    COUNT(*) FILTER (WHERE n_prior_events = 0) AS orphan_transactions,
    ROUND(100.0 * COUNT(*) FILTER (WHERE n_prior_events = 0) / COUNT(*), 2) AS pct_orphan
FROM prior_events;

-- ---------- 3. Internal Consistency: timestamp ordering sanity ----------
-- Cek rentang waktu data (harus masuk akal, tidak ada tanggal future/aneh)
SELECT
    MIN(event_datetime) AS earliest_event,
    MAX(event_datetime) AS latest_event,
    DATEDIFF('day', MIN(event_datetime), MAX(event_datetime)) AS date_range_days
FROM clean_events;

-- ---------- 4. KPI Reconciliation: funnel numbers (unique visitor based) ----------
WITH funnel AS (
    SELECT
        COUNT(DISTINCT visitorid) FILTER (WHERE event = 'view') AS visitors_view,
        COUNT(DISTINCT visitorid) FILTER (WHERE event = 'addtocart') AS visitors_cart,
        COUNT(DISTINCT visitorid) FILTER (WHERE event = 'transaction') AS visitors_txn
    FROM clean_events
)
SELECT
    visitors_view,
    visitors_cart,
    visitors_txn,
    ROUND(100.0 * visitors_cart / visitors_view, 2) AS pct_view_to_cart,
    ROUND(100.0 * visitors_txn / visitors_cart, 2) AS pct_cart_to_txn,
    ROUND(100.0 * visitors_txn / visitors_view, 2) AS pct_overall_conversion
FROM funnel;

-- ---------- 5. Business Rule Validation: item without any category ----------
-- Cek berapa item yang tidak punya categoryid (property mapping) -- expected kecil
WITH items_with_category AS (
    SELECT DISTINCT itemid FROM raw_item_properties WHERE property = 'categoryid'
),
items_in_events AS (
    SELECT DISTINCT itemid FROM clean_events
)
SELECT
    COUNT(*) AS total_items_in_events,
    COUNT(*) FILTER (WHERE c.itemid IS NULL) AS items_without_category,
    ROUND(100.0 * COUNT(*) FILTER (WHERE c.itemid IS NULL) / COUNT(*), 2) AS pct_without_category
FROM items_in_events e
LEFT JOIN items_with_category c ON e.itemid = c.itemid;

-- ---------- 5a. Base count sanity: unique item di clean_events vs unique item dengan categoryid ----------
SELECT COUNT(DISTINCT itemid) AS unique_items_in_clean_events FROM clean_events;

SELECT COUNT(DISTINCT itemid) AS unique_items_with_categoryid
FROM raw_item_properties WHERE property = 'categoryid';

-- ---------- 5b. Distribusi event by categorized vs uncategorized (cek konsentrasi) ----------
WITH items_with_category AS (
    SELECT DISTINCT itemid FROM raw_item_properties WHERE property = 'categoryid'
),
tagged_events AS (
    SELECT
        e.*,
        CASE WHEN c.itemid IS NULL THEN 'Uncategorized' ELSE 'Categorized' END AS category_status
    FROM clean_events e
    LEFT JOIN items_with_category c ON e.itemid = c.itemid
)
SELECT
    category_status,
    COUNT(*) AS n_events,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_of_events,
    COUNT(*) FILTER (WHERE event = 'view') AS n_view,
    COUNT(*) FILTER (WHERE event = 'addtocart') AS n_addtocart,
    COUNT(*) FILTER (WHERE event = 'transaction') AS n_transaction,
    ROUND(100.0 * COUNT(*) FILTER (WHERE event = 'transaction')
          / SUM(COUNT(*) FILTER (WHERE event = 'transaction')) OVER (), 2) AS pct_of_all_transactions
FROM tagged_events
GROUP BY category_status;

-- TODO setelah validasi:
-- 1. Kalau orphan_transactions/items_without_category besar, investigasi lebih lanjut
-- 2. Catat hasil reconciliation funnel di docs/assumptions.md sebagai baseline KPI
-- 3. Lanjut milestone 06 (Data Modeling)
