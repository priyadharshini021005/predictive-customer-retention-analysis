-- Predictive Customer Retention Analysis using SQL
-- Phase 7: Curated Power BI reporting queries over the data-mart views.
-- These queries are read-only and do not modify the database.

USE predictive_customer_retention;

-- Executive KPI cards.
SELECT *
FROM vw_pbi_kpi_summary;

-- Monthly sales and repeat-customer trend.
SELECT
    order_month,
    eligible_orders,
    monthly_active_customers,
    new_customers,
    returning_customers,
    monthly_repeat_customer_rate,
    eligible_revenue,
    average_order_value
FROM vw_pbi_monthly_retention
ORDER BY order_month;

-- RFM segment distribution.
SELECT
    rfm_segment,
    COUNT(*) AS customers,
    ROUND(100 * COUNT(*) / (SELECT COUNT(*) FROM vw_pbi_rfm), 2) AS customer_percentage,
    ROUND(AVG(monetary_value), 2) AS average_customer_value,
    ROUND(AVG(recency_days), 2) AS average_recency_days,
    ROUND(AVG(frequency), 2) AS average_frequency
FROM vw_pbi_rfm
GROUP BY rfm_segment
ORDER BY customers DESC;

-- Risk-band and churn-candidate distribution.
SELECT
    risk_band,
    COUNT(*) AS customers,
    ROUND(100 * COUNT(*) / (SELECT COUNT(*) FROM vw_pbi_customer_risk), 2) AS customer_percentage,
    SUM(churn_candidate_flag) AS churn_candidates,
    SUM(inactive_90_plus_flag) AS inactive_90_plus,
    ROUND(AVG(behavioral_risk_score), 2) AS average_behavioral_risk_score
FROM vw_pbi_customer_risk
GROUP BY risk_band
ORDER BY FIELD(risk_band, 'High Risk', 'Medium Risk', 'Low Risk');

-- Intervention-priority table.
SELECT
    intervention_priority,
    COUNT(*) AS customers,
    ROUND(100 * COUNT(*) / (SELECT COUNT(*) FROM vw_pbi_customer_risk), 2) AS customer_percentage,
    ROUND(SUM(monetary_value), 2) AS monetary_value,
    SUM(churn_candidate_flag) AS churn_candidates
FROM vw_pbi_customer_risk
GROUP BY intervention_priority
ORDER BY FIELD(intervention_priority, 'High Value Intervention', 'Standard Intervention', 'Monitor / Engage');

-- Weighted month-1 retention summary by complete cohort.
SELECT
    cohort_month,
    cohort_size,
    retained_customers AS month_1_retained_customers,
    retention_rate AS month_1_retention_rate
FROM vw_pbi_cohort_retention
WHERE elapsed_month = 1
  AND observation_complete = 1
ORDER BY cohort_month;

-- Full cohort retention matrix source.
SELECT
    cohort_month,
    activity_month,
    elapsed_month,
    cohort_size,
    retained_customers,
    retention_rate,
    observation_complete
FROM vw_pbi_cohort_retention
ORDER BY cohort_month, elapsed_month;

-- Channel performance.
SELECT *
FROM vw_pbi_channel_performance
ORDER BY line_revenue DESC;

-- Payment-method performance.
SELECT *
FROM vw_pbi_payment_performance
ORDER BY line_revenue DESC;

-- Category performance.
SELECT *
FROM vw_pbi_category_performance
ORDER BY line_revenue DESC;

-- Top products by eligible revenue.
SELECT *
FROM vw_pbi_product_performance
ORDER BY line_revenue DESC
LIMIT 20;

-- Customer action list for high-priority interventions.
SELECT
    r.customer_id,
    cs.customer_code,
    cs.city,
    cs.state,
    cs.acquisition_channel,
    r.risk_band,
    r.behavioral_risk_score,
    r.churn_candidate_flag,
    r.intervention_priority,
    r.recency_days,
    r.eligible_order_count,
    r.monetary_value,
    r.risk_reason
FROM vw_pbi_customer_risk AS r
JOIN vw_pbi_customer_summary AS cs ON cs.customer_id = r.customer_id
WHERE r.intervention_priority IN ('High Value Intervention', 'Standard Intervention')
ORDER BY r.behavioral_risk_score DESC, r.monetary_value DESC, r.customer_id;

-- Data-quality exception card.
SELECT
    chronology_exception_orders,
    chronology_exception_customers,
    reference_date,
    lifecycle_rule,
    risk_score_note
FROM vw_pbi_kpi_summary;
