# RAB-SAVE-020: verified identities remain saveable

Djarum Security could not save a new Wonogiri RAB even though its existing business-scope rule resolves to Project ID 1001. The assignment function rejected clients missing from the secondary authority snapshot before asking the canonical resolver. The save RPC then replaced the underlying reason with generic REVIEW.

The repair reuses verified existing canonical identities when the secondary snapshot is absent. Explicit non-client and ambiguous authority decisions still block new inserts; new Project IDs still require one verified client. Durable aliases for Djarum, PT DJARUM and DJARUM SKT WONOGIRI are supported by existing rule DJARUM-SECURITY-V1 and signed offer NIS/966-PRP/IX/2026 dated 21 September 2026.

The private insert trigger passes its assignment result through a transaction-local setting. The save RPC uses it only for diagnostic messages, scoped to the same source record. Source writes remain atomic. No new grants, public definer functions, frontend changes, calculations, invoice, payroll or GL worker changes were introduced.

## Validation

- Reproduced the old error under database role anon before applying the repair.
- Candidate transaction: 309/309 passed and rolled back before promotion.
- Production: 309/309 passed, including new/edit paths for all 147 active RABs, four Djarum name spellings under anon/authenticated, missing secondary snapshot, unknown/non-client/ambiguous guards, alias persistence through refresh and baseline fingerprints.
- Existing source budgets, canonical project rows, identity links and GL invalidation revision remained identical.
- Live HTTP RPC rejected an unknown test client with HTTP 400/P0001 and a specific CLIENT_AUTHORITY_REVIEW message.
- Security and performance advisors introduced zero new findings. Existing advisories are outside this fix.
- No real Wonogiri RAB was imported; the user can submit the existing form without refreshing.

## Change record

Supabase migration: 20261023120553_rab_save_020_reuse_canonical_identity_and_verified_djarum_aliases.
Frontend baseline: d2a6147e2d3a552eabb8ae1d241f84787a116354.
See verification.json for the recorded results.

## Regression gate for future identity/save changes

Execute regression.sql through the existing authorized database administration path. It calls the actual save RPC using browser database roles; successful writes and all fixtures are rolled back. Require passed = test_count and failed = [] before promoting an identity/save change. PostgreSQL sequences may advance during rolled-back inserts; no business records remain.

Do not make an unknown client pass by bypassing authority or minting a second Project ID for a known project. Verified name aliases belong in the existing durable alias table and must survive snapshot refresh.

rollback.sql restores the old functions and removes only the aliases introduced by this repair. It is a recovery reference, not an instruction to execute automatically, and it reintroduces the original defect.
