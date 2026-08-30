-- Predictive Customer Retention Analysis using SQL
-- Phase 4: Chronology exception review
-- Read-only diagnostic; no data correction is performed in Phase 4.

USE predictive_customer_retention;

SELECT 'PRE_SIGNUP_ORDER_EXCEPTIONS_BY_STATUS' AS section;
SELECT
    s.status_code,
    COUNT(*) AS exception_order_count,
    COUNT(DISTINCT o.customer_id) AS affected_customer_count,
    MIN(o.order_date) AS earliest_order_date,
    MAX(o.order_date) AS latest_order_date
FROM orders o
JOIN customers c ON c.customer_id = o.customer_id
JOIN order_statuses s ON s.status_id = o.status_id
WHERE o.order_date < c.signup_date
GROUP BY s.status_id, s.status_code
ORDER BY s.status_id;

SELECT 'PRE_SIGNUP_ORDER_EXCEPTION_SUMMARY' AS section;
SELECT
    COUNT(*) AS exception_order_count,
    COUNT(DISTINCT o.customer_id) AS affected_customer_count,
    MIN(o.order_date) AS earliest_order_date,
    MAX(o.order_date) AS latest_order_date,
    MIN(c.signup_date) AS earliest_affected_signup_date,
    MAX(c.signup_date) AS latest_affected_signup_date,
    MIN(DATEDIFF(o.order_date, c.signup_date)) AS most_negative_day_gap,
    MAX(DATEDIFF(o.order_date, c.signup_date)) AS least_negative_day_gap
FROM orders o
JOIN customers c ON c.customer_id = o.customer_id
WHERE o.order_date < c.signup_date;

SELECT 'PRE_SIGNUP_ORDER_EXCEPTION_SAMPLE' AS section;
SELECT
    o.order_id,
    o.order_number,
    o.customer_id,
    o.order_date,
    c.signup_date,
    DATEDIFF(o.order_date, c.signup_date) AS days_before_signup,
    s.status_code
FROM orders o
JOIN customers c ON c.customer_id = o.customer_id
JOIN order_statuses s ON s.status_id = o.status_id
WHERE o.order_date < c.signup_date
ORDER BY days_before_signup, o.order_id
LIMIT 20;
