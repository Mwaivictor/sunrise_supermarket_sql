# NCRH Kitchen, Procurement, Stores & Nutrition System — Requirements

## 1. Purpose

Replace paper bin cards and disconnected spreadsheets across Kitchen, Procurement,
Stores and Nutrition with one system that answers, at any time: what do we have, where
is it, what was bought, what was issued, what was consumed, what was wasted, and what
needs to be procured next. Built as a modular platform so Pharmacy, Wards, Laboratory,
Theatre and Finance can be added later without rebuilding the core.

## 2. Core principle

**Enter data once, use it everywhere.** A goods receipt posts once and flows through to
the bin card, stock balance, dashboards and reorder monitoring automatically — it is
never re-typed into a second system of record.

## 3. MVP boundary (this build)

In scope: authentication, role-based access control, departments/stores, item master,
supplier master, digital bin cards, the inventory transaction ledger, receiving,
requisitions, purchase orders, goods received notes, stock issues, stock transfers,
stocktaking, adjustments/reversals, expiry monitoring, low-stock monitoring, kitchen
consumption + wastage, nutrition requirement planning + consumption, dashboards
(department + management), core reports, and an audit trail.

Out of scope for this build (see `roadmap.md`): barcode/QR, mobile/offline apps,
forecasting/ML, Power BI/data-warehouse export, delivered notifications (email/SMS),
printable PDF documents, Excel data import, a dedicated data-quality module, and any
department beyond Kitchen/Procurement/Stores/Nutrition.

## 4. Departments

- **Procurement** — supplier management, requisition review/approval, purchase orders,
  delivery tracking, cost tracking.
- **Stores** — receiving, bulk storage, bin cards, issues, transfers, returns,
  adjustments, stocktaking, batch/expiry tracking. Modeled as a store type so multiple
  physical stores are supported from day one (Bulk Store, Kitchen Store, Nutrition Store).
- **Kitchen** — requests commodities, receives issues, records consumption and wastage.
- **Nutrition** — requirement planning for therapeutic/specialized feeds and supplements,
  requisitions, consumption, expiry monitoring.

## 5. AS-IS → TO-BE (assumed, pending NCRH confirmation — see `policy_assumptions.md`)

**AS-IS (assumed typical hospital pattern):** paper bin cards kept per store; requisition
slips hand-carried for signature; stock counts and consumption tallied in Excel at
month-end; procurement tracked in a separate ledger/Excel with no link back to stores;
no automatic reorder or expiry alerting; stock variances discovered only at annual
stocktake.

**TO-BE:** every movement is a system transaction the moment it happens; the bin card is
a read-only view generated from that ledger; requisitions are approved and issued inside
the system so stock never leaves without a recorded, permissioned transaction; dashboards
surface low stock, expiry and variance continuously instead of at month-end.

This assumption must be validated against NCRH's actual current workflow (section 71 of
the source brief) before go-live; `policy_assumptions.md` tracks exactly which
assumptions still need sign-off.

## 6. Non-functional requirements

- **Correctness over convenience**: stock balances are derived, never hand-edited;
  posted transactions are immutable (corrections are reversals, section 14).
- **Auditability**: every state-changing action records who/what/when/where/old→new.
- **RBAC**: every write endpoint checks a permission, not just a role name, so
  permissions stay configurable per section 8's requirement.
- **Modularity**: departments/stores/roles/permissions/item categories are configuration
  data, not hard-coded, so onboarding a new department is a data change, not a code change.
- **Auditable history**: no historical transaction, price, or stock record is overwritten.
- Reasonable performance on modest hospital infrastructure; mobile-responsive UI.

## 7. Success criteria for this build

The five verification scenarios in the project plan's Verification section all pass
against realistic seeded data, end to end through the actual UI (not just API calls).
