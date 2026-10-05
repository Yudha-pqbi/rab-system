# INAX-018 — Jabar + Jateng as one 2026 business project

Tanggal: 6 Oktober 2026.

## User source
1. `Breakdown Cost - INAX 2026 - Jabar.xlsx`
   - SHA256 `74b68ec7f7c815b4eeea006880059214d63f350e7992f48fa7cb15c05f6a0417`
2. `Breakdown Cost - INAX 2026 - Jateng.xlsx`
   - SHA256 `d1135b184e2870a868658e1de0f537b8aac90d36ced3ecd7090e1588dd36e198`

Client authority: **PT. Inax International**.

## Business-project decision
Jabar and Jateng are treated like the Djarum/AWS pattern: **one business project, multiple regional RAB/source areas**.

Evidence:
- GL has one verified reporting identity for PT. Inax International.
- Invoice/GL use common tag `SS01.RR.174.SRG`.
- Invoice descriptions distinguish Inax Jabar and Inax Jateng while keeping the same Promotor business service.
- PayVance carries the same client across many INA Sanitary locations; legacy code 174 appears on part of the population.
- User explicitly instructed annual 2026 treatment and Djarum/AWS-style grouping when the case is the same.

Canonical parent:
**Project ID 1062 — PT. Inax International · Sales Promotor**

Two approved RAB source records are linked to 1062:
- INAX Jabar
- INAX Jateng

Individual INA Sanitary locations remain detail dimensions.

## RAB economics — monthly

### INAX Jabar
- Manpower model before source adjustment: Rp40.728.096
- Source adjustment / payroll deductions & zero-attendance effect: **(Rp2.240.000)**
- RAB COGS: **Rp38.488.096**
- Management Fee 5%: **Rp1.924.404,80**
- RAB Revenue before PPN: **Rp40.412.500,80**
- PPN 11% on Management Fee only: **Rp211.684,528**
- Total after PPN: **Rp40.624.185,328**
- 9 Sales Promotor cards

### INAX Jateng
- Manpower model before source adjustment: Rp16.260.400
- Source adjustment / payroll deductions: **(Rp248.000)**
- RAB COGS: **Rp16.012.400**
- Management Fee 5%: **Rp800.620**
- RAB Revenue before PPN: **Rp16.813.020**
- PPN 11% on Management Fee only: **Rp88.068,20**
- Total after PPN: **Rp16.901.088,20**
- 4 Sales Promotor cards

### Combined Project 1062
- RAB Revenue: **Rp57.225.520,80 / month**
- RAB COGS: **Rp54.500.496 / month**
- RAB Gross Profit: **Rp2.725.024,80 / month**
- RAB GPM: **4,7619%**
- 13 manpower cards

## Annual 2026
User instructed the uploaded monthly economics to represent the full 2026 RAB.

Both RAB versions:
- effective_from: **2026-01-01**
- effective_to: **2026-12-31**
- plan_status: `CURRENT_EFFECTIVE`
- confidence: `HIGH`

Combined annual:
- RAB Revenue: **Rp686.706.249,60**
- RAB COGS: **Rp654.005.952**
- Gross Profit: **Rp32.700.297,60**
- Total after PPN: **Rp690.303.282,336**

Source employee join dates are stored as source evidence, but they do not shorten the user-directed 2026 RAB period.

The Jateng workbook has an internal header inconsistency: its sheet named September states 21 Jul–20 Aug while the attendance sheet states 21 Aug–20 Sep. This is preserved in metadata and does not override the user-directed Jan–Dec 2026 plan.

## Engine representation
All RAB cost is manpower-related:
- Basic salary
- Attendance allowance
- Meal allowance
- Communication/pulsa
- Competency allowance
- BPJS TK source 6.24%
- BPJS Health source 4%

Source deductions / attendance adjustments are represented transparently through `source_adjustment_monthly`; they are not hidden inside another component.

Management Fee basis: total RAB cost, 5%.
PPN basis: Management Fee only, 11%.

## GL
August Project 1062:
- RAB Revenue: Rp57.225.520,80
- Actual Revenue: **Rp57.827.891**
- Revenue variance: **+Rp602.370,20 / +1,0526%**
- RAB COGS: Rp54.500.496
- Actual COGS: **Rp50.049.059,80**
- COGS variance: **(Rp4.451.436,20) / -8,1677%**
- RAB GP: Rp2.725.024,80
- Actual GP: **Rp7.778.831,20**
- Actual GPM: **13,4517%**

The former August residual identity is now zero/resolved.

Jan-Aug independent GL controls remain PASS with Revenue gap 0 and COGS gap 0. Raw GL and Finance decisions are unchanged.

## PayVance
Business decision:
`INAX-SALES-PROMOTOR-2026-V1`

Resolver maps INA Sanitary locations to Project ID 1062 while preserving:
- work_location
- position
- employee identity
- source payroll values

Tested sample locations Bandung, Semarang and Solo all resolve to 1062.

## RAB Report
RAB Report reads the backend dynamically. Post-import:
- active RAB: 131
- active RAB linked to numeric Project ID: 131
- both INAX RAB source records resolve to Project ID 1062
- period Jan-Dec 2026 is available through plan-version governance.

## Production migration
- `20261005175503 inax_2026_jabar_jateng_single_project_20261006`
- SQL SHA256 `dfd3289b19eb844c171346fca5478a9a5dddbf24f94e9daa5562a210201b9c89`

Integrity:
- GL hash `aaa8811053b6580a9370732074a15a3a`
- Finance hash `8a623f60f7d680cdcce5f2d6d671ec1e`
- source revision 452
- September GL batches 0
- waiting locks 0
