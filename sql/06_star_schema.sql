-- ============================================================
-- Milestone: 06_star_schema.sql
-- EAV-to-Wide, Point-in-Time Snapshot, Category Tree Flattening, Star Schema
-- Depends on: 02_data_collection.sql, 04_cleaning.sql (run first in this session)
-- ============================================================

-- ---------- 1. Category Tree Flattening (recursive CTE) ----------
-- Root = categoryid yang parentid-nya NULL. Hasilnya: tiap categoryid tahu root_category & depth-nya.
CREATE OR REPLACE VIEW category_flat AS
WITH RECURSIVE category_path AS (
    SELECT categoryid, parentid, categoryid AS root_category, 1 AS depth
    FROM raw_category_tree
    WHERE parentid IS NULL

    UNION ALL

    SELECT ct.categoryid, ct.parentid, cp.root_category, cp.depth + 1
    FROM raw_category_tree ct
    JOIN category_path cp ON ct.parentid = cp.categoryid
)
SELECT * FROM category_path;

-- Sanity check: berapa root category, berapa depth maksimum
SELECT COUNT(DISTINCT root_category) AS n_root_categories, MAX(depth) AS max_depth
FROM category_flat;

-- Cek ada categoryid yang tidak ter-cover flattening (misal karena cycle atau parentid invalid)
SELECT COUNT(*) AS categories_not_flattened
FROM raw_category_tree ct
WHERE NOT EXISTS (SELECT 1 FROM category_flat cf WHERE cf.categoryid = ct.categoryid);


-- ---------- 2. Point-in-time property views (per property, siap di-ASOF JOIN) ----------
CREATE OR REPLACE VIEW item_categoryid_ts AS
    SELECT itemid, timestamp AS prop_ts, TRY_CAST(value AS BIGINT) AS categoryid
    FROM raw_item_properties
    WHERE property = 'categoryid'
    ORDER BY itemid, prop_ts;

CREATE OR REPLACE VIEW item_available_ts AS
    SELECT itemid, timestamp AS prop_ts, TRY_CAST(value AS BIGINT) AS available
    FROM raw_item_properties
    WHERE property = 'available'
    ORDER BY itemid, prop_ts;

CREATE OR REPLACE VIEW item_price_ts AS
    SELECT itemid, timestamp AS prop_ts, TRY_CAST(REPLACE(value, 'n', '') AS DOUBLE) AS price
    FROM raw_item_properties
    WHERE property = '790'
    ORDER BY itemid, prop_ts;


-- ---------- 3. fact_events: enrich tiap event dengan snapshot categoryid/available/price ----------
-- yang VALID pada saat event terjadi (ASOF JOIN = ambil baris property terakhir <= waktu event)
CREATE OR REPLACE TABLE fact_events AS
SELECT
    e.timestamp,
    e.event_datetime,
    e.visitorid,
    e.event,
    e.itemid,
    e.transactionid,
    COALESCE(cat.categoryid, -1) AS categoryid,          -- -1 = no category snapshot found at this point in time
    avail.available,
    price.price
FROM clean_events e
ASOF LEFT JOIN item_categoryid_ts cat
    ON e.itemid = cat.itemid AND e.timestamp >= cat.prop_ts
ASOF LEFT JOIN item_available_ts avail
    ON e.itemid = avail.itemid AND e.timestamp >= avail.prop_ts
ASOF LEFT JOIN item_price_ts price
    ON e.itemid = price.itemid AND e.timestamp >= price.prop_ts;

SELECT COUNT(*) AS fact_events_rows FROM fact_events;

-- Cek berapa % baris fact_events yang categoryid = -1 (tidak ada snapshot ditemukan sama sekali)
SELECT
    COUNT(*) FILTER (WHERE categoryid = -1) AS rows_no_category_snapshot,
    ROUND(100.0 * COUNT(*) FILTER (WHERE categoryid = -1) / COUNT(*), 2) AS pct_no_category_snapshot
FROM fact_events;

-- Cek konsentrasi per event type -- apakah "no category snapshot" merata atau numpuk di transaction
SELECT
    event,
    COUNT(*) AS n_events,
    COUNT(*) FILTER (WHERE categoryid = -1) AS n_no_category,
    ROUND(100.0 * COUNT(*) FILTER (WHERE categoryid = -1) / COUNT(*), 2) AS pct_no_category
FROM fact_events
GROUP BY event
ORDER BY n_events DESC;


-- ---------- 4. dim_category: gabungkan category_flat + root category info, plus "Uncategorized" ----------
CREATE OR REPLACE TABLE dim_category AS
SELECT categoryid, root_category, depth
FROM category_flat
UNION ALL
SELECT -1 AS categoryid, -1 AS root_category, 0 AS depth;  -- placeholder utk item tanpa category snapshot


-- ---------- 5. dim_item: daftar item unik + info kategori & harga terakhir yang diketahui ----------
CREATE OR REPLACE TABLE dim_item AS
SELECT
    itemid,
    MAX(categoryid) AS last_known_categoryid,   -- ambil salah satu snapshot terakhir per item (agregasi sederhana)
    MAX(price) AS last_known_price
FROM fact_events
GROUP BY itemid;


-- ---------- 6. dim_visitor: daftar visitor unik + first/last activity ----------
CREATE OR REPLACE TABLE dim_visitor AS
SELECT
    visitorid,
    MIN(event_datetime) AS first_activity,
    MAX(event_datetime) AS last_activity,
    COUNT(*) AS total_events
FROM fact_events
GROUP BY visitorid;


-- ---------- 7. dim_time: calendar dimension dari rentang tanggal data ----------
CREATE OR REPLACE TABLE dim_time AS
SELECT
    CAST(d AS DATE) AS date,
    EXTRACT(YEAR FROM d) AS year,
    EXTRACT(MONTH FROM d) AS month,
    EXTRACT(DAY FROM d) AS day,
    EXTRACT(DOW FROM d) AS day_of_week,
    STRFTIME(d, '%A') AS day_name
FROM (
    SELECT UNNEST(GENERATE_SERIES(
        (SELECT MIN(CAST(event_datetime AS DATE)) FROM fact_events),
        (SELECT MAX(CAST(event_datetime AS DATE)) FROM fact_events),
        INTERVAL 1 DAY
    )) AS d
);

SELECT COUNT(*) AS dim_time_rows FROM dim_time;

-- TODO:
-- 1. fact_events + dim_item + dim_category + dim_visitor + dim_time = star schema final
-- 2. Lanjut milestone 07 (Data Transformation) berbasis fact_events ini
