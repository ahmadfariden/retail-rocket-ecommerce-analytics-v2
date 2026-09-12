# Insight & Recommendation
## Retail Rocket E-Commerce Analytics

> Insight ini dibangun dari data yang sudah divalidasi di seluruh pipeline (milestone 1-10).
> Setiap insight mengikuti struktur: Finding → Root Cause → Action → Expected Impact.

---

## Insight 1 (Sheet 2 — Funnel & Conversion): Category 1224 Outperforms Despite Modest Traffic

**Finding**
- Category 1224 punya view→cart rate 6.49% dan cart→transaction rate 42.09% — sekitar 2x rata-rata kategori lain (avg ~2.7% dan ~30-33%)
- Ini terjadi meski traffic-nya relatif kecil (26,009 viewer, ranking #10 by volume, jauh di bawah kategori 140 yang 303,964)

**Root Cause**
- Volume traffic dan kualitas konversi ternyata tidak berkorelasi di sini — kategori dengan traffic tertinggi (-1, 140, 1532) konversinya rata-rata biasa, sementara kategori dengan traffic lebih kecil ini justru konversinya jauh lebih baik
- Kemungkinan penjelasan: assortment yang lebih niche/targeted dengan purchase intent per visitor yang lebih tinggi (perlu validasi eksternal — tipe produk, price point, atau search intent kategori ini)

**Action**
- Investigasi apa yang membedakan kategori 1224 (product mix, pricing, rata-rata `price_analytics` item di kategori ini)
- Uji coba replikasi pendekatan merchandising-nya (placement, rekomendasi) ke kategori dengan traffic tinggi tapi konversi rendah

**Expected Impact**
- Kalau 2 dari 5 kategori dengan traffic teratas bisa naikkan cart→transaction rate 5-10pp mendekati benchmark kategori 1224, itu bisa nambah ratusan transaksi incremental tanpa biaya akuisisi traffic baru

---

## Insight 2 (Sheet 3 — Product & Category Performance): High-Intent Cart Abandonment Cluster

**Finding**
- Minimal 12+ item menerima 10-37 add-to-cart masing-masing, tapi konversi ke transaksi **NOL** (contoh: item 386947: 17 adds, 0 pembelian; item 212650: 15 adds, 0 pembelian)
- Ini pola kegagalan yang berbeda dari item ber-konversi rendah biasa — visitor-visitor ini sudah menunjukkan purchase intent kuat (lewat tahap view, lewat tahap cart) lalu drop total, bukan berkurang bertahap

**Root Cause**
- Cart-to-transaction dropout 0% (vs rata-rata ~31%) khusus di item-item ini menunjukkan ada blocker di level item, bukan kelemahan funnel secara umum — kandidat penyebab: stock tidak tersedia saat checkout (lihat property `available`), perubahan harga antara cart-add dan checkout, atau payment path yang rusak/tidak tersedia untuk item itu
- Bukan soal kualitas traffic — visitor pool yang sama konversi normal (31%) di item lain

**Action**
- Cross-check itemid ini terhadap histori property `available` pada saat cart-add vs beberapa hari setelahnya — kalau stock jadi 0 tak lama setelahnya, itu kemungkinan besar penyebabnya
- Kalau stock/availability bukan penyebab, flag item-item ini untuk manual checkout-flow test (harga, ongkir, opsi pembayaran)

**Expected Impact**
- Bahkan pemulihan parsial (10-15% konversi, bukan 0%) di cluster item ini merepresentasikan transaksi incremental "gratis" — demand (cart adds) sudah ada, tidak butuh traffic baru

---

## Insight 3 (Sheet 4 — Visitor Behavior & Segmentation): Engagement Gap Reveals Retention Opportunity

**Finding**
- Avg sessions per visitor: Buyer 2.79, Cart-adder 1.84, Browser-only 1.21 — engagement meningkat sejalan dengan funnel depth
- Repeat rate Cart-adder 34.80%, lebih dari dua kali lipat Browser-only (12.06%), tapi masih jauh di bawah Buyer (54.09%)
- Cart-adder cuma 1.93% dari semua visitor (27,146), tapi mereka segmen paling dekat dengan konversi — sudah melewati tahap tersulit (menambahkan ke cart)

**Root Cause**
- Data menunjukkan engagement didapat secara progresif (tiap tahap funnel kurang lebih menggandakan kemungkinan kunjungan ulang), bukan acak — artinya cart-adder yang tidak kembali adalah titik kebocoran yang spesifik dan bisa diidentifikasi, bukan churn traffic umum
- Digabung dengan temuan Insight 2 (12+ item dengan 0% cart-to-transaction meski cart intent nyata), ini mengindikasikan sebagian dari 65.20% Cart-adder yang tidak repeat mungkin hilang karena friction yang bisa dicegah (stock, harga, masalah checkout), bukan karena memang tidak tertarik

**Action**
- Prioritaskan retargeting/remarketing khusus ke Cart-adder yang tidak kembali dalam [X] hari — segmen ini 18x lebih kecil dari Browser-only, jadi target yang murah dan high-leverage
- Cross-reference dengan daftar item konversi-nol di Insight 2 — kalau item-item itu menyumbang porsi signifikan dari churn Cart-adder, memperbaiki isu level item bisa langsung mengangkat konversi segmen ini

**Expected Impact**
- Memindahkan bahkan 10pp Cart-adder dari one-time ke repeat (mendekati benchmark Buyer 54%) bisa secara signifikan mengecilkan gap 27,146 → 11,719 (Cart-adder → Buyer), karena repeat visit adalah korelasi terkuat yang teramati terhadap pembelian akhirnya

---

## Catatan Metodologi
Ketiga insight di atas sengaja saling terhubung (Insight 2 dan 3 merujuk satu sama lain) untuk menunjukkan analisis lintas-halaman yang koheren, bukan temuan yang berdiri sendiri per chart. Semua angka diambil langsung dari mart yang sudah divalidasi (`mart_funnel_by_category`, `mart_item_performance`, `mart_visitor_segment`) — bukan estimasi atau asumsi baru.
