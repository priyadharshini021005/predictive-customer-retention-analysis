USE predictive_customer_retention;

WITH eligible_order_values AS (
    SELECT o.order_id, o.customer_id, o.order_date, DATE_FORMAT(o.order_date,'%Y-%m-01') AS activity_month
    FROM orders o JOIN customers c ON c.customer_id=o.customer_id JOIN order_statuses s ON s.status_id=o.status_id AND s.is_eligible=1 JOIN order_items oi ON oi.order_id=o.order_id
    WHERE o.order_date >= c.signup_date GROUP BY o.order_id,o.customer_id,o.order_date,DATE_FORMAT(o.order_date,'%Y-%m-01')
),
customer_cohorts AS (
    SELECT customer_id, DATE_FORMAT(MIN(order_date),'%Y-%m-01') AS cohort_month FROM eligible_order_values GROUP BY customer_id
),
cohort_activity AS (
    SELECT DISTINCT cc.cohort_month, eo.activity_month, eo.customer_id, TIMESTAMPDIFF(MONTH,STR_TO_DATE(cc.cohort_month,'%Y-%m-%d'),STR_TO_DATE(eo.activity_month,'%Y-%m-%d')) AS elapsed_month
    FROM customer_cohorts cc JOIN eligible_order_values eo ON eo.customer_id=cc.customer_id
),
cohort_sizes AS (
    SELECT cohort_month, COUNT(*) AS cohort_size FROM customer_cohorts GROUP BY cohort_month
),
cohort_retention AS (
    SELECT ca.cohort_month, ca.elapsed_month, cs.cohort_size, COUNT(DISTINCT ca.customer_id) AS retained_customers, 100 * COUNT(DISTINCT ca.customer_id) / cs.cohort_size AS retention_rate
    FROM cohort_activity ca JOIN cohort_sizes cs ON cs.cohort_month=ca.cohort_month
    GROUP BY ca.cohort_month,ca.elapsed_month,cs.cohort_size
),
cohort_validation AS (
    SELECT
        SUM(CASE WHEN retention_rate < 0 OR retention_rate > 100 THEN 1 ELSE 0 END) AS out_of_bounds_rows,
        SUM(CASE WHEN elapsed_month = 0 AND retained_customers <> cohort_size THEN 1 ELSE 0 END) AS invalid_month0_rows,
        COUNT(DISTINCT cohort_month) AS cohort_months_observed
    FROM cohort_retention
)
SELECT out_of_bounds_rows, invalid_month0_rows, cohort_months_observed,
       IF(out_of_bounds_rows = 0 AND invalid_month0_rows = 0 AND cohort_months_observed = 24, 'PASS', 'FAIL') AS result
FROM cohort_validation;
