-- Predictive Customer Retention Analysis using SQL
-- Original Phase 16: required-index verification
-- Read-only. No indexes are created or altered.

USE predictive_customer_retention;

SELECT
    'orders.customer_id' AS required_access_path,
    'idx_orders_customer_date' AS expected_index,
    GROUP_CONCAT(CONCAT(seq_in_index, ':', column_name) ORDER BY seq_in_index) AS observed_index_columns,
    IF(SUM(index_name='idx_orders_customer_date' AND seq_in_index=1 AND column_name='customer_id') > 0, 'PASS', 'FAIL') AS result
FROM information_schema.statistics
WHERE table_schema = DATABASE()
  AND table_name = 'orders'
  AND index_name = 'idx_orders_customer_date'
UNION ALL
SELECT
    'orders.order_date',
    'idx_orders_date',
    GROUP_CONCAT(CONCAT(seq_in_index, ':', column_name) ORDER BY seq_in_index),
    IF(SUM(index_name='idx_orders_date' AND seq_in_index=1 AND column_name='order_date') > 0, 'PASS', 'FAIL')
FROM information_schema.statistics
WHERE table_schema = DATABASE()
  AND table_name = 'orders'
  AND index_name = 'idx_orders_date'
UNION ALL
SELECT
    'order_items.order_id',
    'idx_order_items_order_id',
    GROUP_CONCAT(CONCAT(seq_in_index, ':', column_name) ORDER BY seq_in_index),
    IF(SUM(index_name='idx_order_items_order_id' AND seq_in_index=1 AND column_name='order_id') > 0, 'PASS', 'FAIL')
FROM information_schema.statistics
WHERE table_schema = DATABASE()
  AND table_name = 'order_items'
  AND index_name = 'idx_order_items_order_id'
UNION ALL
SELECT
    'order_items.product_id',
    'idx_order_items_product_id',
    GROUP_CONCAT(CONCAT(seq_in_index, ':', column_name) ORDER BY seq_in_index),
    IF(SUM(index_name='idx_order_items_product_id' AND seq_in_index=1 AND column_name='product_id') > 0, 'PASS', 'FAIL')
FROM information_schema.statistics
WHERE table_schema = DATABASE()
  AND table_name = 'order_items'
  AND index_name = 'idx_order_items_product_id';

SELECT
    'NO_REDUNDANT_INDEX_CREATION' AS check_id,
    COUNT(*) AS separately_created_phase16_indexes,
    IF(COUNT(*) = 0, 'PASS', 'FAIL') AS result
FROM information_schema.statistics
WHERE table_schema = DATABASE()
  AND index_name LIKE 'idx_phase16_%';
