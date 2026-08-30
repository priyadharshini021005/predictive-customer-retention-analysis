-- Predictive Customer Retention Analysis using SQL
-- Original Phase 16: read-only stored procedures
-- The procedures do not modify source data or create indexes.

USE predictive_customer_retention;

DROP PROCEDURE IF EXISTS sp_get_customer_lifecycle_summary;
DROP PROCEDURE IF EXISTS sp_get_risk_intervention_list;
DROP PROCEDURE IF EXISTS sp_get_retention_kpi_summary;

DELIMITER $$

CREATE PROCEDURE sp_get_customer_lifecycle_summary(IN p_reference_date DATE)
READS SQL DATA
SQL SECURITY INVOKER
BEGIN
    DECLARE v_reference_date DATE;
    SET v_reference_date = COALESCE(p_reference_date, '2025-12-31');

    IF v_reference_date < '2024-01-01' OR v_reference_date > '2025-12-31' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'p_reference_date must be between 2024-01-01 and 2025-12-31';
    END IF;

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
        CASE WHEN m.last_eligible_order_date IS NULL THEN NULL ELSE DATEDIFF(v_reference_date, m.last_eligible_order_date) END AS recency_days,
        v_reference_date AS reference_date,
        'is_eligible = 1 AND order_date >= signup_date' AS eligibility_rule_applied
    FROM customers AS c
    LEFT JOIN (
        SELECT
            o.customer_id,
            COUNT(DISTINCT o.order_id) AS eligible_order_count,
            ROUND(SUM(oi.line_total), 2) AS monetary_value,
            MIN(o.order_date) AS first_eligible_order_date,
            MAX(o.order_date) AS last_eligible_order_date
        FROM orders AS o
        JOIN customers AS c2 ON c2.customer_id = o.customer_id
        JOIN order_statuses AS s ON s.status_id = o.status_id AND s.is_eligible = 1
        JOIN order_items AS oi ON oi.order_id = o.order_id
        WHERE o.order_date >= c2.signup_date
          AND o.order_date <= v_reference_date
        GROUP BY o.customer_id
    ) AS m ON m.customer_id = c.customer_id
    ORDER BY c.customer_id;
END$$

CREATE PROCEDURE sp_get_risk_intervention_list(
    IN p_risk_band VARCHAR(20),
    IN p_min_score INT,
    IN p_limit INT
)
READS SQL DATA
SQL SECURITY INVOKER
BEGIN
    DECLARE v_min_score INT;
    DECLARE v_limit INT;
    DECLARE v_risk_band VARCHAR(20);

    SET v_min_score = COALESCE(p_min_score, 0);
    SET v_limit = COALESCE(p_limit, 100);
    SET v_risk_band = NULLIF(TRIM(p_risk_band), '');

    IF v_min_score < 0 OR v_min_score > 100 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'p_min_score must be between 0 and 100';
    END IF;

    IF v_limit < 1 OR v_limit > 1000 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'p_limit must be between 1 and 1000';
    END IF;

    IF v_risk_band IS NOT NULL AND v_risk_band NOT IN ('High Risk', 'Medium Risk', 'Low Risk') THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'p_risk_band must be High Risk, Medium Risk, Low Risk, or NULL';
    END IF;

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
        r.risk_reason,
        r.eligibility_rule_applied,
        r.score_classification
    FROM vw_pbi_customer_risk AS r
    JOIN vw_pbi_customer_summary AS cs ON cs.customer_id = r.customer_id
    WHERE (v_risk_band IS NULL OR r.risk_band = v_risk_band)
      AND r.behavioral_risk_score >= v_min_score
    ORDER BY r.behavioral_risk_score DESC, r.monetary_value DESC, r.customer_id
    LIMIT v_limit;
END$$

CREATE PROCEDURE sp_get_retention_kpi_summary()
READS SQL DATA
SQL SECURITY INVOKER
BEGIN
    SELECT *
    FROM vw_pbi_kpi_summary;
END$$

DELIMITER ;
