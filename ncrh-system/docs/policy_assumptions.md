# Policy Assumptions Register

Every row below is a default the system ships with because NCRH's actual policy is not
yet known to this build. All are stored in `system_configuration` (global) or per-item
fields (`items.min_stock`, `reorder_level`, etc.) so they can be changed without a code
deploy. **None of these should be treated as NCRH's real policy until confirmed.**

| Policy | Current assumption (default) | Reason | Responsible person to confirm | Configurable? |
|---|---|---|---|---|
| Reorder level | 14 days of average daily consumption | Common hospital-store rule of thumb cited in the source brief (section 27 example) | Store Manager | Yes, per item |
| Minimum stock | 7 days of average consumption | Buffer below reorder point before "critical" | Store Manager | Yes, per item |
| Maximum stock | 60 days of average consumption | Prevents overstock/expiry risk on bulky perishables | Store Manager / Procurement | Yes, per item |
| Expiry warning thresholds | Red: expired · Orange: ≤30 days · Yellow: ≤60 days · Green: >60 days | Directly from source brief section 20 | Store Manager | Yes, global + per category |
| Stocktake frequency | Monthly for high-value/perishable categories, quarterly otherwise | Reasonable default pending confirmation | Store Manager | Yes |
| Requisition approval threshold | Any requisition requires one approval (Store Manager or Procurement Officer); no value-based multi-tier approval yet | Keeps MVP workflow simple; multi-tier by value is a likely real requirement | Procurement Officer | Yes (Phase 2: value-tiered approval chains) |
| Adjustment/reversal approval | Storekeeper can post a reversal only for their own transaction from the same day; anything older requires Store Manager approval | Balances usability with control; needs real confirmation | Store Manager | Yes |
| Negative stock policy | Disallowed — an issue that would take a balance below zero is rejected by the inventory engine | Prevents the ledger from silently going wrong; correct fix is investigate variance via stocktake, not force a negative issue | Store Manager | Yes (can be relaxed per store if NCRH's paper process already tolerates it) |
| High-consumption alert threshold | Current period consumption > 130% of trailing 3-month average | Simple, transparent statistic per source brief section 29/36 (start simple before ML) | Nutritionist / Kitchen Manager | Yes |
| Slow-moving threshold | No outward transaction in 60 days | Reasonable default | Store Manager | Yes |
| Batch/expiry tracking scope | Enabled per item (`items.batch_tracked`), defaulted on for perishables and nutrition products, off for non-perishable dry goods | Avoids forcing batch entry on items where NCRH doesn't currently track it | Store Manager | Yes, per item |
| Unit of measure conversions | Seeded with common examples only (1 bag = 25kg, 1 carton = 12 packets) | Placeholder; real conversion factors must come from NCRH's actual packaging | Procurement Officer | Yes, per item |

Until these are confirmed, treat every dashboard "critical/low/overstock" flag as
provisional — correct in logic, but tuned on assumed defaults.
