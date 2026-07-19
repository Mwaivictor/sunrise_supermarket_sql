-- =============================================================
-- Sunrise Supermarket — Sample Data (INSERT / UPDATE / DELETE)
-- Run after 01_schema.sql
-- =============================================================

SET search_path TO sunrise;


-- Seed data ---------------------------------------------------

INSERT INTO customers (full_name, email, phone_number, city)
VALUES
    ('Grace Wambui', 'grace.wambui@gmail.com', '0711223344', 'Nairobi'),
    ('Kevin Mutiso', 'kevin.mutiso@gmail.com', '0722334455', 'Nakuru'),
    ('Faith Chebet', 'faith.chebet@gmail.com', '0733445566', 'Eldoret'),
    ('Ibrahim Noor', 'ibrahim.noor@gmail.com', '0744556677', 'Mombasa');

INSERT INTO products (product_name, category, unit_price, stock_quantity)
VALUES
    ('Maize Flour 2kg', 'Groceries',  180.00,  50),
    ('Cooking Oil 1L',  'Groceries',  320.00,  30),
    ('Bathing Soap',    'Toiletries',  85.00, 100),
    ('Notebook A4',     'Stationery',  60.00, 200);

INSERT INTO orders (customer_id, order_date, status)
VALUES
    (1, '2024-04-01', 'delivered'),
    (2, '2024-03-02', 'pending'),
    (1, '2024-03-03', 'delivered'),
    (3, '2024-03-04', 'cancelled');

INSERT INTO order_items (order_id, product_id, quantity)
VALUES
    (1, 1, 2),
    (1, 3, 1),
    (2, 2, 1),
    (3, 4, 5);


-- Updates -----------------------------------------------------

-- Order 2 was fulfilled. Both order_id and order_date are used in
-- the WHERE clause so the update cannot silently affect other rows.
UPDATE orders
SET status = 'delivered'
WHERE order_id = 2
  AND order_date = '2024-03-02';


-- Deletes -----------------------------------------------------

-- Before deleting order 4, check for child rows in order_items.
-- If any existed, PostgreSQL would reject the DELETE with a
-- foreign key violation and the children would have to go first.
SELECT *
FROM order_items
WHERE order_id = 4;
-- -> 0 rows, so the parent can be removed safely.

DELETE FROM orders
WHERE order_id = 4;
