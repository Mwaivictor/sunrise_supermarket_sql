# Role / Permission Matrix

Roles and permissions are both stored as configuration data (`roles`, `permissions`,
`role_permissions` tables) — this matrix is the seeded default, not a hard-coded rule.
An admin can grant/revoke individual permissions per role without a code change.

| Permission                     | Admin | Procurement Officer | Storekeeper | Store Manager | Nutritionist | Kitchen User/Manager | Management | Auditor |
|---------------------------------|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| view_inventory                  | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| view_bin_card                   | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| create_requisition              | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | – | – |
| approve_requisition             | ✓ | ✓ | – | ✓ | – | – | – | – |
| manage_suppliers                | ✓ | ✓ | – | – | – | – | – | – |
| create_purchase_order           | ✓ | ✓ | – | – | – | – | – | – |
| receive_goods (post GRN)        | ✓ | – | ✓ | ✓ | – | – | – | – |
| issue_stock                     | ✓ | – | ✓ | ✓ | – | – | – | – |
| transfer_stock                  | ✓ | – | ✓ | ✓ | – | – | – | – |
| record_consumption               | ✓ | – | – | – | ✓ | ✓ | – | – |
| record_wastage                   | ✓ | – | ✓ | ✓ | ✓ | ✓ | – | – |
| create_stocktake                 | ✓ | – | ✓ | ✓ | – | – | – | – |
| approve_stock_adjustment         | ✓ | – | – | ✓ | – | – | – | – |
| post_reversal_transaction        | ✓ | – | ✓ | ✓ | – | – | – | – |
| view_reports                     | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| view_management_dashboard         | ✓ | – | – | ✓ | – | – | ✓ | ✓ |
| manage_users                      | ✓ | – | – | – | – | – | – | – |
| manage_items_categories_units      | ✓ | ✓ (items) | – | – | – | – | – | – |
| manage_departments_stores          | ✓ | – | – | – | – | – | – | – |
| view_audit_log                     | ✓ | – | – | – | – | – | – | ✓ |
| manage_system_configuration          | ✓ | – | – | – | – | – | – | – |

Notes:
- "Management" and "Auditor" are read-only across every screen they can see — enforced
  at the API layer (their permission set contains only `view_*` permissions), not just
  hidden in the UI.
- Store Manager can approve stock adjustments and reversals; Storekeeper can post a
  reversal only against their own erroneous entries pending Store Manager sign-off —
  see `policy_assumptions.md` for the exact approval threshold, which needs NCRH
  confirmation.
- Kitchen Manager currently has the same permission set as Kitchen User; splitting them
  (e.g. only the manager approves wastage write-offs above a threshold) is a Phase 2
  configuration change, not a schema change.
