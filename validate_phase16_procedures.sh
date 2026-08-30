#!/usr/bin/env bash
set -u

PROJECT_DIR="/home/ubuntu/Predictive Customer Retention Analysis using SQL"
EVIDENCE_DIR="$PROJECT_DIR/evidence/phase16"
DB="predictive_customer_retention"
mkdir -p "$EVIDENCE_DIR"

run_sql() {
  sudo mysql --batch --raw "$DB" -e "$1"
}

run_sql "CALL sp_get_customer_lifecycle_summary('2025-12-31');" > "$EVIDENCE_DIR/lifecycle_summary_call.log"
run_sql "CALL sp_get_customer_lifecycle_summary('2024-01-01');" > "$EVIDENCE_DIR/lifecycle_summary_earliest_call.log"
run_sql "CALL sp_get_risk_intervention_list('High Risk', 70, 10);" > "$EVIDENCE_DIR/risk_intervention_call.log"
run_sql "CALL sp_get_retention_kpi_summary();" > "$EVIDENCE_DIR/kpi_summary_call.log"

printf '%s\n' 'VALID_PROCEDURE_CALLS'
awk -F '\t' 'NR>1 {rows++; if ($10==1) eligible++; if ($10==0) zero++ ; orders += $11; revenue += $12} END {printf "lifecycle_rows=%d\neligible_customers=%d\nzero_purchase_customers=%d\nprocedure_order_sum=%d\nprocedure_revenue_sum=%.2f\n", rows, eligible, zero, orders, revenue}' "$EVIDENCE_DIR/lifecycle_summary_call.log"
awk -F '\t' 'NR>1 {rows++; if ($6!="High Risk") bad_band++; if ($7<70) bad_score++} END {printf "risk_rows=%d\nrisk_band_mismatches=%d\nrisk_score_below_minimum=%d\n", rows, bad_band, bad_score}' "$EVIDENCE_DIR/risk_intervention_call.log"
awk -F '\t' 'NR>1 {rows++; if ($10==1) eligible++; if ($14!="" && $14!="NULL" && $14>"2024-01-01") future_date_rows++} END {printf "earliest_reference_rows=%d\neligible_customers_at_2024_01_01=%d\nfuture_order_rows_at_2024_01_01=%d\n", rows, eligible, future_date_rows}' "$EVIDENCE_DIR/lifecycle_summary_earliest_call.log"
awk -F '\t' 'NR>1 {rows++; print "kpi_row=" $0} END {printf "kpi_rows=%d\n", rows}' "$EVIDENCE_DIR/kpi_summary_call.log"

expected_error_test() {
  label="$1"
  sql="$2"
  err_file="$EVIDENCE_DIR/${label}.err"
  if run_sql "$sql" > /dev/null 2> "$err_file"; then
    printf '%s=FAIL\n' "$label"
  else
    printf '%s=PASS\n' "$label"
  fi
}

expected_error_test invalid_reference_date "CALL sp_get_customer_lifecycle_summary('2026-01-01');"
expected_error_test invalid_risk_band "CALL sp_get_risk_intervention_list('Unknown Risk', 0, 10);"
expected_error_test invalid_min_score "CALL sp_get_risk_intervention_list('High Risk', 101, 10);"
expected_error_test invalid_limit "CALL sp_get_risk_intervention_list('High Risk', 70, 0);"
