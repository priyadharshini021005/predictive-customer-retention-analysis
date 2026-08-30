USE predictive_customer_retention;

WITH eligible_orders AS (
    SELECT o.order_id, o.customer_id, o.order_date
    FROM orders o
    JOIN customers c ON c.customer_id=o.customer_id
    JOIN order_statuses s ON s.status_id=o.status_id AND s.is_eligible=1
    WHERE o.order_date>=c.signup_date
),
customer_cohorts AS (
    SELECT customer_id, DATE_FORMAT(MIN(order_date),'%Y-%m-01') AS cohort_month
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
    FROM customer_cohorts cc
    JOIN eligible_orders eo ON eo.customer_id=cc.customer_id
    WHERE DATE_FORMAT(eo.order_date,'%Y-%m-01') = DATE_FORMAT(DATE_ADD(STR_TO_DATE(cc.cohort_month,'%Y-%m-%d'),INTERVAL 1 MONTH),'%Y-%m-01')
),
month_1 AS (
    SELECT cs.cohort_month, cs.cohort_size, COUNT(DISTINCT m1.customer_id) AS retained_customers,
           CASE WHEN DATE_ADD(STR_TO_DATE(cs.cohort_month,'%Y-%m-%d'),INTERVAL 1 MONTH) <= '2025-12-01' THEN 1 ELSE 0 END AS observation_complete
    FROM cohort_sizes cs
    LEFT JOIN month_1_activity m1 ON m1.cohort_month=cs.cohort_month
    GROUP BY cs.cohort_month, cs.cohort_size
)
SELECT
    SUM(retained_customers) AS complete_cohort_retained_customers,
    SUM(cohort_size) AS complete_cohort_customers,
    ROUND(100*SUM(retained_customers)/SUM(cohort_size),2) AS weighted_month1_retention_rate
FROM month_1
WHERE observation_complete=1;

WITH eligible_order_values AS (
    SELECT o.order_id, o.customer_id, o.order_date, ROUND(SUM(oi.line_total),2) AS order_value
    FROM orders o
    JOIN customers c ON c.customer_id=o.customer_id
    JOIN order_statuses s ON s.status_id=o.status_id AND s.is_eligible=1
    JOIN order_items oi ON oi.order_id=o.order_id
    WHERE o.order_date>=c.signup_date
    GROUP BY o.order_id,o.customer_id,o.order_date
),
customer_metrics AS (
    SELECT customer_id, MIN(order_date) AS first_order_date, MAX(order_date) AS last_order_date,
           DATEDIFF('2025-12-31',MAX(order_date)) AS recency_days,
           COUNT(*) AS frequency, ROUND(SUM(order_value),2) AS monetary_value
    FROM eligible_order_values
    GROUP BY customer_id
),
scored AS (
    SELECT customer_metrics.*,
           6-NTILE(5) OVER (ORDER BY recency_days ASC, customer_id ASC) AS r_score,
           6-NTILE(5) OVER (ORDER BY frequency DESC, customer_id ASC) AS f_score,
           6-NTILE(5) OVER (ORDER BY monetary_value DESC, customer_id ASC) AS m_score
    FROM customer_metrics
),
labeled AS (
    SELECT *, r_score+f_score+m_score AS rfm_score,
           CASE
               WHEN r_score+f_score+m_score >= 13 THEN 'Champions'
               WHEN m_score >= 4 AND r_score <= 2 THEN 'High Value At Risk'
               WHEN f_score >= 4 AND r_score >= 3 THEN 'Loyal Customers'
               WHEN r_score >= 4 AND f_score BETWEEN 2 AND 3 THEN 'Potential Loyalists'
               WHEN frequency=1 AND r_score >= 4 THEN 'New Customers'
               WHEN r_score <= 2 AND frequency >= 2 THEN 'At Risk'
               ELSE 'Needs Attention'
           END AS rfm_segment
    FROM scored
)
SELECT rfm_segment, COUNT(*) AS customer_count, ROUND(100*COUNT(*)/(SELECT COUNT(*) FROM labeled),2) AS customer_share_percent
FROM labeled
GROUP BY rfm_segment
ORDER BY customer_count DESC;
