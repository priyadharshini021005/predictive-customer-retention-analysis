-- Predictive Customer Retention Analysis using SQL
-- Phase 3: Staging and normalized core table creation

USE predictive_customer_retention;

SET FOREIGN_KEY_CHECKS = 0;
DROP TABLE IF EXISTS order_items;
DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS customers;
DROP TABLE IF EXISTS sales_channels;
DROP TABLE IF EXISTS payment_methods;
DROP TABLE IF EXISTS order_statuses;
DROP TABLE IF EXISTS categories;
DROP TABLE IF EXISTS stg_order_items;
DROP TABLE IF EXISTS stg_orders;
DROP TABLE IF EXISTS stg_products;
DROP TABLE IF EXISTS stg_customers;
SET FOREIGN_KEY_CHECKS = 1;

-- Raw-ingestion staging tables mirror the four CSV files.
CREATE TABLE stg_customers (
    customer_id INT NOT NULL,
    customer_code VARCHAR(30) NOT NULL,
    signup_date DATE NOT NULL,
    gender VARCHAR(30) NOT NULL,
    age_band VARCHAR(20) NOT NULL,
    city VARCHAR(80) NOT NULL,
    state CHAR(2) NOT NULL,
    acquisition_channel VARCHAR(40) NOT NULL,
    customer_status VARCHAR(20) NOT NULL
) ENGINE = InnoDB;

CREATE TABLE stg_products (
    product_id INT NOT NULL,
    sku VARCHAR(30) NOT NULL,
    product_name VARCHAR(120) NOT NULL,
    category VARCHAR(80) NOT NULL,
    unit_price DECIMAL(10,2) NOT NULL,
    cost_price DECIMAL(10,2) NOT NULL,
    launch_date DATE NOT NULL,
    product_status VARCHAR(20) NOT NULL
) ENGINE = InnoDB;

CREATE TABLE stg_orders (
    order_id INT NOT NULL,
    order_number VARCHAR(30) NOT NULL,
    customer_id INT NOT NULL,
    order_date DATE NOT NULL,
    order_status VARCHAR(20) NOT NULL,
    payment_method VARCHAR(40) NOT NULL,
    sales_channel VARCHAR(30) NOT NULL,
    shipping_city VARCHAR(80) NOT NULL,
    shipping_state CHAR(2) NOT NULL,
    discount_amount DECIMAL(10,2) NOT NULL,
    shipping_amount DECIMAL(10,2) NOT NULL
) ENGINE = InnoDB;

CREATE TABLE stg_order_items (
    order_item_id INT NOT NULL,
    order_id INT NOT NULL,
    product_id INT NOT NULL,
    quantity SMALLINT NOT NULL,
    unit_price DECIMAL(10,2) NOT NULL,
    line_discount DECIMAL(10,2) NOT NULL,
    line_total DECIMAL(10,2) NOT NULL
) ENGINE = InnoDB;

-- Normalized lookup/master tables.
CREATE TABLE categories (
    category_id SMALLINT UNSIGNED NOT NULL AUTO_INCREMENT,
    category_name VARCHAR(80) NOT NULL,
    PRIMARY KEY (category_id),
    UNIQUE KEY uq_categories_name (category_name)
) ENGINE = InnoDB;

CREATE TABLE order_statuses (
    status_id TINYINT UNSIGNED NOT NULL AUTO_INCREMENT,
    status_code VARCHAR(20) NOT NULL,
    is_eligible TINYINT(1) NOT NULL DEFAULT 0,
    PRIMARY KEY (status_id),
    UNIQUE KEY uq_order_statuses_code (status_code),
    CONSTRAINT chk_order_statuses_eligible CHECK (is_eligible IN (0, 1))
) ENGINE = InnoDB;

CREATE TABLE payment_methods (
    payment_method_id TINYINT UNSIGNED NOT NULL AUTO_INCREMENT,
    payment_method_name VARCHAR(40) NOT NULL,
    PRIMARY KEY (payment_method_id),
    UNIQUE KEY uq_payment_methods_name (payment_method_name)
) ENGINE = InnoDB;

CREATE TABLE sales_channels (
    sales_channel_id TINYINT UNSIGNED NOT NULL AUTO_INCREMENT,
    sales_channel_name VARCHAR(30) NOT NULL,
    PRIMARY KEY (sales_channel_id),
    UNIQUE KEY uq_sales_channels_name (sales_channel_name)
) ENGINE = InnoDB;

CREATE TABLE customers (
    customer_id INT UNSIGNED NOT NULL,
    customer_code VARCHAR(30) NOT NULL,
    signup_date DATE NOT NULL,
    gender VARCHAR(30) NOT NULL,
    age_band VARCHAR(20) NOT NULL,
    city VARCHAR(80) NOT NULL,
    state CHAR(2) NOT NULL,
    acquisition_channel VARCHAR(40) NOT NULL,
    customer_status VARCHAR(20) NOT NULL,
    PRIMARY KEY (customer_id),
    UNIQUE KEY uq_customers_code (customer_code),
    KEY idx_customers_signup_date (signup_date),
    KEY idx_customers_acquisition_channel (acquisition_channel),
    CONSTRAINT chk_customers_id_positive CHECK (customer_id > 0),
    CONSTRAINT chk_customers_status CHECK (customer_status IN ('Active', 'Inactive'))
) ENGINE = InnoDB;

CREATE TABLE products (
    product_id INT UNSIGNED NOT NULL,
    sku VARCHAR(30) NOT NULL,
    product_name VARCHAR(120) NOT NULL,
    category_id SMALLINT UNSIGNED NOT NULL,
    unit_price DECIMAL(10,2) NOT NULL,
    cost_price DECIMAL(10,2) NOT NULL,
    launch_date DATE NOT NULL,
    product_status VARCHAR(20) NOT NULL,
    PRIMARY KEY (product_id),
    UNIQUE KEY uq_products_sku (sku),
    KEY idx_products_category_id (category_id),
    KEY idx_products_status (product_status),
    CONSTRAINT fk_products_category FOREIGN KEY (category_id) REFERENCES categories (category_id),
    CONSTRAINT chk_products_id_positive CHECK (product_id > 0),
    CONSTRAINT chk_products_unit_price_positive CHECK (unit_price > 0),
    CONSTRAINT chk_products_cost_price_positive CHECK (cost_price > 0),
    CONSTRAINT chk_products_cost_below_price CHECK (cost_price < unit_price),
    CONSTRAINT chk_products_status CHECK (product_status IN ('Active', 'Discontinued'))
) ENGINE = InnoDB;

CREATE TABLE orders (
    order_id INT UNSIGNED NOT NULL,
    order_number VARCHAR(30) NOT NULL,
    customer_id INT UNSIGNED NOT NULL,
    order_date DATE NOT NULL,
    status_id TINYINT UNSIGNED NOT NULL,
    payment_method_id TINYINT UNSIGNED NOT NULL,
    sales_channel_id TINYINT UNSIGNED NOT NULL,
    shipping_city VARCHAR(80) NOT NULL,
    shipping_state CHAR(2) NOT NULL,
    discount_amount DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    shipping_amount DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    PRIMARY KEY (order_id),
    UNIQUE KEY uq_orders_number (order_number),
    KEY idx_orders_customer_date (customer_id, order_date),
    KEY idx_orders_status_date (status_id, order_date),
    KEY idx_orders_channel_date (sales_channel_id, order_date),
    KEY idx_orders_date (order_date),
    CONSTRAINT fk_orders_customer FOREIGN KEY (customer_id) REFERENCES customers (customer_id),
    CONSTRAINT fk_orders_status FOREIGN KEY (status_id) REFERENCES order_statuses (status_id),
    CONSTRAINT fk_orders_payment_method FOREIGN KEY (payment_method_id) REFERENCES payment_methods (payment_method_id),
    CONSTRAINT fk_orders_sales_channel FOREIGN KEY (sales_channel_id) REFERENCES sales_channels (sales_channel_id),
    CONSTRAINT chk_orders_id_positive CHECK (order_id > 0),
    CONSTRAINT chk_orders_discount_nonnegative CHECK (discount_amount >= 0),
    CONSTRAINT chk_orders_shipping_nonnegative CHECK (shipping_amount >= 0)
) ENGINE = InnoDB;

CREATE TABLE order_items (
    order_item_id INT UNSIGNED NOT NULL,
    order_id INT UNSIGNED NOT NULL,
    product_id INT UNSIGNED NOT NULL,
    quantity SMALLINT UNSIGNED NOT NULL,
    unit_price DECIMAL(10,2) NOT NULL,
    line_discount DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    line_total DECIMAL(10,2) NOT NULL,
    PRIMARY KEY (order_item_id),
    UNIQUE KEY uq_order_items_order_product (order_id, product_id),
    KEY idx_order_items_order_id (order_id),
    KEY idx_order_items_product_id (product_id),
    CONSTRAINT fk_order_items_order FOREIGN KEY (order_id) REFERENCES orders (order_id),
    CONSTRAINT fk_order_items_product FOREIGN KEY (product_id) REFERENCES products (product_id),
    CONSTRAINT chk_order_items_id_positive CHECK (order_item_id > 0),
    CONSTRAINT chk_order_items_quantity_positive CHECK (quantity > 0),
    CONSTRAINT chk_order_items_unit_price_positive CHECK (unit_price > 0),
    CONSTRAINT chk_order_items_discount_nonnegative CHECK (line_discount >= 0),
    CONSTRAINT chk_order_items_discount_not_above_gross CHECK (line_discount <= quantity * unit_price),
    CONSTRAINT chk_order_items_line_total_nonnegative CHECK (line_total >= 0),
    CONSTRAINT chk_order_items_line_total_reconciles CHECK (line_total = ROUND(quantity * unit_price - line_discount, 2))
) ENGINE = InnoDB;

SHOW TABLES;
