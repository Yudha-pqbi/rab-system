# CBRE-AWS-CONSOLIDATION-017

Tanggal: 5 Oktober 2026.

User mengonfirmasi bahwa CBRE AWS 60, AWS 61, dan AWS 62 adalah **satu business contract AWS**, walaupun masing-masing menggunakan YMID/site pair berbeda. Prinsipnya mengikuti golden case Djarum: satu business project / Project ID dapat memiliki beberapa area/site dan beberapa source identity tanpa memecah parent.

## Canonical result
- Parent authoritative: **Project ID 1038 — CBRE AWS**
- AWS 60 / 63: site detail
- AWS 61 / 64: site detail
- AWS 62 / 65: site detail
- Former Project IDs **1054** (AWS 61) dan **1055** (AWS 62) dipertahankan sebagai histori tetapi statusnya INACTIVE. Nomor tidak dihapus atau dipakai ulang.

## GL
Tiga Finance reporting identities kini map ke 1038:
- AWS60 existing identity -> 1038
- AWS61 -> 1038
- AWS62 -> 1038

Agustus 2026 hasil konsolidasi Project 1038:
- Actual Revenue: **Rp276.715.803,30**
- Actual COGS: **Rp221.186.785,451198**
- Gross Profit: **Rp55.529.017,848802**
- GPM: **20,0672%**
- source reporting identities: 3
- former 1054/1055 actual rows: 0

Semua Jan-Aug independent GL source controls tetap PASS; Revenue gap 0 dan COGS gap 0. Raw GL dan Finance decisions tidak diubah.

## RAB
Existing approved RAB yang tersedia saat ini hanya:
- AWS CGK 60 / Cleaning Service
- RAB Revenue Rp16.781.000
- RAB COGS Rp15.982.062,92

Tidak dibuat RAB fiktif untuk AWS61/62. Semua future RAB dengan area AWS60/AWS61/AWS62 yang sesuai business rule diarahkan ke Project ID 1038 melalui business-scope decision `CBRE-AWS-SINGLE-CONTRACT-V2`.

## PayVance
Resolver sekarang mengembalikan Project ID **1038** untuk AWS60, AWS61, dan AWS62, sementara work_location dan position tetap menjadi detail source. Exact SOURCE_SIGNATURE aliases untuk AWS61/62 ditambahkan untuk memperkuat evidence.

## Governance
Business decision:
- `CBRE-AWS-SINGLE-CONTRACT-V2`
- rule: `END_CLIENT_AREA_MULTI_SERVICE`
- target Project ID: `1038`
- evidence: USER_CONFIRMATION_RAB_GL_PAYVANCE

Old site-specific AWS60 decisions disupersede agar resolver tidak memiliki duplicate business rules.

Backend migration:
- `20261005173421 cbre_aws_single_business_contract_20261005`
- SQL SHA256: `62a5a9d83c8b6e8a09e67a7ebed4ae76f64bee52d167f537c625fda14a72f61e`

Integrity:
- GL hash `aaa8811053b6580a9370732074a15a3a`
- Finance hash `8a623f60f7d680cdcce5f2d6d671ec1e`
- RAB source hash unchanged during consolidation
- source revision 452
- September GL batches 0
- waiting locks 0
