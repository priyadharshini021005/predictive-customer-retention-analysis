-- Predictive Customer Retention Analysis using SQL
-- Focused Phase 3 index verification; no schema changes are performed.

USE predictive_customer_retention;

SELECT required_column,
       covering_index,
       indexed_columns,
       IF(index_name IS NOT NULL, 'PASS', 'FAIL') AS result
FROM (
    SELECT 'orders.customer_id' AS required_column,
           'idx_orders_customer_date' AS covering_index,
           'customer_id, order_date' AS indexed_columns,
           'orders' AS table_name,
           'customer_id' AS column_name,
           1 AS required_sequence
    UNION ALL
    SELECT 'orders.order_date', 'idx_orders_date', 'order_date', 'orders', 'order_date', 1
    UNION ALL
    SELECT 'order_items.order_id', 'idx_order_items_order_id', 'order_id', 'order_items', 'order_id', 1
    UNION ALL
    SELECT 'order_items.product_id', 'idx_order_items_product_id', 'product_id', 'order_items', 'product_id', 1
) AS required
LEFT JOIN (
    SELECT s.table_name,
           s.column_name,
           s.seq_in_index,
           s.index_name
    FROM information_schema.statistics AS s
    WHERE s.table_schema = DATABASE()
) AS actual
  ON actual.table_name = required.table_name
 AND actual.column_name = required.column_name
 AND actual.seq_in_index = required.required_sequence
GROUP BY required_column, covering_index, indexed_columns, index_name
ORDER BY required_column;

SELECT 'NO_INDEX_CREATION_REQUIRED' AS check_name,
       IF(
           (SELECT COUNT(*)
            FROM information_schema.statistics
            WHERE table_schema = DATABASE()
              AND table_name = 'orders'
              AND column_name = 'customer_id'
              AND seq_in_index = 1) > 0
       AND (SELECT COUNT(*)
            FROM information_schema.statistics
            WHERE table_schema = DATABASE()
              AND table_name = 'orders'
              AND column_name = 'order_date'
              AND seq_in_index = 1) > 0
       AND (SELECT COUNT(*)
            FROM information_schema.statistics
            WHERE table_schema = DATABASE()
              AND table_name = 'order_items'
              AND column_name = 'order_id'
              AND seq_in_index = 1) > 0
       AND (SELECT COUNT(*)
            FROM information_schema.statistics
            WHERE table_schema = DATABASE()
              AND table_name = 'order_items'
              AND column_name = 'product_id'
              AND seq_in_index = 1) > 0,
       'PASS', 'FAIL') AS result;
