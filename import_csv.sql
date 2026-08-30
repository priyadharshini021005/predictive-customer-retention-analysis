-- Predictive Customer Retention Analysis using SQL
-- Phase 3: CSV import into staging and normalized core tables
-- Execute with the mysql client using --local-infile=1.

USE predictive_customer_retention;

TRUNCATE TABLE stg_customers;
TRUNCATE TABLE stg_products;
TRUNCATE TABLE stg_orders;
TRUNCATE TABLE stg_order_items;

LOAD DATA LOCAL INFILE 'C:/Users/laksh/PycharmProjects/PythonProject/customers.csv'
INTO TABLE stg_customers
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES
(customer_id, customer_code, signup_date, gender, age_band, city, state, acquisition_channel, customer_status);

LOAD DATA LOCAL INFILE 'C:/Users/laksh/PycharmProjects/PythonProject/products.csv'
INTO TABLE stg_products
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES
(product_id, sku, product_name, category, unit_price, cost_price, launch_date, product_status);

LOAD DATA LOCAL INFILE 'C:/Users/laksh/PycharmProjects/PythonProject/orders.csv'
INTO TABLE stg_orders
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES
(order_id, order_number, customer_id, order_date, order_status, payment_method, sales_channel, shipping_city, shipping_state, discount_amount, shipping_amount);

LOAD DATA LOCAL INFILE 'C:/Users/laksh/PycharmProjects/PythonProject/order_items.csv'
INTO TABLE stg_order_items
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES
(order_item_id, order_id, product_id, quantity, unit_price, line_discount, line_total);

-- Controlled lookup values are normalized from the source data.
INSERT INTO categories (category_name)
SELECT DISTINCT category
FROM stg_products
ORDER BY category;

INSERT INTO order_statuses (status_code, is_eligible)
VALUES
    ('Completed', 1),
    ('Cancelled', 0),
    ('Returned', 0),
    ('Pending', 0);

INSERT INTO payment_methods (payment_method_name)
SELECT DISTINCT payment_method
FROM stg_orders
ORDER BY payment_method;

INSERT INTO sales_channels (sales_channel_name)
SELECT DISTINCT sales_channel
FROM stg_orders
ORDER BY sales_channel;

-- Normalized master data.
INSERT INTO customers (
    customer_id, customer_code, signup_date, gender, age_band, city, state,
    acquisition_channel, customer_status
)
SELECT
    customer_id, customer_code, signup_date, gender, age_band, city, state,
    acquisition_channel, customer_status
FROM stg_customers;

INSERT INTO products (
    product_id, sku, product_name, category_id, unit_price, cost_price,
    launch_date, product_status
)
SELECT
    p.product_id, p.sku, p.product_name, c.category_id, p.unit_price, p.cost_price,
    p.launch_date, p.product_status
FROM stg_products AS p
JOIN categories AS c ON c.category_name = p.category;

INSERT INTO orders (
    order_id, order_number, customer_id, order_date, status_id,
    payment_method_id, sales_channel_id, shipping_city, shipping_state,
    discount_amount, shipping_amount
)
SELECT
    o.order_id,
    o.order_number,
    o.customer_id,
    o.order_date,
    s.status_id,
    pm.payment_method_id,
    sc.sales_channel_id,
    o.shipping_city,
    o.shipping_state,
    o.discount_amount,
    o.shipping_amount
FROM stg_orders AS o
JOIN order_statuses AS s ON s.status_code = o.order_status
JOIN payment_methods AS pm ON pm.payment_method_name = o.payment_method
JOIN sales_channels AS sc ON sc.sales_channel_name = o.sales_channel;

INSERT INTO order_items (
    order_item_id, order_id, product_id, quantity, unit_price, line_discount, line_total
)
SELECT
    oi.order_item_id, oi.order_id, oi.product_id, oi.quantity,
    oi.unit_price, oi.line_discount, oi.line_total
FROM stg_order_items AS oi;

SELECT 'stg_customers' AS table_name, COUNT(*) AS row_count FROM stg_customers
UNION ALL SELECT 'stg_products', COUNT(*) FROM stg_products
UNION ALL SELECT 'stg_orders', COUNT(*) FROM stg_orders
UNION ALL SELECT 'stg_order_items', COUNT(*) FROM stg_order_items
UNION ALL SELECT 'customers', COUNT(*) FROM customers
UNION ALL SELECT 'products', COUNT(*) FROM products
UNION ALL SELECT 'orders', COUNT(*) FROM orders
UNION ALL SELECT 'order_items', COUNT(*) FROM order_items;


SHOW VARIABLES LIKE 'local_infile';

SET GLOBAL local_infile = 1;
SELECT *
FROM stg_customers
LIMIT 10;


USE predictive_customer_retention;

ALTER TABLE stg_customers
MODIFY signup_date VARCHAR(30);

TRUNCATE TABLE stg_customers;

LOAD DATA LOCAL INFILE 'C:/Users/laksh/PycharmProjects/PythonProject/customers.csv'
INTO TABLE stg_customers
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES
(customer_id, customer_code, signup_date, gender, age_band, city, state, acquisition_channel, customer_status);


SELECT customer_id, customer_code, signup_date
FROM stg_customers
LIMIT 10;


SELECT COUNT(*) AS customer_count
FROM customers;

INSERT INTO customers (
    customer_id,
    customer_code,
    signup_date,
    gender,
    age_band,
    city,
    state,
    acquisition_channel,
    customer_status
)
SELECT
    customer_id,
    customer_code,
    STR_TO_DATE(signup_date, '%d-%m-%Y'),
    gender,
    age_band,
    city,
    state,
    acquisition_channel,
    customer_status
FROM stg_customers;

SELECT *
FROM customers
LIMIT 10;


LOAD DATA LOCAL INFILE 'C:/Users/laksh/PycharmProjects/PythonProject/products.csv'
INTO TABLE stg_products
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES;

SELECT *
FROM stg_products
LIMIT 10;

SELECT *
FROM stg_products
LIMIT 10;

DESCRIBE stg_products;

ALTER TABLE stg_products
MODIFY launch_date VARCHAR(30);

TRUNCATE TABLE stg_products;


LOAD DATA LOCAL INFILE 'C:/Users/laksh/PycharmProjects/PythonProject/products.csv'
INTO TABLE stg_products
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES
(product_id, sku, product_name, category, unit_price, cost_price, launch_date, product_status);

SELECT product_id, sku, launch_date
FROM stg_products
LIMIT 10;
SELECT COUNT(*) AS product_count
FROM products;

INSERT INTO products (
    product_id,
    sku,
    product_name,
    category,
    unit_price,
    cost_price,
    launch_date,
    product_status
)
SELECT
    product_id,
    sku,
    product_name,
    category,
    unit_price,
    cost_price,
    STR_TO_DATE(launch_date, '%d-%m-%Y'),
    product_status
FROM stg_products;


SELECT *
FROM products
LIMIT 10;

DESCRIBE products;

SELECT *
FROM categories;

INSERT INTO products (
    product_id,
    sku,
    product_name,
    category_id,
    unit_price,
    cost_price,
    launch_date,
    product_status
)
SELECT
    sp.product_id,
    sp.sku,
    sp.product_name,
    c.category_id,
    sp.unit_price,
    sp.cost_price,
    STR_TO_DATE(sp.launch_date, '%d-%m-%Y'),
    sp.product_status
FROM stg_products AS sp
JOIN categories AS c
    ON c.category_name = sp.category;
    
    SELECT *
FROM products
LIMIT 10;

SELECT COUNT(*) AS product_count
FROM products;

DESCRIBE stg_orders;

DESCRIBE orders;

ALTER TABLE stg_orders
MODIFY order_date VARCHAR(30);

TRUNCATE TABLE stg_orders;

LOAD DATA LOCAL INFILE 'C:/Users/laksh/PycharmProjects/PythonProject/orders.csv'
INTO TABLE stg_orders
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES
(order_id, order_number, customer_id, order_date, order_status,
 payment_method, sales_channel, shipping_city, shipping_state,
 discount_amount, shipping_amount);
 
 SELECT order_id, order_number, order_date
FROM stg_orders
LIMIT 10;

SELECT * FROM order_statuses;

SELECT * FROM payment_methods;

SELECT * FROM sales_channels;

SELECT COUNT(*) AS order_count
FROM orders;


INSERT INTO orders (
    order_id,
    order_number,
    customer_id,
    order_date,
    status_id,
    payment_method_id,
    sales_channel_id,
    shipping_city,
    shipping_state,
    discount_amount,
    shipping_amount
)
SELECT
    so.order_id,
    so.order_number,
    so.customer_id,
    STR_TO_DATE(so.order_date, '%d-%m-%Y'),
    os.status_id,
    pm.payment_method_id,
    sc.sales_channel_id,
    so.shipping_city,
    so.shipping_state,
    so.discount_amount,
    so.shipping_amount
FROM stg_orders AS so
JOIN order_statuses AS os
    ON os.status_name = so.order_status
JOIN payment_methods AS pm
    ON pm.payment_method_name = so.payment_method
JOIN sales_channels AS sc
    ON sc.channel_name = so.sales_channel;
    
    DESCRIBE sales_channels;
    
    DESCRIBE payment_methods;
    
    DESCRIBE order_statuses;
    
    INSERT INTO orders (
    order_id,
    order_number,
    customer_id,
    order_date,
    status_id,
    payment_method_id,
    sales_channel_id,
    shipping_city,
    shipping_state,
    discount_amount,
    shipping_amount
)
SELECT
    so.order_id,
    so.order_number,
    so.customer_id,
    STR_TO_DATE(so.order_date, '%d-%m-%Y'),
    os.status_id,
    pm.payment_method_id,
    sc.sales_channel_id,
    so.shipping_city,
    so.shipping_state,
    so.discount_amount,
    so.shipping_amount
FROM stg_orders AS so
JOIN order_statuses AS os
    ON os.status_code = so.order_status
JOIN payment_methods AS pm
    ON pm.payment_method_name = so.payment_method
JOIN sales_channels AS sc
    ON sc.sales_channel_name = so.sales_channel;
    
    SELECT COUNT(*) AS order_count
FROM orders;

SELECT *
FROM orders
LIMIT 10;

DESCRIBE stg_order_items;

DESCRIBE order_items;


LOAD DATA LOCAL INFILE 'C:/Users/laksh/PycharmProjects/PythonProject/order_items.csv'
INTO TABLE stg_order_items
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES
(order_item_id, order_id, product_id, quantity, unit_price, line_discount, line_total);

SELECT COUNT(*) AS order_item_count
FROM stg_order_items;

SELECT *
FROM stg_order_items
LIMIT 10;


SELECT COUNT(*) AS final_count
FROM order_items;

SELECT *
FROM order_items
LIMIT 10;

SELECT COUNT(*) AS staging_count
FROM stg_order_items;

SELECT COUNT(*) AS final_count
FROM order_items;

SELECT MIN(order_item_id) AS min_id,
       MAX(order_item_id) AS max_id
FROM order_items;

SELECT *
FROM order_items
WHERE order_item_id = 1;

SELECT
    order_item_id,
    COUNT(*) AS duplicate_count
FROM stg_order_items
GROUP BY order_item_id
HAVING COUNT(*) > 1
LIMIT 20;

SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT order_item_id) AS unique_order_item_ids
FROM stg_order_items;

SELECT *
FROM stg_order_items
WHERE order_item_id = 1;

SELECT *
FROM stg_order_items
WHERE order_item_id = 2;


INSERT INTO order_items (
    order_item_id,
    order_id,
    product_id,
    quantity,
    unit_price,
    line_discount,
    line_total
)
SELECT
    order_item_id,
    order_id,
    product_id,
    quantity,
    unit_price,
    line_discount,
    line_total
FROM stg_order_items
GROUP BY
    order_item_id,
    order_id,
    product_id,
    quantity,
    unit_price,
    line_discount,
    line_total;
    
    SELECT COUNT(*) AS final_count
FROM order_items;

SELECT COUNT(DISTINCT order_item_id) AS unique_ids
FROM order_items;

SELECT *
FROM order_items
LIMIT 10;

SELECT COUNT(*) AS customers
FROM customers;

SELECT COUNT(*) AS products
FROM products;

SELECT COUNT(*) AS orders
FROM orders;

SELECT COUNT(*) AS order_items
FROM order_items;

SHOW TABLES;