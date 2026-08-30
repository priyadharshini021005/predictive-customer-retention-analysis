#!/usr/bin/env bash
set -u

DB='predictive_customer_retention'
OUT='/home/ubuntu/Predictive Customer Retention Analysis using SQL/evidence/phase3/constraint_negative_tests.log'
: > "$OUT"

run_test() {
  local name="$1"
  local sql="$2"
  local output
  local rc
  output=$(sudo mysql "$DB" -e "$sql" 2>&1)
  rc=$?
  printf 'TEST: %s\n' "$name" >> "$OUT"
  printf 'RETURN_CODE: %s\n' "$rc" >> "$OUT"
  printf '%s\n' "$output" >> "$OUT"
  if [ "$rc" -eq 0 ]; then
    printf 'RESULT: FAIL (invalid statement was accepted)\n\n' >> "$OUT"
  else
    printf 'RESULT: PASS (invalid statement was rejected)\n\n' >> "$OUT"
  fi
}

run_test 'customer_status_check' "INSERT INTO customers (customer_id, customer_code, signup_date, gender, age_band, city, state, acquisition_channel, customer_status) VALUES (900001, 'TEST-CHECK-01', '2025-01-01', 'Female', '25-34', 'Austin', 'TX', 'Direct', 'Unknown');"
run_test 'order_item_line_total_check' "INSERT INTO order_items (order_item_id, order_id, product_id, quantity, unit_price, line_discount, line_total) VALUES (999999, 1, 1, 1, 100.00, 0.00, 999.00);"
run_test 'order_customer_foreign_key' "INSERT INTO orders (order_id, order_number, customer_id, order_date, status_id, payment_method_id, sales_channel_id, shipping_city, shipping_state, discount_amount, shipping_amount) VALUES (999999, 'TEST-FK-01', 999999, '2025-01-01', 1, 1, 1, 'Austin', 'TX', 0.00, 0.00);"
run_test 'product_cost_price_check' "INSERT INTO products (product_id, sku, product_name, category_id, unit_price, cost_price, launch_date, product_status) VALUES (999999, 'TEST-CHECK-02', 'Constraint Test Product', 1, 10.00, 20.00, '2024-01-01', 'Active');"

if grep -q 'RESULT: FAIL' "$OUT"; then
  exit 1
fi
