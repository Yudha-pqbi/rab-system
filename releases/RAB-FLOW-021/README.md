# RAB-FLOW-021 — automatic identity metadata refresh

An already open page cached the project dictionary indefinitely. Newly saved RAB references could therefore remain unresolved until a page reload. The shared adapter now refreshes expired identity metadata every 60 seconds while visible, on returning to the tab, and on network reconnection. Failed reads retry on the next interval; overlapping reads share a single request.

The existing identity protocol, source identifiers, editable form values, amounts, formulas, parsers, and engine data queries are preserved. This updates identity labels and exports; it is not a live refresh of entire financial-report datasets.

Validation: the previous adapter fails the new-RAB automatic-refresh case; the candidate passes all 17 isolated runtime checks. CI reruns them when the adapter changes. Run:

```sh
node releases/RAB-FLOW-021/test-identity-refresh.cjs project-identity.js
```

Deploy with the existing Pages integration. For rollback, restore project-identity.js from the parent commit; no data migration is needed. Existing browser tabs need to load the deployed script once.
