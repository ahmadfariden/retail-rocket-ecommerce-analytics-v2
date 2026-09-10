-- ============================================================
-- Milestone: 04_cleaning.sql
-- Missing Value Handling, Duplicate Removal, Type Correction, Bot/Anomaly Filtering
-- Depends on: 02_data_collection.sql (must be run first in this session)
-- ============================================================

-- ---------- 1. Identify bot visitors (n_events > 55, LOCKED threshold) ----------
-- REVISED: threshold dihitung dari total event, tapi filter HANYA diterapkan ke event 'view'.
-- Alasan: visitor dengan event count tinggi ternyata sering justru buyer aktif
-- (view banyak -> addtocart berkali-kali -> transaksi berkali-kali), bukan bot.
-- Exclude seluruh visitor terbukti membuang 32.5% transaction & 19.7% addtocart -- terlalu agresif
-- dan menghilangkan data paling berharga. Bot pattern yang sebenarnya = spam VIEW, bukan transaksi.
CREATE OR REPLACE VIEW bot_visitors AS
    SELECT visitorid, COUNT(*) AS n_events
    FROM raw_events
    GROUP BY visitorid
    HAVING COUNT(*) > 55;

SELECT COUNT(*) AS n_bot_visitors FROM bot_visitors;

-- ---------- 2. Build clean_events: dedup + exclude bot VIEW events only ----------
CREATE OR REPLACE VIEW clean_events AS
    SELECT DISTINCT *
    FROM raw_events
    WHERE NOT (
        event = 'view'
        AND visitorid IN (SELECT visitorid FROM bot_visitors)
    );

-- ---------- 3. Sanity check: before vs after ----------
SELECT
    (SELECT COUNT(*) FROM raw_events)   AS raw_row_count,
    (SELECT COUNT(*) FROM clean_events) AS clean_row_count,
    (SELECT COUNT(*) FROM raw_events) - (SELECT COUNT(*) FROM clean_events) AS rows_removed,
    ROUND(100.0 * ((SELECT COUNT(*) FROM raw_events) - (SELECT COUNT(*) FROM clean_events))
          / (SELECT COUNT(*) FROM raw_events), 2) AS pct_removed;

-- Breakdown event type before vs after (memastikan proporsi funnel tidak berubah drastis)
SELECT event, COUNT(*) AS n_rows_clean
FROM clean_events
GROUP BY event
ORDER BY n_rows_clean DESC;

-- ---------- 4. Data Quality Summary (untuk mart_data_quality_summary nanti) ----------
CREATE OR REPLACE VIEW data_quality_log AS
SELECT
    (SELECT COUNT(*) FROM raw_events) AS raw_events_count,
    (SELECT COUNT(*) FROM clean_events) AS clean_events_count,
    (SELECT COUNT(*) FROM raw_events) - (SELECT COUNT(*) FROM (SELECT DISTINCT * FROM raw_events)) AS duplicate_rows_removed,
    (SELECT COUNT(*) FROM bot_visitors) AS bot_visitors_identified,
    (SELECT COUNT(*) FROM raw_events) - (SELECT COUNT(*) FROM clean_events) AS total_rows_excluded_view_only;

SELECT * FROM data_quality_log;

-- TODO:
-- 1. clean_events adalah basis untuk semua milestone berikutnya (05 dst)
-- 2. data_quality_log dipakai sebagai sumber mart_data_quality_summary (milestone 10)
