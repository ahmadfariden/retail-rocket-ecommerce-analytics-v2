# Assumptions, Definitions & Limitations

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

## Bot / Anomaly Traffic Filtering
- Metode: threshold jumlah event per `visitorid`
- Threshold: TBD — isi setelah Data Profiling (milestone 03)

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
