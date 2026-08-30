-- Predictive Customer Retention Analysis using SQL
-- Phase 5: Retention and cohort analysis
-- Approved lifecycle filter: completed and order_date >= signup_date.
-- This script does not create a predictive risk score.

USE predictive_customer_retention;

WITH eligible_orders AS (
    SELECT
        o.order_id,
        o.customer_id,
        o.order_date,
        DATE_FORMAT(o.order_date, '%Y-%m-01') AS order_month
    FROM orders AS o
    JOIN customers AS c ON c.customer_id = o.customer_id
    JOIN order_statuses AS s ON s.status_id = o.status_id AND s.is_eligible = 1
    WHERE o.order_date >= c.signup_date
),
order_values AS (
    SELECT
        eo.order_id,
        eo.customer_id,
        eo.order_date,
        eo.order_month,
        ROUND(SUM(oi.line_total), 2) AS order_value
    FROM eligible_orders AS eo
    JOIN order_items AS oi ON oi.order_id = eo.order_id
    GROUP BY eo.order_id, eo.customer_id, eo.order_date, eo.order_month
),
customer_period_metrics AS (
    SELECT
        customer_id,
        COUNT(*) AS eligible_order_count,
        ROUND(SUM(order_value), 2) AS monetary_value,
        MIN(order_date) AS first_eligible_order_date,
        MAX(order_date) AS last_eligible_order_date,
        DATE_FORMAT(MIN(order_date), '%Y-%m-01') AS cohort_month
    FROM order_values
    GROUP BY customer_id
),
monthly_metrics AS (
    SELECT
        order_month,
        COUNT(*) AS eligible_orders,
        COUNT(DISTINCT customer_id) AS monthly_active_customers,
        ROUND(SUM(order_value), 2) AS eligible_revenue,
        ROUND(SUM(order_value) / COUNT(*), 2) AS average_order_value
    FROM order_values
    GROUP BY order_month
),
monthly_customer_status AS (
    SELECT
        om.order_month,
        om.customer_id,
        cpm.cohort_month,
        CASE WHEN cpm.cohort_month = om.order_month THEN 1 ELSE 0 END AS is_new_customer,
        CASE WHEN cpm.cohort_month < om.order_month THEN 1 ELSE 0 END AS is_returning_customer
    FROM (SELECT DISTINCT order_month, customer_id FROM order_values) AS om
    JOIN customer_period_metrics AS cpm ON cpm.customer_id = om.customer_id
)
SELECT
    mm.order_month,
    mm.eligible_orders,
    mm.monthly_active_customers,
    COUNT(DISTINCT CASE WHEN mcs.is_new_customer = 1 THEN mcs.customer_id END) AS new_customers,
    COUNT(DISTINCT CASE WHEN mcs.is_returning_customer = 1 THEN mcs.customer_id END) AS returning_customers,
    ROUND(100 * COUNT(DISTINCT CASE WHEN mcs.is_returning_customer = 1 THEN mcs.customer_id END) / mm.monthly_active_customers, 2) AS monthly_repeat_customer_rate,
    mm.eligible_revenue,
    mm.average_order_value
FROM monthly_metrics AS mm
JOIN monthly_customer_status AS mcs ON mcs.order_month = mm.order_month
GROUP BY mm.order_month, mm.eligible_orders, mm.monthly_active_customers, mm.eligible_revenue, mm.average_order_value
ORDER BY mm.order_month;

WITH eligible_orders AS (
    SELECT
        o.order_id,
        o.customer_id,
        o.order_date,
        DATE_FORMAT(o.order_date, '%Y-%m-01') AS activity_month
    FROM orders AS o
    JOIN customers AS c ON c.customer_id = o.customer_id
    JOIN order_statuses AS s ON s.status_id = o.status_id AND s.is_eligible = 1
    WHERE o.order_date >= c.signup_date
),
customer_cohorts AS (
    SELECT customer_id, DATE_FORMAT(MIN(order_date), '%Y-%m-01') AS cohort_month
    FROM eligible_orders
    GROUP BY customer_id
),
cohort_activity AS (
    SELECT DISTINCT
        cc.cohort_month,
        eo.activity_month,
        eo.customer_id,
        TIMESTAMPDIFF(MONTH, cc.cohort_month, eo.activity_month) AS elapsed_month
    FROM customer_cohorts AS cc
    JOIN eligible_orders AS eo ON eo.customer_id = cc.customer_id
),
cohort_sizes AS (
    SELECT cohort_month, COUNT(DISTINCT customer_id) AS cohort_size
    FROM customer_cohorts
    GROUP BY cohort_month
)
SELECT
    ca.cohort_month,
    ca.elapsed_month,
    cs.cohort_size,
    COUNT(DISTINCT ca.customer_id) AS retained_customers,
    ROUND(100 * COUNT(DISTINCT ca.customer_id) / cs.cohort_size, 2) AS retention_rate,
    CASE WHEN DATE_ADD(STR_TO_DATE(ca.cohort_month, '%Y-%m-%d'), INTERVAL ca.elapsed_month MONTH) <= '2025-12-01' THEN 1 ELSE 0 END AS observation_complete
FROM cohort_activity AS ca
JOIN cohort_sizes AS cs ON cs.cohort_month = ca.cohort_month
GROUP BY ca.cohort_month, ca.elapsed_month, cs.cohort_size
ORDER BY ca.cohort_month, ca.elapsed_month;

WITH eligible_orders AS (
    SELECT
        o.order_id,
        o.customer_id,
        o.order_date
    FROM orders AS o
    JOIN customers AS c ON c.customer_id = o.customer_id
    JOIN order_statuses AS s ON s.status_id = o.status_id AND s.is_eligible = 1
    WHERE o.order_date >= c.signup_date
),
customer_cohorts AS (
    SELECT customer_id, DATE_FORMAT(MIN(order_date), '%Y-%m-01') AS cohort_month
    FROM eligible_orders
    GROUP BY customer_id
),
cohort_sizes AS (
    SELECT cohort_month, COUNT(DISTINCT customer_id) AS cohort_size
    FROM customer_cohorts
    GROUP BY cohort_month
),
month_1_activity AS (
    SELECT DISTINCT
        cc.cohort_month,
        eo.customer_id
    FROM customer_cohorts AS cc
    JOIN eligible_orders AS eo ON eo.customer_id = cc.customer_id
    WHERE DATE_FORMAT(eo.order_date, '%Y-%m-01') = DATE_FORMAT(DATE_ADD(STR_TO_DATE(cc.cohort_month, '%Y-%m-%d'), INTERVAL 1 MONTH), '%Y-%m-01')
)
SELECT
    cs.cohort_month,
    cs.cohort_size,
    COUNT(DISTINCT m1.customer_id) AS month_1_retained_customers,
    ROUND(100 * COUNT(DISTINCT m1.customer_id) / cs.cohort_size, 2) AS month_1_retention_rate,
    CASE WHEN DATE_ADD(STR_TO_DATE(cs.cohort_month, '%Y-%m-%d'), INTERVAL 1 MONTH) <= '2025-12-01' THEN 1 ELSE 0 END AS observation_complete
FROM cohort_sizes AS cs
LEFT JOIN month_1_activity AS m1 ON m1.cohort_month = cs.cohort_month
GROUP BY cs.cohort_month, cs.cohort_size
ORDER BY cs.cohort_month;

WITH eligible_orders AS (
    SELECT o.order_id, o.customer_id
    FROM orders AS o
    JOIN customers AS c ON c.customer_id = o.customer_id
    JOIN order_statuses AS s ON s.status_id = o.status_id AND s.is_eligible = 1
    WHERE o.order_date >= c.signup_date
),
customer_counts AS (
    SELECT customer_id, COUNT(DISTINCT order_id) AS eligible_order_count
    FROM eligible_orders
    GROUP BY customer_id
)
SELECT
    COUNT(*) AS eligible_customers,
    SUM(eligible_order_count >= 2) AS repeat_customers,
    ROUND(100 * SUM(eligible_order_count >= 2) / COUNT(*), 2) AS period_repeat_retention_rate,
    SUM(eligible_order_count = 1) AS one_order_customers
FROM customer_counts;
