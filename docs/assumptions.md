# Assumptions, Definitions & Limitations

## EDA Findings (Milestone 08)
- **"Uncategorized" is the single largest category bucket** by unique visitor count (412,222
  visitors — larger than any real category). Must be shown prominently in dashboard, not hidden.
- **Price outlier confirmed as data error — WINSORIZED (LOCKED):**
  - `max_price` = 1,199,999,999.88, appearing as an **exact duplicate 4 times** — confirms
    placeholder/error value, not a real price. Other extreme values follow suspicious round-number
    patterns (600,612,000 / 424,524,000, etc.)
  - 1,709 items (1%) fall above P99 (1,142,145.37)
  - **Decision: keep `price_raw` (untouched, for audit) + add `price_analytics` (capped at P99)**
    in `dim_item`. All aggregations/visualizations (avg price, price band, segment) must use
    `price_analytics`, never `price_raw`, to avoid distortion from placeholder values.
- **Item-level conversion rates (top items, cart-abandonment) — REVISED to unique-visitor basis.**
  Raw event-count basis initially showed implausible rates (one item at 50%+ view→transaction),
  likely inflated by repeat purchases (same visitor buying the same item multiple times without
  re-viewing). Unique-visitor basis gives more realistic, comparable rates across items.
- Segment behavior: avg sessions per visitor increases with funnel depth — Browser-only 1.21,
  Cart-adder 1.84, Buyer 2.79 sessions — buyers engage across more return visits, as expected.
- **Timezone note:** `event_datetime` displays in the local system timezone (+07 / WIB) when
  queried, not necessarily the dataset's original locale. Hour-of-day activity patterns are
  relative/comparable but the absolute hour label should not be over-interpreted as the
  visitor's true local time.

## Data Transformation Findings (Milestone 07)
- Session mapping: gap > 30 minutes between events (same visitor) = new session (standard
  e-commerce definition). Result: 1,731,690 sessions, avg 1.49 events/session
- **Visitor segmentation reconciliation: PASSED** — 1,407,184 total visitors = 1,368,319
  Browser-only + 27,146 Cart-adder + 11,719 Buyer (exact match, LOCKED rule confirmed correct)
- Time-to-convert: median 20.0 min, average 5,268.6 min (~3.7 days) — large gap is expected
  (long-tail: most buyers convert fast, a minority convert days/months later). **Use median**,
  not average, for dashboard reporting — average is skewed by outliers.
- **Known side effect of view-only bot filter:** only 10,698 / 11,719 Buyers (91.3%) have a
  valid time-to-convert calculation. The gap (1,021 visitors) likely occurs because some
  buyers were also bot-flagged (>55 total events) and had their earliest `view` events
  excluded by the milestone 04 filter, so their true "first view" timestamp is missing.
  Documented as a limitation — time-to-convert mart will only cover the 10,698 with complete data.

## Data Modeling Findings (Milestone 06 — Star Schema)
- Category tree flattening: 25 root categories, max depth 6, 0 categories failed to flatten (no cycles/orphans)
- `fact_events` built via **ASOF JOIN** (point-in-time match) for categoryid, available, price —
  attaches the property value valid *at the time each event occurred*, not just "ever known"
- fact_events row count: 2,572,482 — matches clean_events exactly (no row loss/duplication from joins)
- **Point-in-time category gap: 23.78%** of fact_events rows have no categoryid snapshot at event
  time (vs 9.53% using the looser "item ever has categoryid" definition in milestone 05) —
  expected: some items get their categoryid logged *after* they were first viewed
- Concentration check by event type (no red flag — fairly even, not concentrated in transactions):
  | event | % no category |
  |---|---|
  | view | 24.00% |
  | addtocart | 17.29% |
  | transaction | 18.76% |
- **Decision: keep categoryid = -1 ("Uncategorized") bucket**, same approach as milestone 05 lock
- Star schema tables: `fact_events`, `dim_item`, `dim_category`, `dim_visitor`, `dim_time` (139 days)

## Data Profiling Findings
- Total rows: 2,756,101 | Distinct rows: 2,755,641 → **460 duplicate rows** (to be dropped in milestone 04)
- Event distribution: view 2,664,312 | addtocart 69,332 | transaction 22,457
- `missing_transactionid` = 2,733,644 — expected, only populated when event = transaction (not a data quality issue)

## Bot / Anomaly Traffic Filtering (LOCKED — REVISED)
- Distribution of events per visitor: min 1, median 1, avg 1.96, p95=5, p99=13, p999=55, max=7757
- **Threshold: p999 (>55 total events per visitor)**
- **Filter scope: REVISED — applied only to `view` events, not the entire visitor.**
  Initial approach (excluding all events from visitors > 55 total events) removed 32.5% of
  transactions and 19.7% of addtocart events — too aggressive, since high-event-count visitors
  are often active buyers (many views → many cart adds → multiple purchases), not bots.
  Bot-like behavior is specifically excessive `view` spam, not transaction volume.
- Visitors flagged (>55 total events) keep their addtocart/transaction events; only their
  excess `view` events are excluded.
- **Final result (verified):**
  - view: 2,664,312 → 2,481,059 (−183,253, −6.9%) — bot views removed
  - addtocart: 69,332 → 68,966 (−366, −0.5%) — from duplicate removal only, not bot filter
  - **transaction: 22,457 → 22,457 (0% loss)** — fully preserved
  - Total clean rows: 2,572,482 (raw 2,756,101 minus 460 duplicates minus 183,619 bot views)

## Data Validation Findings (Milestone 05)
- Completeness: 0 missing values in `clean_events` (timestamp, visitorid, itemid)
- Orphan transactions (no prior view/addtocart from same visitor+item): 1,029 / 22,457 (4.58%)
  — accepted as normal data gap (e.g. tracking started mid-session), not investigated further
- Date range: 2015-05-03 to 2015-09-18 (138 days)
- **Funnel reconciliation (unique visitor basis):** view→cart 2.69%, cart→transaction 31.07%,
  overall 0.84% — consistent with typical e-commerce benchmarks, used as baseline KPI

## Category Coverage (LOCKED)
- 21.15% of items (48,671 / 230,133) in `clean_events` have no `categoryid` in item_properties
- Investigated distribution across event types to check for concentration risk:
  | | % of items | % of events | % of transactions |
  |---|---|---|---|
  | Uncategorized | 21.15% | 9.53% | **2.12%** |
- Pattern decreases from item → event → transaction level = classic long-tail (rarely-viewed
  items lack metadata, not high-value ones). No red flag — transaction concentration in
  uncategorized items is proportionally lower than their item share.
- **Decision: bucket missing categoryid as "Uncategorized"** in category-based marts/visuals.
  Keeps all traffic visible, stays transparent, totals still reconcile.
  Category-level analysis coverage ≈78.85% of items (or note "9.53% of events uncategorized").

## Property Code Mapping (CONFIRMED)
| Property Code | Representasi | Bukti |
|---|---|---|
| `categoryid` | Category ID item | Nama literal, langsung dipakai |
| `available` | Status ketersediaan (0/1) | Nama literal, langsung dipakai |
| `790` | Price | 1,790,516 baris — 100% value berprefix `n` (format: `n<angka>.000`); n_items = 417,053, sama dengan total item di categoryid/available |

Cara parsing value price:
```sql
CAST(REPLACE(value, 'n', '') AS DOUBLE) AS price
```

## Row Counts (Raw)
| Source | Rows |
|---|---|
| raw_events | 2,756,101 |
| raw_category_tree | 1,669 |
| raw_item_properties | 20,275,902 |

## KPI Definitions
| KPI | Formula |
|---|---|
| Conversion Rate (View→Cart) | unique visitor addtocart / unique visitor view |
| Conversion Rate (Cart→Transaction) | unique visitor transaction / unique visitor addtocart |
| Overall Conversion Rate | unique visitor transaction / unique visitor view |

## Locked Methodology Decisions
1. **Item Ranking Threshold** — minimum 10 views sebelum item masuk ranking (divalidasi ulang saat EDA)
2. **Visitor Segmentation** — mutually exclusive: `Buyer > Cart-adder > Browser-only`, total harus reconcile ke unique visitors
3. **Data Quality Mart** — `mart_data_quality_summary` hanya metrik kuantitatif; assumptions/definitions sebagai teks statis di Power BI

## Known Limitations
- Timestamp asli dalam epoch milidetik — dikonversi via `to_timestamp(timestamp/1000)`
- Tidak ada source-of-truth eksternal untuk validasi silang (validasi = internal consistency)
- Property value bisa berubah seiring waktu (time-varying) — perlu snapshot point-in-time
