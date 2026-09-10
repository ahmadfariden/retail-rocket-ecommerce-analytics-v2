# Assumptions, Definitions & Limitations

## Data Profiling Findings
- Total rows: 2,756,101 | Distinct rows: 2,755,641 → **460 duplicate rows** (to be dropped in milestone 04)
- Event distribution: view 2,664,312 | addtocart 69,332 | transaction 22,457
- `missing_transactionid` = 2,733,644 — expected, only populated when event = transaction (not a data quality issue)

## Bot / Anomaly Traffic Filtering (LOCKED)
- Distribution of events per visitor: min 1, median 1, avg 1.96, p95=5, p99=13, p999=55, max=7757
- **Threshold chosen: p999 (>55 events)** — not p99
- Reasoning: p99 (>13 events) would exclude 12,712 visitors / 465,283 events (~16.9% of total),
  too aggressive — visitors with 13-50 events are plausibly active shoppers, not bots.
  p999 targets only extreme outliers (clear gap: top visitor 7,757 events vs 2nd place 4,328).
- **Final result: 1,037 visitors excluded, 203,761 events removed (7.39% of total events)**
- Applied in milestone 04 (Data Cleaning): exclude visitors with n_events > 55

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
