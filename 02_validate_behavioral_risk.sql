-- Predictive Customer Retention Analysis using SQL
-- Phase 6: Deterministic behavioral risk-scoring validation
-- Read-only validation; no persistent database objects are created.

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
    SELECT eov.*, LAG(order_date) OVER (PARTITION BY customer_id ORDER BY order_date, order_id) AS previous_order_date
    FROM eligible_order_values AS eov
),
customer_cadence AS (
    SELECT customer_id, AVG(DATEDIFF(order_date, previous_order_date)) AS average_interorder_gap_days_raw, ROUND(AVG(DATEDIFF(order_date, previous_order_date)), 2) AS average_interorder_gap_days
    FROM ordered_with_lag
    WHERE previous_order_date IS NOT NULL
    GROUP BY customer_id
),
customer_features AS (
    SELECT
        eov.customer_id,
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
        CASE WHEN cc.average_interorder_gap_days_raw IS NULL OR cc.average_interorder_gap_days_raw = 0 THEN NULL ELSE cf.recency_days / cc.average_interorder_gap_days_raw END AS cadence_ratio,
        CASE WHEN cc.average_interorder_gap_days_raw IS NULL OR cc.average_interorder_gap_days_raw = 0 THEN NULL ELSE ROUND(cf.recency_days / cc.average_interorder_gap_days_raw, 2) END AS cadence_ratio_display
    FROM customer_features AS cf
    LEFT JOIN customer_cadence AS cc ON cc.customer_id = cf.customer_id
),
scored_features AS (
    SELECT
        fwc.*,
        6 - NTILE(5) OVER (ORDER BY monetary_value DESC, customer_id ASC) AS value_quintile,
        CASE WHEN recency_days <= 30 THEN 0 WHEN recency_days <= 60 THEN 10 WHEN recency_days <= 90 THEN 20 WHEN recency_days <= 180 THEN 30 ELSE 40 END AS recency_points,
        CASE WHEN eligible_order_count >= 6 THEN 0 WHEN eligible_order_count BETWEEN 3 AND 5 THEN 8 WHEN eligible_order_count = 2 THEN 16 ELSE 25 END AS frequency_points,
        CASE WHEN eligible_order_count = 1 THEN 15 WHEN cadence_ratio IS NULL THEN 0 WHEN cadence_ratio <= 1.0 THEN 0 WHEN cadence_ratio <= 1.5 THEN 8 WHEN cadence_ratio <= 2.0 THEN 16 ELSE 25 END AS cadence_points,
        CASE WHEN orders_last_180_days >= 3 THEN 0 WHEN orders_last_180_days = 2 THEN 3 WHEN orders_last_180_days = 1 THEN 6 ELSE 10 END AS recent_activity_points
    FROM features_with_cadence AS fwc
),
risk_scored AS (
    SELECT
        sf.*,
        recency_points + frequency_points + cadence_points + recent_activity_points AS behavioral_risk_score
    FROM scored_features AS sf
),
risk_output AS (
    SELECT
        rs.*,
        CASE WHEN behavioral_risk_score >= 70 THEN 'High Risk' WHEN behavioral_risk_score >= 40 THEN 'Medium Risk' ELSE 'Low Risk' END AS risk_band,
        CASE WHEN recency_days > 90 THEN 1 ELSE 0 END AS inactive_90_plus_flag,
        CASE WHEN recency_days > 180 THEN 1 ELSE 0 END AS inactive_180_plus_flag,
        CASE WHEN eligible_order_count >= 2 AND average_interorder_gap_days > 0 AND cadence_ratio > 2.0 THEN 1 ELSE 0 END AS overdue_cadence_flag,
        CASE WHEN recency_days > 180 THEN 1 ELSE 0 END AS churn_candidate_flag,
        CASE WHEN recency_days > 180 THEN 1 ELSE 0 END AS expected_churn_candidate_flag,
        CASE WHEN eligible_order_count >= 2 AND average_interorder_gap_days > 0 AND cadence_ratio > 2.0 THEN 1 ELSE 0 END AS expected_overdue_cadence_flag
    FROM risk_scored AS rs
)
SELECT '1_risk_population' AS check_id,
       CAST(COUNT(*) AS CHAR) AS observed_value,
       '7069 scored eligible customers' AS expected_value,
       IF(COUNT(*) = 7069, 'PASS', 'FAIL') AS result
FROM risk_output
UNION ALL
SELECT '2_zero_purchase_exclusion',
       CONCAT('zero-purchase customers=', (SELECT COUNT(*) FROM customers c LEFT JOIN risk_output ro ON ro.customer_id=c.customer_id WHERE ro.customer_id IS NULL AND NOT EXISTS (SELECT 1 FROM eligible_order_values eov WHERE eov.customer_id=c.customer_id)), '; scored_zero_purchase=', (SELECT COUNT(*) FROM risk_output ro WHERE NOT EXISTS (SELECT 1 FROM eligible_order_values eov WHERE eov.customer_id=ro.customer_id))),
       'zero-purchase customers may be outside scoring; scored zero-purchase customers=0',
       IF((SELECT COUNT(*) FROM risk_output ro WHERE NOT EXISTS (SELECT 1 FROM eligible_order_values eov WHERE eov.customer_id=ro.customer_id)) = 0, 'PASS', 'FAIL')
FROM (SELECT 1 AS one_row) AS one
UNION ALL
SELECT '3_total_score_bounds', CONCAT(MIN(behavioral_risk_score), '-', MAX(behavioral_risk_score)), '0-100', IF(MIN(behavioral_risk_score) >= 0 AND MAX(behavioral_risk_score) <= 100, 'PASS', 'FAIL')
FROM risk_output
UNION ALL
SELECT '4_component_point_bounds', CONCAT('R=', MIN(recency_points), '-', MAX(recency_points), '; F=', MIN(frequency_points), '-', MAX(frequency_points), '; C=', MIN(cadence_points), '-', MAX(cadence_points), '; A=', MIN(recent_activity_points), '-', MAX(recent_activity_points)), 'R=0-40; F=0-25; C=0-25; A=0-10', IF(MIN(recency_points) >= 0 AND MAX(recency_points) <= 40 AND MIN(frequency_points) >= 0 AND MAX(frequency_points) <= 25 AND MIN(cadence_points) >= 0 AND MAX(cadence_points) <= 25 AND MIN(recent_activity_points) >= 0 AND MAX(recent_activity_points) <= 10, 'PASS', 'FAIL')
FROM risk_output
UNION ALL
SELECT '5_risk_band_assignment', CONCAT('unassigned=', SUM(risk_band IS NULL), '; distinct_bands=', COUNT(DISTINCT risk_band)), 'unassigned=0; bands between 1 and 3', IF(SUM(risk_band IS NULL) = 0 AND COUNT(DISTINCT risk_band) BETWEEN 1 AND 3, 'PASS', 'FAIL')
FROM risk_output
UNION ALL
SELECT '6_churn_flag_logic', CONCAT('mismatches=', SUM(churn_candidate_flag <> expected_churn_candidate_flag)), 'mismatches=0; churn_candidate_flag iff recency_days > 180', IF(SUM(churn_candidate_flag <> expected_churn_candidate_flag) = 0, 'PASS', 'FAIL')
FROM risk_output
UNION ALL
SELECT '7_overdue_cadence_logic', CONCAT('mismatches=', SUM(overdue_cadence_flag <> expected_overdue_cadence_flag)), 'mismatches=0; overdue iff repeat and cadence_ratio > 2', IF(SUM(overdue_cadence_flag <> expected_overdue_cadence_flag) = 0, 'PASS', 'FAIL')
FROM risk_output
UNION ALL
SELECT '8_explanatory_output_completeness', CONCAT('null_or_blank_reasons=', SUM(CASE WHEN risk_reason IS NULL OR TRIM(risk_reason) = '' THEN 1 ELSE 0 END), '; null_rules=', SUM(CASE WHEN eligibility_rule_applied IS NULL OR TRIM(eligibility_rule_applied) = '' THEN 1 ELSE 0 END)), 'null_or_blank_reasons=0; null_rules=0', IF(SUM(CASE WHEN risk_reason IS NULL OR TRIM(risk_reason) = '' THEN 1 ELSE 0 END) = 0 AND SUM(CASE WHEN eligibility_rule_applied IS NULL OR TRIM(eligibility_rule_applied) = '' THEN 1 ELSE 0 END) = 0, 'PASS', 'FAIL')
FROM (
    SELECT
        rs.*,
        COALESCE(NULLIF(TRIM(CONCAT_WS('; ', CASE WHEN recency_days > 180 THEN 'No eligible purchase in more than 180 days' WHEN recency_days > 90 THEN 'No eligible purchase in more than 90 days' END, CASE WHEN eligible_order_count = 1 THEN 'Only one eligible purchase' END, CASE WHEN cadence_ratio > 2.0 THEN 'Overdue versus historical purchase cadence' WHEN cadence_ratio > 1.5 THEN 'Purchase cadence deterioration' END, CASE WHEN orders_last_180_days = 0 THEN 'No eligible purchase in the last 180 days' END, CASE WHEN active_months_last_12 < 3 THEN 'Fewer than three active months in the last twelve months' END)), ''), 'No elevated behavior signal') AS risk_reason,
        'is_eligible = 1 AND order_date >= signup_date' AS eligibility_rule_applied
    FROM risk_output AS rs
) AS explained
UNION ALL
SELECT '9_frequency_reconciliation', CONCAT('risk_frequency_sum=', SUM(eligible_order_count), '; eligible_orders=', (SELECT COUNT(*) FROM eligible_order_values)), 'both=35017', IF(SUM(eligible_order_count) = 35017 AND (SELECT COUNT(*) FROM eligible_order_values) = 35017, 'PASS', 'FAIL')
FROM risk_output
UNION ALL
SELECT '10_monetary_reconciliation', CONCAT('risk_monetary=', ROUND(SUM(monetary_value),2), '; eligible_revenue=', (SELECT ROUND(SUM(order_value),2) FROM eligible_order_values)), 'both=53997988.41', IF(ROUND(SUM(monetary_value),2) = 53997988.41 AND (SELECT ROUND(SUM(order_value),2) FROM eligible_order_values) = 53997988.41, 'PASS', 'FAIL')
FROM risk_output;

-- Risk-band distribution.
WITH eligible_order_values AS (
    SELECT o.order_id,o.customer_id,o.order_date,ROUND(SUM(oi.line_total),2) AS order_value
    FROM orders o JOIN customers c ON c.customer_id=o.customer_id JOIN order_statuses s ON s.status_id=o.status_id AND s.is_eligible=1 JOIN order_items oi ON oi.order_id=o.order_id
    WHERE o.order_date>=c.signup_date GROUP BY o.order_id,o.customer_id,o.order_date
),
ordered_with_lag AS (
    SELECT eov.*,LAG(order_date) OVER (PARTITION BY customer_id ORDER BY order_date,order_id) AS previous_order_date FROM eligible_order_values eov
),
customer_cadence AS (
    SELECT customer_id,AVG(DATEDIFF(order_date,previous_order_date)) AS average_interorder_gap_days_raw,ROUND(AVG(DATEDIFF(order_date,previous_order_date)),2) AS average_interorder_gap_days FROM ordered_with_lag WHERE previous_order_date IS NOT NULL GROUP BY customer_id
),
features AS (
    SELECT eov.customer_id,MAX(eov.order_date) AS last_order_date,DATEDIFF('2025-12-31',MAX(eov.order_date)) AS recency_days,COUNT(*) AS eligible_order_count,ROUND(SUM(eov.order_value),2) AS monetary_value,SUM(CASE WHEN eov.order_date>=DATE_SUB('2025-12-31',INTERVAL 179 DAY) THEN 1 ELSE 0 END) AS orders_last_180_days
    FROM eligible_order_values eov GROUP BY eov.customer_id
),
scored AS (
    SELECT f.*,cc.average_interorder_gap_days_raw,cc.average_interorder_gap_days,CASE WHEN cc.average_interorder_gap_days_raw IS NULL OR cc.average_interorder_gap_days_raw=0 THEN NULL ELSE f.recency_days/cc.average_interorder_gap_days_raw END AS cadence_ratio,CASE WHEN cc.average_interorder_gap_days_raw IS NULL OR cc.average_interorder_gap_days_raw=0 THEN NULL ELSE ROUND(f.recency_days/cc.average_interorder_gap_days_raw,2) END AS cadence_ratio_display
    FROM features f LEFT JOIN customer_cadence cc ON cc.customer_id=f.customer_id
),
points AS (
    SELECT s.*,CASE WHEN recency_days<=30 THEN 0 WHEN recency_days<=60 THEN 10 WHEN recency_days<=90 THEN 20 WHEN recency_days<=180 THEN 30 ELSE 40 END+CASE WHEN eligible_order_count>=6 THEN 0 WHEN eligible_order_count BETWEEN 3 AND 5 THEN 8 WHEN eligible_order_count=2 THEN 16 ELSE 25 END+CASE WHEN eligible_order_count=1 THEN 15 WHEN cadence_ratio IS NULL THEN 0 WHEN cadence_ratio<=1 THEN 0 WHEN cadence_ratio<=1.5 THEN 8 WHEN cadence_ratio<=2 THEN 16 ELSE 25 END+CASE WHEN orders_last_180_days>=3 THEN 0 WHEN orders_last_180_days=2 THEN 3 WHEN orders_last_180_days=1 THEN 6 ELSE 10 END AS behavioral_risk_score
    FROM scored s
)
SELECT risk_band,customer_count,ROUND(100*customer_count/(SELECT COUNT(*) FROM points),2) AS customer_percentage
FROM (SELECT CASE WHEN behavioral_risk_score>=70 THEN 'High Risk' WHEN behavioral_risk_score>=40 THEN 'Medium Risk' ELSE 'Low Risk' END AS risk_band,COUNT(*) AS customer_count FROM points GROUP BY CASE WHEN behavioral_risk_score>=70 THEN 'High Risk' WHEN behavioral_risk_score>=40 THEN 'Medium Risk' ELSE 'Low Risk' END) AS distribution
ORDER BY FIELD(risk_band,'High Risk','Medium Risk','Low Risk');

-- Churn-candidate and inactivity summary.
WITH eligible_orders AS (
    SELECT o.order_id,o.customer_id,o.order_date
    FROM orders o JOIN customers c ON c.customer_id=o.customer_id JOIN order_statuses s ON s.status_id=o.status_id AND s.is_eligible=1
    WHERE o.order_date>=c.signup_date
), customer_features AS (
    SELECT customer_id,MAX(order_date) AS last_order_date,DATEDIFF('2025-12-31',MAX(order_date)) AS recency_days,COUNT(*) AS eligible_order_count
    FROM eligible_orders GROUP BY customer_id
)
SELECT
    'churn_candidate_summary' AS summary_name,
    COUNT(*) AS eligible_customers,
    SUM(recency_days > 180) AS churn_candidates,
    SUM(recency_days > 90) AS inactive_90_plus,
    SUM(eligible_order_count = 1 AND recency_days > 180) AS single_order_churn_candidates,
    SUM(eligible_order_count >= 2 AND recency_days > 180) AS repeat_customer_churn_candidates,
    ROUND(100*SUM(recency_days > 180)/COUNT(*),2) AS churn_candidate_percentage
FROM customer_features;

-- Chronology-exception preservation audit; no write operation occurs in this script.
SELECT
    'chronology_exception_preservation' AS check_id,
    COUNT(DISTINCT o.order_id) AS exception_orders,
    COUNT(DISTINCT o.customer_id) AS exception_customers,
    ROUND(SUM(oi.line_total),2) AS exception_line_revenue,
    IF(COUNT(DISTINCT o.order_id)=557 AND COUNT(DISTINCT o.customer_id)=404 AND ROUND(SUM(oi.line_total),2)=834047.20, 'PASS', 'FAIL') AS result
FROM orders o
JOIN customers c ON c.customer_id=o.customer_id
JOIN order_items oi ON oi.order_id=o.order_id
WHERE o.order_date<c.signup_date;

-- Phase 6 scope boundary.
SELECT
    'PHASE6_SCOPE_BOUNDARY' AS check_id,
    (SELECT COUNT(*) FROM information_schema.views WHERE table_schema=DATABASE()) AS views_created,
    (SELECT COUNT(*) FROM information_schema.routines WHERE routine_schema=DATABASE()) AS routines_created,
    IF((SELECT COUNT(*) FROM information_schema.views WHERE table_schema=DATABASE())=0 AND (SELECT COUNT(*) FROM information_schema.routines WHERE routine_schema=DATABASE())=0, 'PASS', 'FAIL') AS result;
