# SQL Notes

Working notes from building the Sunrise Supermarket database. Every example is real code from this project, not invented syntax.

PostgreSQL 16. Some of this is Postgres-specific and is flagged where it matters.


## Contents

- [1. Mental model](#1-mental-model)
- [2. Schemas and search_path](#2-schemas-and-search_path)
- [3. Creating tables (DDL)](#3-creating-tables-ddl)
- [4. Data types](#4-data-types)
- [5. Constraints](#5-constraints)
- [6. Keys and relationships](#6-keys-and-relationships)
- [7. ENUM types](#7-enum-types)
- [8. Changing an existing schema (ALTER TABLE)](#8-changing-an-existing-schema-alter-table)
- [9. Inserting data](#9-inserting-data)
- [10. Updating data](#10-updating-data)
- [11. Deleting data](#11-deleting-data)
- [12. SELECT and clause order](#12-select-and-clause-order)
- [13. Filtering with WHERE](#13-filtering-with-where)
- [14. Pattern matching with LIKE](#14-pattern-matching-with-like)
- [15. NULL handling](#15-null-handling)
- [16. Sorting and limiting](#16-sorting-and-limiting)
- [17. Aggregate functions](#17-aggregate-functions)
- [18. GROUP BY and HAVING](#18-group-by-and-having)
- [19. JOINs](#19-joins)
- [20. Aliases](#20-aliases)
- [21. Comments](#21-comments)
- [22. Useful psql commands](#22-useful-psql-commands)
- [23. Mistakes made and lessons learned](#23-mistakes-made-and-lessons-learned)
- [24. Not yet covered](#24-not-yet-covered)


## 1. Mental model

SQL splits into sublanguages. Knowing which one a command belongs to explains its behaviour.

| Sublanguage | Stands for | Commands | What it touches |
|---|---|---|---|
| **DDL** | Data Definition Language | `CREATE`, `ALTER`, `DROP`, `TRUNCATE` | The structure |
| **DML** | Data Manipulation Language | `INSERT`, `UPDATE`, `DELETE` | The rows |
| **DQL** | Data Query Language | `SELECT` | Reading rows |
| **DCL** | Data Control Language | `GRANT`, `REVOKE` | Permissions |
| **TCL** | Transaction Control Language | `COMMIT`, `ROLLBACK`, `SAVEPOINT` | Grouping changes |

A key practical difference: in PostgreSQL, DDL is transactional. You can `BEGIN`, `CREATE TABLE`, then `ROLLBACK` and the table is gone. MySQL cannot do this.


## 2. Schemas and search_path

A schema is a namespace inside a database. It prevents table name collisions and groups related objects.

```sql
CREATE SCHEMA sunrise;
```

Without setting a path, every reference needs qualifying:

```sql
SELECT * FROM sunrise.customers;
```

`search_path` sets where unqualified names are looked up:

```sql
SET search_path TO sunrise;

SELECT * FROM customers;   -- now resolves to sunrise.customers
```

**Important:** `SET search_path` lasts only for the current session. Open a new psql window or a new pgAdmin query tab and it resets to `public`. This is the single most common source of "relation does not exist" errors. Every script in this project re-declares it at the top for exactly that reason.

To set it permanently for a database:

```sql
ALTER DATABASE sunrise_supermarket SET search_path TO sunrise;
```


## 3. Creating tables (DDL)

```sql
CREATE TABLE table_name (
    column_name  data_type  [constraints],
    column_name  data_type  [constraints],
    ...
);
```

Real example:

```sql
CREATE TABLE customers (
    customer_id  serial       NOT NULL PRIMARY KEY,
    full_name    varchar(100) NOT NULL,
    email        varchar(150) NOT NULL UNIQUE,
    phone_number varchar(15)  NOT NULL UNIQUE,
    city         varchar(50)  NOT NULL
);
```

Safe variants:

```sql
CREATE TABLE IF NOT EXISTS customers (...);   -- skip if it exists
DROP TABLE IF EXISTS customers;               -- no error if absent
DROP TABLE customers CASCADE;                 -- also drop dependent objects
```

`CASCADE` is worth respecting. It silently drops foreign keys in other tables that point at this one.


## 4. Data types

The ones used here, and why each was chosen.

| Type | Used for | Notes |
|---|---|---|
| `serial` | All primary keys | Auto-incrementing integer. Postgres shorthand for `integer NOT NULL DEFAULT nextval(...)`. Modern equivalent is `GENERATED ALWAYS AS IDENTITY` |
| `varchar(n)` | Names, emails, cities | Variable length with a hard cap. Errors if you exceed `n` |
| `text` | Not used here | Unlimited length. In Postgres it performs identically to `varchar`, so `varchar(n)` is really a constraint, not an optimisation |
| `int` | Quantities, FKs, points | 4 bytes, roughly ±2.1 billion |
| `decimal(10,2)` | `unit_price` | Exact. 10 total digits, 2 after the point. Synonym for `numeric` |
| `date` | `order_date` | Date only, no time |
| `order_status` | `status` | Custom ENUM, see section 7 |

**Never use `float` or `real` for money.** Floating point cannot represent 0.1 exactly, so totals drift by fractions of a cent and the errors compound across a sum. `decimal` / `numeric` stores the value exactly.

Other common types worth knowing: `boolean`, `timestamp`, `timestamptz` (timezone-aware, usually the right choice over `timestamp`), `bigint`, `uuid`, `jsonb`.


## 5. Constraints

Constraints push data rules into the database, where every client is subject to them.

| Constraint | Guarantees | Example from this project |
|---|---|---|
| `PRIMARY KEY` | Unique **and** not null. One per table | `customer_id serial PRIMARY KEY` |
| `FOREIGN KEY` | Value must exist in the referenced table | `customer_id int REFERENCES customers(customer_id)` |
| `UNIQUE` | No duplicates. Allows multiple NULLs | `email varchar(150) UNIQUE` |
| `NOT NULL` | Value required | `full_name varchar(100) NOT NULL` |
| `DEFAULT` | Value used when none supplied | `order_date date DEFAULT current_date` |
| `CHECK` | Custom boolean rule | `unit_price decimal(10,2) CHECK (unit_price >= 0)` |

Two ways to write them:

```sql
-- Column level: applies to one column
unit_price decimal(10,2) NOT NULL CHECK (unit_price >= 0)

-- Table level: required when the rule spans multiple columns
CREATE TABLE orders (
    ...
    CONSTRAINT valid_date CHECK (order_date <= current_date)
);
```

Naming a constraint with `CONSTRAINT name` means error messages say `valid_date` instead of `orders_check1`, and you can drop it by name later. Worth doing on anything non-obvious.

**`UNIQUE` and NULL:** a `UNIQUE` column accepts many NULL rows, because NULL is not equal to anything, including another NULL. If a column must be genuinely unique, pair `UNIQUE` with `NOT NULL`, as `email` and `phone_number` do here.


## 6. Keys and relationships

**Primary key:** uniquely identifies a row. **Foreign key:** points at a primary key elsewhere, and the database refuses any value that does not exist there.

```sql
CREATE TABLE orders (
    order_id    serial PRIMARY KEY,
    customer_id int NOT NULL REFERENCES customers(customer_id),
    ...
);
```

That single `REFERENCES` clause makes it impossible to record an order for customer 99 when no such customer exists.

### Relationship cardinalities

| Type | Meaning | Implementation |
|---|---|---|
| One-to-many | One customer has many orders | FK on the "many" side (`orders.customer_id`) |
| Many-to-many | Orders contain many products; products appear in many orders | A third **junction table** |
| One-to-one | Rare | FK plus a `UNIQUE` constraint on it |

### The junction table

A many-to-many relationship cannot be expressed with a column on either side. `order_items` resolves it:

```sql
CREATE TABLE order_items (
    order_item_id serial PRIMARY KEY,
    order_id      int NOT NULL REFERENCES orders(order_id),
    product_id    int NOT NULL REFERENCES products(product_id),
    quantity      int NOT NULL CHECK (quantity > 0)
);
```

Note where `quantity` lives. It describes the pairing of an order with a product, not the order alone and not the product alone, so the junction table is its only correct home. Spotting which attributes belong to the relationship rather than to either entity is the core skill in schema design.

### Referential actions

By default a parent row cannot be deleted while children reference it. That default can be changed:

```sql
order_id int REFERENCES orders(order_id) ON DELETE CASCADE     -- delete children too
order_id int REFERENCES orders(order_id) ON DELETE SET NULL    -- orphan them
order_id int REFERENCES orders(order_id) ON DELETE RESTRICT    -- block it (the default)
```

This project uses the default deliberately. `CASCADE` on financial records means deleting one order silently destroys its line items and the sales history with them.

## 7. ENUM types

A custom type restricted to a fixed list of values.

```sql
CREATE TYPE order_status AS ENUM (
    'pending',
    'delivered',
    'cancelled'
);

CREATE TABLE orders (
    ...
    status order_status NOT NULL DEFAULT 'pending'
);
```

The advantage over `varchar`: `'delivrd'` is rejected on write. With a plain `varchar` the typo is stored happily, and then that row is silently absent from every report filtering on `status = 'delivered'`. A bug that hides rows is far worse than one that throws an error.

Managing an ENUM:

```sql
ALTER TYPE order_status ADD VALUE 'refunded';
ALTER TYPE order_status ADD VALUE 'refunded' BEFORE 'cancelled';

SELECT unnest(enum_range(NULL::order_status));   -- list all values
```

**Limitation:** removing or renaming an ENUM value is awkward and may need the type rebuilt. For a list that changes often, a lookup table with a foreign key is more flexible. For a stable list like order status, the ENUM is the better fit.


## 8. Changing an existing schema (ALTER TABLE)

Requirements change after tables hold data. `ALTER TABLE` migrates them without a rebuild.

```sql
-- Rename a column
ALTER TABLE products RENAME COLUMN stock TO stock_quantity;

-- Add a column
ALTER TABLE customers
    ADD COLUMN loyalty_points int NOT NULL CHECK (loyalty_points >= 0) DEFAULT 0;

-- Change a type
ALTER TABLE products ALTER COLUMN product_name TYPE varchar(150);

-- Other common forms
ALTER TABLE products DROP COLUMN discontinued;
ALTER TABLE products ALTER COLUMN category SET NOT NULL;
ALTER TABLE products ALTER COLUMN category DROP NOT NULL;
ALTER TABLE products ADD CONSTRAINT positive_price CHECK (unit_price > 0);
ALTER TABLE products DROP CONSTRAINT positive_price;
ALTER TABLE products RENAME TO inventory;
```

**The lesson from the `loyalty_points` migration:** adding a `NOT NULL` column to a table that already has rows fails, because those rows would need a value they do not have. `DEFAULT 0` supplies one and the migration succeeds. Order of thinking: does this column need a default *because* existing rows must satisfy it?

**Widening versus narrowing a type:** `varchar(50)` to `varchar(150)` always works, since every existing value still fits. Going the other way fails if any row is too long. Widening is safe; narrowing needs the data checked first.


## 9. Inserting data

```sql
INSERT INTO table_name (col1, col2, col3)
VALUES
    (val1, val2, val3),
    (val1, val2, val3);
```

```sql
INSERT INTO products (product_name, category, unit_price, stock_quantity)
VALUES
    ('Maize Flour 2kg', 'Groceries',  180.00,  50),
    ('Cooking Oil 1L',  'Groceries',  320.00,  30);
```

Points that matter:

- **Always name the columns.** `INSERT INTO products VALUES (...)` depends on column order, and breaks the day someone adds a column.
- **Omit `serial` primary keys.** The sequence supplies them. Passing your own value does not advance the sequence and causes duplicate key errors later.
- **Omit columns with a useful `DEFAULT`.** Leaving out `status` gives `'pending'`; leaving out `order_date` gives today.
- **Single quotes for strings, never double.** In Postgres, `"Nairobi"` is read as an identifier (a column name) and errors. Escape an apostrophe by doubling it: `'O''Brien'`.
- **Insertion order follows dependencies.** Customers and products before orders, orders before order_items. A foreign key cannot point at a row that does not exist yet.

Returning generated values, a genuinely useful Postgres feature:

```sql
INSERT INTO customers (full_name, email, phone_number, city)
VALUES ('Jane Doe', 'jane@example.com', '0700000000', 'Nairobi')
RETURNING customer_id;
```


## 10. Updating data

```sql
UPDATE table_name
SET column = value
WHERE condition;
```

```sql
UPDATE orders
SET status = 'delivered'
WHERE order_id = 2
  AND order_date = '2024-03-02';
```

**`UPDATE` without `WHERE` rewrites every row in the table.** There is no confirmation prompt and no undo outside a transaction.

The habit that prevents it: write the `SELECT` first, confirm the row count, then convert it to an `UPDATE`.

```sql
SELECT * FROM orders WHERE order_id = 2;   -- check what will be hit
UPDATE orders SET status = 'delivered' WHERE order_id = 2;
```

Or work inside a transaction, where a wrong result can be undone:

```sql
BEGIN;
UPDATE orders SET status = 'delivered' WHERE order_id = 2;
-- inspect the result
COMMIT;   -- or ROLLBACK to undo
```

Multiple columns in one statement:

```sql
UPDATE products
SET unit_price = 200.00,
    stock_quantity = stock_quantity - 5
WHERE product_id = 1;
```

Note `stock_quantity = stock_quantity - 5`. The right side reads the existing value, so updates can be relative rather than absolute.


## 11. Deleting data

```sql
DELETE FROM orders
WHERE order_id = 4;
```

Same warning: no `WHERE` empties the table.

### Checking children before deleting a parent

This was the most useful lesson in the project. Before deleting order 4:

```sql
SELECT * FROM order_items WHERE order_id = 4;
-- 0 rows, so the delete is safe
DELETE FROM orders WHERE order_id = 4;
```

Had any `order_items` referenced order 4, Postgres would have rejected the delete:

```
ERROR: update or delete on table "orders" violates foreign key constraint
DETAIL: Key (order_id)=(4) is still referenced from table "order_items".
```

The fix in that case is to delete children first, then the parent. **Deletion order is the reverse of insertion order.** Insert parents before children; delete children before parents.

That error is the foreign key working correctly. It is preventing orphaned rows.

### DELETE vs TRUNCATE vs DROP

| Command | Removes | Keeps table | Can filter | Speed |
|---|---|---|---|---|
| `DELETE FROM t` | Rows | Yes | Yes, with `WHERE` | Slow, row by row |
| `TRUNCATE t` | All rows | Yes | No | Fast |
| `DROP TABLE t` | Rows and table | No | No | Fast |

`TRUNCATE` also resets `serial` sequences with `RESTART IDENTITY`.


## 12. SELECT and clause order

Two different orders, and confusing them causes real errors.

**Written order** (how you type it):

```
SELECT    columns
FROM      table
WHERE     row filter
GROUP BY  grouping
HAVING    group filter
ORDER BY  sorting
LIMIT     row cap
```

**Execution order** (how the database runs it):

```
FROM  ->  WHERE  ->  GROUP BY  ->  HAVING  ->  SELECT  ->  ORDER BY  ->  LIMIT
```

Execution order explains two things that otherwise look arbitrary:

1. **`WHERE` cannot use aggregates.** `WHERE COUNT(*) > 1` fails because `WHERE` runs before `GROUP BY` has formed any groups. That is what `HAVING` is for.
2. **`ORDER BY` can use a `SELECT` alias but `WHERE` cannot.** `ORDER BY` runs after `SELECT`, so the alias exists by then. `WHERE` runs before it and the alias does not exist yet.

```sql
SELECT product_name, unit_price * 1.16 AS price_with_vat
FROM products
ORDER BY price_with_vat;              -- works, ORDER BY runs after SELECT

SELECT product_name, unit_price * 1.16 AS price_with_vat
FROM products
WHERE price_with_vat > 100;           -- ERROR: column does not exist
```


## 13. Filtering with WHERE

### Comparison operators

| Operator | Meaning |
|---|---|
| `=` | Equal |
| `<>` or `!=` | Not equal (`<>` is the SQL standard; both work in Postgres) |
| `>` `<` | Greater / less than |
| `>=` `<=` | Greater / less than or equal |

### Logical operators

`AND`, `OR`, `NOT`. `AND` binds tighter than `OR`, so parentheses are not optional when mixing them:

```sql
-- These mean different things
WHERE city = 'Nairobi' OR city = 'Nakuru' AND loyalty_points > 100
WHERE (city = 'Nairobi' OR city = 'Nakuru') AND loyalty_points > 100
```

The first returns all Nairobi customers regardless of points. Parenthesise whenever both appear.

### Range and set operators

```sql
-- BETWEEN is inclusive on both ends
SELECT * FROM products WHERE unit_price BETWEEN 60 AND 200;
-- identical to: unit_price >= 60 AND unit_price <= 200

-- IN, cleaner than chained ORs
SELECT * FROM customers WHERE city IN ('Nakuru', 'Nairobi', 'Mombasa');

-- Negated forms
WHERE unit_price NOT BETWEEN 60 AND 200
WHERE city NOT IN ('Nairobi')
```

**A trap with `NOT IN`:** if the list contains a NULL, `NOT IN` returns no rows at all. `NOT IN (1, 2, NULL)` evaluates to unknown for every row. `NOT EXISTS` is safer against subqueries that might produce NULLs.

## 14. Pattern matching with LIKE

| Wildcard | Matches |
|---|---|
| `%` | Any sequence of characters, including none |
| `_` | Exactly one character |

```sql
SELECT * FROM products WHERE product_name LIKE '%Oil%';   -- contains "Oil"
WHERE product_name LIKE 'Oil%'                            -- starts with
WHERE product_name LIKE '%Oil'                            -- ends with
WHERE product_name LIKE '_ilk'                            -- Milk, silk: 4 chars
```

`LIKE` is case-sensitive in Postgres. `ILIKE` is the case-insensitive version:

```sql
WHERE product_name ILIKE '%oil%';   -- matches Oil, OIL, oil
```

For portable case-insensitive matching, lowercase both sides instead:

```sql
WHERE LOWER(product_name) LIKE '%oil%';
```

**Performance note:** a leading `%` prevents a normal index from being used, because the database cannot know where the match begins. Fine on four rows, slow on four million. Full-text search or a trigram index solves it at scale.


## 15. NULL handling

NULL means *unknown*, not zero and not empty string. This has consequences.

```sql
WHERE city = NULL     -- never true, not even for NULL rows
WHERE city IS NULL    -- correct
WHERE city IS NOT NULL
```

Any comparison with NULL yields unknown, and unknown rows are excluded by `WHERE`.

NULL also propagates through arithmetic. `100 + NULL` is NULL. Substitute a fallback with `COALESCE`, which returns the first non-null argument:

```sql
SELECT product_name, COALESCE(stock_quantity, 0) AS stock FROM products;
```

Aggregates behave differently: `COUNT`, `SUM`, and `AVG` skip NULLs rather than returning NULL. This is why `COUNT(*)` and `COUNT(column)` can disagree, and why an `AVG` over a column with NULLs divides by the count of non-null values only.


## 16. Sorting and limiting

```sql
SELECT * FROM products
ORDER BY unit_price DESC
LIMIT 2;
```

- `ASC` is the default and can be omitted; `DESC` reverses it.
- Multiple sort keys apply left to right: `ORDER BY category ASC, unit_price DESC`.
- NULLs sort last in `ASC` and first in `DESC` by default. Override with `ORDER BY col DESC NULLS LAST`.
- `LIMIT n OFFSET m` skips `m` rows, the basis of pagination.

**`LIMIT` without `ORDER BY` returns an arbitrary set of rows.** Without an explicit sort there is no defined row order, so "the top 2" is only meaningful when `ORDER BY` states what "top" means.


## 17. Aggregate functions

These collapse many rows into one value.

| Function | Returns |
|---|---|
| `COUNT(*)` | Number of rows, NULLs included |
| `COUNT(col)` | Number of non-null values in `col` |
| `COUNT(DISTINCT col)` | Number of distinct non-null values |
| `SUM(col)` | Total |
| `AVG(col)` | Mean |
| `MIN(col)` / `MAX(col)` | Smallest / largest |

```sql
SELECT
    COUNT(*)        AS total_products,
    AVG(unit_price) AS average_price,
    MAX(unit_price) AS most_expensive
FROM products;
```

`COUNT(*)` versus `COUNT(col)` is a genuine distinction: on a column containing NULLs they return different numbers, and picking the wrong one quietly skews the result.


## 18. GROUP BY and HAVING

`GROUP BY` collapses rows that share a value, then applies aggregates per group.

```sql
SELECT
    customer_id,
    COUNT(*) AS order_count
FROM orders
GROUP BY customer_id;
```

**The rule:** every column in `SELECT` must either appear in `GROUP BY` or be wrapped in an aggregate. Anything else is ambiguous, because the group has many values for it and no way to choose.

```sql
-- ERROR: full_name is neither grouped nor aggregated
SELECT customer_id, full_name, COUNT(*)
FROM orders
GROUP BY customer_id;
```

`HAVING` filters groups after aggregation, which `WHERE` cannot do:

```sql
SELECT customer_id, COUNT(*) AS order_count
FROM orders
GROUP BY customer_id
HAVING COUNT(*) > 1;
```

| | Filters | Runs | Can use aggregates |
|---|---|---|---|
| `WHERE` | Individual rows | Before grouping | No |
| `HAVING` | Groups | After grouping | Yes |

Both can appear in one query, and should. Filter rows with `WHERE` first so fewer rows reach the grouping stage:

```sql
SELECT customer_id, COUNT(*) AS delivered_orders
FROM orders
WHERE status = 'delivered'      -- rows first
GROUP BY customer_id
HAVING COUNT(*) > 1;            -- then groups
```


## 19. JOINs

Joins combine rows from multiple tables using a related column.

```sql
SELECT columns
FROM table_a
JOIN table_b
    ON table_a.key = table_b.foreign_key;
```

### Types

| Join | Returns |
|---|---|
| `INNER JOIN` | Only rows matching in both tables |
| `LEFT JOIN` | All left rows, plus matches; NULLs where none |
| `RIGHT JOIN` | All right rows, plus matches |
| `FULL OUTER JOIN` | Everything from both, NULLs on either side |
| `CROSS JOIN` | Every combination (Cartesian product) |

`JOIN` alone means `INNER JOIN`. `LEFT OUTER JOIN` and `LEFT JOIN` are the same thing.

### INNER JOIN

```sql
SELECT c.full_name, o.order_id, o.status
FROM customers AS c
INNER JOIN orders AS o
    ON c.customer_id = o.customer_id;
```

A customer with no orders does not appear. Neither would an order with no customer, though the foreign key makes that impossible here.

### LEFT JOIN

```sql
SELECT o.order_id, oi.product_id, oi.quantity
FROM orders AS o
LEFT JOIN order_items AS oi
    ON o.order_id = oi.order_id;
```

Every order appears. Orders with no line items show NULL in the right-hand columns, which is exactly the information wanted: an order with nothing in it is a data problem worth seeing.

**Choosing between them:** ask whether the unmatched rows are noise or the point. If a missing match is itself a finding, use `LEFT JOIN`.

### Finding only the unmatched rows

A `LEFT JOIN` with a NULL check isolates rows that have no match, a genuinely common pattern:

```sql
SELECT o.order_id
FROM orders AS o
LEFT JOIN order_items AS oi
    ON o.order_id = oi.order_id
WHERE oi.order_id IS NULL;      -- orders with no line items at all
```

### Multi-table joins

Joins chain. Each new `JOIN` operates on the result so far:

```sql
SELECT
    c.full_name,
    o.order_id,
    p.product_name,
    oi.quantity
FROM customers AS c
JOIN orders AS o       ON c.customer_id = o.customer_id
JOIN order_items AS oi ON o.order_id = oi.order_id
JOIN products AS p     ON p.product_id = oi.product_id;
```

Customers connect to products only through orders and order_items. The junction table is what makes the path exist.

### Joins with aggregation

Combining both is where the useful business questions get answered:

```sql
SELECT
    p.product_name,
    SUM(oi.quantity) AS total_quantity
FROM order_items AS oi
INNER JOIN products AS p
    ON p.product_id = oi.product_id
GROUP BY p.product_name
ORDER BY total_quantity DESC;
```

**Worth knowing:** one `LEFT JOIN` in a chain followed by an `INNER JOIN` on the same optional table silently converts the whole thing back to an inner join, because the inner join discards the NULL rows the left join just preserved. If a chain mixes both, order matters.


## 20. Aliases

```sql
SELECT c.full_name AS customer, COUNT(*) AS order_count
FROM customers AS c
JOIN orders AS o ON c.customer_id = o.customer_id
GROUP BY c.full_name;
```

`AS` is optional for tables (`FROM customers c` works) but including it reads better. For column aliases containing spaces or capitals, use double quotes: `AS "Total Sales"`. Postgres folds unquoted identifiers to lowercase, so `AS TotalSales` becomes `totalsales`.

Qualifying every column with its table alias in a multi-table query prevents ambiguous column errors and makes the query readable months later.


## 21. Comments

```sql
-- single line

/* multi
   line */
```

A quirk seen in this project: `---` is not a special syntax. It is just `--` followed by another dash, so it comments the line out identically.


## 22. Useful psql commands

Backslash commands work in `psql`, not in pgAdmin's query editor.

| Command | Does |
|---|---|
| `\l` | List databases |
| `\c dbname` | Connect to a database |
| `\dt` | List tables in the search path |
| `\dt sunrise.*` | List tables in a specific schema |
| `\d tablename` | Describe a table: columns, types, constraints, indexes |
| `\dn` | List schemas |
| `\dT+` | List custom types, including ENUM values |
| `\df` | List functions |
| `\x` | Toggle expanded output, useful for wide rows |
| `\i file.sql` | Run a script |
| `\q` | Quit |

From the shell:

```bash
createdb sunrise_supermarket
dropdb sunrise_supermarket
psql -d sunrise_supermarket -f 01_schema.sql
pg_dump sunrise_supermarket > backup.sql
```

`\d tablename` is the single most useful one. It shows every constraint on a table, which is how you verify a migration did what you intended.


## 23. Mistakes made and lessons learned

**A typo in seed data passed every constraint.** `'faith.chebet@gmail,come'` has a comma instead of a period, and `varchar(150) NOT NULL UNIQUE` accepted it without complaint. Constraints enforce *structure*, not *correctness*. A `CHECK (email LIKE '%_@_%._%')` would have caught this, and validating format at the database level is worth it for fields that other systems depend on.

**`SET search_path` does not persist.** Losing it between sessions produces `relation "customers" does not exist`, which looks like the table was never created. Re-declare it at the top of every script.

**Inconsistent casing in seed data.** `'groceries'` and `'Groceries'` are different values to `GROUP BY`, which splits one category into two rows in a sales report. Either normalise on write or add a `CHECK` constraint restricting the allowed set. This is the argument for a lookup table on `category`.

**Deletion order is the reverse of insertion order.** Children before parents, or the foreign key blocks it.

**Write the `SELECT` before the `UPDATE` or `DELETE`.** Confirm which rows are affected before changing them. This costs seconds and prevents the mistake that has no undo.

**Defaults make migrations possible.** Adding a `NOT NULL` column to a populated table only works with a `DEFAULT`.


## 24. Not yet covered

The natural next topics, roughly in order of usefulness:

- **Indexes:** `CREATE INDEX`, what makes a query slow, reading `EXPLAIN ANALYZE`
- **Subqueries:** scalar, `IN`, correlated, `EXISTS`
- **CTEs:** `WITH name AS (...)`, and recursive CTEs
- **Window functions:** `ROW_NUMBER()`, `RANK()`, `SUM() OVER (PARTITION BY ...)`, running totals
- **Views:** `CREATE VIEW`, materialised views
- **Transactions:** `BEGIN` / `COMMIT` / `ROLLBACK`, isolation levels
- **Set operations:** `UNION`, `UNION ALL`, `INTERSECT`, `EXCEPT`
- **Conditional logic:** `CASE WHEN ... THEN ... ELSE ... END`
- **Date functions:** `DATE_TRUNC`, `EXTRACT`, intervals, for time-series reporting
- **Normalisation theory:** 1NF through 3NF, and when denormalising is the right call
- **Stored procedures and triggers**

## Author - Mwai Victor