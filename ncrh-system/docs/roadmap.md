# Roadmap

## This build (MVP — section 67 of the source brief)

Authentication · RBAC · departments/stores · item master · supplier master · digital bin
cards · inventory transaction ledger (immutable, reversal-based) · receiving/GRN ·
requisitions · purchase orders · stock issues · stock transfers · stocktaking ·
adjustments · expiry monitoring · low-stock/reorder monitoring · kitchen consumption +
wastage · nutrition requirement planning + consumption · department dashboards ·
management dashboard with drill-down · core reports (bin card, consumption, procurement) ·
audit trail.

Delivered as: PostgreSQL schema + seed data (`db/`), FastAPI backend (`backend/`), React
frontend (`frontend/`).

## Phase 2

- Advanced procurement: multi-tier value-based approval chains, PO amendment workflow.
- Supplier performance scoring (on-time %, rejection rate, price trend) — the raw data
  (GRN accepted/rejected quantities, PO expected vs. actual delivery dates) is already
  captured in the MVP schema; this phase adds the aggregation views/UI.
- Barcode/QR generation and scanning for items and batches.
- Inventory valuation (FIFO/weighted-average costing) on top of the existing ledger.
- Delivered notifications (email/SMS/push) — MVP only shows in-app alerts.
- Report export (PDF/Excel/CSV) and printable documents (bin card, requisition, PO, GRN,
  issue voucher, stocktake sheet) with signature fields.
- Excel/CSV data import pipeline (upload → validate → preview → approve → import) for
  item master, opening stock, suppliers, historical data.
- Data-quality module (duplicate items, missing units/costs/batches, negative stock,
  unreconciled balances).
- Global search across items, suppliers, GRNs, POs, requisitions, issues, batch numbers.
- Rate limiting, account lockout, MFA, secrets-manager integration, formal pentest
  (security hardening flagged in `security_model.md`).

## Phase 3

- Demand forecasting and predictive procurement, starting with simple transparent
  statistics (moving average, seasonal index) before any ML model, per the source
  brief's explicit instruction to "start with simple transparent statistical methods
  before introducing machine learning."
- Anomaly detection on consumption/wastage patterns.
- Power BI / data-warehouse export; the schema already preserves granular
  transaction-level data specifically so this doesn't require a redesign later.
- Mobile application, with offline support if confirmed necessary.
- Additional departments — Pharmacy, Medical Stores, Wards, Laboratory, Theatre — added
  as new `departments`/`stores` rows plus department-specific screens; the inventory
  engine, ledger, and RBAC model do not need to change to onboard them.
- Finance/Accounts integration (costing feeding into hospital financial systems).
- API integrations: EMR, hospital management system, DHIS2.

## Explicitly not building speculative infrastructure now

No feature flags, no multi-tenant abstraction, no plugin system — the modularity comes
from departments/stores/items/roles being configuration data, not from speculative code
abstractions for departments that don't exist yet.
