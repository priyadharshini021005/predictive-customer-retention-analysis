-- Predictive Customer Retention Analysis using SQL
-- Original Phase 16: stored-procedure and index validation
-- Read-only validation. Procedures are called but no data is modified.

USE predictive_customer_retention;

SELECT
    '01_procedure_count' AS check_id,
    COUNT(*) AS observed_count,
    3 AS expected_count,
    IF(COUNT(*) = 3, 'PASS', 'FAIL') AS result
FROM information_schema.routines
WHERE routine_schema = DATABASE()
  AND routine_name IN ('sp_get_customer_lifecycle_summary', 'sp_get_risk_intervention_list', 'sp_get_retention_kpi_summary')
  AND routine_type = 'PROCEDURE';

SELECT
    '02_procedure_characteristics' AS check_id,
    COUNT(*) AS read_sql_procedures,
    IF(COUNT(*) = 3, 'PASS', 'FAIL') AS result
FROM information_schema.routines
WHERE routine_schema = DATABASE()
  AND routine_name IN ('sp_get_customer_lifecycle_summary', 'sp_get_risk_intervention_list', 'sp_get_retention_kpi_summary')
  AND routine_type = 'PROCEDURE'
  AND sql_data_access = 'READS SQL DATA'
  AND security_type = 'INVOKER';

SELECT
    '03_source_table_row_counts' AS check_id,
    (SELECT COUNT(*) FROM customers) AS customers,
    (SELECT COUNT(*) FROM products) AS products,
    (SELECT COUNT(*) FROM orders) AS orders,
    (SELECT COUNT(*) FROM order_items) AS order_items,
    IF((SELECT COUNT(*) FROM customers)=8000 AND (SELECT COUNT(*) FROM products)=180 AND (SELECT COUNT(*) FROM orders)=40000 AND (SELECT COUNT(*) FROM order_items)=116953, 'PASS', 'FAIL') AS result;

SELECT
    '04_chronology_exception_preservation' AS check_id,
    COUNT(DISTINCT o.order_id) AS exception_orders,
    COUNT(DISTINCT o.customer_id) AS exception_customers,
    IF(COUNT(DISTINCT o.order_id)=557 AND COUNT(DISTINCT o.customer_id)=404, 'PASS', 'FAIL') AS result
FROM orders o
JOIN customers c ON c.customer_id=o.customer_id
WHERE o.order_date < c.signup_date;

SELECT
    '05_lifecycle_rule_metadata' AS check_id,
    (SELECT lifecycle_rule FROM vw_pbi_kpi_summary) AS lifecycle_rule,
    IF((SELECT lifecycle_rule FROM vw_pbi_kpi_summary)='is_eligible = 1 AND order_date >= signup_date', 'PASS', 'FAIL') AS result;

-- Valid procedure calls used by the shell validation wrapper.
SELECT '06_valid_lifecycle_call' AS call_id;
CALL sp_get_customer_lifecycle_summary('2025-12-31');

SELECT '07_valid_risk_list_call' AS call_id;
CALL sp_get_risk_intervention_list('High Risk', 70, 10);

SELECT '08_valid_kpi_call' AS call_id;
CALL sp_get_retention_kpi_summary();
