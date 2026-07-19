-- =============================================================
-- Sunrise Supermarket: Business Queries
-- Run after 01_schema.sql and 02_data.sql
--
-- Logical clause order used throughout:
--   SELECT -> FROM -> WHERE -> GROUP BY -> HAVING -> ORDER BY -> LIMIT
-- =============================================================

SET search_path TO sunrise;


-- -------------------------------------------------------------
-- 1. FILTERING
-- -------------------------------------------------------------

-- Q1: Which products cost more than KES 100?
SELECT product_name, unit_price
FROM products
WHERE unit_price > 100.00;

-- Q2: Which customers are based outside Nairobi?
SELECT *
FROM customers
WHERE city <> 'Nairobi';

-- Q3: Which products fall in the KES 60-200 price band?
SELECT *
FROM products
WHERE unit_price BETWEEN 60 AND 200;

-- Q4: Which customers live in our three priority cities?
SELECT *
FROM customers
WHERE city IN ('Nakuru', 'Nairobi', 'Mombasa');

-- Q5: Which products have "Oil" in the name? (wildcard search)
SELECT *
FROM products
WHERE product_name LIKE '%Oil%';

-- Q6: Which orders are still awaiting fulfilment?
SELECT *
FROM orders
WHERE status = 'pending';


-- -------------------------------------------------------------
-- 2. SORTING & LIMITING
-- -------------------------------------------------------------

-- Q7: What are the two most expensive products?
SELECT *
FROM products
ORDER BY unit_price DESC
LIMIT 2;


-- -------------------------------------------------------------
-- 3. AGGREGATION
-- -------------------------------------------------------------

-- Q8: How many orders has each customer placed?
SELECT
    customer_id,
    COUNT(*) AS order_count
FROM orders
GROUP BY customer_id;

-- Q9: Which customers are repeat buyers (more than one order)?
-- HAVING filters the aggregated groups; WHERE could not do this.
SELECT
    customer_id,
    COUNT(*) AS order_count
FROM orders
GROUP BY customer_id
HAVING COUNT(*) > 1;


-- -------------------------------------------------------------
-- 4. JOINS
-- -------------------------------------------------------------

-- Q10: Which customer placed each order?
-- INNER JOIN: only orders that have a matching customer.
SELECT
    c.full_name,
    o.order_id,
    o.status
FROM customers AS c
INNER JOIN orders AS o
    ON c.customer_id = o.customer_id;

-- Q11: Which orders have no line items attached?
-- LEFT JOIN keeps every order; empty ones show NULL on the right.
SELECT
    o.order_id,
    oi.product_id,
    oi.quantity
FROM orders AS o
LEFT JOIN order_items AS oi
    ON o.order_id = oi.order_id;

-- Q12: Which products were purchased in each order?
-- INNER JOIN chosen deliberately: we only want line items that
-- resolve to a real product.
SELECT
    oi.order_id,
    p.product_name,
    p.category,
    oi.quantity
FROM products AS p
INNER JOIN order_items AS oi
    ON p.product_id = oi.product_id;

-- Q13: Full order detail across all four tables.
SELECT
    c.full_name,
    o.order_id,
    p.product_name,
    oi.quantity
FROM customers AS c
JOIN orders AS o
    ON c.customer_id = o.customer_id
JOIN order_items AS oi
    ON o.order_id = oi.order_id
JOIN products AS p
    ON p.product_id = oi.product_id;

-- Q14: What is the total quantity sold per product?
SELECT
    p.product_name,
    SUM(oi.quantity) AS total_quantity
FROM customers AS c
INNER JOIN orders AS o
    ON c.customer_id = o.customer_id
INNER JOIN order_items AS oi
    ON o.order_id = oi.order_id
INNER JOIN products AS p
    ON p.product_id = oi.product_id
GROUP BY p.product_name
ORDER BY total_quantity DESC;
