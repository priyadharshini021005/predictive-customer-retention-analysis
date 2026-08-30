-- Predictive Customer Retention Analysis using SQL
-- Phase 4: Exploratory-output reconciliation
-- Read-only checks; no RFM, retention, churn, risk, views, or Power BI.

USE predictive_customer_retention;

WITH base AS (
    SELECT
        COUNT(DISTINCT o.order_id) AS completed_orders,
        COUNT(DISTINCT o.customer_id) AS completed_customers,
        ROUND(SUM(oi.line_total), 2) AS completed_revenue
    FROM orders o
    JOIN order_statuses s ON s.status_id = o.status_id AND s.is_eligible = 1
    JOIN order_items oi ON oi.order_id = o.order_id
)
SELECT 'base_completed_profile' AS check_name,
       completed_orders,
       completed_customers,
       completed_revenue,
       IF(completed_orders = 35500 AND completed_customers = 7247 AND completed_revenue = 54706775.88, 'PASS', 'FAIL') AS result
FROM base;

WITH base AS (
    SELECT COUNT(DISTINCT o.order_id) AS completed_orders, ROUND(SUM(oi.line_total), 2) AS completed_revenue
    FROM orders o JOIN order_statuses s ON s.status_id=o.status_id AND s.is_eligible=1 JOIN order_items oi ON oi.order_id=o.order_id
), monthly AS (
    SELECT DATE_FORMAT(o.order_date, '%Y-%m-01') AS order_month, COUNT(DISTINCT o.order_id) AS completed_orders, ROUND(SUM(oi.line_total), 2) AS revenue
    FROM orders o JOIN order_statuses s ON s.status_id=o.status_id AND s.is_eligible=1 JOIN order_items oi ON oi.order_id=o.order_id
    GROUP BY DATE_FORMAT(o.order_date, '%Y-%m-01')
)
SELECT 'monthly_totals_reconcile_to_base' AS check_name,
       COUNT(*) AS month_count,
       SUM(monthly.completed_orders) AS monthly_orders,
       SUM(monthly.revenue) AS monthly_revenue,
       IF(COUNT(*) = 24 AND SUM(monthly.completed_orders) = MAX(base.completed_orders) AND ROUND(SUM(monthly.revenue),2) = MAX(base.completed_revenue), 'PASS', 'FAIL') AS result
FROM monthly CROSS JOIN base;

WITH base AS (
    SELECT ROUND(SUM(oi.line_total), 2) AS completed_revenue
    FROM orders o JOIN order_statuses s ON s.status_id=o.status_id AND s.is_eligible=1 JOIN order_items oi ON oi.order_id=o.order_id
), channel AS (
    SELECT sc.sales_channel_id, ROUND(SUM(oi.line_total), 2) AS revenue
    FROM orders o JOIN order_statuses s ON s.status_id=o.status_id AND s.is_eligible=1 JOIN sales_channels sc ON sc.sales_channel_id=o.sales_channel_id JOIN order_items oi ON oi.order_id=o.order_id
    GROUP BY sc.sales_channel_id
)
SELECT 'channel_revenue_reconcile_to_base' AS check_name, ROUND(SUM(channel.revenue),2) AS channel_revenue, MAX(base.completed_revenue) AS base_revenue, IF(ROUND(SUM(channel.revenue),2)=MAX(base.completed_revenue),'PASS','FAIL') AS result
FROM channel CROSS JOIN base;

WITH base AS (
    SELECT ROUND(SUM(oi.line_total), 2) AS completed_revenue
    FROM orders o JOIN order_statuses s ON s.status_id=o.status_id AND s.is_eligible=1 JOIN order_items oi ON oi.order_id=o.order_id
), payment AS (
    SELECT pm.payment_method_id, ROUND(SUM(oi.line_total), 2) AS revenue
    FROM orders o JOIN order_statuses s ON s.status_id=o.status_id AND s.is_eligible=1 JOIN payment_methods pm ON pm.payment_method_id=o.payment_method_id JOIN order_items oi ON oi.order_id=o.order_id
    GROUP BY pm.payment_method_id
)
SELECT 'payment_revenue_reconcile_to_base' AS check_name, ROUND(SUM(payment.revenue),2) AS payment_revenue, MAX(base.completed_revenue) AS base_revenue, IF(ROUND(SUM(payment.revenue),2)=MAX(base.completed_revenue),'PASS','FAIL') AS result
FROM payment CROSS JOIN base;

WITH base AS (
    SELECT ROUND(SUM(oi.line_total), 2) AS completed_revenue
    FROM orders o JOIN order_statuses s ON s.status_id=o.status_id AND s.is_eligible=1 JOIN order_items oi ON oi.order_id=o.order_id
), category AS (
    SELECT p.category_id, ROUND(SUM(oi.line_total), 2) AS revenue
    FROM orders o JOIN order_statuses s ON s.status_id=o.status_id AND s.is_eligible=1 JOIN order_items oi ON oi.order_id=o.order_id JOIN products p ON p.product_id=oi.product_id
    GROUP BY p.category_id
)
SELECT 'category_revenue_reconcile_to_base' AS check_name, ROUND(SUM(category.revenue),2) AS category_revenue, MAX(base.completed_revenue) AS base_revenue, IF(ROUND(SUM(category.revenue),2)=MAX(base.completed_revenue),'PASS','FAIL') AS result
FROM category CROSS JOIN base;

WITH customer_orders AS (
    SELECT o.customer_id, COUNT(DISTINCT o.order_id) AS completed_orders, ROUND(SUM(oi.line_total),2) AS revenue
    FROM orders o JOIN order_statuses s ON s.status_id=o.status_id AND s.is_eligible=1 JOIN order_items oi ON oi.order_id=o.order_id
    GROUP BY o.customer_id
), frequency_bands AS (
    SELECT CASE WHEN completed_orders=1 THEN 'One order' WHEN completed_orders BETWEEN 2 AND 4 THEN '2-4 orders' WHEN completed_orders BETWEEN 5 AND 9 THEN '5-9 orders' ELSE '10+ orders' END AS frequency_band, revenue
    FROM customer_orders
), base AS (
    SELECT COUNT(*) AS completed_customers, ROUND(SUM(revenue),2) AS completed_revenue FROM customer_orders
), grouped AS (
    SELECT COUNT(*) AS grouped_customers, ROUND(SUM(revenue),2) AS grouped_revenue FROM frequency_bands
)
SELECT 'customer_frequency_bands_reconcile' AS check_name, grouped.grouped_customers, base.completed_customers, grouped.grouped_revenue, base.completed_revenue, IF(grouped.grouped_customers=base.completed_customers AND grouped.grouped_revenue=base.completed_revenue,'PASS','FAIL') AS result
FROM grouped CROSS JOIN base;

WITH order_values AS (
    SELECT o.order_id, ROUND(SUM(oi.line_total),2) AS order_value
    FROM orders o JOIN order_statuses s ON s.status_id=o.status_id AND s.is_eligible=1 JOIN order_items oi ON oi.order_id=o.order_id
    GROUP BY o.order_id
), bands AS (
    SELECT CASE WHEN order_value < 50 THEN 'Under USD 50' WHEN order_value < 100 THEN 'USD 50-99.99' WHEN order_value < 250 THEN 'USD 100-249.99' WHEN order_value < 500 THEN 'USD 250-499.99' ELSE 'USD 500+' END AS value_band, order_value
    FROM order_values
), grouped AS (
    SELECT COUNT(*) AS grouped_orders, ROUND(SUM(order_value),2) AS grouped_revenue FROM bands
), base AS (
    SELECT COUNT(*) AS completed_orders, ROUND(SUM(order_value),2) AS completed_revenue FROM order_values
)
SELECT 'order_value_bands_reconcile' AS check_name, grouped.grouped_orders, base.completed_orders, grouped.grouped_revenue, base.completed_revenue, IF(grouped.grouped_orders=base.completed_orders AND grouped.grouped_revenue=base.completed_revenue,'PASS','FAIL') AS result
FROM grouped CROSS JOIN base;

WITH base AS (
    SELECT COUNT(DISTINCT o.order_id) AS completed_orders, ROUND(SUM(oi.line_total),2) AS completed_revenue
    FROM orders o JOIN order_statuses s ON s.status_id=o.status_id AND s.is_eligible=1 JOIN order_items oi ON oi.order_id=o.order_id
), calendar_month AS (
    SELECT MONTH(o.order_date) AS month_number, COUNT(DISTINCT o.order_id) AS completed_orders, ROUND(SUM(oi.line_total),2) AS revenue
    FROM orders o JOIN order_statuses s ON s.status_id=o.status_id AND s.is_eligible=1 JOIN order_items oi ON oi.order_id=o.order_id
    GROUP BY MONTH(o.order_date)
)
SELECT 'month_of_year_pattern_reconcile' AS check_name, COUNT(*) AS calendar_months, SUM(calendar_month.completed_orders) AS completed_orders, SUM(calendar_month.revenue) AS revenue, IF(COUNT(*)=12 AND SUM(calendar_month.completed_orders)=MAX(base.completed_orders) AND ROUND(SUM(calendar_month.revenue),2)=MAX(base.completed_revenue),'PASS','FAIL') AS result
FROM calendar_month CROSS JOIN base;

SELECT 'PROHIBITED_PHASE4_OBJECT_CHECK' AS check_name,
       (SELECT COUNT(*) FROM information_schema.views WHERE table_schema=DATABASE()) AS views_created,
       (SELECT COUNT(*) FROM information_schema.routines WHERE routine_schema=DATABASE()) AS routines_created,
       IF((SELECT COUNT(*) FROM information_schema.views WHERE table_schema=DATABASE()) = 0 AND (SELECT COUNT(*) FROM information_schema.routines WHERE routine_schema=DATABASE()) = 0, 'PASS', 'FAIL') AS result;
