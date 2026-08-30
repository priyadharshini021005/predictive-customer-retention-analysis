-- Phase 6 review: cadence-rounding sensitivity
-- Read-only only. No database object or data is modified.

USE predictive_customer_retention;

WITH eligible_order_values AS (
    SELECT o.order_id,o.customer_id,o.order_date,ROUND(SUM(oi.line_total),2) AS order_value
    FROM orders o
    JOIN customers c ON c.customer_id=o.customer_id
    JOIN order_statuses s ON s.status_id=o.status_id AND s.is_eligible=1
    JOIN order_items oi ON oi.order_id=o.order_id
    WHERE o.order_date>=c.signup_date
    GROUP BY o.order_id,o.customer_id,o.order_date
),
ordered_with_lag AS (
    SELECT eov.*,LAG(order_date) OVER (PARTITION BY customer_id ORDER BY order_date,order_id) AS previous_order_date
    FROM eligible_order_values eov
),
cadence AS (
    SELECT
        customer_id,
        AVG(DATEDIFF(order_date,previous_order_date)) AS raw_average_gap_days,
        ROUND(AVG(DATEDIFF(order_date,previous_order_date)),2) AS implemented_average_gap_days
    FROM ordered_with_lag
    WHERE previous_order_date IS NOT NULL
    GROUP BY customer_id
),
features AS (
    SELECT
        eov.customer_id,
        DATEDIFF('2025-12-31',MAX(eov.order_date)) AS recency_days,
        COUNT(*) AS eligible_order_count
    FROM eligible_order_values eov
    GROUP BY eov.customer_id
),
ratios AS (
    SELECT
        f.customer_id,
        f.eligible_order_count,
        f.recency_days,
        c.raw_average_gap_days,
        c.implemented_average_gap_days,
        f.recency_days / c.raw_average_gap_days AS raw_cadence_ratio,
        ROUND(f.recency_days / c.implemented_average_gap_days,2) AS implemented_cadence_ratio
    FROM features f
    JOIN cadence c ON c.customer_id=f.customer_id
),
comparison AS (
    SELECT
        ratios.*,
        CASE
            WHEN eligible_order_count=1 THEN 15
            WHEN raw_cadence_ratio<=1.0 THEN 0
            WHEN raw_cadence_ratio<=1.5 THEN 8
            WHEN raw_cadence_ratio<=2.0 THEN 16
            ELSE 25
        END AS raw_cadence_points,
        CASE
            WHEN eligible_order_count=1 THEN 15
            WHEN implemented_cadence_ratio<=1.0 THEN 0
            WHEN implemented_cadence_ratio<=1.5 THEN 8
            WHEN implemented_cadence_ratio<=2.0 THEN 16
            ELSE 25
        END AS implemented_cadence_points
    FROM ratios
)
SELECT
    'cadence_rounding_sensitivity' AS check_id,
    COUNT(*) AS repeat_customers_with_cadence,
    SUM(raw_cadence_points<>implemented_cadence_points) AS cadence_point_assignment_changes,
    SUM(ABS(raw_cadence_ratio-implemented_cadence_ratio)>0) AS ratio_value_changes,
    MAX(ABS(raw_cadence_ratio-implemented_cadence_ratio)) AS max_ratio_difference,
    IF(SUM(raw_cadence_points<>implemented_cadence_points)=0,'PASS','REVIEW') AS result
FROM comparison;

