-- =============================================================
-- Sunrise Supermarket: Schema Definition
-- PostgreSQL 16
--
-- Creates the `sunrise` schema, the order_status ENUM, and the
-- four core tables with their integrity constraints.
-- Run order: 01_schema.sql -> 02_data.sql -> 03_queries.sql
-- =============================================================

CREATE SCHEMA sunrise;

SET search_path TO sunrise;


-- Customers ---------------------------------------------------
CREATE TABLE customers (
    customer_id  serial       NOT NULL PRIMARY KEY,
    full_name    varchar(100) NOT NULL,
    email        varchar(150) NOT NULL UNIQUE,
    phone_number varchar(15)  NOT NULL UNIQUE,
    city         varchar(50)  NOT NULL
);


-- Products ----------------------------------------------------
CREATE TABLE products (
    product_id   serial        NOT NULL PRIMARY KEY,
    product_name varchar(50)   NOT NULL,
    category     varchar(50)   NOT NULL,
    unit_price   decimal(10,2) NOT NULL CHECK (unit_price >= 0),
    stock        int           NOT NULL CHECK (stock >= 0) DEFAULT 0
);


-- Order status ENUM -------------------------------------------
CREATE TYPE order_status AS ENUM (
    'pending',
    'delivered',
    'cancelled'
);


-- Orders ------------------------------------------------------
CREATE TABLE orders (
    order_id    serial       NOT NULL PRIMARY KEY,
    customer_id int          NOT NULL REFERENCES customers(customer_id),
    order_date  date         DEFAULT current_date,
    status      order_status NOT NULL DEFAULT 'pending'
);


-- Order items (junction table: orders <-> products) ------------
CREATE TABLE order_items (
    order_item_id serial NOT NULL PRIMARY KEY,
    order_id      int    NOT NULL REFERENCES orders(order_id),
    product_id    int    NOT NULL REFERENCES products(product_id),
    quantity      int    NOT NULL CHECK (quantity > 0)
);


-- =============================================================
-- Schema evolution
-- Requirements changed after the initial design; these ALTER
-- statements are kept to document how the schema migrated.
-- =============================================================

-- `stock` was ambiguous; renamed for clarity.
ALTER TABLE products
    RENAME COLUMN stock TO stock_quantity;

-- Loyalty programme added after launch. Defaulted to 0 so
-- existing rows stay valid under the NOT NULL constraint.
ALTER TABLE customers
    ADD COLUMN loyalty_points int NOT NULL CHECK (loyalty_points >= 0) DEFAULT 0;

-- varchar(50) truncated longer product names.
ALTER TABLE products
    ALTER COLUMN product_name TYPE varchar(150);
