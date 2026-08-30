-- Predictive Customer Retention Analysis using SQL
-- Phase 5 methodology review: read-only checks only.
-- No database structure or data is modified.

USE predictive_customer_retention;

-- Shared eligible order grain: one row per eligible completed order.
WITH eligible_orders AS (
    SELECT
        o.order_id,
        o.customer_id,
        o.order_date
    FROM orders AS o
    JOIN customers AS c ON c.customer_id = o.customer_id
    JOIN order_statuses AS s ON s.status_id = o.status_id
    WHERE s.is_eligible = 1
      AND o.order_date >= c.signup_date
),
rfm_customers AS (
    SELECT DISTINCT customer_id
    FROM eligible_orders
)
SELECT
    '1_rfm_customer_eligibility' AS check_id,
    (SELECT COUNT(*) FROM rfm_customers) AS rfm_customers,
    (SELECT COUNT(*) FROM rfm_customers rc JOIN customers c ON c.customer_id = rc.customer_id) AS customers_with_eligible_purchase,
    IF((SELECT COUNT(*) FROM rfm_customers) = 7069
       AND (SELECT COUNT(*) FROM rfm_customers rc JOIN customers c ON c.customer_id = rc.customer_id) = 7069,
       'PASS', 'FAIL') AS result;

-- Zero-purchase customers must not enter normal RFM scoring.
WITH eligible_customers AS (
    SELECT DISTINCT o.customer_id
    FROM orders AS o
    JOIN customers AS c ON c.customer_id = o.customer_id
    JOIN order_statuses AS s ON s.status_id = o.status_id AND s.is_eligible = 1
    WHERE o.order_date >= c.signup_date
),
rfm_output AS (
    SELECT DISTINCT customer_id
    FROM (
        SELECT
            o.customer_id,
            COUNT(DISTINCT o.order_id) AS frequency,
            ROUND(SUM(oi.line_total), 2) AS monetary_value
        FROM orders AS o
        JOIN customers AS c ON c.customer_id = o.customer_id
        JOIN order_statuses AS s ON s.status_id = o.status_id AND s.is_eligible = 1
        JOIN order_items AS oi ON oi.order_id = o.order_id
        WHERE o.order_date >= c.signup_date
        GROUP BY o.customer_id
    ) AS scored_population
)
SELECT
    '2_zero_purchase_exclusion' AS check_id,
    (SELECT COUNT(*) FROM customers c LEFT JOIN eligible_customers ec ON ec.customer_id = c.customer_id WHERE ec.customer_id IS NULL) AS zero_purchase_customers,
    (SELECT COUNT(*) FROM rfm_output ro LEFT JOIN eligible_customers ec ON ec.customer_id = ro.customer_id WHERE ec.customer_id IS NULL) AS zero_purchase_customers_in_rfm,
    IF((SELECT COUNT(*) FROM rfm_output ro LEFT JOIN eligible_customers ec ON ec.customer_id = ro.customer_id WHERE ec.customer_id IS NULL) = 0, 'PASS', 'FAIL') AS result;

-- RFM segment counts and percentages from the Phase 5 scoring logic.
WITH eligible_order_values AS (
    SELECT
        o.order_id,
        o.customer_id,
        o.order_date,
        ROUND(SUM(oi.line_total), 2) AS order_value
    FROM orders AS o
    JOIN customers AS c ON c.customer_id = o.customer_id
    JOIN order_statuses AS s ON s.status_id = o.status_id AND s.is_eligible = 1
    JOIN order_items AS oi ON oi.order_id = o.order_id
    WHERE o.order_date >= c.signup_date
    GROUP BY o.order_id, o.customer_id, o.order_date
),
customer_metrics AS (
    SELECT
        customer_id,
        MAX(order_date) AS last_order_date,
        COUNT(*) AS frequency,
        ROUND(SUM(order_value), 2) AS monetary_value
    FROM eligible_order_values
    GROUP BY customer_id
),
scored AS (
    SELECT
        customer_metrics.*,
        6 - NTILE(5) OVER (ORDER BY DATEDIFF('2025-12-31', last_order_date) ASC, customer_id ASC) AS r_score,
        6 - NTILE(5) OVER (ORDER BY frequency DESC, customer_id ASC) AS f_score,
        6 - NTILE(5) OVER (ORDER BY monetary_value DESC, customer_id ASC) AS m_score
    FROM customer_metrics
),
segmented AS (
    SELECT
        customer_id,
        CASE
            WHEN r_score + f_score + m_score >= 13 THEN 'Champions'
            WHEN m_score >= 4 AND r_score <= 2 THEN 'High Value At Risk'
            WHEN f_score >= 4 AND r_score >= 3 THEN 'Loyal Customers'
            WHEN r_score >= 4 AND f_score BETWEEN 2 AND 3 THEN 'Potential Loyalists'
            WHEN frequency = 1 AND r_score >= 4 THEN 'New Customers'
            WHEN r_score <= 2 AND frequency >= 2 THEN 'At Risk'
            ELSE 'Needs Attention'
        END AS rfm_segment
    FROM scored
),
segment_counts AS (
    SELECT rfm_segment, COUNT(*) AS customer_count
    FROM segmented
    GROUP BY rfm_segment
)
SELECT
    '3_rfm_segment_counts' AS check_id,
    rfm_segment,
    customer_count,
    ROUND(100 * customer_count / (SELECT COUNT(*) FROM segmented), 2) AS customer_percentage,
    IF((SELECT SUM(customer_count) FROM segment_counts) = 7069
       AND (SELECT COUNT(*) FROM segment_counts) = 7,
       'PASS', 'FAIL') AS result
FROM segment_counts
ORDER BY customer_count DESC;

-- Repeat-retention calculation.
WITH eligible_order_counts AS (
    SELECT
        o.customer_id,
        COUNT(DISTINCT o.order_id) AS eligible_order_count
    FROM orders AS o
    JOIN customers AS c ON c.customer_id = o.customer_id
    JOIN order_statuses AS s ON s.status_id = o.status_id AND s.is_eligible = 1
    WHERE o.order_date >= c.signup_date
    GROUP BY o.customer_id
)
SELECT
    '4_period_repeat_retention' AS check_id,
    COUNT(*) AS eligible_customers,
    SUM(eligible_order_count >= 2) AS repeat_customers,
    SUM(eligible_order_count = 1) AS one_order_customers,
    ROUND(100 * SUM(eligible_order_count >= 2) / COUNT(*), 2) AS repeat_retention_percentage,
    IF(COUNT(*) = 7069
       AND SUM(eligible_order_count >= 2) = 4745
       AND SUM(eligible_order_count = 1) = 2324
       AND ROUND(100 * SUM(eligible_order_count >= 2) / COUNT(*), 2) = 67.12,
       'PASS', 'FAIL') AS result
FROM eligible_order_counts;

-- Weighted month-1 cohort retention across complete cohorts only.
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
    SELECT DISTINCT cc.cohort_month, eo.customer_id
    FROM customer_cohorts AS cc
    JOIN eligible_orders AS eo ON eo.customer_id = cc.customer_id
    WHERE DATE_FORMAT(eo.order_date, '%Y-%m-01') = DATE_FORMAT(DATE_ADD(STR_TO_DATE(cc.cohort_month, '%Y-%m-%d'), INTERVAL 1 MONTH), '%Y-%m-01')
),
month_1_by_cohort AS (
    SELECT
        cs.cohort_month,
        cs.cohort_size,
        COUNT(DISTINCT m1.customer_id) AS retained_customers,
        CASE WHEN DATE_ADD(STR_TO_DATE(cs.cohort_month, '%Y-%m-%d'), INTERVAL 1 MONTH) <= '2025-12-01' THEN 1 ELSE 0 END AS observation_complete
    FROM cohort_sizes AS cs
    LEFT JOIN month_1_activity AS m1 ON m1.cohort_month = cs.cohort_month
    GROUP BY cs.cohort_month, cs.cohort_size
),
weighted_month_1 AS (
    SELECT
        SUM(retained_customers) AS retained_customers,
        SUM(cohort_size) AS cohort_customers,
        ROUND(100 * SUM(retained_customers) / SUM(cohort_size), 2) AS weighted_rate,
        SUM(observation_complete) AS complete_cohorts,
        COUNT(*) AS all_cohorts
    FROM month_1_by_cohort
    WHERE observation_complete = 1
)
SELECT
    '5_weighted_month1_retention' AS check_id,
    retained_customers,
    cohort_customers,
    weighted_rate,
    complete_cohorts,
    all_cohorts,
    IF(retained_customers = 1735
       AND cohort_customers = 6927
       AND weighted_rate = 25.05
       AND complete_cohorts = 23
       AND all_cohorts = 23,
       'PASS', 'FAIL') AS result
FROM weighted_month_1;

-- Verify the exact eligibility rule used by the Phase 5 SQL scripts.
SELECT
    '6_eligibility_rule' AS check_id,
    (SELECT COUNT(*)
     FROM orders o
     JOIN customers c ON c.customer_id = o.customer_id
     JOIN order_statuses s ON s.status_id = o.status_id
     WHERE s.is_eligible = 1 AND o.order_date >= c.signup_date) AS eligible_order_count,
    (SELECT COUNT(*)
     FROM orders o
     JOIN customers c ON c.customer_id = o.customer_id
     JOIN order_statuses s ON s.status_id = o.status_id
     WHERE s.is_eligible = 1 AND o.order_date < c.signup_date) AS excluded_completed_chronology_orders,
    IF((SELECT COUNT(*)
        FROM orders o
        JOIN customers c ON c.customer_id = o.customer_id
        JOIN order_statuses s ON s.status_id = o.status_id
        WHERE s.is_eligible = 1 AND o.order_date >= c.signup_date) = 35017
       AND (SELECT COUNT(*)
            FROM orders o
            JOIN customers c ON c.customer_id = o.customer_id
            JOIN order_statuses s ON s.status_id = o.status_id
            WHERE s.is_eligible = 1 AND o.order_date < c.signup_date) = 483,
       'PASS', 'FAIL') AS result;

-- Confirm all 557 chronology-exception orders remain present by the documented audit totals.
-- No write operation is performed; unchanged status is supported by the matching count,
-- affected-customer count, date range, and current line-revenue audit total.
SELECT
    '7_chronology_exceptions_unchanged' AS check_id,
    COUNT(DISTINCT o.order_id) AS exception_orders,
    COUNT(DISTINCT o.customer_id) AS exception_customers,
    ROUND(SUM(oi.line_total), 2) AS exception_line_revenue,
    MIN(o.order_date) AS earliest_exception_order_date,
    MAX(o.order_date) AS latest_exception_order_date,
    IF(COUNT(DISTINCT o.order_id) = 557
       AND COUNT(DISTINCT o.customer_id) = 404
       AND ROUND(SUM(oi.line_total), 2) = 834047.20
       AND MIN(o.order_date) = '2025-05-31'
       AND MAX(o.order_date) = '2025-11-20',
       'PASS', 'FAIL') AS result
FROM orders o
JOIN customers c ON c.customer_id = o.customer_id
JOIN order_items oi ON oi.order_id = o.order_id
WHERE o.order_date < c.signup_date;

-- RFM Frequency and Monetary reconciliation against eligible completed orders.
WITH eligible_order_values AS (
    SELECT
        o.order_id,
        o.customer_id,
        ROUND(SUM(oi.line_total), 2) AS order_value
    FROM orders o
    JOIN customers c ON c.customer_id = o.customer_id
    JOIN order_statuses s ON s.status_id = o.status_id AND s.is_eligible = 1
    JOIN order_items oi ON oi.order_id = o.order_id
    WHERE o.order_date >= c.signup_date
    GROUP BY o.order_id, o.customer_id
),
customer_rfm_totals AS (
    SELECT customer_id, COUNT(*) AS frequency, ROUND(SUM(order_value), 2) AS monetary_value
    FROM eligible_order_values
    GROUP BY customer_id
),
reconciled AS (
    SELECT
        (SELECT COUNT(*) FROM eligible_order_values) AS eligible_completed_orders,
        (SELECT ROUND(SUM(order_value), 2) FROM eligible_order_values) AS eligible_completed_revenue,
        (SELECT SUM(frequency) FROM customer_rfm_totals) AS rfm_frequency_sum,
        (SELECT ROUND(SUM(monetary_value), 2) FROM customer_rfm_totals) AS rfm_monetary_sum
)
SELECT
    '8_rfm_frequency_monetary_reconciliation' AS check_id,
    eligible_completed_orders,
    rfm_frequency_sum,
    eligible_completed_revenue,
    rfm_monetary_sum,
    IF(eligible_completed_orders = 35017
       AND rfm_frequency_sum = eligible_completed_orders
       AND eligible_completed_revenue = 53997988.41
       AND rfm_monetary_sum = eligible_completed_revenue,
       'PASS', 'FAIL') AS result
FROM reconciled;

SELECT
    'scope_boundary' AS check_id,
    (SELECT COUNT(*) FROM information_schema.views WHERE table_schema = DATABASE()) AS views_created,
    (SELECT COUNT(*) FROM information_schema.routines WHERE routine_schema = DATABASE()) AS routines_created,
    IF((SELECT COUNT(*) FROM information_schema.views WHERE table_schema = DATABASE()) = 0
       AND (SELECT COUNT(*) FROM information_schema.routines WHERE routine_schema = DATABASE()) = 0,
       'PASS', 'FAIL') AS result;
