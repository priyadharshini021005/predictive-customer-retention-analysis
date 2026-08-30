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
