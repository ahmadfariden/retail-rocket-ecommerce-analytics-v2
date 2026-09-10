# Assumptions, Definitions & Limitations

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
