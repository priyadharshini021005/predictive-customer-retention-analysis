-- Predictive Customer Retention Analysis using SQL
-- Phase 4: Data-quality and validation checks
-- Read-only validation; this script does not clean or modify data.

USE predictive_customer_retention;

SELECT 'PHASE4_SCOPE' AS section,
       'Read-only data-quality validation; no data cleaning, RFM, retention, churn/risk scoring, or Power BI.' AS scope_statement;

SELECT 'ROW_COUNT_RECONCILIATION' AS section;
SELECT check_name, actual_count, expected_count,
       IF(actual_count = expected_count, 'PASS', 'FAIL') AS result
FROM (
    SELECT 'customers' AS check_name, COUNT(*) AS actual_count, 8000 AS expected_count FROM customers
    UNION ALL SELECT 'products', COUNT(*), 180 FROM products
    UNION ALL SELECT 'orders', COUNT(*), 40000 FROM orders
    UNION ALL SELECT 'order_items', COUNT(*), 116953 FROM order_items
    UNION ALL SELECT 'stg_customers', COUNT(*), 8000 FROM stg_customers
    UNION ALL SELECT 'stg_products', COUNT(*), 180 FROM stg_products
    UNION ALL SELECT 'stg_orders', COUNT(*), 40000 FROM stg_orders
    UNION ALL SELECT 'stg_order_items', COUNT(*), 116953 FROM stg_order_items
) AS counts;

SELECT 'PRIMARY_KEY_DUPLICATE_CHECKS' AS section;
SELECT check_name, duplicate_group_count,
       IF(duplicate_group_count = 0, 'PASS', 'FAIL') AS result
FROM (
    SELECT 'customers.customer_id' AS check_name,
           (SELECT COUNT(*) FROM (SELECT customer_id FROM customers GROUP BY customer_id HAVING COUNT(*) > 1) AS d) AS duplicate_group_count
    UNION ALL SELECT 'products.product_id', (SELECT COUNT(*) FROM (SELECT product_id FROM products GROUP BY product_id HAVING COUNT(*) > 1) AS d)
    UNION ALL SELECT 'orders.order_id', (SELECT COUNT(*) FROM (SELECT order_id FROM orders GROUP BY order_id HAVING COUNT(*) > 1) AS d)
    UNION ALL SELECT 'order_items.order_item_id', (SELECT COUNT(*) FROM (SELECT order_item_id FROM order_items GROUP BY order_item_id HAVING COUNT(*) > 1) AS d)
    UNION ALL SELECT 'customers.customer_code', (SELECT COUNT(*) FROM (SELECT customer_code FROM customers GROUP BY customer_code HAVING COUNT(*) > 1) AS d)
    UNION ALL SELECT 'products.sku', (SELECT COUNT(*) FROM (SELECT sku FROM products GROUP BY sku HAVING COUNT(*) > 1) AS d)
    UNION ALL SELECT 'orders.order_number', (SELECT COUNT(*) FROM (SELECT order_number FROM orders GROUP BY order_number HAVING COUNT(*) > 1) AS d)
) AS duplicate_checks;

SELECT 'NULL_OR_BLANK_CHECKS' AS section;
SELECT check_name, invalid_count,
       IF(invalid_count = 0, 'PASS', 'FAIL') AS result
FROM (
    SELECT 'customers.required_fields' AS check_name,
           SUM(customer_id IS NULL OR NULLIF(TRIM(customer_code), '') IS NULL OR signup_date IS NULL OR NULLIF(TRIM(gender), '') IS NULL OR NULLIF(TRIM(age_band), '') IS NULL OR NULLIF(TRIM(city), '') IS NULL OR NULLIF(TRIM(state), '') IS NULL OR NULLIF(TRIM(acquisition_channel), '') IS NULL OR NULLIF(TRIM(customer_status), '') IS NULL) AS invalid_count
    FROM customers
    UNION ALL SELECT 'products.required_fields', SUM(product_id IS NULL OR NULLIF(TRIM(sku), '') IS NULL OR NULLIF(TRIM(product_name), '') IS NULL OR category_id IS NULL OR unit_price IS NULL OR cost_price IS NULL OR launch_date IS NULL OR NULLIF(TRIM(product_status), '') IS NULL) FROM products
    UNION ALL SELECT 'orders.required_fields', SUM(order_id IS NULL OR NULLIF(TRIM(order_number), '') IS NULL OR customer_id IS NULL OR order_date IS NULL OR status_id IS NULL OR payment_method_id IS NULL OR sales_channel_id IS NULL OR NULLIF(TRIM(shipping_city), '') IS NULL OR NULLIF(TRIM(shipping_state), '') IS NULL OR discount_amount IS NULL OR shipping_amount IS NULL) FROM orders
    UNION ALL SELECT 'order_items.required_fields', SUM(order_item_id IS NULL OR order_id IS NULL OR product_id IS NULL OR quantity IS NULL OR unit_price IS NULL OR line_discount IS NULL OR line_total IS NULL) FROM order_items
) AS null_checks;

SELECT 'CONTROLLED_DOMAIN_CHECKS' AS section;
SELECT check_name, invalid_count,
       IF(invalid_count = 0, 'PASS', 'FAIL') AS result
FROM (
    SELECT 'customers.customer_status' AS check_name, COUNT(*) AS invalid_count FROM customers WHERE customer_status NOT IN ('Active', 'Inactive')
    UNION ALL SELECT 'products.product_status', COUNT(*) FROM products WHERE product_status NOT IN ('Active', 'Discontinued')
    UNION ALL SELECT 'orders.status_reference', COUNT(*) FROM orders o LEFT JOIN order_statuses s ON s.status_id = o.status_id WHERE s.status_id IS NULL
    UNION ALL SELECT 'orders.payment_reference', COUNT(*) FROM orders o LEFT JOIN payment_methods p ON p.payment_method_id = o.payment_method_id WHERE p.payment_method_id IS NULL
    UNION ALL SELECT 'orders.channel_reference', COUNT(*) FROM orders o LEFT JOIN sales_channels sc ON sc.sales_channel_id = o.sales_channel_id WHERE sc.sales_channel_id IS NULL
    UNION ALL SELECT 'products.category_reference', COUNT(*) FROM products p LEFT JOIN categories c ON c.category_id = p.category_id WHERE c.category_id IS NULL
) AS domain_checks;

SELECT 'DATE_AND_CHRONOLOGY_CHECKS' AS section;
SELECT check_name, invalid_count,
       IF(invalid_count = 0, 'PASS', 'FAIL') AS result
FROM (
    SELECT 'orders.outside_analysis_period' AS check_name, COUNT(*) AS invalid_count FROM orders WHERE order_date NOT BETWEEN '2024-01-01' AND '2025-12-31'
    UNION ALL SELECT 'customers.signup_after_analysis_end', COUNT(*) FROM customers WHERE signup_date > '2025-11-30'
    UNION ALL SELECT 'orders.before_customer_signup', COUNT(*) FROM orders o JOIN customers c ON c.customer_id = o.customer_id WHERE o.order_date < c.signup_date
    UNION ALL SELECT 'order_items.before_product_launch', COUNT(*) FROM order_items oi JOIN orders o ON o.order_id = oi.order_id JOIN products p ON p.product_id = oi.product_id WHERE o.order_date < p.launch_date
    UNION ALL SELECT 'missing_completed_boundary_start', IF(EXISTS (SELECT 1 FROM orders o JOIN order_statuses s ON s.status_id = o.status_id WHERE s.is_eligible = 1 AND o.order_date = '2024-01-01'), 0, 1)
    UNION ALL SELECT 'missing_completed_boundary_end', IF(EXISTS (SELECT 1 FROM orders o JOIN order_statuses s ON s.status_id = o.status_id WHERE s.is_eligible = 1 AND o.order_date = '2025-12-31'), 0, 1)
) AS chronology_checks;

SELECT 'NUMERIC_AND_FINANCIAL_CHECKS' AS section;
SELECT check_name, invalid_count,
       IF(invalid_count = 0, 'PASS', 'FAIL') AS result
FROM (
    SELECT 'products.nonpositive_unit_price' AS check_name, COUNT(*) AS invalid_count FROM products WHERE unit_price <= 0
    UNION ALL SELECT 'products.nonpositive_cost_price', COUNT(*) FROM products WHERE cost_price <= 0
    UNION ALL SELECT 'products.cost_not_below_unit_price', COUNT(*) FROM products WHERE cost_price >= unit_price
    UNION ALL SELECT 'orders.negative_discount_or_shipping', COUNT(*) FROM orders WHERE discount_amount < 0 OR shipping_amount < 0
    UNION ALL SELECT 'order_items.invalid_quantity_or_price', COUNT(*) FROM order_items WHERE quantity <= 0 OR unit_price <= 0
    UNION ALL SELECT 'order_items.negative_discount_or_total', COUNT(*) FROM order_items WHERE line_discount < 0 OR line_total < 0
    UNION ALL SELECT 'order_items.discount_above_gross', COUNT(*) FROM order_items WHERE line_discount > quantity * unit_price
    UNION ALL SELECT 'order_items.line_total_formula_mismatch', COUNT(*) FROM order_items WHERE line_total <> ROUND(quantity * unit_price - line_discount, 2)
    UNION ALL SELECT 'order_items.product_price_mismatch', COUNT(*) FROM order_items oi JOIN products p ON p.product_id = oi.product_id WHERE oi.unit_price <> p.unit_price
    UNION ALL SELECT 'orders.discount_reconciliation_mismatch', COUNT(*) FROM orders o JOIN (SELECT order_id, ROUND(SUM(line_discount), 2) AS item_discount FROM order_items GROUP BY order_id) x ON x.order_id = o.order_id WHERE o.discount_amount <> x.item_discount
) AS numeric_checks;

SELECT 'REFERENTIAL_AND_COMPLETENESS_CHECKS' AS section;
SELECT check_name, invalid_count,
       IF(invalid_count = 0, 'PASS', 'FAIL') AS result
FROM (
    SELECT 'orders.orphan_customer' AS check_name, COUNT(*) AS invalid_count FROM orders o LEFT JOIN customers c ON c.customer_id = o.customer_id WHERE c.customer_id IS NULL
    UNION ALL SELECT 'order_items.orphan_order', COUNT(*) FROM order_items oi LEFT JOIN orders o ON o.order_id = oi.order_id WHERE o.order_id IS NULL
    UNION ALL SELECT 'order_items.orphan_product', COUNT(*) FROM order_items oi LEFT JOIN products p ON p.product_id = oi.product_id WHERE p.product_id IS NULL
    UNION ALL SELECT 'orders.without_items', COUNT(*) FROM orders o LEFT JOIN order_items oi ON oi.order_id = o.order_id WHERE oi.order_item_id IS NULL
    UNION ALL SELECT 'duplicate_product_within_order', COUNT(*) FROM (SELECT order_id, product_id FROM order_items GROUP BY order_id, product_id HAVING COUNT(*) > 1) d
) AS completeness_checks;

SELECT 'STATUS_AND_ELIGIBILITY_CHECKS' AS section;
SELECT status_code, is_eligible, COUNT(o.order_id) AS order_count
FROM order_statuses s
LEFT JOIN orders o ON o.status_id = s.status_id
GROUP BY s.status_id, s.status_code, s.is_eligible
ORDER BY s.status_id;

SELECT 'QUALITY_SUMMARY' AS section,
       ROUND(SUM(CASE WHEN s.is_eligible = 1 THEN oi.line_total ELSE 0 END), 2) AS eligible_line_revenue,
       ROUND(SUM(CASE WHEN s.is_eligible = 0 THEN oi.line_total ELSE 0 END), 2) AS noneligible_line_revenue,
       COUNT(DISTINCT CASE WHEN s.is_eligible = 1 THEN o.customer_id END) AS completed_customers,
       COUNT(DISTINCT CASE WHEN s.is_eligible = 1 THEN o.order_id END) AS completed_orders
FROM order_items oi
JOIN orders o ON o.order_id = oi.order_id
JOIN order_statuses s ON s.status_id = o.status_id;
