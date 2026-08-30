-- Predictive Customer Retention Analysis using SQL
-- Phase 7: Power BI data-mart validation
-- Read-only validation. Source tables and records are not modified.

USE predictive_customer_retention;

SELECT
    '01_required_view_count' AS check_id,
    COUNT(*) AS observed_value,
    14 AS expected_value,
    IF(COUNT(*) = 14, 'PASS', 'FAIL') AS result
FROM information_schema.views
WHERE table_schema = DATABASE()
  AND table_name LIKE 'vw_pbi_%';

SELECT
    '02_customer_dimension_grain' AS check_id,
    COUNT(*) AS view_rows,
    COUNT(DISTINCT customer_id) AS distinct_customers,
    8000 AS expected_rows,
    IF(COUNT(*) = 8000 AND COUNT(*) = COUNT(DISTINCT customer_id), 'PASS', 'FAIL') AS result
FROM vw_pbi_dim_customer;

SELECT
    '03_product_dimension_grain' AS check_id,
    COUNT(*) AS view_rows,
    COUNT(DISTINCT product_id) AS distinct_products,
    180 AS expected_rows,
    IF(COUNT(*) = 180 AND COUNT(*) = COUNT(DISTINCT product_id), 'PASS', 'FAIL') AS result
FROM vw_pbi_dim_product;

SELECT
    '04_order_fact_grain_and_reconciliation' AS check_id,
    (SELECT COUNT(*) FROM vw_pbi_fact_order) AS mart_orders,
    (SELECT COUNT(DISTINCT o.order_id) FROM orders o JOIN customers c ON c.customer_id=o.customer_id JOIN order_statuses s ON s.status_id=o.status_id AND s.is_eligible=1 WHERE o.order_date>=c.signup_date) AS source_eligible_orders,
    (SELECT COUNT(*) FROM vw_pbi_fact_order) - (SELECT COUNT(DISTINCT o.order_id) FROM orders o JOIN customers c ON c.customer_id=o.customer_id JOIN order_statuses s ON s.status_id=o.status_id AND s.is_eligible=1 WHERE o.order_date>=c.signup_date) AS row_difference,
    IF((SELECT COUNT(*) FROM vw_pbi_fact_order)=(SELECT COUNT(DISTINCT o.order_id) FROM orders o JOIN customers c ON c.customer_id=o.customer_id JOIN order_statuses s ON s.status_id=o.status_id AND s.is_eligible=1 WHERE o.order_date>=c.signup_date), 'PASS', 'FAIL') AS result;

SELECT
    '05_order_item_fact_grain_and_reconciliation' AS check_id,
    (SELECT COUNT(*) FROM vw_pbi_fact_order_item) AS mart_order_items,
    (SELECT COUNT(*) FROM order_items oi JOIN orders o ON o.order_id=oi.order_id JOIN customers c ON c.customer_id=o.customer_id JOIN order_statuses s ON s.status_id=o.status_id AND s.is_eligible=1 WHERE o.order_date>=c.signup_date) AS source_eligible_order_items,
    (SELECT COUNT(*) FROM vw_pbi_fact_order_item) - (SELECT COUNT(*) FROM order_items oi JOIN orders o ON o.order_id=oi.order_id JOIN customers c ON c.customer_id=o.customer_id JOIN order_statuses s ON s.status_id=o.status_id AND s.is_eligible=1 WHERE o.order_date>=c.signup_date) AS row_difference,
    IF((SELECT COUNT(*) FROM vw_pbi_fact_order_item)=(SELECT COUNT(*) FROM order_items oi JOIN orders o ON o.order_id=oi.order_id JOIN customers c ON c.customer_id=o.customer_id JOIN order_statuses s ON s.status_id=o.status_id AND s.is_eligible=1 WHERE o.order_date>=c.signup_date), 'PASS', 'FAIL') AS result;

SELECT
    '06_line_revenue_reconciliation' AS check_id,
    (SELECT ROUND(SUM(line_revenue),2) FROM vw_pbi_fact_order) AS mart_order_revenue,
    (SELECT ROUND(SUM(line_revenue),2) FROM vw_pbi_fact_order_item) AS mart_item_revenue,
    (SELECT ROUND(SUM(oi.line_total),2) FROM order_items oi JOIN orders o ON o.order_id=oi.order_id JOIN customers c ON c.customer_id=o.customer_id JOIN order_statuses s ON s.status_id=o.status_id AND s.is_eligible=1 WHERE o.order_date>=c.signup_date) AS source_revenue,
    IF((SELECT ROUND(SUM(line_revenue),2) FROM vw_pbi_fact_order)=53997988.41 AND (SELECT ROUND(SUM(line_revenue),2) FROM vw_pbi_fact_order_item)=53997988.41, 'PASS', 'FAIL') AS result;

SELECT
    '07_customer_summary_population' AS check_id,
    COUNT(*) AS customer_summary_rows,
    SUM(has_eligible_purchase=1) AS eligible_customers,
    SUM(has_eligible_purchase=0) AS zero_purchase_customers,
    IF(COUNT(*)=8000 AND SUM(has_eligible_purchase=1)=7069 AND SUM(has_eligible_purchase=0)=931, 'PASS', 'FAIL') AS result
FROM vw_pbi_customer_summary;

SELECT
    '08_rfm_view_reconciliation' AS check_id,
    COUNT(*) AS rfm_rows,
    COUNT(DISTINCT customer_id) AS distinct_rfm_customers,
    SUM(frequency) AS rfm_frequency_sum,
    ROUND(SUM(monetary_value),2) AS rfm_monetary_sum,
    IF(COUNT(*)=7069 AND COUNT(*)=COUNT(DISTINCT customer_id) AND SUM(frequency)=35017 AND ROUND(SUM(monetary_value),2)=53997988.41, 'PASS', 'FAIL') AS result
FROM vw_pbi_rfm;

SELECT
    '09_risk_view_reconciliation' AS check_id,
    COUNT(*) AS risk_rows,
    COUNT(DISTINCT customer_id) AS distinct_risk_customers,
    SUM(risk_band='High Risk') AS high_risk_customers,
    SUM(risk_band='Medium Risk') AS medium_risk_customers,
    SUM(risk_band='Low Risk') AS low_risk_customers,
    SUM(churn_candidate_flag=1) AS churn_candidates,
    SUM(risk_reason IS NULL OR TRIM(risk_reason)='') AS null_or_blank_reasons,
    IF(COUNT(*)=7069 AND COUNT(*)=COUNT(DISTINCT customer_id) AND SUM(risk_band IS NULL)=0 AND SUM(risk_reason IS NULL OR TRIM(risk_reason)='')=0 AND SUM(churn_candidate_flag=1)=2491, 'PASS', 'FAIL') AS result
FROM vw_pbi_customer_risk;

SELECT
    '10_monthly_retention_reconciliation' AS check_id,
    COUNT(*) AS monthly_rows,
    SUM(eligible_orders) AS monthly_orders,
    ROUND(SUM(eligible_revenue),2) AS monthly_revenue,
    MIN(order_month) AS first_month,
    MAX(order_month) AS last_month,
    IF(COUNT(*)=24 AND SUM(eligible_orders)=35017 AND ROUND(SUM(eligible_revenue),2)=53997988.41 AND MIN(order_month)='2024-01-01' AND MAX(order_month)='2025-12-01', 'PASS', 'FAIL') AS result
FROM vw_pbi_monthly_retention;

SELECT
    '11_cohort_retention_reconciliation' AS check_id,
    COUNT(DISTINCT cohort_month) AS cohort_months,
    COUNT(DISTINCT CASE WHEN elapsed_month=0 THEN cohort_month END) AS month0_cohorts,
    SUM(CASE WHEN elapsed_month=0 AND retained_customers<>cohort_size THEN 1 ELSE 0 END) AS invalid_month0_rows,
    SUM(CASE WHEN retention_rate<0 OR retention_rate>100 THEN 1 ELSE 0 END) AS out_of_bounds_rows,
    SUM(CASE WHEN elapsed_month=1 AND observation_complete=1 THEN retained_customers ELSE 0 END) AS month1_retained_customers,
    SUM(CASE WHEN elapsed_month=1 AND observation_complete=1 THEN cohort_size ELSE 0 END) AS complete_month1_customers,
    ROUND(100*SUM(CASE WHEN elapsed_month=1 AND observation_complete=1 THEN retained_customers ELSE 0 END)/SUM(CASE WHEN elapsed_month=1 AND observation_complete=1 THEN cohort_size ELSE 0 END),2) AS weighted_month1_retention_rate,
    IF(COUNT(DISTINCT cohort_month)=24 AND COUNT(DISTINCT CASE WHEN elapsed_month=0 THEN cohort_month END)=24 AND SUM(CASE WHEN elapsed_month=0 AND retained_customers<>cohort_size THEN 1 ELSE 0 END)=0 AND SUM(CASE WHEN retention_rate<0 OR retention_rate>100 THEN 1 ELSE 0 END)=0 AND ROUND(100*SUM(CASE WHEN elapsed_month=1 AND observation_complete=1 THEN retained_customers ELSE 0 END)/SUM(CASE WHEN elapsed_month=1 AND observation_complete=1 THEN cohort_size ELSE 0 END),2)=25.05, 'PASS', 'FAIL') AS result
FROM vw_pbi_cohort_retention;

SELECT
    '12_channel_category_product_reconciliation' AS check_id,
    (SELECT COUNT(*) FROM vw_pbi_channel_performance) AS channels,
    (SELECT COUNT(*) FROM vw_pbi_payment_performance) AS payment_methods,
    (SELECT COUNT(*) FROM vw_pbi_category_performance) AS categories,
    (SELECT COUNT(*) FROM vw_pbi_product_performance) AS products_with_sales,
    (SELECT ROUND(SUM(line_revenue),2) FROM vw_pbi_channel_performance) AS channel_revenue,
    (SELECT ROUND(SUM(line_revenue),2) FROM vw_pbi_payment_performance) AS payment_revenue,
    (SELECT ROUND(SUM(line_revenue),2) FROM vw_pbi_category_performance) AS category_revenue,
    (SELECT ROUND(SUM(line_revenue),2) FROM vw_pbi_product_performance) AS product_revenue,
    IF((SELECT ROUND(SUM(line_revenue),2) FROM vw_pbi_channel_performance)=53997988.41 AND (SELECT ROUND(SUM(line_revenue),2) FROM vw_pbi_payment_performance)=53997988.41 AND (SELECT ROUND(SUM(line_revenue),2) FROM vw_pbi_category_performance)=53997988.41 AND (SELECT ROUND(SUM(line_revenue),2) FROM vw_pbi_product_performance)=53997988.41, 'PASS', 'FAIL') AS result;

SELECT
    '13_kpi_summary_reconciliation' AS check_id,
    eligible_orders,
    eligible_customers,
    eligible_revenue,
    zero_purchase_customers,
    repeat_customers,
    period_repeat_retention_rate,
    month_1_retained_customers,
    complete_month_1_cohort_customers,
    weighted_month_1_retention_rate,
    high_risk_customers,
    medium_risk_customers,
    low_risk_customers,
    churn_candidates,
    chronology_exception_orders,
    chronology_exception_customers,
    IF(eligible_orders=35017 AND eligible_customers=7069 AND eligible_revenue=53997988.41 AND zero_purchase_customers=931 AND repeat_customers=4745 AND period_repeat_retention_rate=67.12 AND month_1_retained_customers=1735 AND complete_month_1_cohort_customers=6927 AND weighted_month_1_retention_rate=25.05 AND high_risk_customers=2647 AND medium_risk_customers=1305 AND low_risk_customers=3117 AND churn_candidates=2491 AND chronology_exception_orders=557 AND chronology_exception_customers=404, 'PASS', 'FAIL') AS result
FROM vw_pbi_kpi_summary;

SELECT
    '14_scope_and_rule_check' AS check_id,
    (SELECT COUNT(*) FROM information_schema.routines WHERE routine_schema=DATABASE()) AS routines_created,
    (SELECT COUNT(*) FROM information_schema.tables WHERE table_schema=DATABASE() AND table_name IN ('customers','products','orders','order_items') AND table_type='BASE TABLE') AS raw_base_tables,
    (SELECT lifecycle_rule FROM vw_pbi_kpi_summary) AS lifecycle_rule,
    IF((SELECT COUNT(*) FROM information_schema.routines WHERE routine_schema=DATABASE())=0 AND (SELECT lifecycle_rule FROM vw_pbi_kpi_summary)='is_eligible = 1 AND order_date >= signup_date', 'PASS', 'FAIL') AS result;
