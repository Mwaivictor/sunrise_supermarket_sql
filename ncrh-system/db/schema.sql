-- =============================================================================
-- NCRH KITCHEN, PROCUREMENT, STORES & NUTRITION SYSTEM
-- Schema definition
-- Engine: PostgreSQL 16+
-- Purpose: core tables, enums, constraints and triggers for the inventory
--          transaction engine described in ../docs/erd.md
-- Run order: schema.sql -> seed.sql -> views.sql
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS ncrh;
SET search_path TO ncrh;

-- =============================================================================
-- 1. ENUM TYPES
-- =============================================================================

CREATE TYPE user_status         AS ENUM ('active', 'inactive');
CREATE TYPE store_type          AS ENUM ('bulk', 'kitchen', 'nutrition', 'other');
CREATE TYPE transaction_type    AS ENUM (
    'opening_balance', 'purchase_receipt', 'issue', 'transfer_in', 'transfer_out',
    'return', 'damage', 'expiry', 'wastage', 'positive_adjustment',
    'negative_adjustment', 'stocktake_adjustment', 'reversal'
);
CREATE TYPE requisition_status  AS ENUM (
    'draft', 'submitted', 'approved', 'rejected', 'partially_issued',
    'fully_issued', 'cancelled'
);
CREATE TYPE po_status           AS ENUM (
    'draft', 'submitted', 'under_review', 'approved', 'rejected', 'po_created',
    'partially_delivered', 'fully_delivered', 'cancelled', 'closed'
);
CREATE TYPE grn_inspection_status AS ENUM ('pending', 'passed', 'failed', 'partial');
CREATE TYPE issue_status        AS ENUM ('pending', 'issued', 'received', 'cancelled');
CREATE TYPE transfer_status     AS ENUM ('pending', 'approved', 'completed', 'cancelled');
CREATE TYPE stocktake_type      AS ENUM ('monthly', 'quarterly', 'annual', 'spot');
CREATE TYPE stocktake_status    AS ENUM ('draft', 'counting', 'under_review', 'approved', 'closed');
CREATE TYPE wastage_reason      AS ENUM (
    'spoilage', 'preparation_waste', 'cooking_waste', 'serving_waste',
    'expired', 'damaged_packaging', 'other'
);
CREATE TYPE alert_type          AS ENUM (
    'low_stock', 'stock_out', 'expiry', 'overstock', 'slow_moving', 'high_consumption'
);
CREATE TYPE alert_severity      AS ENUM ('watch', 'warning', 'critical');
CREATE TYPE approval_decision   AS ENUM ('approved', 'rejected');

-- =============================================================================
-- 2. IDENTITY, ORGANIZATION & ACCESS CONTROL
-- =============================================================================

CREATE TABLE roles (
    role_id      serial       NOT NULL PRIMARY KEY,
    role_name    varchar(50)  NOT NULL UNIQUE,
    description  text
);

CREATE TABLE permissions (
    permission_id  serial       NOT NULL PRIMARY KEY,
    permission_key varchar(60)  NOT NULL UNIQUE,
    description    text
);

CREATE TABLE role_permissions (
    role_id       integer NOT NULL REFERENCES roles(role_id),
    permission_id integer NOT NULL REFERENCES permissions(permission_id),
    PRIMARY KEY (role_id, permission_id)
);

CREATE TABLE departments (
    department_id   serial       NOT NULL PRIMARY KEY,
    department_name varchar(80)  NOT NULL UNIQUE,
    description      text,
    active            boolean     NOT NULL DEFAULT true
);

CREATE TABLE stores (
    store_id       serial       NOT NULL PRIMARY KEY,
    store_name     varchar(80)  NOT NULL UNIQUE,
    store_type     store_type   NOT NULL,
    department_id  integer      REFERENCES departments(department_id),
    active         boolean      NOT NULL DEFAULT true
);

CREATE TABLE users (
    user_id       serial        NOT NULL PRIMARY KEY,
    full_name     varchar(120)  NOT NULL,
    username      varchar(60)   NOT NULL UNIQUE,
    email         varchar(120)  UNIQUE,
    phone         varchar(30),
    department_id integer       REFERENCES departments(department_id),
    role_id       integer       NOT NULL REFERENCES roles(role_id),
    password_hash text          NOT NULL,
    status        user_status   NOT NULL DEFAULT 'active',
    last_login    timestamptz,
    last_activity timestamptz,
    created_at    timestamptz   NOT NULL DEFAULT now()
);

-- =============================================================================
-- 3. ITEM MASTER
-- =============================================================================

CREATE TABLE units (
    unit_id    serial      NOT NULL PRIMARY KEY,
    unit_code  varchar(10) NOT NULL UNIQUE,
    unit_name  varchar(40) NOT NULL
);

CREATE TABLE categories (
    category_id        serial       NOT NULL PRIMARY KEY,
    category_name      varchar(80)  NOT NULL,
    parent_category_id integer      REFERENCES categories(category_id),
    UNIQUE (category_name, parent_category_id)
);

CREATE TABLE items (
    item_id              serial        NOT NULL PRIMARY KEY,
    item_code            varchar(20)   NOT NULL UNIQUE,
    item_name            varchar(120)  NOT NULL,
    category_id          integer       NOT NULL REFERENCES categories(category_id),
    description          text,
    stock_unit_id        integer       NOT NULL REFERENCES units(unit_id),
    purchase_unit_id     integer       REFERENCES units(unit_id),
    issue_unit_id        integer       REFERENCES units(unit_id),
    min_stock            numeric(12,3) NOT NULL DEFAULT 0,
    max_stock            numeric(12,3) NOT NULL DEFAULT 0,
    reorder_level        numeric(12,3) NOT NULL DEFAULT 0,
    safety_stock         numeric(12,3) NOT NULL DEFAULT 0,
    avg_daily_consumption numeric(12,3) NOT NULL DEFAULT 0,
    batch_tracked        boolean       NOT NULL DEFAULT false,
    expiry_tracked       boolean       NOT NULL DEFAULT false,
    active               boolean       NOT NULL DEFAULT true,
    created_at           timestamptz   NOT NULL DEFAULT now(),
    CHECK (min_stock >= 0 AND max_stock >= 0 AND reorder_level >= 0 AND safety_stock >= 0)
);

CREATE TABLE unit_conversions (
    unit_conversion_id serial        NOT NULL PRIMARY KEY,
    item_id            integer       NOT NULL REFERENCES items(item_id),
    from_unit_id       integer       NOT NULL REFERENCES units(unit_id),
    to_unit_id         integer       NOT NULL REFERENCES units(unit_id),
    factor             numeric(14,6) NOT NULL CHECK (factor > 0),
    UNIQUE (item_id, from_unit_id, to_unit_id)
);

-- =============================================================================
-- 4. SUPPLIERS
-- =============================================================================

CREATE TABLE suppliers (
    supplier_id    serial       NOT NULL PRIMARY KEY,
    supplier_name  varchar(120) NOT NULL UNIQUE,
    contact_person varchar(120),
    phone          varchar(30),
    email          varchar(120),
    address        text,
    active         boolean      NOT NULL DEFAULT true,
    created_at     timestamptz  NOT NULL DEFAULT now()
);

CREATE TABLE supplier_items (
    supplier_id       integer       NOT NULL REFERENCES suppliers(supplier_id),
    item_id           integer       NOT NULL REFERENCES items(item_id),
    supplier_item_code varchar(40),
    last_unit_cost    numeric(10,2),
    PRIMARY KEY (supplier_id, item_id)
);

-- =============================================================================
-- 5. BATCHES
-- =============================================================================

CREATE TABLE batches (
    batch_id        serial        NOT NULL PRIMARY KEY,
    item_id         integer       NOT NULL REFERENCES items(item_id),
    store_id        integer       NOT NULL REFERENCES stores(store_id),
    batch_number    varchar(60)   NOT NULL,
    manufacture_date date,
    expiry_date     date,
    supplier_id     integer       REFERENCES suppliers(supplier_id),
    received_qty    numeric(12,3) NOT NULL CHECK (received_qty >= 0),
    remaining_qty   numeric(12,3) NOT NULL DEFAULT 0,
    unit_cost       numeric(10,2),
    created_at      timestamptz   NOT NULL DEFAULT now(),
    UNIQUE (item_id, store_id, batch_number)
);

-- =============================================================================
-- 6. INVENTORY TRANSACTION ENGINE  (immutable ledger)
-- =============================================================================

CREATE TABLE inventory_transactions (
    transaction_id          serial            NOT NULL PRIMARY KEY,
    transaction_number      varchar(30)       NOT NULL UNIQUE,
    transaction_type        transaction_type  NOT NULL,
    reference_type          varchar(30),
    reference_id            integer,
    reverses_transaction_id integer           REFERENCES inventory_transactions(transaction_id),
    posted_by               integer           NOT NULL REFERENCES users(user_id),
    posted_at               timestamptz       NOT NULL DEFAULT now(),
    notes                   text
);

CREATE TABLE inventory_transaction_lines (
    line_id        serial        NOT NULL PRIMARY KEY,
    transaction_id integer       NOT NULL REFERENCES inventory_transactions(transaction_id),
    item_id        integer       NOT NULL REFERENCES items(item_id),
    store_id       integer       NOT NULL REFERENCES stores(store_id),
    batch_id       integer       REFERENCES batches(batch_id),
    quantity       numeric(12,3) NOT NULL CHECK (quantity <> 0),
    unit_id        integer       NOT NULL REFERENCES units(unit_id),
    unit_cost      numeric(10,2),
    line_notes     text
);

CREATE INDEX idx_itl_store_item ON inventory_transaction_lines (store_id, item_id);
CREATE INDEX idx_itl_transaction ON inventory_transaction_lines (transaction_id);
CREATE INDEX idx_itl_batch ON inventory_transaction_lines (batch_id);

-- Cached, reconciled-not-hand-edited stock balance (section 51 of the source brief).
CREATE TABLE stock_balances (
    store_id            integer       NOT NULL REFERENCES stores(store_id),
    item_id             integer       NOT NULL REFERENCES items(item_id),
    quantity_on_hand    numeric(12,3) NOT NULL DEFAULT 0,
    reserved_qty        numeric(12,3) NOT NULL DEFAULT 0,
    last_transaction_id integer       REFERENCES inventory_transactions(transaction_id),
    updated_at          timestamptz   NOT NULL DEFAULT now(),
    PRIMARY KEY (store_id, item_id)
);

-- ---- Immutability + balance-maintenance triggers -----------------------------

CREATE OR REPLACE FUNCTION fn_block_mutation() RETURNS trigger AS $$
BEGIN
    RAISE EXCEPTION
        'Posted inventory transactions are immutable. Post a reversal transaction instead (table: %, operation: %).',
        TG_TABLE_NAME, TG_OP;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_transactions_immutable
    BEFORE UPDATE OR DELETE ON inventory_transactions
    FOR EACH ROW EXECUTE FUNCTION fn_block_mutation();

CREATE TRIGGER trg_transaction_lines_immutable
    BEFORE UPDATE OR DELETE ON inventory_transaction_lines
    FOR EACH ROW EXECUTE FUNCTION fn_block_mutation();

CREATE OR REPLACE FUNCTION fn_apply_transaction_line() RETURNS trigger AS $$
DECLARE
    v_current_qty numeric(12,3);
BEGIN
    SELECT quantity_on_hand INTO v_current_qty
    FROM stock_balances
    WHERE store_id = NEW.store_id AND item_id = NEW.item_id
    FOR UPDATE;

    IF NOT FOUND THEN
        v_current_qty := 0;
        INSERT INTO stock_balances (store_id, item_id, quantity_on_hand, last_transaction_id)
        VALUES (NEW.store_id, NEW.item_id, 0, NEW.transaction_id);
    END IF;

    IF v_current_qty + NEW.quantity < 0 THEN
        RAISE EXCEPTION
            'Rejected: item % at store % would go negative (on hand %, movement %). Negative stock is disallowed by policy (see policy_assumptions.md).',
            NEW.item_id, NEW.store_id, v_current_qty, NEW.quantity;
    END IF;

    UPDATE stock_balances
       SET quantity_on_hand    = v_current_qty + NEW.quantity,
           last_transaction_id = NEW.transaction_id,
           updated_at          = now()
     WHERE store_id = NEW.store_id AND item_id = NEW.item_id;

    IF NEW.batch_id IS NOT NULL THEN
        UPDATE batches
           SET remaining_qty = remaining_qty + NEW.quantity
         WHERE batch_id = NEW.batch_id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_apply_transaction_line
    AFTER INSERT ON inventory_transaction_lines
    FOR EACH ROW EXECUTE FUNCTION fn_apply_transaction_line();

-- =============================================================================
-- 7. REQUISITIONS & APPROVALS
-- =============================================================================

CREATE TABLE requisitions (
    requisition_id     serial              NOT NULL PRIMARY KEY,
    requisition_number varchar(30)         NOT NULL UNIQUE,
    department_id      integer             NOT NULL REFERENCES departments(department_id),
    requested_by       integer             NOT NULL REFERENCES users(user_id),
    store_id           integer             NOT NULL REFERENCES stores(store_id),
    status             requisition_status  NOT NULL DEFAULT 'draft',
    justification      text,
    needed_by          date,
    created_at         timestamptz         NOT NULL DEFAULT now()
);

CREATE TABLE requisition_lines (
    line_id            serial        NOT NULL PRIMARY KEY,
    requisition_id     integer       NOT NULL REFERENCES requisitions(requisition_id),
    item_id            integer       NOT NULL REFERENCES items(item_id),
    quantity_requested numeric(12,3) NOT NULL CHECK (quantity_requested > 0),
    quantity_approved  numeric(12,3),
    unit_id            integer       NOT NULL REFERENCES units(unit_id)
);

CREATE TABLE approvals (
    approval_id     serial            NOT NULL PRIMARY KEY,
    approvable_type varchar(30)       NOT NULL CHECK (approvable_type IN
                        ('requisition', 'purchase_order', 'stock_adjustment', 'stocktake')),
    approvable_id   integer           NOT NULL,
    approver_id     integer           NOT NULL REFERENCES users(user_id),
    decision        approval_decision NOT NULL,
    comments        text,
    decided_at      timestamptz       NOT NULL DEFAULT now()
);

CREATE INDEX idx_approvals_target ON approvals (approvable_type, approvable_id);

-- =============================================================================
-- 8. PROCUREMENT: PURCHASE ORDERS & GOODS RECEIVED NOTES
-- =============================================================================

CREATE TABLE purchase_orders (
    po_id                 serial      NOT NULL PRIMARY KEY,
    po_number             varchar(30) NOT NULL UNIQUE,
    requisition_id        integer     REFERENCES requisitions(requisition_id),
    supplier_id           integer     NOT NULL REFERENCES suppliers(supplier_id),
    status                po_status   NOT NULL DEFAULT 'draft',
    order_date            date        NOT NULL DEFAULT current_date,
    expected_delivery_date date,
    created_by            integer     NOT NULL REFERENCES users(user_id),
    total_cost            numeric(12,2) NOT NULL DEFAULT 0,
    created_at            timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE purchase_order_lines (
    line_id           serial        NOT NULL PRIMARY KEY,
    po_id             integer       NOT NULL REFERENCES purchase_orders(po_id),
    item_id           integer       NOT NULL REFERENCES items(item_id),
    quantity_ordered  numeric(12,3) NOT NULL CHECK (quantity_ordered > 0),
    unit_id           integer       NOT NULL REFERENCES units(unit_id),
    unit_cost         numeric(10,2) NOT NULL CHECK (unit_cost >= 0),
    quantity_received numeric(12,3) NOT NULL DEFAULT 0
);

CREATE TABLE goods_received_notes (
    grn_id            serial                NOT NULL PRIMARY KEY,
    grn_number        varchar(30)           NOT NULL UNIQUE,
    po_id             integer               NOT NULL REFERENCES purchase_orders(po_id),
    supplier_id       integer               NOT NULL REFERENCES suppliers(supplier_id),
    delivery_note_ref varchar(60),
    store_id          integer               NOT NULL REFERENCES stores(store_id),
    received_by       integer               NOT NULL REFERENCES users(user_id),
    received_date     date                  NOT NULL DEFAULT current_date,
    inspection_status grn_inspection_status NOT NULL DEFAULT 'pending',
    remarks           text,
    created_at        timestamptz           NOT NULL DEFAULT now()
);

CREATE TABLE goods_received_lines (
    line_id           serial        NOT NULL PRIMARY KEY,
    grn_id            integer       NOT NULL REFERENCES goods_received_notes(grn_id),
    po_line_id        integer       REFERENCES purchase_order_lines(line_id),
    item_id           integer       NOT NULL REFERENCES items(item_id),
    quantity_ordered  numeric(12,3),
    quantity_delivered numeric(12,3) NOT NULL CHECK (quantity_delivered >= 0),
    quantity_accepted numeric(12,3) NOT NULL DEFAULT 0 CHECK (quantity_accepted >= 0),
    quantity_rejected numeric(12,3) NOT NULL DEFAULT 0 CHECK (quantity_rejected >= 0),
    unit_id           integer       NOT NULL REFERENCES units(unit_id),
    batch_number      varchar(60),
    manufacture_date  date,
    expiry_date       date,
    unit_cost         numeric(10,2) NOT NULL CHECK (unit_cost >= 0),
    rejection_reason  text,
    batch_id          integer       REFERENCES batches(batch_id),
    posted_transaction_id integer   REFERENCES inventory_transactions(transaction_id),
    CHECK (quantity_accepted + quantity_rejected <= quantity_delivered)
);

-- =============================================================================
-- 9. STOCK ISSUES & TRANSFERS
-- =============================================================================

CREATE TABLE stock_issues (
    issue_id        serial       NOT NULL PRIMARY KEY,
    issue_number    varchar(30)  NOT NULL UNIQUE,
    requisition_id  integer      REFERENCES requisitions(requisition_id),
    department_id   integer      NOT NULL REFERENCES departments(department_id),
    from_store_id   integer      NOT NULL REFERENCES stores(store_id),
    issued_by       integer      NOT NULL REFERENCES users(user_id),
    received_by     integer      REFERENCES users(user_id),
    issue_date      date         NOT NULL DEFAULT current_date,
    status          issue_status NOT NULL DEFAULT 'pending',
    created_at      timestamptz  NOT NULL DEFAULT now()
);

CREATE TABLE stock_issue_lines (
    line_id             serial        NOT NULL PRIMARY KEY,
    issue_id            integer       NOT NULL REFERENCES stock_issues(issue_id),
    item_id             integer       NOT NULL REFERENCES items(item_id),
    batch_id            integer       REFERENCES batches(batch_id),
    quantity_requested  numeric(12,3),
    quantity_approved   numeric(12,3),
    quantity_issued     numeric(12,3) NOT NULL CHECK (quantity_issued > 0),
    unit_id             integer       NOT NULL REFERENCES units(unit_id),
    posted_transaction_id integer     REFERENCES inventory_transactions(transaction_id)
);

CREATE TABLE stock_transfers (
    transfer_id     serial          NOT NULL PRIMARY KEY,
    transfer_number varchar(30)     NOT NULL UNIQUE,
    from_store_id   integer         NOT NULL REFERENCES stores(store_id),
    to_store_id     integer         NOT NULL REFERENCES stores(store_id),
    requested_by    integer         NOT NULL REFERENCES users(user_id),
    approved_by     integer         REFERENCES users(user_id),
    transfer_date   date            NOT NULL DEFAULT current_date,
    status          transfer_status NOT NULL DEFAULT 'pending',
    created_at      timestamptz     NOT NULL DEFAULT now(),
    CHECK (from_store_id <> to_store_id)
);

CREATE TABLE stock_transfer_lines (
    line_id      serial        NOT NULL PRIMARY KEY,
    transfer_id  integer       NOT NULL REFERENCES stock_transfers(transfer_id),
    item_id      integer       NOT NULL REFERENCES items(item_id),
    batch_id     integer       REFERENCES batches(batch_id),
    quantity     numeric(12,3) NOT NULL CHECK (quantity > 0),
    unit_id      integer       NOT NULL REFERENCES units(unit_id),
    out_transaction_id integer REFERENCES inventory_transactions(transaction_id),
    in_transaction_id  integer REFERENCES inventory_transactions(transaction_id)
);

-- =============================================================================
-- 10. STOCKTAKING
-- =============================================================================

CREATE TABLE stocktakes (
    stocktake_id     serial          NOT NULL PRIMARY KEY,
    stocktake_number varchar(30)     NOT NULL UNIQUE,
    store_id         integer         NOT NULL REFERENCES stores(store_id),
    stocktake_type   stocktake_type  NOT NULL,
    status           stocktake_status NOT NULL DEFAULT 'draft',
    scheduled_date   date            NOT NULL DEFAULT current_date,
    conducted_by     integer         REFERENCES users(user_id),
    approved_by      integer         REFERENCES users(user_id),
    created_at       timestamptz     NOT NULL DEFAULT now()
);

CREATE TABLE stocktake_lines (
    line_id             serial        NOT NULL PRIMARY KEY,
    stocktake_id        integer       NOT NULL REFERENCES stocktakes(stocktake_id),
    item_id             integer       NOT NULL REFERENCES items(item_id),
    batch_id            integer       REFERENCES batches(batch_id),
    system_quantity     numeric(12,3) NOT NULL,
    counted_quantity    numeric(12,3),
    variance_quantity   numeric(12,3) GENERATED ALWAYS AS (counted_quantity - system_quantity) STORED,
    unit_cost           numeric(10,2),
    investigation_notes text,
    posted_transaction_id integer    REFERENCES inventory_transactions(transaction_id)
);

-- =============================================================================
-- 11. WASTAGE
-- =============================================================================

CREATE TABLE wastage (
    wastage_id     serial         NOT NULL PRIMARY KEY,
    item_id        integer        NOT NULL REFERENCES items(item_id),
    store_id       integer        NOT NULL REFERENCES stores(store_id),
    batch_id       integer        REFERENCES batches(batch_id),
    quantity       numeric(12,3)  NOT NULL CHECK (quantity > 0),
    unit_id        integer        NOT NULL REFERENCES units(unit_id),
    reason         wastage_reason NOT NULL,
    wastage_date   date           NOT NULL DEFAULT current_date,
    recorded_by    integer        NOT NULL REFERENCES users(user_id),
    department_id  integer        REFERENCES departments(department_id),
    unit_cost      numeric(10,2),
    notes          text,
    posted_transaction_id integer REFERENCES inventory_transactions(transaction_id),
    created_at     timestamptz    NOT NULL DEFAULT now()
);

-- =============================================================================
-- 12. KITCHEN CONSUMPTION
-- =============================================================================

CREATE TABLE kitchen_consumption_logs (
    log_id            serial        NOT NULL PRIMARY KEY,
    issue_line_id     integer       REFERENCES stock_issue_lines(line_id),
    item_id           integer       NOT NULL REFERENCES items(item_id),
    department_id     integer       NOT NULL REFERENCES departments(department_id),
    consumption_date  date          NOT NULL DEFAULT current_date,
    quantity_issued   numeric(12,3) NOT NULL DEFAULT 0,
    quantity_used     numeric(12,3) NOT NULL DEFAULT 0,
    quantity_returned numeric(12,3) NOT NULL DEFAULT 0,
    quantity_wasted   numeric(12,3) NOT NULL DEFAULT 0,
    recorded_by       integer       NOT NULL REFERENCES users(user_id),
    notes             text,
    created_at        timestamptz   NOT NULL DEFAULT now()
);

-- =============================================================================
-- 13. NUTRITION REQUIREMENT PLANNING
-- =============================================================================

CREATE TABLE nutrition_requirements (
    requirement_id     serial        NOT NULL PRIMARY KEY,
    item_id            integer       NOT NULL REFERENCES items(item_id),
    department_id      integer       NOT NULL REFERENCES departments(department_id),
    period_month       date          NOT NULL,
    required_quantity  numeric(12,3) NOT NULL CHECK (required_quantity >= 0),
    unit_id            integer       NOT NULL REFERENCES units(unit_id),
    created_by         integer       NOT NULL REFERENCES users(user_id),
    created_at         timestamptz   NOT NULL DEFAULT now(),
    UNIQUE (item_id, department_id, period_month)
);

-- =============================================================================
-- 14. ALERTS, AUDIT & CONFIGURATION
-- =============================================================================

CREATE TABLE alerts (
    alert_id     serial         NOT NULL PRIMARY KEY,
    alert_type   alert_type     NOT NULL,
    item_id      integer        REFERENCES items(item_id),
    store_id     integer        REFERENCES stores(store_id),
    severity     alert_severity NOT NULL,
    message      text           NOT NULL,
    is_resolved  boolean        NOT NULL DEFAULT false,
    generated_at timestamptz    NOT NULL DEFAULT now(),
    resolved_at  timestamptz
);

CREATE TABLE audit_logs (
    audit_id    serial      NOT NULL PRIMARY KEY,
    user_id     integer     REFERENCES users(user_id),
    action      varchar(60) NOT NULL,
    entity_type varchar(60) NOT NULL,
    entity_id   integer,
    old_value   jsonb,
    new_value   jsonb,
    reference   varchar(60),
    ip_address  inet,
    created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE system_configuration (
    config_key   varchar(80) NOT NULL PRIMARY KEY,
    config_value text        NOT NULL,
    description  text,
    updated_at   timestamptz NOT NULL DEFAULT now(),
    updated_by   integer     REFERENCES users(user_id)
);

-- =============================================================================
-- 15. HELPFUL INDEXES
-- =============================================================================

CREATE INDEX idx_items_category   ON items (category_id);
CREATE INDEX idx_batches_item     ON batches (item_id, store_id);
CREATE INDEX idx_batches_expiry   ON batches (expiry_date) WHERE remaining_qty > 0;
CREATE INDEX idx_requisitions_dept ON requisitions (department_id, status);
CREATE INDEX idx_po_supplier      ON purchase_orders (supplier_id, status);
CREATE INDEX idx_alerts_open      ON alerts (is_resolved, severity);
CREATE INDEX idx_audit_entity     ON audit_logs (entity_type, entity_id);
