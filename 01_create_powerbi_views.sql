-- Predictive Customer Retention Analysis using SQL
-- Phase 7: Power BI-ready SQL data mart views
-- Raw and normalized source tables are not modified.

USE predictive_customer_retention;

-- Dimensions
CREATE OR REPLACE VIEW vw_pbi_dim_customer AS
SELECT
    customer_id,
    customer_code,
    signup_date,
    gender,
    age_band,
    city,
    state,
    acquisition_channel,
    customer_status
FROM customers;

CREATE OR REPLACE VIEW vw_pbi_dim_product AS
SELECT
    p.product_id,
    p.sku,
    p.product_name,
    p.category_id,
    cat.category_name,
    p.unit_price,
    p.cost_price,
    p.launch_date,
    p.product_status
FROM products AS p
JOIN categories AS cat ON cat.category_id = p.category_id;

-- One row per eligible completed order.
CREATE OR REPLACE VIEW vw_pbi_fact_order AS
SELECT
    o.order_id,
    o.order_number,
    o.customer_id,
    c.customer_code,
    c.signup_date,
    o.order_date,
    DATE_FORMAT(o.order_date, '%Y-%m-01') AS order_month,
    s.status_code AS order_status,
    pm.payment_method_name,
    sc.sales_channel_name,
    o.shipping_city,
    o.shipping_state,
    COUNT(oi.order_item_id) AS line_count,
    SUM(oi.quantity) AS total_units,
    ROUND(SUM(oi.line_total), 2) AS line_revenue,
    o.discount_amount,
    o.shipping_amount,
    ROUND(SUM(oi.line_total) - o.discount_amount + o.shipping_amount, 2) AS net_order_value
FROM orders AS o
JOIN customers AS c ON c.customer_id = o.customer_id
JOIN order_statuses AS s ON s.status_id = o.status_id AND s.is_eligible = 1
JOIN payment_methods AS pm ON pm.payment_method_id = o.payment_method_id
JOIN sales_channels AS sc ON sc.sales_channel_id = o.sales_channel_id
JOIN order_items AS oi ON oi.order_id = o.order_id
WHERE o.order_date >= c.signup_date
GROUP BY
    o.order_id,
    o.order_number,
    o.customer_id,
    c.customer_code,
    c.signup_date,
    o.order_date,
    DATE_FORMAT(o.order_date, '%Y-%m-01'),
    s.status_code,
    pm.payment_method_name,
    sc.sales_channel_name,
    o.shipping_city,
    o.shipping_state,
    o.discount_amount,
    o.shipping_amount;

-- One row per eligible order item.
CREATE OR REPLACE VIEW vw_pbi_fact_order_item AS
SELECT
    oi.order_item_id,
    oi.order_id,
    fo.order_number,
    fo.customer_id,
    fo.customer_code,
    fo.order_date,
    fo.order_month,
    fo.order_status,
    fo.payment_method_name,
    fo.sales_channel_name,
    p.product_id,
    p.sku,
    p.product_name,
    p.category_id,
    cat.category_name,
    oi.quantity,
    oi.unit_price AS item_unit_price,
    oi.line_discount,
    oi.line_total AS line_revenue,
    ROUND(oi.quantity * p.cost_price, 2) AS line_cost,
    ROUND(oi.line_total - (oi.quantity * p.cost_price), 2) AS gross_margin
FROM order_items AS oi
JOIN vw_pbi_fact_order AS fo ON fo.order_id = oi.order_id
JOIN products AS p ON p.product_id = oi.product_id
JOIN categories AS cat ON cat.category_id = p.category_id;

-- One row per customer, including customers with no eligible completed purchase.
CREATE OR REPLACE VIEW vw_pbi_customer_summary AS
SELECT
    c.customer_id,
    c.customer_code,
    c.signup_date,
    c.gender,
    c.age_band,
    c.city,
    c.state,
    c.acquisition_channel,
    c.customer_status,
    CASE WHEN m.customer_id IS NULL THEN 0 ELSE 1 END AS has_eligible_purchase,
    COALESCE(m.eligible_order_count, 0) AS eligible_order_count,
    COALESCE(m.monetary_value, 0.00) AS monetary_value,
    m.first_eligible_order_date,
    m.last_eligible_order_date,
    CASE WHEN m.last_eligible_order_date IS NULL THEN NULL ELSE DATEDIFF('2025-12-31', m.last_eligible_order_date) END AS recency_days,
    CASE
        WHEN COALESCE(m.eligible_order_count, 0) = 0 THEN 'No Purchase'
        WHEN m.eligible_order_count = 1 THEN '1 Order'
        WHEN m.eligible_order_count BETWEEN 2 AND 3 THEN '2-3 Orders'
        WHEN m.eligible_order_count BETWEEN 4 AND 5 THEN '4-5 Orders'
        ELSE '6+ Orders'
    END AS purchase_frequency_band
FROM customers AS c
LEFT JOIN (
    SELECT
        customer_id,
        COUNT(*) AS eligible_order_count,
        ROUND(SUM(line_revenue), 2) AS monetary_value,
        MIN(order_date) AS first_eligible_order_date,
        MAX(order_date) AS last_eligible_order_date
    FROM vw_pbi_fact_order
    GROUP BY customer_id
) AS m ON m.customer_id = c.customer_id;

-- Customer-level RFM view, one row per eligible customer.
CREATE OR REPLACE VIEW vw_pbi_rfm AS
WITH customer_metrics AS (
    SELECT
        customer_id,
        MIN(order_date) AS first_eligible_order_date,
        MAX(order_date) AS last_eligible_order_date,
        DATEDIFF('2025-12-31', MAX(order_date)) AS recency_days,
        COUNT(*) AS frequency,
        ROUND(SUM(line_revenue), 2) AS monetary_value
    FROM vw_pbi_fact_order
    GROUP BY customer_id
),
scored AS (
    SELECT
        cm.*,
        6 - NTILE(5) OVER (ORDER BY recency_days ASC, customer_id ASC) AS recency_score,
        6 - NTILE(5) OVER (ORDER BY frequency DESC, customer_id ASC) AS frequency_score,
        6 - NTILE(5) OVER (ORDER BY monetary_value DESC, customer_id ASC) AS monetary_score
    FROM customer_metrics AS cm
),
labeled AS (
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
    recency_days,
    frequency,
    monetary_value,
    ROUND(monetary_value / frequency, 2) AS average_order_value,
    recency_score AS r_score,
    frequency_score AS f_score,
    monetary_score AS m_score,
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
FROM labeled;

-- Customer-level remediated deterministic behavioral risk view.
CREATE OR REPLACE VIEW vw_pbi_customer_risk AS
WITH ordered_with_lag AS (
    SELECT
        fo.*,
        LAG(order_date) OVER (PARTITION BY customer_id ORDER BY order_date, order_id) AS previous_order_date
    FROM vw_pbi_fact_order AS fo
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
        fo.customer_id,
        MIN(fo.order_date) AS first_eligible_order_date,
        MAX(fo.order_date) AS last_eligible_order_date,
        DATEDIFF('2025-12-31', MAX(fo.order_date)) AS recency_days,
        COUNT(*) AS eligible_order_count,
        ROUND(SUM(fo.line_revenue), 2) AS monetary_value,
        COUNT(DISTINCT CASE WHEN fo.order_date BETWEEN '2025-01-01' AND '2025-12-31' THEN fo.order_month END) AS active_months_last_12,
        SUM(CASE WHEN fo.order_date >= DATE_SUB('2025-12-31', INTERVAL 179 DAY) THEN 1 ELSE 0 END) AS orders_last_180_days
    FROM vw_pbi_fact_order AS fo
    GROUP BY fo.customer_id
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
        CASE WHEN recency_days <= 30 THEN 0 WHEN recency_days <= 60 THEN 10 WHEN recency_days <= 90 THEN 20 WHEN recency_days <= 180 THEN 30 ELSE 40 END AS recency_points,
        CASE WHEN eligible_order_count >= 6 THEN 0 WHEN eligible_order_count BETWEEN 3 AND 5 THEN 8 WHEN eligible_order_count = 2 THEN 16 ELSE 25 END AS frequency_points,
        CASE WHEN eligible_order_count = 1 THEN 15 WHEN cadence_ratio IS NULL THEN 0 WHEN cadence_ratio <= 1.0 THEN 0 WHEN cadence_ratio <= 1.5 THEN 8 WHEN cadence_ratio <= 2.0 THEN 16 ELSE 25 END AS cadence_points,
        CASE WHEN orders_last_180_days >= 3 THEN 0 WHEN orders_last_180_days = 2 THEN 3 WHEN orders_last_180_days = 1 THEN 6 ELSE 10 END AS recent_activity_points
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
    CASE WHEN behavioral_risk_score >= 70 THEN 'High Risk' WHEN behavioral_risk_score >= 40 THEN 'Medium Risk' ELSE 'Low Risk' END AS risk_band,
    CASE WHEN recency_days > 90 THEN 1 ELSE 0 END AS inactive_90_plus_flag,
    CASE WHEN recency_days > 180 THEN 1 ELSE 0 END AS inactive_180_plus_flag,
    CASE WHEN eligible_order_count >= 2 AND average_interorder_gap_days > 0 AND cadence_ratio > 2.0 THEN 1 ELSE 0 END AS overdue_cadence_flag,
    CASE WHEN recency_days > 180 THEN 1 ELSE 0 END AS churn_candidate_flag,
    CASE WHEN recency_days <= 180 THEN 'Not a churn candidate' WHEN eligible_order_count >= 2 THEN 'Repeat-customer inactivity' ELSE 'Single-order inactivity' END AS churn_candidate_type,
    CASE WHEN behavioral_risk_score >= 40 AND value_quintile >= 4 THEN 'High Value Intervention' WHEN behavioral_risk_score >= 40 THEN 'Standard Intervention' ELSE 'Monitor / Engage' END AS intervention_priority,
    COALESCE(NULLIF(TRIM(CONCAT_WS('; ',
        CASE WHEN recency_days > 180 THEN 'No eligible purchase in more than 180 days' WHEN recency_days > 90 THEN 'No eligible purchase in more than 90 days' END,
        CASE WHEN eligible_order_count = 1 THEN 'Only one eligible purchase' END,
        CASE WHEN cadence_ratio > 2.0 THEN 'Overdue versus historical purchase cadence' WHEN cadence_ratio > 1.5 THEN 'Purchase cadence deterioration' END,
        CASE WHEN orders_last_180_days = 0 THEN 'No eligible purchase in the last 180 days' END,
        CASE WHEN active_months_last_12 < 3 THEN 'Fewer than three active months in the last twelve months' END
    )), ''), 'No elevated behavior signal') AS risk_reason,
    'is_eligible = 1 AND order_date >= signup_date' AS eligibility_rule_applied,
    'Deterministic SQL behavioral score; not machine-learning prediction' AS score_classification
FROM scored;

-- One row per activity month.
CREATE OR REPLACE VIEW vw_pbi_monthly_retention AS
WITH first_order_month AS (
    SELECT customer_id, MIN(order_month) AS cohort_month
    FROM vw_pbi_fact_order
    GROUP BY customer_id
),
monthly_customer_status AS (
    SELECT DISTINCT
        fo.order_month,
        fo.customer_id,
        fom.cohort_month,
        CASE WHEN fo.order_month = fom.cohort_month THEN 1 ELSE 0 END AS is_new_customer,
        CASE WHEN fo.order_month > fom.cohort_month THEN 1 ELSE 0 END AS is_returning_customer
    FROM vw_pbi_fact_order AS fo
    JOIN first_order_month AS fom ON fom.customer_id = fo.customer_id
),
monthly_metrics AS (
    SELECT
        order_month,
        COUNT(*) AS eligible_orders,
        COUNT(DISTINCT customer_id) AS monthly_active_customers,
        ROUND(SUM(line_revenue), 2) AS eligible_revenue,
        ROUND(SUM(line_revenue) / COUNT(*), 2) AS average_order_value
    FROM vw_pbi_fact_order
    GROUP BY order_month
)
SELECT
    mm.order_month,
    mm.eligible_orders,
    mm.monthly_active_customers,
    COUNT(DISTINCT CASE WHEN mcs.is_new_customer = 1 THEN mcs.customer_id END) AS new_customers,
    COUNT(DISTINCT CASE WHEN mcs.is_returning_customer = 1 THEN mcs.customer_id END) AS returning_customers,
    ROUND(100 * COUNT(DISTINCT CASE WHEN mcs.is_returning_customer = 1 THEN mcs.customer_id END) / mm.monthly_active_customers, 2) AS monthly_repeat_customer_rate,
    mm.eligible_revenue,
    mm.average_order_value
FROM monthly_metrics AS mm
JOIN monthly_customer_status AS mcs ON mcs.order_month = mm.order_month
GROUP BY mm.order_month, mm.eligible_orders, mm.monthly_active_customers, mm.eligible_revenue, mm.average_order_value;

-- One row per cohort month and elapsed month.
CREATE OR REPLACE VIEW vw_pbi_cohort_retention AS
WITH customer_cohorts AS (
    SELECT customer_id, MIN(order_month) AS cohort_month
    FROM vw_pbi_fact_order
    GROUP BY customer_id
),
cohort_sizes AS (
    SELECT cohort_month, COUNT(DISTINCT customer_id) AS cohort_size
    FROM customer_cohorts
    GROUP BY cohort_month
),
cohort_activity AS (
    SELECT DISTINCT
        cc.cohort_month,
        fo.order_month AS activity_month,
        fo.customer_id,
        TIMESTAMPDIFF(MONTH, STR_TO_DATE(cc.cohort_month, '%Y-%m-%d'), STR_TO_DATE(fo.order_month, '%Y-%m-%d')) AS elapsed_month
    FROM customer_cohorts AS cc
    JOIN vw_pbi_fact_order AS fo ON fo.customer_id = cc.customer_id
)
SELECT
    ca.cohort_month,
    ca.activity_month,
    ca.elapsed_month,
    cs.cohort_size,
    COUNT(DISTINCT ca.customer_id) AS retained_customers,
    ROUND(100 * COUNT(DISTINCT ca.customer_id) / cs.cohort_size, 2) AS retention_rate,
    CASE WHEN DATE_ADD(STR_TO_DATE(ca.cohort_month, '%Y-%m-%d'), INTERVAL ca.elapsed_month MONTH) <= '2025-12-01' THEN 1 ELSE 0 END AS observation_complete
FROM cohort_activity AS ca
JOIN cohort_sizes AS cs ON cs.cohort_month = ca.cohort_month
GROUP BY ca.cohort_month, ca.activity_month, ca.elapsed_month, cs.cohort_size;

-- One row per sales channel.
CREATE OR REPLACE VIEW vw_pbi_channel_performance AS
SELECT
    sales_channel_name,
    COUNT(*) AS eligible_orders,
    COUNT(DISTINCT customer_id) AS customers,
    SUM(total_units) AS units,
    ROUND(SUM(line_revenue), 2) AS line_revenue,
    ROUND(SUM(net_order_value), 2) AS net_order_value,
    ROUND(AVG(line_revenue), 2) AS average_order_value
FROM vw_pbi_fact_order
GROUP BY sales_channel_name;

-- One row per payment method.
CREATE OR REPLACE VIEW vw_pbi_payment_performance AS
SELECT
    payment_method_name,
    COUNT(*) AS eligible_orders,
    COUNT(DISTINCT customer_id) AS customers,
    ROUND(SUM(line_revenue), 2) AS line_revenue,
    ROUND(SUM(net_order_value), 2) AS net_order_value,
    ROUND(AVG(line_revenue), 2) AS average_order_value
FROM vw_pbi_fact_order
GROUP BY payment_method_name;

-- One row per category.
CREATE OR REPLACE VIEW vw_pbi_category_performance AS
SELECT
    category_id,
    category_name,
    COUNT(DISTINCT order_id) AS eligible_orders,
    COUNT(DISTINCT customer_id) AS customers,
    SUM(quantity) AS units,
    ROUND(SUM(line_revenue), 2) AS line_revenue,
    ROUND(SUM(line_cost), 2) AS line_cost,
    ROUND(SUM(gross_margin), 2) AS gross_margin,
    ROUND(100 * SUM(gross_margin) / NULLIF(SUM(line_revenue), 0), 2) AS gross_margin_percentage
FROM vw_pbi_fact_order_item
GROUP BY category_id, category_name;

-- One row per product.
CREATE OR REPLACE VIEW vw_pbi_product_performance AS
SELECT
    product_id,
    sku,
    product_name,
    category_id,
    category_name,
    COUNT(DISTINCT order_id) AS eligible_orders,
    COUNT(DISTINCT customer_id) AS customers,
    SUM(quantity) AS units,
    ROUND(SUM(line_revenue), 2) AS line_revenue,
    ROUND(SUM(line_cost), 2) AS line_cost,
    ROUND(SUM(gross_margin), 2) AS gross_margin,
    ROUND(100 * SUM(gross_margin) / NULLIF(SUM(line_revenue), 0), 2) AS gross_margin_percentage
FROM vw_pbi_fact_order_item
GROUP BY product_id, sku, product_name, category_id, category_name;

-- One row for executive KPI cards.
CREATE OR REPLACE VIEW vw_pbi_kpi_summary AS
SELECT
    (SELECT COUNT(*) FROM vw_pbi_fact_order) AS eligible_orders,
    (SELECT COUNT(DISTINCT customer_id) FROM vw_pbi_fact_order) AS eligible_customers,
    (SELECT ROUND(SUM(line_revenue), 2) FROM vw_pbi_fact_order) AS eligible_revenue,
    (SELECT COUNT(*) FROM vw_pbi_customer_summary WHERE has_eligible_purchase = 0) AS zero_purchase_customers,
    (SELECT COUNT(*) FROM vw_pbi_customer_summary WHERE eligible_order_count >= 2) AS repeat_customers,
    (SELECT ROUND(100 * SUM(eligible_order_count >= 2) / COUNT(*), 2) FROM vw_pbi_customer_summary WHERE has_eligible_purchase = 1) AS period_repeat_retention_rate,
    (SELECT SUM(retained_customers) FROM vw_pbi_cohort_retention WHERE elapsed_month = 1 AND observation_complete = 1) AS month_1_retained_customers,
    (SELECT SUM(cohort_size) FROM vw_pbi_cohort_retention WHERE elapsed_month = 1 AND observation_complete = 1) AS complete_month_1_cohort_customers,
    (SELECT ROUND(100 * SUM(retained_customers) / SUM(cohort_size), 2) FROM vw_pbi_cohort_retention WHERE elapsed_month = 1 AND observation_complete = 1) AS weighted_month_1_retention_rate,
    (SELECT COUNT(*) FROM vw_pbi_customer_risk WHERE risk_band = 'High Risk') AS high_risk_customers,
    (SELECT COUNT(*) FROM vw_pbi_customer_risk WHERE risk_band = 'Medium Risk') AS medium_risk_customers,
    (SELECT COUNT(*) FROM vw_pbi_customer_risk WHERE risk_band = 'Low Risk') AS low_risk_customers,
    (SELECT COUNT(*) FROM vw_pbi_customer_risk WHERE churn_candidate_flag = 1) AS churn_candidates,
    (SELECT COUNT(DISTINCT o.order_id) FROM orders AS o JOIN customers AS c ON c.customer_id = o.customer_id WHERE o.order_date < c.signup_date) AS chronology_exception_orders,
    (SELECT COUNT(DISTINCT o.customer_id) FROM orders AS o JOIN customers AS c ON c.customer_id = o.customer_id WHERE o.order_date < c.signup_date) AS chronology_exception_customers,
    '2025-12-31' AS reference_date,
    'is_eligible = 1 AND order_date >= signup_date' AS lifecycle_rule,
    'Risk score is deterministic SQL behavior scoring, not machine-learning prediction' AS risk_score_note;
