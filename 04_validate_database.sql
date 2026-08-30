-- Predictive Customer Retention Analysis using SQL
-- Phase 3: Database, schema, import, relationship, and constraint validation

USE predictive_customer_retention;

SELECT 'DATABASE' AS section, DATABASE() AS database_name, VERSION() AS mysql_version;

SELECT 'TABLE_COUNT' AS check_name,
       COUNT(*) AS actual_value,
       12 AS expected_value,
       IF(COUNT(*) = 12, 'PASS', 'FAIL') AS result
FROM information_schema.tables
WHERE table_schema = DATABASE()
  AND table_type = 'BASE TABLE';

SELECT 'CORE_AND_STAGING_ROW_COUNTS' AS section;
SELECT 'stg_customers' AS table_name, COUNT(*) AS row_count, 8000 AS expected_count, IF(COUNT(*) = 8000, 'PASS', 'FAIL') AS result FROM stg_customers
UNION ALL SELECT 'stg_products', COUNT(*), 180, IF(COUNT(*) = 180, 'PASS', 'FAIL') FROM stg_products
UNION ALL SELECT 'stg_orders', COUNT(*), 40000, IF(COUNT(*) = 40000, 'PASS', 'FAIL') FROM stg_orders
UNION ALL SELECT 'stg_order_items', COUNT(*), 116953, IF(COUNT(*) = 116953, 'PASS', 'FAIL') FROM stg_order_items
UNION ALL SELECT 'customers', COUNT(*), 8000, IF(COUNT(*) = 8000, 'PASS', 'FAIL') FROM customers
UNION ALL SELECT 'products', COUNT(*), 180, IF(COUNT(*) = 180, 'PASS', 'FAIL') FROM products
UNION ALL SELECT 'orders', COUNT(*), 40000, IF(COUNT(*) = 40000, 'PASS', 'FAIL') FROM orders
UNION ALL SELECT 'order_items', COUNT(*), 116953, IF(COUNT(*) = 116953, 'PASS', 'FAIL') FROM order_items;

SELECT 'LOOKUP_COUNTS' AS section;
SELECT 'categories' AS table_name, COUNT(*) AS row_count FROM categories
UNION ALL SELECT 'order_statuses', COUNT(*) FROM order_statuses
UNION ALL SELECT 'payment_methods', COUNT(*) FROM payment_methods
UNION ALL SELECT 'sales_channels', COUNT(*) FROM sales_channels;

SELECT 'ORDER_STATUS_COUNTS' AS section;
SELECT s.status_code, s.is_eligible, COUNT(o.order_id) AS order_count
FROM order_statuses AS s
LEFT JOIN orders AS o ON o.status_id = s.status_id
GROUP BY s.status_id, s.status_code, s.is_eligible
ORDER BY s.status_id;

SELECT 'DATE_RANGE' AS section;
SELECT MIN(order_date) AS order_min_date,
       MAX(order_date) AS order_max_date,
       IF(MIN(order_date) = '2024-01-01' AND MAX(order_date) = '2025-12-31', 'PASS', 'FAIL') AS order_date_result
FROM orders;

SELECT 'REFERENTIAL_INTEGRITY' AS section;
SELECT 'orders_to_customers' AS check_name, COUNT(*) AS orphan_count, IF(COUNT(*) = 0, 'PASS', 'FAIL') AS result
FROM orders AS o LEFT JOIN customers AS c ON c.customer_id = o.customer_id WHERE c.customer_id IS NULL
UNION ALL SELECT 'orders_to_statuses', COUNT(*), IF(COUNT(*) = 0, 'PASS', 'FAIL') FROM orders AS o LEFT JOIN order_statuses AS s ON s.status_id = o.status_id WHERE s.status_id IS NULL
UNION ALL SELECT 'orders_to_payment_methods', COUNT(*), IF(COUNT(*) = 0, 'PASS', 'FAIL') FROM orders AS o LEFT JOIN payment_methods AS p ON p.payment_method_id = o.payment_method_id WHERE p.payment_method_id IS NULL
UNION ALL SELECT 'orders_to_sales_channels', COUNT(*), IF(COUNT(*) = 0, 'PASS', 'FAIL') FROM orders AS o LEFT JOIN sales_channels AS sc ON sc.sales_channel_id = o.sales_channel_id WHERE sc.sales_channel_id IS NULL
UNION ALL SELECT 'order_items_to_orders', COUNT(*), IF(COUNT(*) = 0, 'PASS', 'FAIL') FROM order_items AS oi LEFT JOIN orders AS o ON o.order_id = oi.order_id WHERE o.order_id IS NULL
UNION ALL SELECT 'order_items_to_products', COUNT(*), IF(COUNT(*) = 0, 'PASS', 'FAIL') FROM order_items AS oi LEFT JOIN products AS p ON p.product_id = oi.product_id WHERE p.product_id IS NULL
UNION ALL SELECT 'products_to_categories', COUNT(*), IF(COUNT(*) = 0, 'PASS', 'FAIL') FROM products AS p LEFT JOIN categories AS c ON c.category_id = p.category_id WHERE c.category_id IS NULL;

SELECT 'ORDER_COMPOSITION' AS section;
SELECT COUNT(*) AS orders_without_items,
       IF(COUNT(*) = 0, 'PASS', 'FAIL') AS result
FROM orders AS o
LEFT JOIN order_items AS oi ON oi.order_id = o.order_id
WHERE oi.order_item_id IS NULL;

SELECT 'LINE_FINANCIAL_RECONCILIATION' AS section;
SELECT COUNT(*) AS line_total_mismatch_count,
       IF(COUNT(*) = 0, 'PASS', 'FAIL') AS result
FROM order_items
WHERE line_total <> ROUND(quantity * unit_price - line_discount, 2);

SELECT COUNT(*) AS product_price_mismatch_count,
       IF(COUNT(*) = 0, 'PASS', 'FAIL') AS result
FROM order_items AS oi
JOIN products AS p ON p.product_id = oi.product_id
WHERE oi.unit_price <> p.unit_price;

SELECT 'ORDER_FINANCIAL_RECONCILIATION' AS section;
SELECT COUNT(*) AS order_discount_mismatch_count,
       IF(COUNT(*) = 0, 'PASS', 'FAIL') AS result
FROM orders AS o
JOIN (
    SELECT order_id, ROUND(SUM(line_discount), 2) AS item_discount
    FROM order_items
    GROUP BY order_id
) AS x ON x.order_id = o.order_id
WHERE o.discount_amount <> x.item_discount;

SELECT 'COMPLETED_REVENUE_RECONCILIATION' AS section;
SELECT ROUND(SUM(CASE WHEN s.is_eligible = 1 THEN oi.line_total ELSE 0 END), 2) AS eligible_revenue,
       ROUND(SUM(CASE WHEN s.is_eligible = 0 THEN oi.line_total ELSE 0 END), 2) AS noneligible_line_revenue,
       ROUND(SUM(oi.line_total), 2) AS all_status_line_revenue
FROM order_items AS oi
JOIN orders AS o ON o.order_id = oi.order_id
JOIN order_statuses AS s ON s.status_id = o.status_id;

SELECT 'CONSTRAINT_METADATA' AS section;
SELECT tc.table_name,
       tc.constraint_type,
       COUNT(*) AS constraint_count
FROM information_schema.table_constraints AS tc
WHERE tc.constraint_schema = DATABASE()
  AND tc.table_name IN ('customers', 'products', 'orders', 'order_items')
GROUP BY tc.table_name, tc.constraint_type
ORDER BY tc.table_name, tc.constraint_type;

SELECT 'CHECK_CONSTRAINT_METADATA' AS section;
SELECT tc.table_name,
       cc.constraint_name,
       cc.check_clause
FROM information_schema.check_constraints AS cc
JOIN information_schema.table_constraints AS tc
  ON tc.constraint_schema = cc.constraint_schema
 AND tc.constraint_name = cc.constraint_name
WHERE cc.constraint_schema = DATABASE()
  AND tc.table_name IN ('customers', 'products', 'orders', 'order_items')
ORDER BY tc.table_name, cc.constraint_name;

SELECT 'INDEX_METADATA' AS section;
SELECT table_name,
       index_name,
       non_unique,
       GROUP_CONCAT(column_name ORDER BY seq_in_index) AS indexed_columns
FROM information_schema.statistics
WHERE table_schema = DATABASE()
  AND table_name IN ('customers', 'products', 'orders', 'order_items')
GROUP BY table_name, index_name, non_unique
ORDER BY table_name, index_name;

SELECT 'REQUIRED_INDEX_CHECKS' AS section;
SELECT required_index,
       IF(COUNT(*) > 0, 'PASS', 'FAIL') AS result
FROM (
    SELECT 'idx_customers_signup_date' AS required_index
    UNION ALL SELECT 'idx_customers_acquisition_channel'
    UNION ALL SELECT 'idx_products_category_id'
    UNION ALL SELECT 'idx_products_status'
    UNION ALL SELECT 'idx_orders_customer_date'
    UNION ALL SELECT 'idx_orders_status_date'
    UNION ALL SELECT 'idx_orders_channel_date'
    UNION ALL SELECT 'idx_orders_date'
    UNION ALL SELECT 'idx_order_items_order_id'
    UNION ALL SELECT 'idx_order_items_product_id'
) AS required
LEFT JOIN information_schema.statistics AS s
  ON s.table_schema = DATABASE() AND s.index_name = required.required_index
GROUP BY required_index
ORDER BY required_index;

SELECT 'ANALYTICAL_SCOPE_BOUNDARY' AS section,
       'Phase 3 validation only; no RFM, retention, risk scoring, views, procedures, or Power BI objects created.' AS statement;
