-- ============================================================
-- Milestone: 09_analytical_dataset.sql
-- KPI Tables, Reporting Tables, Dashboard-ready Dataset (consolidation layer)
-- Depends on: 06_star_schema.sql, 07_transformation.sql, 08_eda.sql
-- ============================================================

-- ---------- 1. Consolidated view: fact_events + root_category attached ----------
-- Basis reusable untuk semua mart kategori (funnel, performance)
CREATE OR REPLACE VIEW vw_events_with_root_category AS
SELECT
    fe.*,
    COALESCE(dc.root_category, -1) AS root_category
FROM fact_events fe
LEFT JOIN dim_category dc ON fe.categoryid = dc.categoryid;


-- ---------- 2. KPI Summary: angka headline untuk Halaman 1 Overview ----------
CREATE OR REPLACE TABLE kpi_summary AS
SELECT
    (SELECT COUNT(*) FROM fact_events) AS total_events,
    (SELECT COUNT(DISTINCT visitorid) FROM fact_events) AS unique_visitors,
    (SELECT COUNT(*) FROM fact_events WHERE event = 'transaction') AS total_transactions,
    (SELECT COUNT(DISTINCT visitorid) FROM fact_events WHERE event = 'view') AS visitors_view,
    (SELECT COUNT(DISTINCT visitorid) FROM fact_events WHERE event = 'transaction') AS visitors_txn,
    ROUND(100.0 *
        (SELECT COUNT(DISTINCT visitorid) FROM fact_events WHERE event = 'transaction')
        / (SELECT COUNT(DISTINCT visitorid) FROM fact_events WHERE event = 'view'), 2
    ) AS overall_conversion_rate_pct;

SELECT * FROM kpi_summary;

-- TODO: lanjut milestone 10 -- bangun 5 mart final dari view/table konsolidasi ini
