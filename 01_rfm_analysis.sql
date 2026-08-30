-- Predictive Customer Retention Analysis using SQL
-- Phase 5: Customer-level RFM analysis
-- Descriptive segmentation only; no predictive risk score is created.

USE predictive_customer_retention;

WITH eligible_order_lines AS (
    SELECT
        o.order_id,
        o.customer_id,
        o.order_date,
        oi.line_total
    FROM orders AS o
    JOIN customers AS c ON c.customer_id = o.customer_id
    JOIN order_statuses AS s ON s.status_id = o.status_id AND s.is_eligible = 1
    JOIN order_items AS oi ON oi.order_id = o.order_id
    WHERE o.order_date >= c.signup_date
),
customer_metrics AS (
    SELECT
        customer_id,
        MIN(order_date) AS first_eligible_order_date,
        MAX(order_date) AS last_eligible_order_date,
        COUNT(DISTINCT order_id) AS frequency,
        ROUND(SUM(line_total), 2) AS monetary_value
    FROM eligible_order_lines
    GROUP BY customer_id
),
rfm_base AS (
    SELECT
        customer_id,
        first_eligible_order_date,
        last_eligible_order_date,
        DATEDIFF('2025-12-31', last_eligible_order_date) AS recency_days,
        frequency,
        monetary_value,
        ROUND(monetary_value / frequency, 2) AS average_order_value,
        DATE_FORMAT(first_eligible_order_date, '%Y-%m-01') AS first_eligible_order_month
    FROM customer_metrics
),
scored AS (
    SELECT
        rfm_base.*,
        6 - NTILE(5) OVER (ORDER BY recency_days ASC, customer_id ASC) AS recency_score,
        6 - NTILE(5) OVER (ORDER BY frequency DESC, customer_id ASC) AS frequency_score,
        6 - NTILE(5) OVER (ORDER BY monetary_value DESC, customer_id ASC) AS monetary_score
    FROM rfm_base
),
scored_directional AS (
    SELECT
        scored.*,
        recency_score AS r_score,
        frequency_score AS f_score,
        monetary_score AS m_score,
        recency_score + frequency_score + monetary_score AS rfm_score
    FROM scored
)
SELECT
    customer_id,
    first_eligible_order_date,
    last_eligible_order_date,
    first_eligible_order_month,
    recency_days,
    frequency,
    monetary_value,
    average_order_value,
    r_score,
    f_score,
    m_score,
    rfm_score,
    CASE
        WHEN rfm_score >= 13 THEN 'Champions'
        WHEN m_score >= 4 AND r_score <= 2 THEN 'High Value At Risk'
        WHEN f_score >= 4 AND r_score >= 3 THEN 'Loyal Customers'
        WHEN r_score >= 4 AND f_score BETWEEN 2 AND 3 THEN 'Potential Loyalists'
        WHEN frequency = 1 AND r_score >= 4 THEN 'New Customers'
        WHEN r_score <= 2 AND frequency >= 2 THEN 'At Risk'
        ELSE 'Needs Attention'
    END AS rfm_segment
FROM scored_directional
ORDER BY rfm_score DESC, monetary_value DESC, customer_id;
