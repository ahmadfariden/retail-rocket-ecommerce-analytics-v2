-- ============================================================
-- Milestone: 08_eda.sql
-- Funnel/Conversion Analysis, Trend, Segment, Descriptive Statistics
-- Depends on: 07_transformation.sql (fact_events, visitor_segment must exist)
-- ============================================================

-- ---------- 1. Trend Analysis: daily activity ----------
SELECT
    CAST(event_datetime AS DATE) AS event_date,
    COUNT(*) FILTER (WHERE event = 'view') AS n_view,
    COUNT(*) FILTER (WHERE event = 'addtocart') AS n_addtocart,
    COUNT(*) FILTER (WHERE event = 'transaction') AS n_transaction,
    COUNT(DISTINCT visitorid) AS unique_visitors
FROM fact_events
GROUP BY event_date
ORDER BY event_date
LIMIT 10;  -- preview 10 hari pertama saja


-- ---------- 2. Funnel & Conversion per Category (root_category) ----------
WITH events_with_root AS (
    SELECT
        fe.*,
        COALESCE(dc.root_category, -1) AS root_category
    FROM fact_events fe
    LEFT JOIN dim_category dc ON fe.categoryid = dc.categoryid
),
funnel_per_cat AS (
    SELECT
        root_category,
        COUNT(DISTINCT visitorid) FILTER (WHERE event = 'view') AS visitors_view,
        COUNT(DISTINCT visitorid) FILTER (WHERE event = 'addtocart') AS visitors_cart,
        COUNT(DISTINCT visitorid) FILTER (WHERE event = 'transaction') AS visitors_txn
    FROM events_with_root
    GROUP BY root_category
)
SELECT
    root_category,
    visitors_view,
    visitors_cart,
    visitors_txn,
    ROUND(100.0 * visitors_cart / NULLIF(visitors_view, 0), 2) AS pct_view_to_cart,
    ROUND(100.0 * visitors_txn / NULLIF(visitors_cart, 0), 2) AS pct_cart_to_txn
FROM funnel_per_cat
WHERE visitors_view >= 100  -- filter kategori dengan traffic terlalu kecil biar hasil stabil
ORDER BY visitors_view DESC
LIMIT 15;


-- ---------- 3. Top Items by View vs Transaction (threshold 10 views, LOCKED) ----------
-- REVISED: basis unique visitor, bukan raw event count -- supaya tidak bias oleh repeat purchase
-- (visitor yang sama beli item sama berkali-kali tanpa perlu view ulang tiap kali)
WITH item_stats AS (
    SELECT
        itemid,
        COUNT(DISTINCT visitorid) FILTER (WHERE event = 'view') AS visitors_view,
        COUNT(DISTINCT visitorid) FILTER (WHERE event = 'addtocart') AS visitors_addtocart,
        COUNT(DISTINCT visitorid) FILTER (WHERE event = 'transaction') AS visitors_transaction
    FROM fact_events
    GROUP BY itemid
)
SELECT *,
    ROUND(100.0 * visitors_transaction / NULLIF(visitors_view, 0), 2) AS view_to_txn_rate
FROM item_stats
WHERE visitors_view >= 10  -- LOCKED threshold
ORDER BY visitors_transaction DESC
LIMIT 15;


-- ---------- 4. Cart-abandonment candidates: sering addtocart, jarang transaction ----------
-- REVISED: basis unique visitor, diurutkan dari cart_to_txn_rate TERENDAH (kandidat abandonment sebenarnya)
WITH item_stats AS (
    SELECT
        itemid,
        COUNT(DISTINCT visitorid) FILTER (WHERE event = 'addtocart') AS visitors_addtocart,
        COUNT(DISTINCT visitorid) FILTER (WHERE event = 'transaction') AS visitors_transaction
    FROM fact_events
    GROUP BY itemid
)
SELECT *,
    ROUND(100.0 * visitors_transaction / NULLIF(visitors_addtocart, 0), 2) AS cart_to_txn_rate
FROM item_stats
WHERE visitors_addtocart >= 10  -- minimum threshold biar hasil stabil
ORDER BY cart_to_txn_rate ASC, visitors_addtocart DESC
LIMIT 15;


-- ---------- 5. Segment Analysis: perilaku per visitor_segment ----------
WITH session_per_visitor AS (
    SELECT visitorid, COUNT(DISTINCT session_id) AS n_sessions
    FROM fact_events
    GROUP BY visitorid
)
SELECT
    vs.segment,
    COUNT(*) AS n_visitors,
    ROUND(AVG(sp.n_sessions), 2) AS avg_sessions_per_visitor
FROM visitor_segment vs
JOIN session_per_visitor sp ON vs.visitorid = sp.visitorid
GROUP BY vs.segment
ORDER BY n_visitors DESC;


-- ---------- 6. Descriptive Statistics: price distribution (item dengan price valid) ----------
SELECT
    COUNT(*) AS n_items_with_price,
    ROUND(MIN(last_known_price), 2) AS min_price,
    ROUND(APPROX_QUANTILE(last_known_price, 0.25), 2) AS q1_price,
    ROUND(MEDIAN(last_known_price), 2) AS median_price,
    ROUND(APPROX_QUANTILE(last_known_price, 0.75), 2) AS q3_price,
    ROUND(APPROX_QUANTILE(last_known_price, 0.99), 2) AS p99_price,
    ROUND(APPROX_QUANTILE(last_known_price, 0.995), 2) AS p995_price,
    ROUND(MAX(last_known_price), 2) AS max_price
FROM dim_item
WHERE last_known_price IS NOT NULL;

-- Investigasi: top 20 harga tertinggi -- cek pola placeholder/error
SELECT itemid, last_known_price
FROM dim_item
WHERE last_known_price IS NOT NULL
ORDER BY last_known_price DESC
LIMIT 20;

-- Berapa banyak baris/item di atas p99 -- cek skala masalahnya
SELECT
    COUNT(*) FILTER (WHERE last_known_price > (SELECT APPROX_QUANTILE(last_known_price, 0.99) FROM dim_item WHERE last_known_price IS NOT NULL)) AS n_items_above_p99,
    COUNT(*) AS n_items_total
FROM dim_item
WHERE last_known_price IS NOT NULL;

-- ---------- 6a. LOCKED: Price winsorization -- raw disimpan, analytics layer di-cap P99 ----------
-- Pola outlier terkonfirmasi: nilai 1,199,999,999.88 berulang PERSIS 4x -> placeholder/error, bukan harga asli.
-- Approach: price_raw tetap utuh untuk audit, price_analytics di-cap di P99 untuk semua
-- agregasi/visualisasi (avg price, price band, price segment, dsb) supaya tidak terdistorsi outlier.
CREATE OR REPLACE TABLE dim_item AS
WITH price_p99 AS (
    SELECT APPROX_QUANTILE(last_known_price, 0.99) AS p99_value
    FROM dim_item WHERE last_known_price IS NOT NULL
)
SELECT
    d.itemid,
    d.last_known_categoryid,
    d.last_known_price AS price_raw,
    CASE
        WHEN d.last_known_price IS NULL THEN NULL
        WHEN d.last_known_price > (SELECT p99_value FROM price_p99) THEN (SELECT p99_value FROM price_p99)
        ELSE d.last_known_price
    END AS price_analytics
FROM dim_item d;

-- Sanity check: distribusi price_analytics setelah capping (max seharusnya = p99 value)
SELECT
    ROUND(MIN(price_analytics), 2) AS min_price,
    ROUND(MEDIAN(price_analytics), 2) AS median_price,
    ROUND(MAX(price_analytics), 2) AS max_price_capped
FROM dim_item
WHERE price_analytics IS NOT NULL;


-- ---------- 7. Activity by hour of day ----------
SELECT
    EXTRACT(HOUR FROM event_datetime) AS hour_of_day,
    COUNT(*) AS n_events
FROM fact_events
GROUP BY hour_of_day
ORDER BY hour_of_day;

-- TODO:
-- 1. Hasil EDA ini jadi basis mart di milestone 09-10 (KPI tables, dashboard-ready dataset)
-- 2. Perhatikan kategori/item mana yang insight-nya menarik untuk halaman Insight & Recommendation
