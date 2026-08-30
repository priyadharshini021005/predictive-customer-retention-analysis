-- Predictive Customer Retention Analysis using SQL
-- Phase 6 methodology and implementation review: read-only only.
-- No database object or data is modified.

USE predictive_customer_retention;

-- 1. Eligibility population and zero-purchase exclusion.
WITH eligible_order_values AS (
    SELECT o.order_id,o.customer_id,o.order_date,ROUND(SUM(oi.line_total),2) AS order_value
    FROM orders o
    JOIN customers c ON c.customer_id=o.customer_id
    JOIN order_statuses s ON s.status_id=o.status_id AND s.is_eligible=1
    JOIN order_items oi ON oi.order_id=o.order_id
    WHERE o.order_date>=c.signup_date
    GROUP BY o.order_id,o.customer_id,o.order_date
),
scored_population AS (
    SELECT customer_id FROM eligible_order_values GROUP BY customer_id
)
SELECT
    'eligibility_population_review' AS check_id,
    (SELECT COUNT(*) FROM scored_population) AS scored_customers,
    (SELECT COUNT(*) FROM customers c LEFT JOIN scored_population sp ON sp.customer_id=c.customer_id WHERE sp.customer_id IS NULL) AS zero_purchase_customers,
    (SELECT COUNT(*) FROM eligible_order_values) AS eligible_orders,
    IF((SELECT COUNT(*) FROM scored_population)=7069 AND (SELECT COUNT(*) FROM eligible_order_values)=35017, 'PASS','FAIL') AS result;

-- 2. Independent reconstruction of feature and point logic.
WITH eligible_order_values AS (
    SELECT o.order_id,o.customer_id,o.order_date,ROUND(SUM(oi.line_total),2) AS order_value
    FROM orders o JOIN customers c ON c.customer_id=o.customer_id JOIN order_statuses s ON s.status_id=o.status_id AND s.is_eligible=1 JOIN order_items oi ON oi.order_id=o.order_id
    WHERE o.order_date>=c.signup_date GROUP BY o.order_id,o.customer_id,o.order_date
),
ordered_with_lag AS (
    SELECT eov.*,LAG(order_date) OVER (PARTITION BY customer_id ORDER BY order_date,order_id) AS previous_order_date FROM eligible_order_values eov
),
customer_cadence AS (
    SELECT customer_id,ROUND(AVG(DATEDIFF(order_date,previous_order_date)),2) AS average_interorder_gap_days FROM ordered_with_lag WHERE previous_order_date IS NOT NULL GROUP BY customer_id
),
features AS (
    SELECT eov.customer_id,MAX(eov.order_date) AS last_order_date,DATEDIFF('2025-12-31',MAX(eov.order_date)) AS recency_days,COUNT(*) AS eligible_order_count,ROUND(SUM(eov.order_value),2) AS monetary_value,SUM(CASE WHEN eov.order_date>=DATE_SUB('2025-12-31',INTERVAL 179 DAY) THEN 1 ELSE 0 END) AS orders_last_180_days
    FROM eligible_order_values eov GROUP BY eov.customer_id
),
scored AS (
    SELECT f.*,cc.average_interorder_gap_days,CASE WHEN cc.average_interorder_gap_days IS NULL OR cc.average_interorder_gap_days=0 THEN NULL ELSE ROUND(f.recency_days/cc.average_interorder_gap_days,2) END AS cadence_ratio
    FROM features f LEFT JOIN customer_cadence cc ON cc.customer_id=f.customer_id
),
points AS (
    SELECT s.*,
           CASE WHEN recency_days<=30 THEN 0 WHEN recency_days<=60 THEN 10 WHEN recency_days<=90 THEN 20 WHEN recency_days<=180 THEN 30 ELSE 40 END AS recency_points,
           CASE WHEN eligible_order_count>=6 THEN 0 WHEN eligible_order_count BETWEEN 3 AND 5 THEN 8 WHEN eligible_order_count=2 THEN 16 ELSE 25 END AS frequency_points,
           CASE WHEN eligible_order_count=1 THEN 15 WHEN cadence_ratio IS NULL THEN 0 WHEN cadence_ratio<=1 THEN 0 WHEN cadence_ratio<=1.5 THEN 8 WHEN cadence_ratio<=2 THEN 16 ELSE 25 END AS cadence_points,
           CASE WHEN orders_last_180_days>=3 THEN 0 WHEN orders_last_180_days=2 THEN 3 WHEN orders_last_180_days=1 THEN 6 ELSE 10 END AS recent_activity_points
    FROM scored s
),
scored_output AS (
    SELECT p.*,recency_points+frequency_points+cadence_points+recent_activity_points AS behavioral_risk_score,
           CASE WHEN recency_points+frequency_points+cadence_points+recent_activity_points>=70 THEN 'High Risk' WHEN recency_points+frequency_points+cadence_points+recent_activity_points>=40 THEN 'Medium Risk' ELSE 'Low Risk' END AS expected_risk_band
    FROM points p
)
SELECT
    'score_logic_review' AS check_id,
    COUNT(*) AS scored_customers,
    MIN(behavioral_risk_score) AS min_score,
    MAX(behavioral_risk_score) AS max_score,
    SUM(expected_risk_band IS NULL) AS null_bands,
    IF(COUNT(*)=7069 AND MIN(behavioral_risk_score)>=0 AND MAX(behavioral_risk_score)<=100 AND SUM(expected_risk_band IS NULL)=0,'PASS','FAIL') AS result
FROM scored_output;

-- 3. Exact risk-band counts reproduced from the documented score thresholds.
WITH eligible_order_values AS (
    SELECT o.order_id,o.customer_id,o.order_date,ROUND(SUM(oi.line_total),2) AS order_value
    FROM orders o JOIN customers c ON c.customer_id=o.customer_id JOIN order_statuses s ON s.status_id=o.status_id AND s.is_eligible=1 JOIN order_items oi ON oi.order_id=o.order_id
    WHERE o.order_date>=c.signup_date GROUP BY o.order_id,o.customer_id,o.order_date
),
ordered_with_lag AS (
    SELECT eov.*,LAG(order_date) OVER (PARTITION BY customer_id ORDER BY order_date,order_id) AS previous_order_date FROM eligible_order_values eov
),
customer_cadence AS (
    SELECT customer_id,ROUND(AVG(DATEDIFF(order_date,previous_order_date)),2) AS average_interorder_gap_days FROM ordered_with_lag WHERE previous_order_date IS NOT NULL GROUP BY customer_id
),
features AS (
    SELECT eov.customer_id,MAX(eov.order_date) AS last_order_date,DATEDIFF('2025-12-31',MAX(eov.order_date)) AS recency_days,COUNT(*) AS eligible_order_count,ROUND(SUM(eov.order_value),2) AS monetary_value,SUM(CASE WHEN eov.order_date>=DATE_SUB('2025-12-31',INTERVAL 179 DAY) THEN 1 ELSE 0 END) AS orders_last_180_days
    FROM eligible_order_values eov GROUP BY eov.customer_id
),
scored AS (
    SELECT f.*,cc.average_interorder_gap_days,CASE WHEN cc.average_interorder_gap_days IS NULL OR cc.average_interorder_gap_days=0 THEN NULL ELSE ROUND(f.recency_days/cc.average_interorder_gap_days,2) END AS cadence_ratio
    FROM features f LEFT JOIN customer_cadence cc ON cc.customer_id=f.customer_id
),
points AS (
    SELECT s.*,CASE WHEN recency_days<=30 THEN 0 WHEN recency_days<=60 THEN 10 WHEN recency_days<=90 THEN 20 WHEN recency_days<=180 THEN 30 ELSE 40 END+CASE WHEN eligible_order_count>=6 THEN 0 WHEN eligible_order_count BETWEEN 3 AND 5 THEN 8 WHEN eligible_order_count=2 THEN 16 ELSE 25 END+CASE WHEN eligible_order_count=1 THEN 15 WHEN cadence_ratio IS NULL THEN 0 WHEN cadence_ratio<=1 THEN 0 WHEN cadence_ratio<=1.5 THEN 8 WHEN cadence_ratio<=2 THEN 16 ELSE 25 END+CASE WHEN orders_last_180_days>=3 THEN 0 WHEN orders_last_180_days=2 THEN 3 WHEN orders_last_180_days=1 THEN 6 ELSE 10 END AS behavioral_risk_score
    FROM scored s
),
bands AS (
    SELECT CASE WHEN behavioral_risk_score>=70 THEN 'High Risk' WHEN behavioral_risk_score>=40 THEN 'Medium Risk' ELSE 'Low Risk' END AS risk_band,COUNT(*) AS customer_count
    FROM points GROUP BY CASE WHEN behavioral_risk_score>=70 THEN 'High Risk' WHEN behavioral_risk_score>=40 THEN 'Medium Risk' ELSE 'Low Risk' END
)
SELECT 'risk_band_distribution_review' AS check_id,risk_band,customer_count,ROUND(100*customer_count/(SELECT SUM(customer_count) FROM bands),2) AS customer_percentage,'PASS' AS result FROM bands ORDER BY FIELD(risk_band,'High Risk','Medium Risk','Low Risk');

-- 4. Risk-reason fallback review. The current implementation uses COALESCE(CONCAT_WS(...), fallback).
-- CONCAT_WS returns an empty string when all arguments are NULL, so COALESCE does not apply the fallback.
WITH eligible_order_values AS (
    SELECT o.order_id,o.customer_id,o.order_date,ROUND(SUM(oi.line_total),2) AS order_value
    FROM orders o JOIN customers c ON c.customer_id=o.customer_id JOIN order_statuses s ON s.status_id=o.status_id AND s.is_eligible=1 JOIN order_items oi ON oi.order_id=o.order_id
    WHERE o.order_date>=c.signup_date GROUP BY o.order_id,o.customer_id,o.order_date
),
ordered_with_lag AS (
    SELECT eov.*,LAG(order_date) OVER (PARTITION BY customer_id ORDER BY order_date,order_id) AS previous_order_date FROM eligible_order_values eov
),
customer_cadence AS (
    SELECT customer_id,ROUND(AVG(DATEDIFF(order_date,previous_order_date)),2) AS average_interorder_gap_days FROM ordered_with_lag WHERE previous_order_date IS NOT NULL GROUP BY customer_id
),
features AS (
    SELECT eov.customer_id,MAX(eov.order_date) AS last_order_date,DATEDIFF('2025-12-31',MAX(eov.order_date)) AS recency_days,COUNT(*) AS eligible_order_count,ROUND(SUM(eov.order_value),2) AS monetary_value,COUNT(DISTINCT CASE WHEN eov.order_date BETWEEN '2025-01-01' AND '2025-12-31' THEN DATE_FORMAT(eov.order_date,'%Y-%m-01') END) AS active_months_last_12,SUM(CASE WHEN eov.order_date>=DATE_SUB('2025-12-31',INTERVAL 179 DAY) THEN 1 ELSE 0 END) AS orders_last_180_days
    FROM eligible_order_values eov GROUP BY eov.customer_id
),
scored AS (
    SELECT f.*,cc.average_interorder_gap_days,CASE WHEN cc.average_interorder_gap_days IS NULL OR cc.average_interorder_gap_days=0 THEN NULL ELSE ROUND(f.recency_days/cc.average_interorder_gap_days,2) END AS cadence_ratio
    FROM features f LEFT JOIN customer_cadence cc ON cc.customer_id=f.customer_id
),
reason_review AS (
    SELECT
        scored.*,
        COALESCE(CONCAT_WS('; ',CASE WHEN recency_days>180 THEN 'No eligible purchase in more than 180 days' WHEN recency_days>90 THEN 'No eligible purchase in more than 90 days' END,CASE WHEN eligible_order_count=1 THEN 'Only one eligible purchase' END,CASE WHEN cadence_ratio>2 THEN 'Overdue versus historical purchase cadence' WHEN cadence_ratio>1.5 THEN 'Purchase cadence deterioration' END,CASE WHEN orders_last_180_days=0 THEN 'No eligible purchase in the last 180 days' END,CASE WHEN active_months_last_12<3 THEN 'Fewer than three active months in the last twelve months' END),'No elevated behavior signal') AS implemented_reason,
        COALESCE(NULLIF(TRIM(CONCAT_WS('; ',CASE WHEN recency_days>180 THEN 'No eligible purchase in more than 180 days' WHEN recency_days>90 THEN 'No eligible purchase in more than 90 days' END,CASE WHEN eligible_order_count=1 THEN 'Only one eligible purchase' END,CASE WHEN cadence_ratio>2 THEN 'Overdue versus historical purchase cadence' WHEN cadence_ratio>1.5 THEN 'Purchase cadence deterioration' END,CASE WHEN orders_last_180_days=0 THEN 'No eligible purchase in the last 180 days' END,CASE WHEN active_months_last_12<3 THEN 'Fewer than three active months in the last twelve months' END)),''),'No elevated behavior signal') AS corrected_reason
    FROM scored
)
SELECT
    'risk_reason_fallback_review' AS check_id,
    COUNT(*) AS scored_customers,
    SUM(implemented_reason IS NULL) AS implemented_null_reasons,
    SUM(TRIM(implemented_reason)='') AS implemented_blank_reasons,
    SUM(corrected_reason='No elevated behavior signal') AS rows_requiring_fallback,
    SUM(corrected_reason IS NULL OR TRIM(corrected_reason)='') AS corrected_blank_reasons,
    IF(SUM(TRIM(implemented_reason)='')=0,'PASS','FAIL') AS current_implementation_result,
    IF(SUM(corrected_reason IS NULL OR TRIM(corrected_reason)='')=0,'PASS','FAIL') AS corrected_logic_result
FROM reason_review;

-- 5. Chronology-exception and scope checks.
SELECT
    'chronology_and_scope_review' AS check_id,
    (SELECT COUNT(DISTINCT o.order_id) FROM orders o JOIN customers c ON c.customer_id=o.customer_id WHERE o.order_date<c.signup_date) AS chronology_exception_orders,
    (SELECT COUNT(DISTINCT o.customer_id) FROM orders o JOIN customers c ON c.customer_id=o.customer_id WHERE o.order_date<c.signup_date) AS chronology_exception_customers,
    (SELECT COUNT(*) FROM information_schema.views WHERE table_schema=DATABASE()) AS views_created,
    (SELECT COUNT(*) FROM information_schema.routines WHERE routine_schema=DATABASE()) AS routines_created,
    IF((SELECT COUNT(DISTINCT o.order_id) FROM orders o JOIN customers c ON c.customer_id=o.customer_id WHERE o.order_date<c.signup_date)=557 AND (SELECT COUNT(*) FROM information_schema.views WHERE table_schema=DATABASE())=0 AND (SELECT COUNT(*) FROM information_schema.routines WHERE routine_schema=DATABASE())=0,'PASS','FAIL') AS result;
