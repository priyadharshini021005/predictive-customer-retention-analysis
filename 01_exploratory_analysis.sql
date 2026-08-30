-- Predictive Customer Retention Analysis using SQL
-- Phase 4: Exploratory SQL analysis
-- Descriptive analysis only. No RFM, retention, churn, risk scoring, views, or Power BI objects.

USE predictive_customer_retention;

SELECT 'EXPLORATORY_SCOPE' AS section,
       'Descriptive purchasing, sales, product, category, channel, payment, and customer-order behavior only.' AS scope_statement;

SELECT 'OVERALL_COMPLETED_ORDER_PROFILE' AS section;
SELECT
    COUNT(DISTINCT o.order_id) AS completed_orders,
    COUNT(DISTINCT o.customer_id) AS customers_with_completed_orders,
    SUM(oi.quantity) AS completed_units,
    ROUND(SUM(oi.line_total), 2) AS completed_line_revenue,
    ROUND(SUM(oi.line_total) / COUNT(DISTINCT o.order_id), 2) AS average_order_value,
    ROUND(SUM(oi.quantity) / COUNT(DISTINCT o.order_id), 2) AS average_units_per_order
FROM orders o
JOIN order_statuses s ON s.status_id = o.status_id AND s.is_eligible = 1
JOIN order_items oi ON oi.order_id = o.order_id;

SELECT 'MONTHLY_COMPLETED_ORDER_TREND' AS section;
WITH monthly AS (
    SELECT
        DATE_FORMAT(o.order_date, '%Y-%m-01') AS order_month,
        COUNT(DISTINCT o.order_id) AS completed_orders,
        COUNT(DISTINCT o.customer_id) AS purchasing_customers,
        SUM(oi.quantity) AS units,
        ROUND(SUM(oi.line_total), 2) AS revenue,
        ROUND(SUM(oi.line_total) / COUNT(DISTINCT o.order_id), 2) AS average_order_value
    FROM orders o
    JOIN order_statuses s ON s.status_id = o.status_id AND s.is_eligible = 1
    JOIN order_items oi ON oi.order_id = o.order_id
    GROUP BY DATE_FORMAT(o.order_date, '%Y-%m-01')
), with_lag AS (
    SELECT
        order_month,
        completed_orders,
        purchasing_customers,
        units,
        revenue,
        average_order_value,
        LAG(revenue) OVER (ORDER BY order_month) AS previous_month_revenue
    FROM monthly
)
SELECT
    order_month,
    completed_orders,
    purchasing_customers,
    units,
    revenue,
    average_order_value,
    previous_month_revenue,
    ROUND(revenue - previous_month_revenue, 2) AS revenue_change,
    CASE
        WHEN previous_month_revenue IS NULL THEN 'Baseline month'
        WHEN revenue > previous_month_revenue THEN 'Increase'
        WHEN revenue < previous_month_revenue THEN 'Decrease'
        ELSE 'No change'
    END AS revenue_direction
FROM with_lag
ORDER BY order_month;

SELECT 'MONTHLY_ORDER_STATUS_TREND' AS section;
SELECT
    DATE_FORMAT(o.order_date, '%Y-%m-01') AS order_month,
    s.status_code,
    COUNT(*) AS order_count,
    ROUND(COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY DATE_FORMAT(o.order_date, '%Y-%m-01')) * 100, 2) AS share_of_month_orders
FROM orders o
JOIN order_statuses s ON s.status_id = o.status_id
GROUP BY DATE_FORMAT(o.order_date, '%Y-%m-01'), s.status_code
ORDER BY order_month, s.status_code;

SELECT 'SALES_CHANNEL_PERFORMANCE' AS section;
SELECT
    sc.sales_channel_name,
    COUNT(DISTINCT o.order_id) AS completed_orders,
    COUNT(DISTINCT o.customer_id) AS customers,
    SUM(oi.quantity) AS units,
    ROUND(SUM(oi.line_total), 2) AS revenue,
    ROUND(SUM(oi.line_total) / COUNT(DISTINCT o.order_id), 2) AS average_order_value,
    ROUND(100 * SUM(oi.line_total) / SUM(SUM(oi.line_total)) OVER (), 2) AS revenue_share_percent
FROM orders o
JOIN order_statuses s ON s.status_id = o.status_id AND s.is_eligible = 1
JOIN sales_channels sc ON sc.sales_channel_id = o.sales_channel_id
JOIN order_items oi ON oi.order_id = o.order_id
GROUP BY sc.sales_channel_id, sc.sales_channel_name
ORDER BY revenue DESC;

SELECT 'PAYMENT_METHOD_PERFORMANCE' AS section;
SELECT
    pm.payment_method_name,
    COUNT(DISTINCT o.order_id) AS completed_orders,
    COUNT(DISTINCT o.customer_id) AS customers,
    ROUND(SUM(oi.line_total), 2) AS revenue,
    ROUND(SUM(oi.line_total) / COUNT(DISTINCT o.order_id), 2) AS average_order_value
FROM orders o
JOIN order_statuses s ON s.status_id = o.status_id AND s.is_eligible = 1
JOIN payment_methods pm ON pm.payment_method_id = o.payment_method_id
JOIN order_items oi ON oi.order_id = o.order_id
GROUP BY pm.payment_method_id, pm.payment_method_name
ORDER BY revenue DESC;

SELECT 'CATEGORY_PERFORMANCE' AS section;
SELECT
    c.category_name,
    COUNT(DISTINCT o.order_id) AS completed_orders,
    COUNT(DISTINCT o.customer_id) AS customers,
    SUM(oi.quantity) AS units,
    ROUND(SUM(oi.line_total), 2) AS revenue,
    ROUND(SUM(oi.line_total) / COUNT(DISTINCT o.order_id), 2) AS revenue_per_order,
    ROUND(100 * SUM(oi.line_total) / SUM(SUM(oi.line_total)) OVER (), 2) AS revenue_share_percent
FROM order_items oi
JOIN orders o ON o.order_id = oi.order_id
JOIN order_statuses s ON s.status_id = o.status_id AND s.is_eligible = 1
JOIN products p ON p.product_id = oi.product_id
JOIN categories c ON c.category_id = p.category_id
GROUP BY c.category_id, c.category_name
ORDER BY revenue DESC;

SELECT 'TOP_PRODUCTS_WITHIN_CATEGORY' AS section;
WITH product_sales AS (
    SELECT
        c.category_name,
        p.product_id,
        p.sku,
        p.product_name,
        COUNT(DISTINCT o.order_id) AS completed_orders,
        SUM(oi.quantity) AS units,
        ROUND(SUM(oi.line_total), 2) AS revenue
    FROM order_items oi
    JOIN orders o ON o.order_id = oi.order_id
    JOIN order_statuses s ON s.status_id = o.status_id AND s.is_eligible = 1
    JOIN products p ON p.product_id = oi.product_id
    JOIN categories c ON c.category_id = p.category_id
    GROUP BY c.category_name, p.product_id, p.sku, p.product_name
), ranked AS (
    SELECT
        product_sales.*,
        RANK() OVER (PARTITION BY category_name ORDER BY revenue DESC) AS revenue_rank_within_category
    FROM product_sales
)
SELECT category_name, product_id, sku, product_name, completed_orders, units, revenue, revenue_rank_within_category
FROM ranked
WHERE revenue_rank_within_category <= 3
ORDER BY category_name, revenue_rank_within_category, revenue DESC;

SELECT 'CUSTOMER_COMPLETED_ORDER_FREQUENCY' AS section;
WITH customer_orders AS (
    SELECT
        o.customer_id,
        COUNT(DISTINCT o.order_id) AS completed_order_count,
        ROUND(SUM(oi.line_total), 2) AS customer_revenue,
        ROUND(SUM(oi.line_total) / COUNT(DISTINCT o.order_id), 2) AS customer_average_order_value
    FROM orders o
    JOIN order_statuses s ON s.status_id = o.status_id AND s.is_eligible = 1
    JOIN order_items oi ON oi.order_id = o.order_id
    GROUP BY o.customer_id
), frequency_bands AS (
    SELECT
        customer_id,
        completed_order_count,
        customer_revenue,
        customer_average_order_value,
        CASE
            WHEN completed_order_count = 1 THEN 'One order'
            WHEN completed_order_count BETWEEN 2 AND 4 THEN '2-4 orders'
            WHEN completed_order_count BETWEEN 5 AND 9 THEN '5-9 orders'
            ELSE '10+ orders'
        END AS frequency_band,
        NTILE(4) OVER (ORDER BY customer_revenue) AS revenue_quartile
    FROM customer_orders
)
SELECT
    frequency_band,
    COUNT(*) AS customer_count,
    ROUND(SUM(customer_revenue), 2) AS revenue,
    ROUND(AVG(customer_average_order_value), 2) AS average_customer_order_value,
    MIN(revenue_quartile) AS lowest_revenue_quartile,
    MAX(revenue_quartile) AS highest_revenue_quartile
FROM frequency_bands
GROUP BY frequency_band
ORDER BY MIN(completed_order_count);

SELECT 'ORDER_VALUE_BANDS' AS section;
WITH order_values AS (
    SELECT
        o.order_id,
        SUM(oi.line_total) AS order_value
    FROM orders o
    JOIN order_statuses s ON s.status_id = o.status_id AND s.is_eligible = 1
    JOIN order_items oi ON oi.order_id = o.order_id
    GROUP BY o.order_id
)
SELECT
    CASE
        WHEN order_value < 50 THEN 'Under USD 50'
        WHEN order_value < 100 THEN 'USD 50-99.99'
        WHEN order_value < 250 THEN 'USD 100-249.99'
        WHEN order_value < 500 THEN 'USD 250-499.99'
        ELSE 'USD 500+'
    END AS order_value_band,
    COUNT(*) AS order_count,
    ROUND(SUM(order_value), 2) AS revenue,
    ROUND(AVG(order_value), 2) AS average_order_value
FROM order_values
GROUP BY order_value_band
ORDER BY MIN(order_value);

SELECT 'MONTH_OF_YEAR_PATTERN' AS section;
SELECT
    MONTH(o.order_date) AS calendar_month_number,
    MONTHNAME(o.order_date) AS calendar_month,
    COUNT(DISTINCT o.order_id) AS completed_orders,
    COUNT(DISTINCT o.customer_id) AS customers,
    ROUND(SUM(oi.line_total), 2) AS revenue,
    ROUND(SUM(oi.line_total) / COUNT(DISTINCT o.order_id), 2) AS average_order_value
FROM orders o
JOIN order_statuses s ON s.status_id = o.status_id AND s.is_eligible = 1
JOIN order_items oi ON oi.order_id = o.order_id
GROUP BY MONTH(o.order_date), MONTHNAME(o.order_date)
ORDER BY calendar_month_number;

SELECT 'TOP_CUSTOMERS_BY_COMPLETED_REVENUE' AS section;
SELECT customer_id, completed_orders, completed_units, completed_revenue, revenue_rank
FROM (
    SELECT
        o.customer_id,
        COUNT(DISTINCT o.order_id) AS completed_orders,
        SUM(oi.quantity) AS completed_units,
        ROUND(SUM(oi.line_total), 2) AS completed_revenue,
        DENSE_RANK() OVER (ORDER BY SUM(oi.line_total) DESC) AS revenue_rank
    FROM orders o
    JOIN order_statuses s ON s.status_id = o.status_id AND s.is_eligible = 1
    JOIN order_items oi ON oi.order_id = o.order_id
    GROUP BY o.customer_id
) AS ranked_customers
WHERE revenue_rank <= 20
ORDER BY revenue_rank, customer_id;
