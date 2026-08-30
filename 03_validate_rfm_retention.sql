-- Predictive Customer Retention Analysis using SQL
-- Phase 5: RFM and retention validation
-- Raw chronology-exception rows remain unchanged; this script applies the approved analytical filter.

USE predictive_customer_retention;

WITH eligible_order_values AS (
    SELECT
        o.order_id,
        o.customer_id,
        o.order_date,
        DATE_FORMAT(o.order_date, '%Y-%m-01') AS order_month,
        ROUND(SUM(oi.line_total), 2) AS order_value
    FROM orders o
    JOIN customers c ON c.customer_id = o.customer_id
    JOIN order_statuses s ON s.status_id = o.status_id AND s.is_eligible = 1
    JOIN order_items oi ON oi.order_id = o.order_id
    WHERE o.order_date >= c.signup_date
    GROUP BY o.order_id, o.customer_id, o.order_date, DATE_FORMAT(o.order_date, '%Y-%m-01')
),
base AS (
    SELECT COUNT(*) AS eligible_orders, COUNT(DISTINCT customer_id) AS eligible_customers, ROUND(SUM(order_value),2) AS eligible_revenue, MIN(order_date) AS min_date, MAX(order_date) AS max_date
    FROM eligible_order_values
)
SELECT 'eligible_lifecycle_population' AS check_name,
       eligible_orders,
       eligible_customers,
       eligible_revenue,
       min_date,
       max_date,
       IF(eligible_orders = 35017 AND eligible_customers = 7069 AND eligible_revenue = 53997988.41 AND min_date = '2024-01-01' AND max_date = '2025-12-31', 'PASS', 'FAIL') AS result
FROM base;

SELECT 'chronology_exception_exclusion' AS check_name,
       COUNT(DISTINCT o.order_id) AS excluded_completed_orders,
       COUNT(DISTINCT o.customer_id) AS excluded_customers,
       ROUND(SUM(oi.line_total),2) AS excluded_revenue,
       IF(COUNT(DISTINCT o.order_id) = 483 AND COUNT(DISTINCT o.customer_id) = 375, 'PASS', 'FAIL') AS result
FROM orders o
JOIN customers c ON c.customer_id=o.customer_id
JOIN order_statuses s ON s.status_id=o.status_id AND s.is_eligible=1
JOIN order_items oi ON oi.order_id=o.order_id
WHERE o.order_date < c.signup_date;

WITH eligible_order_values AS (
    SELECT o.order_id, o.customer_id, o.order_date, ROUND(SUM(oi.line_total),2) AS order_value
    FROM orders o JOIN customers c ON c.customer_id=o.customer_id JOIN order_statuses s ON s.status_id=o.status_id AND s.is_eligible=1 JOIN order_items oi ON oi.order_id=o.order_id
    WHERE o.order_date >= c.signup_date
    GROUP BY o.order_id, o.customer_id, o.order_date
),
customer_metrics AS (
    SELECT customer_id, MIN(order_date) AS first_order_date, MAX(order_date) AS last_order_date, DATEDIFF('2025-12-31',MAX(order_date)) AS recency_days, COUNT(*) AS frequency, ROUND(SUM(order_value),2) AS monetary_value
    FROM eligible_order_values GROUP BY customer_id
),
rfm_scored AS (
    SELECT customer_metrics.*,
           6-NTILE(5) OVER (ORDER BY recency_days ASC, customer_id ASC) AS recency_score,
           6-NTILE(5) OVER (ORDER BY frequency DESC, customer_id ASC) AS frequency_score,
           6-NTILE(5) OVER (ORDER BY monetary_value DESC, customer_id ASC) AS monetary_score
    FROM customer_metrics
),
rfm_labeled AS (
    SELECT rfm_scored.*,
           recency_score + frequency_score + monetary_score AS rfm_score,
           CASE
               WHEN recency_score + frequency_score + monetary_score >= 13 THEN 'Champions'
               WHEN monetary_score >= 4 AND recency_score <= 2 THEN 'High Value At Risk'
               WHEN frequency_score >= 4 AND recency_score >= 3 THEN 'Loyal Customers'
               WHEN recency_score >= 4 AND frequency_score BETWEEN 2 AND 3 THEN 'Potential Loyalists'
               WHEN frequency = 1 AND recency_score >= 4 THEN 'New Customers'
               WHEN recency_score <= 2 AND frequency >= 2 THEN 'At Risk'
               ELSE 'Needs Attention'
           END AS rfm_segment
    FROM rfm_scored
)
SELECT 'rfm_customer_reconciliation' AS check_name,
       COUNT(*) AS rfm_customers,
       COUNT(DISTINCT customer_id) AS distinct_rfm_customers,
       SUM(frequency) AS summed_frequency,
       MAX(rfm_score) AS max_rfm_score,
       MIN(rfm_score) AS min_rfm_score,
       SUM(rfm_segment IS NULL) AS null_segments,
       IF(COUNT(*) = 7069 AND COUNT(DISTINCT customer_id) = 7069 AND SUM(frequency) = 35017 AND MIN(rfm_score) >= 3 AND MAX(rfm_score) <= 15 AND SUM(rfm_segment IS NULL) = 0, 'PASS', 'FAIL') AS result
FROM rfm_labeled;

WITH eligible_order_values AS (
    SELECT o.order_id, o.customer_id, o.order_date, ROUND(SUM(oi.line_total),2) AS order_value
    FROM orders o JOIN customers c ON c.customer_id=o.customer_id JOIN order_statuses s ON s.status_id=o.status_id AND s.is_eligible=1 JOIN order_items oi ON oi.order_id=o.order_id
    WHERE o.order_date >= c.signup_date GROUP BY o.order_id,o.customer_id,o.order_date
),
customer_metrics AS (
    SELECT customer_id, COUNT(*) AS frequency, ROUND(SUM(order_value),2) AS monetary_value FROM eligible_order_values GROUP BY customer_id
),
rfm_scored AS (
    SELECT customer_metrics.*, 6-NTILE(5) OVER (ORDER BY frequency DESC, customer_id ASC) AS frequency_score, 6-NTILE(5) OVER (ORDER BY monetary_value DESC, customer_id ASC) AS monetary_score
    FROM customer_metrics
)
SELECT 'rfm_monetary_reconciliation' AS check_name,
       ROUND(SUM(monetary_value),2) AS summed_customer_monetary_value,
       53997988.41 AS eligible_revenue,
       MIN(frequency_score) AS min_frequency_score,
       MAX(frequency_score) AS max_frequency_score,
       MIN(monetary_score) AS min_monetary_score,
       MAX(monetary_score) AS max_monetary_score,
       IF(ROUND(SUM(monetary_value),2) = 53997988.41 AND MIN(frequency_score) >= 1 AND MAX(frequency_score) <= 5 AND MIN(monetary_score) >= 1 AND MAX(monetary_score) <= 5, 'PASS', 'FAIL') AS result
FROM rfm_scored;

WITH eligible_order_values AS (
    SELECT o.order_id, o.customer_id, o.order_date, DATE_FORMAT(o.order_date,'%Y-%m-01') AS order_month, ROUND(SUM(oi.line_total),2) AS order_value
    FROM orders o JOIN customers c ON c.customer_id=o.customer_id JOIN order_statuses s ON s.status_id=o.status_id AND s.is_eligible=1 JOIN order_items oi ON oi.order_id=o.order_id
    WHERE o.order_date >= c.signup_date GROUP BY o.order_id,o.customer_id,o.order_date,DATE_FORMAT(o.order_date,'%Y-%m-01')
),
customer_counts AS (
    SELECT customer_id, COUNT(*) AS frequency FROM eligible_order_values GROUP BY customer_id
)
SELECT 'period_repeat_retention' AS check_name,
       COUNT(*) AS eligible_customers,
       SUM(frequency >= 2) AS repeat_customers,
       SUM(frequency = 1) AS one_order_customers,
       ROUND(100 * SUM(frequency >= 2) / COUNT(*),2) AS period_repeat_retention_rate,
       IF(SUM(frequency >= 2) + SUM(frequency = 1) = COUNT(*), 'PASS', 'FAIL') AS result
FROM customer_counts;

WITH eligible_order_values AS (
    SELECT o.order_id, o.customer_id, o.order_date, DATE_FORMAT(o.order_date,'%Y-%m-01') AS order_month, ROUND(SUM(oi.line_total),2) AS order_value
    FROM orders o JOIN customers c ON c.customer_id=o.customer_id JOIN order_statuses s ON s.status_id=o.status_id AND s.is_eligible=1 JOIN order_items oi ON oi.order_id=o.order_id
    WHERE o.order_date >= c.signup_date GROUP BY o.order_id,o.customer_id,o.order_date,DATE_FORMAT(o.order_date,'%Y-%m-01')
),
customer_cohorts AS (
    SELECT customer_id, DATE_FORMAT(MIN(order_date),'%Y-%m-01') AS cohort_month FROM eligible_order_values GROUP BY customer_id
),
cohort_sizes AS (
    SELECT cohort_month, COUNT(DISTINCT customer_id) AS cohort_size FROM customer_cohorts GROUP BY cohort_month
)
SELECT 'cohort_base_reconciliation' AS check_name,
       COUNT(*) AS cohort_month_count,
       SUM(cohort_size) AS summed_cohort_size,
       7069 AS eligible_customers,
       MIN(cohort_size) AS smallest_cohort,
       MAX(cohort_size) AS largest_cohort,
       IF(SUM(cohort_size)=7069 AND COUNT(*)=24, 'PASS', 'FAIL') AS result
FROM cohort_sizes;

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
    SELECT cohort_month, COUNT(DISTINCT customer_id) AS cohort_size FROM customer_cohorts GROUP BY cohort_month
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
SELECT 'cohort_retention_bounds_and_month0' AS check_name,
       out_of_bounds_rows,
       invalid_month0_rows,
       cohort_months_observed,
       IF(out_of_bounds_rows = 0 AND invalid_month0_rows = 0 AND cohort_months_observed = 24, 'PASS', 'FAIL') AS result
FROM cohort_validation;

WITH eligible_orders AS (
    SELECT o.order_id, o.customer_id, o.order_date
    FROM orders o JOIN customers c ON c.customer_id=o.customer_id JOIN order_statuses s ON s.status_id=o.status_id AND s.is_eligible=1
    WHERE o.order_date >= c.signup_date
),
customer_cohorts AS (
    SELECT customer_id, DATE_FORMAT(MIN(order_date),'%Y-%m-01') AS cohort_month FROM eligible_orders GROUP BY customer_id
),
cohort_sizes AS (
    SELECT cohort_month, COUNT(DISTINCT customer_id) AS cohort_size FROM customer_cohorts GROUP BY cohort_month
),
month_1_activity AS (
    SELECT DISTINCT cc.cohort_month, eo.customer_id
    FROM customer_cohorts cc JOIN eligible_orders eo ON eo.customer_id=cc.customer_id
    WHERE DATE_FORMAT(eo.order_date,'%Y-%m-01') = DATE_FORMAT(DATE_ADD(STR_TO_DATE(cc.cohort_month,'%Y-%m-%d'),INTERVAL 1 MONTH),'%Y-%m-01')
),
month_1 AS (
    SELECT cs.cohort_month, cs.cohort_size, COUNT(DISTINCT m1.customer_id) AS retained_customers, CASE WHEN DATE_ADD(STR_TO_DATE(cs.cohort_month,'%Y-%m-%d'),INTERVAL 1 MONTH) <= '2025-12-01' THEN 1 ELSE 0 END AS observation_complete
    FROM cohort_sizes cs LEFT JOIN month_1_activity m1 ON m1.cohort_month=cs.cohort_month GROUP BY cs.cohort_month,cs.cohort_size
)
SELECT 'month1_retention_completeness' AS check_name,
       COUNT(*) AS all_cohorts,
       SUM(observation_complete) AS complete_cohorts,
       SUM(observation_complete = 0) AS incomplete_cohorts,
       SUM(retained_customers > cohort_size) AS invalid_retained_counts,
       IF(COUNT(*)=24 AND SUM(observation_complete)=23 AND SUM(observation_complete = 0)=1 AND SUM(retained_customers > cohort_size)=0, 'PASS', 'FAIL') AS result
FROM month_1;

SELECT 'PHASE5_SCOPE_BOUNDARY' AS check_name,
       (SELECT COUNT(*) FROM information_schema.views WHERE table_schema=DATABASE()) AS views_created,
       (SELECT COUNT(*) FROM information_schema.routines WHERE routine_schema=DATABASE()) AS routines_created,
       IF((SELECT COUNT(*) FROM information_schema.views WHERE table_schema=DATABASE())=0 AND (SELECT COUNT(*) FROM information_schema.routines WHERE routine_schema=DATABASE())=0, 'PASS', 'FAIL') AS result;
