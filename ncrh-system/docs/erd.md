# Entity-Relationship Diagram

Full DDL lives in [`../db/schema.sql`](../db/schema.sql). This is the conceptual map.

```mermaid
erDiagram
    ROLES ||--o{ ROLE_PERMISSIONS : grants
    PERMISSIONS ||--o{ ROLE_PERMISSIONS : "granted via"
    ROLES ||--o{ USERS : has
    DEPARTMENTS ||--o{ USERS : employs
    DEPARTMENTS ||--o{ STORES : owns
    STORES ||--o{ STOCK_BALANCES : holds
    ITEMS ||--o{ STOCK_BALANCES : "tracked as"
    CATEGORIES ||--o{ ITEMS : classifies
    UNITS ||--o{ ITEMS : "measured in"
    ITEMS ||--o{ UNIT_CONVERSIONS : defines
    SUPPLIERS ||--o{ SUPPLIER_ITEMS : supplies
    ITEMS ||--o{ SUPPLIER_ITEMS : "supplied by"

    ITEMS ||--o{ BATCHES : "received as"
    STORES ||--o{ BATCHES : "stored at"

    INVENTORY_TRANSACTIONS ||--o{ INVENTORY_TRANSACTION_LINES : contains
    ITEMS ||--o{ INVENTORY_TRANSACTION_LINES : moves
    STORES ||--o{ INVENTORY_TRANSACTION_LINES : "at store"
    BATCHES ||--o{ INVENTORY_TRANSACTION_LINES : "from batch"
    USERS ||--o{ INVENTORY_TRANSACTIONS : posts

    DEPARTMENTS ||--o{ REQUISITIONS : requests
    REQUISITIONS ||--o{ REQUISITION_LINES : contains
    ITEMS ||--o{ REQUISITION_LINES : requests
    REQUISITIONS ||--o{ APPROVALS : "approved via"
    REQUISITIONS ||--o{ PURCHASE_ORDERS : "sourced by"

    SUPPLIERS ||--o{ PURCHASE_ORDERS : "ordered from"
    PURCHASE_ORDERS ||--o{ PURCHASE_ORDER_LINES : contains
    ITEMS ||--o{ PURCHASE_ORDER_LINES : ordered

    PURCHASE_ORDERS ||--o{ GOODS_RECEIVED_NOTES : delivered
    GOODS_RECEIVED_NOTES ||--o{ GOODS_RECEIVED_LINES : contains
    GOODS_RECEIVED_LINES ||--o| INVENTORY_TRANSACTIONS : posts
    GOODS_RECEIVED_LINES ||--o| BATCHES : creates

    REQUISITIONS ||--o{ STOCK_ISSUES : fulfills
    STOCK_ISSUES ||--o{ STOCK_ISSUE_LINES : contains
    STOCK_ISSUE_LINES ||--o| INVENTORY_TRANSACTIONS : posts

    STORES ||--o{ STOCK_TRANSFERS : "from/to"
    STOCK_TRANSFERS ||--o{ STOCK_TRANSFER_LINES : contains
    STOCK_TRANSFER_LINES ||--o| INVENTORY_TRANSACTIONS : posts

    STORES ||--o{ STOCKTAKES : counted
    STOCKTAKES ||--o{ STOCKTAKE_LINES : contains
    STOCKTAKE_LINES ||--o| INVENTORY_TRANSACTIONS : "adjustment posts"

    STORES ||--o{ WASTAGE : recorded
    ITEMS ||--o{ WASTAGE : wasted
    WASTAGE ||--o| INVENTORY_TRANSACTIONS : posts

    ITEMS ||--o{ ALERTS : triggers
    USERS ||--o{ AUDIT_LOGS : performs
```

## Design notes

- **Every stock-affecting document (GRN line, issue line, transfer line, stocktake
  variance, wastage) posts exactly one `inventory_transactions` row through the backend's
  `inventory_engine` service.** No table other than that ledger is ever the source of
  truth for "how much is on hand" — `stock_balances` is a maintained cache reconciled
  against it (section 51 of the source brief).
- `inventory_transactions` is header + `inventory_transaction_lines` detail so one
  physical event (e.g. one GRN, one issue voucher) can move several items at once while
  still producing one auditable transaction number.
- Corrections never UPDATE/DELETE a posted transaction; they INSERT a `reversal` typed
  transaction referencing the original (section 14).
- `batches` carries expiry per received lot; `inventory_transaction_lines.batch_id` is
  nullable (not every item is batch-tracked) but required whenever `items.batch_tracked`
  is true — enforced in the backend, not just the UI.
