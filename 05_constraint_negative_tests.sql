-- Predictive Customer Retention Analysis using SQL
-- Phase 3: Expected-failure constraint tests
-- Each statement is executed independently by the shell wrapper. No statement should succeed.

-- CHECK constraint: customer_status must be Active or Inactive.
INSERT INTO customers (
    customer_id, customer_code, signup_date, gender, age_band, city, state,
    acquisition_channel, customer_status
)
VALUES (900001, 'TEST-CHECK-01', '2025-01-01', 'Female', '25-34', 'Austin', 'TX', 'Direct', 'Unknown');

-- CHECK constraint: order-item line_total must reconcile to quantity * unit_price - line_discount.
INSERT INTO order_items (
    order_item_id, order_id, product_id, quantity, unit_price, line_discount, line_total
)
VALUES (999999, 1, 1, 1, 100.00, 0.00, 999.00);

-- FOREIGN KEY constraint: an order cannot reference a missing customer.
INSERT INTO orders (
    order_id, order_number, customer_id, order_date, status_id,
    payment_method_id, sales_channel_id, shipping_city, shipping_state,
    discount_amount, shipping_amount
)
VALUES (999999, 'TEST-FK-01', 999999, '2025-01-01', 1, 1, 1, 'Austin', 'TX', 0.00, 0.00);

-- CHECK constraint: product cost_price must be below unit_price.
INSERT INTO products (
    product_id, sku, product_name, category_id, unit_price, cost_price,
    launch_date, product_status
)
VALUES (999999, 'TEST-CHECK-02', 'Constraint Test Product', 1, 10.00, 20.00, '2024-01-01', 'Active');
