# ERHA-019 — 13-location Erha 2026 RAB as one business project

Tanggal: 6 Oktober 2026.

## Source
User file: `NIS - Erha 2026 Terbaru.pdf`
SHA256: `8fb9f03521446e6549c84c80acc8ec273f2d0cb9d7aa4d3a7ce4578a276f065b`

The source contains 13 Erha locations with one 2026 pricing structure, Management Fee 4%, monthly total Rp91,160,386 and reported annual total Rp1,093,924,638.

## Business-project decision
The RAB is treated like Djarum / CBRE AWS / Inax:
**one business project, multiple areas/source RABs.**

Canonical parent:
**Project ID 1063 — PT. Erha Clinic Indonesia · Cleaning Service**

13 approved RAB source records are linked to 1063:
Lampung; Alam Sutera; Cengkareng/Citra Garden; Warung Buncit; Mampang Buspark; Tebet Raya; Ciputat; Cinere; Tasikmalaya; Dermies Tangerang City; Mall Kelapa Gading; Pakuwon Mall - Yogyakarta; Solo Paragon Mall.

Each RAB is CURRENT_EFFECTIVE from 1 Jan to 31 Dec 2026.

## Source structure preserved
Per source row the engine preserves:
- MPP 2025 / MPP 2026
- UMK 2026
- Upah
- Total Biaya SDM
- Consumables
- Sub Total
- Management Fee 4%
- Monthly Total
- Reported Annual Total

The PDF does not label the Rp150k / Rp350k gap between Total Biaya SDM + Consumables and Sub Total. It is therefore stored transparently as **Additional Cost - source component not itemized in PDF**, not silently assigned to another category.

Two source rows contain Rp1 rounding differences between displayed Sub Total + Management Fee and Total. Those are preserved as explicit source rounding adjustments so portfolio totals tie the source summary.

Visit-based source MPP values (0.45 / 0.15) are retained in metadata. Engine costing cards use weighted Upah for edit safety and do not reinterpret those fractions as literal people.

No PPN is present in the PDF source, so the RAB is stored with no PPN.

## Monthly RAB — Project 1063
- RAB COGS: **Rp88,161,284**
- Management Fee: **Rp2,999,102**
- RAB Revenue: **Rp91,160,386**
- RAB GP: **Rp2,999,102**
- RAB GPM: **3.2899%**

Reported annual source Revenue: **Rp1,093,924,638**. The source itself contains a few rupiah of annual-vs-monthly rounding at row level; exact annual figures are preserved in metadata.

## GL evidence
The uploaded source ties to the verified PT. Erha Clinic Indonesia GL identity:
- August RAB Revenue: Rp91,160,386
- August Actual Revenue: **Rp91,160,384**
- Revenue variance: **-Rp2**
- August RAB COGS: Rp88,161,284
- August Actual COGS: **Rp83,217,321.866667**
- COGS variance: **-Rp4,943,962.133333**
- Actual GP: **Rp7,943,062.133333**
- Actual GPM: **8.7133%**

The former PT. Erha Clinic Indonesia residual is cleared.

**Erha Medicals is explicitly NOT merged into 1063.**
It remains a separate unresolved GL identity because it uses distinct tag family 160 and August evidence is OOJ General Cleaning / Erha Genero rather than the RAB source that ties to PT. Erha Clinic Indonesia/tag 161 ECI.

## PayVance
Business decision:
`ERHA-CLINIC-CLEANING-2026-V1`

Tested Erha source locations such as Lampung, Alam Sutera, Warung Buncit and Dermies Tangerang City resolve to Project ID 1063 while preserving work_location and role detail.

The existing historical rule for `ERHA Genero` -> Genero project remains untouched.

## RAB Report
RAB Report is dynamic and now sees:
- active RAB: **144**
- active RAB linked to numeric Project ID: **144**
- Project 1063 has 13 RAB records and Jan-Dec 2026 plan governance.

## Production migration
- `20261005181320 erha_2026_multi_site_single_project_20261006`
- SQL SHA256 `585b52428207562fce5f7729d4802c4f7ad79d165f7d3dd3a36f63065ea822eb`

Post-RAB hash: `1fb58a72498d485c89816a4dd7d30556`

Integrity:
- Jan-Aug independent GL controls PASS
- Revenue gap 0
- COGS gap 0
- raw GL hash `aaa8811053b6580a9370732074a15a3a`
- Finance hash `8a623f60f7d680cdcce5f2d6d671ec1e`
- source revision 452
- September GL batches 0
- waiting locks 0
