# RAB-REPORT-INLINE-007 — RAB main/report parity

Tanggal: 5 Oktober 2026.

## Masalah
RAB Report sebelumnya membaca tabel `projects` langsung, tetapi:
1. tidak membaca numeric Project ID dari Project Identity Dictionary;
2. tidak membaca `canonical_rab_plan_versions_candidate_v1`;
3. monthly schedule hanya menghormati tanggal pada manpower card, sehingga komponen non-manpower bisa tetap muncul di luar periode project/RAB;
4. RAB historical/superseded dapat ikut terjumlah bersama current design;
5. export Project List masih mencari legacy `project_master`, bukan numeric Project ID.

Akibatnya RAB yang sudah benar di engine utama belum selalu direpresentasikan konsisten di RAB Report.

## Perbaikan umum
RAB Report sekarang memuat secara paralel:
- seluruh `projects` aktif / non-DELETED;
- `project_identity_dictionary_v1`;
- `canonical_rab_plan_versions_candidate_v1`.

Setiap RAB di-enrich dengan numeric Project ID dan status/periode plan.

Periode report ditentukan dari evidence yang tersedia:
- plan version effective_from/effective_to;
- project_meta source_period_start/source_period_end;
- min/max contract dates pada manpower cards.

Untuk CURRENT_EFFECTIVE/base RAB, report memakai rentang gabungan evidence tersebut. RAB tanpa periode eksplisit mempertahankan perilaku baseline bulanan. HISTORICAL_REFERENCE / SUPERSEDED tetap tercatat di jumlah/list project tetapi tidak didouble-count pada current design.

Monthly schedule sekarang mematikan **seluruh project** di luar periode project, bukan hanya manpower. Pada bulan aktif, manpower per-card tetap menghormati contract_start/contract_end; non-manpower, management fee dan PPN ikut periode project yang sama.

Export Project List sekarang berisi:
- Project ID numerik
- Client
- Area
- Service
- RAB Plan Status
- Effective From
- Effective To

Legacy project_master tidak lagi menjadi authority Project ID pada RAB Report.

## OSID/O!Save
User telah memperpanjang OSID sampai Desember 2026. Backend diselaraskan:
- Project ID 1052
- source/meta start 2026-09-01
- source/meta end 2026-12-31
- manpower contract end 2026-12-31
- CURRENT_EFFECTIVE plan end 2026-12-31
- evidence basis USER_OSID_EXTENSION_TO_DEC_2026
- confidence HIGH

Migration: `rab_osid_extend_to_dec_2026_20261005`.

RAB Report browser validation:
- August OSID Revenue/COGS = 0 pada schedule RAB
- September Revenue Rp10.516.130 / COGS Rp9.737.158
- December Revenue Rp10.516.130 / COGS Rp9.737.158
- Project ID export = 1052

## Coverage
Live browser test membaca production Supabase:
- **129 active RAB**
- **129/129 numeric Project ID**
- ADM sample: 10 RAB tersimpan, 1 HISTORICAL_REFERENCE, 9 current-design; historical tetap represented namun tidak double-count.

## Validation
GitHub Actions run 37347354127:
- 11 browser/live read-only checks PASS
- inline JavaScript syntax PASS
- no runtime browser errors

Tidak ada perubahan formula/source RAB massal. Perubahan report hanya memperbaiki representation/period governance dan numeric identity.