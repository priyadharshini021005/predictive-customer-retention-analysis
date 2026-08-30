-- Predictive Customer Retention Analysis using SQL
-- Phase 6: Deterministic behavioral customer risk scoring
-- This is a transparent SQL heuristic, not a machine-learning prediction.

USE predictive_customer_retention;

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
ordered_with_lag AS (
    SELECT
        eov.*,
        LAG(order_date) OVER (PARTITION BY customer_id ORDER BY order_date, order_id) AS previous_order_date
    FROM eligible_order_values AS eov
),
customer_cadence AS (
    SELECT
        customer_id,
        AVG(DATEDIFF(order_date, previous_order_date)) AS average_interorder_gap_days_raw,
        ROUND(AVG(DATEDIFF(order_date, previous_order_date)), 2) AS average_interorder_gap_days
    FROM ordered_with_lag
    WHERE previous_order_date IS NOT NULL
    GROUP BY customer_id
),
customer_features AS (
    SELECT
        eov.customer_id,
        MIN(eov.order_date) AS first_eligible_order_date,
        MAX(eov.order_date) AS last_eligible_order_date,
        DATEDIFF('2025-12-31', MAX(eov.order_date)) AS recency_days,
        COUNT(*) AS eligible_order_count,
        ROUND(SUM(eov.order_value), 2) AS monetary_value,
        COUNT(DISTINCT CASE WHEN eov.order_date BETWEEN '2025-01-01' AND '2025-12-31' THEN DATE_FORMAT(eov.order_date, '%Y-%m-01') END) AS active_months_last_12,
        SUM(CASE WHEN eov.order_date >= DATE_SUB('2025-12-31', INTERVAL 179 DAY) THEN 1 ELSE 0 END) AS orders_last_180_days
    FROM eligible_order_values AS eov
    GROUP BY eov.customer_id
),
features_with_cadence AS (
    SELECT
        cf.*,
        cc.average_interorder_gap_days_raw,
        cc.average_interorder_gap_days,
        CASE
            WHEN cc.average_interorder_gap_days_raw IS NULL OR cc.average_interorder_gap_days_raw = 0 THEN NULL
            ELSE cf.recency_days / cc.average_interorder_gap_days_raw
        END AS cadence_ratio,
        CASE
            WHEN cc.average_interorder_gap_days_raw IS NULL OR cc.average_interorder_gap_days_raw = 0 THEN NULL
            ELSE ROUND(cf.recency_days / cc.average_interorder_gap_days_raw, 2)
        END AS cadence_ratio_display
    FROM customer_features AS cf
    LEFT JOIN customer_cadence AS cc ON cc.customer_id = cf.customer_id
),
scored_features AS (
    SELECT
        fwc.*,
        6 - NTILE(5) OVER (ORDER BY monetary_value DESC, customer_id ASC) AS value_quintile,
        CASE
            WHEN recency_days <= 30 THEN 0
            WHEN recency_days <= 60 THEN 10
            WHEN recency_days <= 90 THEN 20
            WHEN recency_days <= 180 THEN 30
            ELSE 40
        END AS recency_points,
        CASE
            WHEN eligible_order_count >= 6 THEN 0
            WHEN eligible_order_count BETWEEN 3 AND 5 THEN 8
            WHEN eligible_order_count = 2 THEN 16
            ELSE 25
        END AS frequency_points,
        CASE
            WHEN eligible_order_count = 1 THEN 15
            WHEN cadence_ratio IS NULL THEN 0
            WHEN cadence_ratio <= 1.0 THEN 0
            WHEN cadence_ratio <= 1.5 THEN 8
            WHEN cadence_ratio <= 2.0 THEN 16
            ELSE 25
        END AS cadence_points,
        CASE
            WHEN orders_last_180_days >= 3 THEN 0
            WHEN orders_last_180_days = 2 THEN 3
            WHEN orders_last_180_days = 1 THEN 6
            ELSE 10
        END AS recent_activity_points
    FROM features_with_cadence AS fwc
),
scored AS (
    SELECT
        sf.*,
        recency_points + frequency_points + cadence_points + recent_activity_points AS behavioral_risk_score
    FROM scored_features AS sf
)
SELECT
    customer_id,
    first_eligible_order_date,
    last_eligible_order_date,
    recency_days,
    eligible_order_count,
    monetary_value,
    active_months_last_12,
    orders_last_180_days,
    average_interorder_gap_days,
    cadence_ratio,
    cadence_ratio_display,
    value_quintile,
    recency_points,
    frequency_points,
    cadence_points,
    recent_activity_points,
    behavioral_risk_score,
    CASE
        WHEN behavioral_risk_score >= 70 THEN 'High Risk'
        WHEN behavioral_risk_score >= 40 THEN 'Medium Risk'
        ELSE 'Low Risk'
    END AS risk_band,
    CASE WHEN recency_days > 90 THEN 1 ELSE 0 END AS inactive_90_plus_flag,
    CASE WHEN recency_days > 180 THEN 1 ELSE 0 END AS inactive_180_plus_flag,
    CASE WHEN eligible_order_count >= 2 AND average_interorder_gap_days > 0 AND cadence_ratio > 2.0 THEN 1 ELSE 0 END AS overdue_cadence_flag,
    CASE WHEN recency_days > 180 THEN 1 ELSE 0 END AS churn_candidate_flag,
    CASE
        WHEN recency_days <= 180 THEN 'Not a churn candidate'
        WHEN eligible_order_count >= 2 THEN 'Repeat-customer inactivity'
        ELSE 'Single-order inactivity'
    END AS churn_candidate_type,
    CASE
        WHEN behavioral_risk_score >= 40 AND value_quintile >= 4 THEN 'High Value Intervention'
        WHEN behavioral_risk_score >= 40 THEN 'Standard Intervention'
        ELSE 'Monitor / Engage'
    END AS intervention_priority,
    COALESCE(
        NULLIF(TRIM(CONCAT_WS('; ',
            CASE WHEN recency_days > 180 THEN 'No eligible purchase in more than 180 days' WHEN recency_days > 90 THEN 'No eligible purchase in more than 90 days' END,
            CASE WHEN eligible_order_count = 1 THEN 'Only one eligible purchase' END,
            CASE WHEN cadence_ratio > 2.0 THEN 'Overdue versus historical purchase cadence' WHEN cadence_ratio > 1.5 THEN 'Purchase cadence deterioration' END,
            CASE WHEN orders_last_180_days = 0 THEN 'No eligible purchase in the last 180 days' END,
            CASE WHEN active_months_last_12 < 3 THEN 'Fewer than three active months in the last twelve months' END
        )), ''),
        'No elevated behavior signal'
    ) AS risk_reason,
    'is_eligible = 1 AND order_date >= signup_date' AS eligibility_rule_applied,
    'Deterministic SQL behavioral score; not machine-learning prediction' AS score_classification
FROM scored
ORDER BY behavioral_risk_score DESC, monetary_value DESC, customer_id;
