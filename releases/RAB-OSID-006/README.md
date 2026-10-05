# RAB-OSID-006 — OSID / O!Save September–October 2026

Tanggal: 5 Oktober 2026.

## Sumber
File user: `RAB - OSID Sept - Okt (rev.osave).xlsx`
SHA256: `6737402a1c6de8d9c134874bb97c3cd19c6771085a3d101d45c1714532e43503`

Client authority dari Invoice/PayVance/GL menormalkan OSID / OSAVE / O!Save menjadi **PT Osid Management Corp**.

## Identitas
RAB baru memakai source-record UUID internal:
`e6a72274-57b5-4807-8fed-038d8fa39816`

RAB tersebut terhubung ke **Project ID 1052** — `PT Osid Management Corp · Cleaning Service`.
Tidak dibuat Project ID baru 1062. Alias area `OSAVE` ditambahkan agar resolver RAB memilih existing 1052.

## Nilai bulanan yang dipertahankan dari source
- Manpower: Rp8.013.693,13
- Machinery: Rp160.417,00
- Chemicals: Rp364.290,00
- Consumables: Rp876.871,33
- Equipment: Rp221.886,33
- Total Cost Project / RAB COGS: **Rp9.737.157,80**
- Management Fee 8%: **Rp778.972,62**
- RAB Revenue sebelum PPN: **Rp10.516.130,42**
- PPN: **Rp170.012,26**
- Total setelah PPN: **Rp10.686.142,68**

PPN mengikuti formula source: management fee + training + machinery + chemicals + equipment. Manpower, uniform, dan consumables tidak dipaksakan masuk basis PPN.

## Manpower
- HOUSEKEEPING: 1 orang
- UMK Kota Depok 2026: Rp5.999.443
- Meal/transport allowance: Rp300.000
- THR: Rp499.953,58
- BPJS Kesehatan: Rp239.977,72
- BPJS TK aggregate 6,24%: Rp374.365,24
- PKWT: Rp499.953,58

Workbook source menghitung Training Rp20.000 dan Uniform/Shoes Rp80.000 di dalam subtotal Salary & Benefit **dan** menambahkan kategori tersebut lagi di summary. Release ini tidak mengoreksi source secara diam-diam. Overlap dipertahankan secara eksplisit di `details_json.project_meta`, sehingga angka engine tie dengan workbook.

## Periode
Nama file menyatakan September–Oktober 2026. RAB disimpan sebagai plan:
- effective_from: **2026-09-01**
- effective_to: **2026-10-31**
- plan_status: `CURRENT_EFFECTIVE`
- confidence: `MEDIUM`

Cell source D25 berisi 3 dan label summary berbunyi “JUMLAH TOTAL 1 TAHUN”. Konflik template ini dicatat di metadata dan **tidak digunakan untuk memperpanjang RAB ke bulan lain**.

## Engine mapping
- Training → Additional Cost
- Uniform/Shoes → Uniform
- Machinery/Peripheral → Machinery
- Chemicals → Chemicals
- Consumables → Consumables
- Equipment → Equipment

Source item detail tersimpan di `details_json`: 1 manpower card, 2 uniform, 1 machinery, 8 chemical, 12 consumable, 15 equipment, dan 1 additional cost.

## Production
Migration:
- `20261005164631 rab_osid_osave_sep_oct_2026_20261005`
- SQL SHA256: `a4f1b42165f995b5aacbe57d3ff5adc550331470d6a36bdbba23a9325b89c736`

Pre-change RAB: 136 rows, hash `a227fa159a04a1f96b02b4883cdf5ce4`.
Post-change RAB: 137 rows, hash `7341d7075dce0ab917a3759738fa990f`.

Raw GL and Finance decisions were not changed:
- GL hash `aaa8811053b6580a9370732074a15a3a`
- Finance hash `8a623f60f7d680cdcce5f2d6d671ec1e`
- source revision 452
- September GL batches: 0

Frontend RAB tidak memerlukan perubahan kode. Existing main already reads the `projects` table and Project Identity Dictionary dynamically.
