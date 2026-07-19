create schema sunrise;

set search_path to sunrise;


create table customers (
	customer_id serial not null primary key,
	full_name Varchar(100) not null,
	email varchar(150) not null unique,
	phone_number varchar(15) unique not null,
	city varchar(50) not null
);

create table products (
	product_id serial not null primary key,
	product_name varchar(50) not null,
	category varchar(50) not null,
	unit_price decimal(10,2) not null check(unit_price >= 0),
	stock INT not null check(stock >= 0) default 0
);

create type order_status as enum(
	'pending',
	'delivered',
	'cancelled'
);

create table orders (
	order_id serial not null primary key,
	customer_id int not null references customers(customer_id),
	order_date date default current_date,
	status order_status not null default 'pending'
);


create table order_items(
	order_item_id serial not null primary key,
	order_id INT not null references orders(order_id),
	product_id INT not null references products(product_id),
	quantity INT not null check(quantity > 0)
);


alter table products
rename column stock to stock_quantity;

alter table customers
add column loyalty_points INT not null check(loyalty_points >= 0) default 0;

alter table products
alter column product_name type 	VARCHAR(150);


insert into customers (full_name, email, phone_number, city)
values
	('Grace Wambui', 'grace.wambui@gmail.com', '0711223344', 'Nairobi'),
	('Kevin Mutiso', 'kevin.mutiso@gmail.com', '0722334455', 'Nakuru'),
	('Faith Chebet', 'faith.chebet@gmail,come', '0733445566', 'Eldoret'),
	('Ibrahim Noor', 'ibrahim.noor@gmail.com', '0744556677', 'Mombasa');

select *
from  customers;

insert into products (product_name, category, unit_price, stock_quantity)
	values
		('maize flour 2kg','groceries',180.00, 50),
		('cooking Oil 1l', 'groceries', 320.00, 30),
		('Bathing soap','Toiletries', 85.00, 100),
		('Notebook A4', 'Stationary', 60.00,200);


select *
from products ;

INSERT INTO orders (customer_id, order_date, status)
VALUES
    (1, '2024-04-01', 'delivered'),
    (2, '2024-03-02', 'pending'),
    (1, '2024-03-03', 'delivered'),
    (3, '2024-03-04', 'cancelled');

select *
	from orders;

insert into order_items(order_id, product_id, quantity)
	values
		(1,1,2),
		(1,3,1),
		(2,2,1),
		(3,4,5);

select *
	from order_items;

/*update syntax
update column_name
set column = value
where condition;
*/

update orders
	set status = 'delivered'
	where order_id = 2 
	and order_date ='2024-03-02';


SELECT *
FROM order_items
WHERE order_id = 4;

---There are no order items returned for the cancelled order Id
/*It was important to check whether there were any order_items for the order_id 
 * reason being if there were any order items referencing  the order_id that we need to drop
 * postgres would fail with a foreign key violation
 * and that means we would beed to delete the child rows first which in this case would be the order_items before deleting the order_id
 */

delete from orders
where order_id = 4;

select product_name, unit_price
from products
where unit_price > 100.00;

/*
 order of writting commands in sql
 SELECT
 FROM
 WHERE
 GROUP BY
 HAVING
 ORDER BY
 LIMIT
 */

select *
from customers
where city <> 'Nairobi';

select *
from products
where unit_price between 60 and 200;


select *
from customers
where city in ('Nakuru', 'Nairobi', 'Mombasa');

select *
from products
where product_name like '%Oil%';


select *
from orders
where status = 'pending';

select *
from products
order by unit_price desc
limit 2;

SELECT
    customer_id,
    COUNT(*)
FROM sunrise.orders
GROUP BY customer_id;

SELECT
    customer_id,
    COUNT(*)
FROM sunrise.orders
GROUP BY customer_id
having count(*) > 1;

select *
from sunrise.order_items;

/*
 *joins syntax
 *select columns1 ...
 *from table 1
 *join table 2
 *on table 1 primary_key = table_2 foreign_key
 */
select 
	c.full_name,
	o.order_id,
	o.status
from customers as c
inner join orders as o
	on c.customer_id = o.customer_id;

select
	o.order_id,
	oi.product_id,
	oi.quantity
from orders as o
left join order_items as oi
	on o.order_id = oi.order_id;


---task 25 inner join wsa chosen since we wanted only to showrows
---where an order item matches a product
select 
	oi.order_id,
	p.product_name,
	p.category,
	oi.quantity
from products as p
inner join order_items as oi
	on p.product_id = oi.product_id;


select
	c.full_name,
	o.order_id,
	p.product_name,
	oi.quantity
from customers as c
join orders as o
on c.customer_id = o.customer_id
join order_items as oi
on o.order_id = oi.order_id 
join products as p
on p.product_id = oi.product_id;

select 
	p.product_name,
	sum(oi.quantity) as total_quantity
from customers as c 
inner join orders as o 
	on c.customer_id = o.customer_id
inner join order_items as oi
	on o.order_id = oi.order_id
inner join products as p 
	on p.product_id = oi.product_id
group by 
	p.product_name;

















































































































































































