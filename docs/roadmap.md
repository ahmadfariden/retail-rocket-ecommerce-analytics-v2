# Roadmap & Checklist Portofolio Data Analysis
## Retail Rocket Recommender System Dataset — DuckDB + Power BI (Revisi v2)

> Revisi dari roadmap awal, disesuaikan dengan karakteristik spesifik dataset Retail Rocket:
> tidak ada revenue eksplisit, struktur item_properties berbentuk EAV, ada kemungkinan bot traffic,
> dan category_tree berbentuk parent-child hierarchy. Versi ini juga menyematkan **git commit &
> push di setiap major milestone**, bukan cuma di tahap akhir, supaya history repo mencerminkan
> proses kerja yang nyata.

> 🔄 **Alur kerja per milestone:** CSV mentah di `data/raw/` adalah **source of truth** dan
> tidak pernah diubah. DuckDB membaca langsung dari CSV di tiap milestone (bukan melanjutkan
> dari state DuckDB milestone sebelumnya), lalu hasil tahap tersebut dibentuk jadi **mart kecil**
> dan di-**export ke parquet**. File parquet mart itu yang di-push ke GitHub — bukan file
> `.duckdb` mentah, dan bukan CSV besar. Ini bikin tiap milestone reproducible dari raw data
> dan history repo tetap ringan.

> 📌 **Konvensi commit:** setiap tahap besar diakhiri dengan checkpoint git
> (`git add <sql/notebook + parquet mart> && git commit -m "..." && git push`). Gunakan
> `git add` spesifik (bukan `git add .`) supaya `.duckdb` tidak ikut ter-stage. Gunakan
> conventional commits (`feat:`, `fix:`, `docs:`, `refactor:`). Commit granular boleh
> dilakukan di dalam tahap (per sub-pekerjaan yang selesai secara logis), tapi push
> minimal terjadi di setiap checkpoint milestone di bawah.

---

## 0. Project Setup *(baru)*
- Init repo & `.gitignore` (exclude data mentah besar, `.duckdb` file, `__pycache__`, dsb.)
- README awal (deskripsi project, dataset, tools)
- Struktur folder (`data/raw`, `data/processed`, `notebooks`, `sql`, `docs`)
- **Bangun skeleton project SEBELUM sentuh data** *(baru, kunci dari metode ini)* —
  buat semua file `sql/02_*.sql` sampai `sql/10_*.sql` sebagai **stub kosong** (isinya cuma
  komentar/TODO) sejak awal, sesuai urutan roadmap. Tujuannya: struktur akhir project sudah
  kelihatan dari hari pertama, tiap milestone tinggal "isi filenya", bukan mikirin dari nol
  mau bikin file apa. Termasuk siapkan `run_milestone.ps1` (template otomasi run→commit→push)
  di tahap ini juga, meski isinya masih generic.
- ✅ **Checkpoint:** `git commit -m "chore: initial project structure"` → push

> 🔁 **Pola kerja iteratif per milestone (LOCKED METHOD)** — ini yang membuat pengerjaan
> project besar terasa tidak overwhelming, dipakai konsisten dari tahap 2 sampai 10:
> 1. **Tulis query awal** di file `sql/0N_*.sql` sesuai tujuan milestone
> 2. **Jalankan & lihat hasil mentah** — jangan asumsikan hasilnya pasti benar
> 3. **Investigasi kalau ada angka yang janggal** (mis. distribusi ekstrem, jumlah yang nggak
>    reconcile, pola berulang yang mencurigakan) — jangan buru-buru lanjut kalau ada sinyal aneh
> 4. **Putuskan secara eksplisit** bagaimana menangani temuan itu (mis. threshold mana yang
>    dipakai, exclude vs cap vs bucket "Uncategorized") — kalau ada trade-off, putuskan dulu
>    sebelum lanjut, jangan dibiarkan ambigu
> 5. **Revisi query** sesuai keputusan, jalankan ulang untuk verifikasi angka barunya masuk akal
> 6. **Catat keputusan + angka final** di `docs/assumptions.md` (bukan cuma di kepala/chat) —
>    supaya keputusan itu bisa dipertanggungjawabkan & dijelaskan ke orang lain nanti
> 7. **Commit + push** sebagai checkpoint milestone selesai
>
> Pola ini berlaku berulang: cleaning (bot filter awalnya buang transaksi, direvisi jadi
> view-only), validation (item tanpa kategori dicek konsentrasinya dulu sebelum diputuskan),
> EDA (price outlier diinvestigasi polanya sebelum di-winsorize). Intinya: **setiap keputusan
> metodologi harus melalui investigasi kecil dulu, bukan asumsi langsung** — dan semua keputusan
> itu didokumentasikan real-time, bukan di akhir project.

## 1. Business Understanding
- Objective
- **Data Feasibility Check** *(baru)* — inventarisasi field yang benar-benar tersedia
  (events, item_properties, category_tree) sebelum menentukan KPI, supaya KPI tidak
  bergantung pada data yang ternyata tidak ada (mis. revenue eksplisit)
- KPI (disesuaikan dengan feasibility check: funnel conversion, item popularity,
  visitor behavior — bukan revenue absolut kecuali diasumsikan/diestimasi)
- Business Questions
- Success Criteria
- **Develop Mart Kecil + Export Parquet** *(baru)* — sebelum push, buat tabel mart ringkas dari hasil tahap ini & export ke parquet kecil (`data/processed/milestone_XX.parquet`); file CSV mentah tetap jadi source of truth, tidak diubah/tidak ikut diproses ulang
- ✅ **Checkpoint:** `git commit -m "chore: define business objectives, KPI, and feasibility check"` → push

## 2. Data Collection
- Source Identification
- Data Extraction
- Data Inventory
- **Property Code Mapping** *(baru)* — identifikasi manual property code di
  item_properties yang merepresentasikan `categoryid`, `available`, dan `price`
  (jika ada), karena semua property disimpan sebagai kode numerik generik
- **Develop Mart Kecil + Export Parquet** *(baru)* — sebelum push, buat tabel mart ringkas dari hasil tahap ini & export ke parquet kecil (`data/processed/milestone_XX.parquet`); file CSV mentah tetap jadi source of truth, tidak diubah/tidak ikut diproses ulang
- ✅ **Checkpoint:** `git commit -m "feat: add data collection scripts and property code mapping"` → push

## 3. Data Profiling
- Structure Analysis
- Missing Values
- Duplicates
- Data Quality Assessment
- **Anomaly/Bot Traffic Profiling** *(baru)* — cek distribusi jumlah event per
  visitorid; visitor dengan volume ekstrem berpotensi bot dan mendistorsi funnel
- **Develop Mart Kecil + Export Parquet** *(baru)* — sebelum push, buat tabel mart ringkas dari hasil tahap ini & export ke parquet kecil (`data/processed/milestone_XX.parquet`); file CSV mentah tetap jadi source of truth, tidak diubah/tidak ikut diproses ulang
- ✅ **Checkpoint:** `git commit -m "feat: add data profiling notebook incl. bot traffic profiling"` → push

## 4. Data Cleaning
- Missing Value Handling
- Duplicate Removal
- Data Type Correction
- Outlier Review
- **Bot/Anomaly Filtering** *(baru)* — tetapkan threshold & exclude/flag
  visitor dengan pola non-human sebelum masuk ke tahap agregasi
- **Develop Mart Kecil + Export Parquet** *(baru)* — sebelum push, buat tabel mart ringkas dari hasil tahap ini & export ke parquet kecil (`data/processed/milestone_XX.parquet`); file CSV mentah tetap jadi source of truth, tidak diubah/tidak ikut diproses ulang
- ✅ **Checkpoint:** `git commit -m "fix: clean data and filter bot/anomaly traffic"` → push

## 5. Data Validation
- Data Completeness Check
- **Internal Consistency Validation** *(revisi nama)* — karena tidak ada
  source-of-truth eksternal (ERP/finance), validasi berbasis aturan internal:
  urutan timestamp logis, transaction idealnya didahului view/addtocart
- KPI Reconciliation (terhadap definisi KPI internal, bukan sumber eksternal)
- ~~Source-to-Target Validation~~ *(dihapus/digabung ke atas — tidak relevan
  tanpa sumber eksternal)*
- **Develop Mart Kecil + Export Parquet** *(baru)* — sebelum push, buat tabel mart ringkas dari hasil tahap ini & export ke parquet kecil (`data/processed/milestone_XX.parquet`); file CSV mentah tetap jadi source of truth, tidak diubah/tidak ikut diproses ulang
- ✅ **Checkpoint:** `git commit -m "feat: add data validation and internal consistency checks"` → push

## 6. Data Modeling
- **EAV-to-Wide Transformation** *(baru)* — pivot item_properties dari
  long-format (itemid, property, value, timestamp) ke wide-format per item
- **Point-in-Time Snapshot Handling** *(baru)* — property value item berubah
  seiring waktu; ambil snapshot value yang valid pada saat event terjadi,
  bukan value terakhir saja
- **Category Tree Flattening** *(baru)* — traverse parent-child hierarchy
  (recursive CTE di DuckDB) supaya kategori bisa dianalisis per level
- Star Schema
- Fact Table (fact_events)
- Dimension Table (dim_item, dim_category, dim_visitor, dim_time)
- Relationship Design
- **Develop Mart Kecil + Export Parquet** *(baru)* — sebelum push, buat tabel mart ringkas dari hasil tahap ini & export ke parquet kecil (`data/processed/milestone_XX.parquet`); file CSV mentah tetap jadi source of truth, tidak diubah/tidak ikut diproses ulang
- ✅ **Checkpoint:** `git commit -m "feat: build star schema in duckdb (EAV pivot, category tree, fact/dim tables)"` → push

## 7. Data Transformation
- Feature Creation (session mapping dari visitorid + timestamp gap)
- Aggregation
- Business Metrics
- Derived Columns
- **Develop Mart Kecil + Export Parquet** *(baru)* — sebelum push, buat tabel mart ringkas dari hasil tahap ini & export ke parquet kecil (`data/processed/milestone_XX.parquet`); file CSV mentah tetap jadi source of truth, tidak diubah/tidak ikut diproses ulang
- ✅ **Checkpoint:** `git commit -m "feat: add feature engineering and business metrics transformation"` → push

## 8. Exploratory Data Analysis (EDA)
- **Funnel/Conversion Analysis** *(diangkat jadi item eksplisit)* —
  view → addtocart → transaction, per item/kategori/waktu
- Trend Analysis
- Segment Analysis (per kategori, per perilaku visitor)
- Correlation Analysis
- Descriptive Statistics
- **Develop Mart Kecil + Export Parquet** *(baru)* — sebelum push, buat tabel mart ringkas dari hasil tahap ini & export ke parquet kecil (`data/processed/milestone_XX.parquet`); file CSV mentah tetap jadi source of truth, tidak diubah/tidak ikut diproses ulang
- ✅ **Checkpoint:** `git commit -m "feat: add EDA notebook incl. funnel/conversion analysis"` → push

## 9. Analytical Dataset Creation
- KPI Tables
- Reporting Tables
- Dashboard-ready Dataset
- **Develop Mart Kecil + Export Parquet** *(baru)* — sebelum push, buat tabel mart ringkas dari hasil tahap ini & export ke parquet kecil (`data/processed/milestone_XX.parquet`); file CSV mentah tetap jadi source of truth, tidak diubah/tidak ikut diproses ulang
- ✅ **Checkpoint:** `git commit -m "feat: build analytical datasets for reporting/dashboard"` → push

## 10. Data Mart Development
- Subject-oriented Data Mart — 5 mart, satu per halaman dashboard *(baru, lihat detail di bawah)*:
  - `mart_overview_daily` → Halaman 1 (Overview)
  - `mart_funnel_by_category`, `mart_time_to_convert` → Halaman 2 (Funnel & Conversion)
  - `mart_item_performance`, `mart_category_performance` → Halaman 3 (Product & Category Performance)
  - `mart_visitor_segment`, `mart_activity_by_hour` → Halaman 4 (Visitor Behavior & Segmentation)
  - `mart_data_quality_summary` → Halaman 5 (Data Quality & Methodology)
- Business Layer

**📌 Dashboard Methodology Decisions — LOCKED**

1. **Item Ranking Threshold** (`mart_item_performance`)
   - Terapkan minimum view threshold sebelum ranking item.
   - Default analytical threshold: 10 views.
   - Threshold divalidasi ulang saat tahap EDA (bisa berubah kalau distribusi data minta lain).
   - Diperlakukan sebagai **aturan analitik**, bukan aturan data cleaning — jadi item dengan view < threshold tetap ada di data, cuma di-exclude dari ranking/visual tertentu.

2. **Visitor Segmentation** (`mart_visitor_segment`)
   - Segmen bersifat **mutually exclusive**.
   - Klasifikasi berdasarkan funnel stage tertinggi yang dicapai visitor:
     `Buyer > Cart-adder > Browser-only`.
   - Total tiap segmen harus reconcile ke total unique visitors (validasi wajib sebelum masuk dashboard).

3. **Data Quality & Methodology** (`mart_data_quality_summary`)
   - Mart ini isinya **hanya metrik kuantitatif** (before/after count, % filtered, dsb.) — cocok untuk card/chart.
   - Assumptions, KPI definitions, methodology notes, dan limitations **tidak** ditarik dari mart — disajikan sebagai teks statis/dokumentasi langsung di Power BI (text box), bukan tabel.

- **Develop Mart Kecil + Export Parquet** *(baru)* — sebelum push, buat tabel mart ringkas dari hasil tahap ini & export ke parquet kecil (`data/processed/milestone_XX.parquet`); file CSV mentah tetap jadi source of truth, tidak diubah/tidak ikut diproses ulang
- ✅ **Checkpoint:** `git commit -m "feat: build subject-oriented data mart (5 marts for 5 dashboard pages)"` → push

## 11. Parquet Export
- Optimized Storage
- Reusable Dataset Layer
- **Develop Mart Kecil + Export Parquet** *(baru)* — sebelum push, buat tabel mart ringkas dari hasil tahap ini & export ke parquet kecil (`data/processed/milestone_XX.parquet`); file CSV mentah tetap jadi source of truth, tidak diubah/tidak ikut diproses ulang
- ✅ **Checkpoint:** `git commit -m "feat: export parquet layer for BI consumption"` → push

## 12. Visualization & Dashboard Development
- **5 Halaman Dashboard** *(baru, disepakati & locked)*:
  1. Overview — KPI cards, funnel ringkas, trend harian/mingguan
  2. Funnel & Conversion — conversion rate per tahap & kategori, time-to-convert, drop-off
  3. Product & Category Performance — top item (view vs transaction, dengan threshold 10 views), top kategori + drill-down, cart-abandonment
  4. Visitor Behavior & Segmentation — one-time vs repeat, segmentasi Buyer/Cart-adder/Browser-only (mutually exclusive), activity by hour/day
  5. Data Quality & Methodology — metrik kuantitatif dari `mart_data_quality_summary` + text box statis untuk assumptions/KPI definitions/limitations
- KPI Monitoring
- Drill-down Analysis
- Interactive Dashboard
- **Develop Mart Kecil + Export Parquet** *(baru)* — sebelum push, buat tabel mart ringkas dari hasil tahap ini & export ke parquet kecil (`data/processed/milestone_XX.parquet`); file CSV mentah tetap jadi source of truth, tidak diubah/tidak ikut diproses ulang
- ✅ **Checkpoint:** `git commit -m "feat: build power bi dashboard (5 pages)"` → push

## 13. Insight & Recommendation
- Findings
- Root Cause Analysis
- Business Impact
- Actionable Recommendation
- **Develop Mart Kecil + Export Parquet** *(baru)* — sebelum push, buat tabel mart ringkas dari hasil tahap ini & export ke parquet kecil (`data/processed/milestone_XX.parquet`); file CSV mentah tetap jadi source of truth, tidak diubah/tidak ikut diproses ulang
- ✅ **Checkpoint:** `git commit -m "docs: add insights and business recommendations"` → push

## 14. Documentation
- Methodology
- Assumptions (termasuk asumsi property code price/available, definisi bot filter)
- Limitations (termasuk tidak adanya data revenue eksplisit)
- Data Dictionary
- **Develop Mart Kecil + Export Parquet** *(baru)* — sebelum push, buat tabel mart ringkas dari hasil tahap ini & export ke parquet kecil (`data/processed/milestone_XX.parquet`); file CSV mentah tetap jadi source of truth, tidak diubah/tidak ikut diproses ulang
- ✅ **Checkpoint:** `git commit -m "docs: add methodology, assumptions, limitations, data dictionary"` → push

## 15. Final Publishing *(revisi — git checkpoint sudah tersebar di tahap 0–14)*
- Review ulang seluruh commit history (rapikan jika perlu dengan `rebase -i` sebelum publish)
- Finalisasi README (ringkasan project, cara reproduce, screenshot dashboard)
- Tag release (mis. `v1.0`) di GitHub
- Portfolio Publication (LinkedIn/blog post merujuk ke repo)
- ✅ **Checkpoint akhir:** `git commit -m "docs: finalize README and release v1.0"` → push + tag

---

### Ringkasan Perubahan (v1 → v2 → v3)
| Tahap | Perubahan |
|---|---|
| 0 | Tahap baru: Project Setup (init repo, .gitignore, struktur folder) |
| 1 | + Data Feasibility Check |
| 2 | + Property Code Mapping |
| 3 | + Anomaly/Bot Traffic Profiling |
| 4 | + Bot/Anomaly Filtering |
| 5 | Reframe validasi jadi internal consistency |
| 6 | + EAV-to-Wide, + Point-in-Time Snapshot, + Category Tree Flattening |
| 8 | Funnel Analysis diangkat jadi item eksplisit |
| 14 | Assumptions & Limitations diperjelas isinya |
| 0–14 | **Baru:** setiap tahap ditutup checkpoint `git commit` + push |
| 1–14 | **Baru:** tiap tahap develop mart kecil + export parquet dulu sebelum push;
        CSV mentah tetap jadi source of truth dan tidak ikut diubah/diproses ulang |
| 10 | + 5 mart dashboard dipetakan eksplisit + 3 Methodology Decisions LOCKED
      (item ranking threshold, visitor segmentation rule, data quality mart scope) |
| 12 | + Struktur 5 halaman dashboard dijabarkan eksplisit (Overview, Funnel,
      Product, Visitor, Data Quality) |
| 15 | Direname jadi "Final Publishing" — bukan lagi tempat commit pertama kali,
     tapi review history, rapikan, tag release, dan publikasi |
| 0 (v3) | **Baru:** eksplisit "bangun skeleton project dulu sebelum sentuh data" —
     semua file `sql/02-10_*.sql` dibuat sebagai stub kosong sejak awal |
| — (v3) | **Baru:** pola kerja iteratif 7 langkah (tulis query → jalankan → investigasi
     kalau janggal → putuskan → revisi → dokumentasikan → commit) ditulis eksplisit sebagai
     metode baku, bukan cuma dipraktikkan tanpa didefinisikan |
