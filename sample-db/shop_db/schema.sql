-- =============================================================================
-- shop_db — OLTP Production Schema
-- Cơ sở dữ liệu OLTP production cho hệ thống thương mại điện tử
-- =============================================================================

CREATE DATABASE IF NOT EXISTS shop_db
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE shop_db;

-- =============================================================================
-- customers — Tài khoản khách hàng
-- =============================================================================
CREATE TABLE customers (
    id           BIGINT UNSIGNED  NOT NULL AUTO_INCREMENT,
    uuid         CHAR(36)         NOT NULL,                    -- UUID v4 for external use / UUID v4 cho bên ngoài
    email        VARCHAR(255)     NOT NULL,
    phone        VARCHAR(30)      NULL,
    full_name    VARCHAR(255)     NOT NULL,
    status       ENUM('active','inactive','banned') NOT NULL DEFAULT 'active',
    -- Audit columns / Cột kiểm toán
    created_at   DATETIME(3)      NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    updated_at   DATETIME(3)      NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
    deleted_at   DATETIME(3)      NULL,                        -- Soft delete / Xóa mềm
    PRIMARY KEY (id),
    UNIQUE KEY uq_customers_uuid  (uuid),
    UNIQUE KEY uq_customers_email (email),
    KEY idx_customers_status      (status),
    KEY idx_customers_deleted_at  (deleted_at)                 -- Partial scan for soft deletes
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================================================
-- customer_addresses — Địa chỉ khách hàng (1:N)
-- =============================================================================
CREATE TABLE customer_addresses (
    id          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    customer_id BIGINT UNSIGNED NOT NULL,
    label       VARCHAR(50)  NOT NULL DEFAULT 'home',          -- 'home', 'office', 'other'
    address     VARCHAR(500) NOT NULL,
    city        VARCHAR(100) NOT NULL,
    country     CHAR(2)      NOT NULL DEFAULT 'VN',
    is_default  TINYINT(1)   NOT NULL DEFAULT 0,
    created_at  DATETIME(3)  NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    PRIMARY KEY (id),
    KEY idx_customer_addresses_customer_id (customer_id),
    CONSTRAINT fk_customer_addresses_customer
        FOREIGN KEY (customer_id) REFERENCES customers (id)
        ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================================================
-- categories — Danh mục sản phẩm (self-referencing hierarchy)
-- =============================================================================
CREATE TABLE categories (
    id        BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    parent_id BIGINT UNSIGNED NULL,                            -- NULL = root category
    name      VARCHAR(255)   NOT NULL,
    slug      VARCHAR(255)   NOT NULL,
    lft       INT UNSIGNED   NOT NULL DEFAULT 0,               -- Nested set left / Trái nested set
    rgt       INT UNSIGNED   NOT NULL DEFAULT 0,               -- Nested set right / Phải nested set
    depth     TINYINT        NOT NULL DEFAULT 0,               -- Tree depth / Độ sâu cây
    created_at DATETIME(3)   NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    updated_at DATETIME(3)   NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
    PRIMARY KEY (id),
    UNIQUE KEY uq_categories_slug (slug),
    KEY idx_categories_parent_id  (parent_id),
    KEY idx_categories_lft_rgt    (lft, rgt),
    CONSTRAINT fk_categories_parent
        FOREIGN KEY (parent_id) REFERENCES categories (id)
        ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================================================
-- products — Danh mục sản phẩm
-- =============================================================================
CREATE TABLE products (
    id          BIGINT UNSIGNED  NOT NULL AUTO_INCREMENT,
    sku         VARCHAR(100)     NOT NULL,
    category_id BIGINT UNSIGNED  NULL,
    name        VARCHAR(500)     NOT NULL,
    description TEXT             NULL,
    price       DECIMAL(12,2)    NOT NULL,
    status      ENUM('active','inactive','archived') NOT NULL DEFAULT 'active',
    -- JSON metadata for flexible attributes / Metadata JSON cho thuộc tính linh hoạt
    attributes  JSON             NULL,
    created_at  DATETIME(3)      NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    updated_at  DATETIME(3)      NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
    deleted_at  DATETIME(3)      NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uq_products_sku       (sku),
    KEY idx_products_category_id     (category_id),
    KEY idx_products_status          (status),
    KEY idx_products_deleted_at      (deleted_at),
    -- Generated column for JSON attribute extraction / Cột được sinh từ JSON
    price_cents BIGINT UNSIGNED AS (CAST(price * 100 AS UNSIGNED)) STORED,
    CONSTRAINT fk_products_category
        FOREIGN KEY (category_id) REFERENCES categories (id)
        ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================================================
-- inventory — Quản lý tồn kho
-- =============================================================================
CREATE TABLE inventory (
    id                  BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    product_id          BIGINT UNSIGNED NOT NULL,
    warehouse_code      VARCHAR(20)     NOT NULL DEFAULT 'WH-HN-01',
    quantity_available  INT             NOT NULL DEFAULT 0,
    quantity_reserved   INT             NOT NULL DEFAULT 0,    -- In-cart or pending / Trong giỏ hoặc chờ xử lý
    reorder_threshold   INT             NOT NULL DEFAULT 10,
    updated_at          DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
    PRIMARY KEY (id),
    UNIQUE KEY uq_inventory_product_warehouse (product_id, warehouse_code),
    KEY idx_inventory_quantity_available (quantity_available),
    CONSTRAINT fk_inventory_product
        FOREIGN KEY (product_id) REFERENCES products (id)
        ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================================================
-- orders — Đơn hàng
-- =============================================================================
CREATE TABLE orders (
    id              BIGINT UNSIGNED  NOT NULL AUTO_INCREMENT,
    uuid            CHAR(36)         NOT NULL,
    customer_id     BIGINT UNSIGNED  NOT NULL,
    address_id      BIGINT UNSIGNED  NULL,
    status          ENUM('pending','confirmed','processing','shipped','delivered','cancelled','refunded')
                    NOT NULL DEFAULT 'pending',
    -- Financials / Tài chính
    subtotal        DECIMAL(14,2)    NOT NULL DEFAULT 0.00,
    discount_amount DECIMAL(14,2)    NOT NULL DEFAULT 0.00,
    tax_amount      DECIMAL(14,2)    NOT NULL DEFAULT 0.00,
    shipping_amount DECIMAL(14,2)    NOT NULL DEFAULT 0.00,
    total_amount    DECIMAL(14,2)    NOT NULL DEFAULT 0.00,
    currency        CHAR(3)          NOT NULL DEFAULT 'VND',
    -- Metadata
    notes           TEXT             NULL,
    source          VARCHAR(50)      NOT NULL DEFAULT 'web',   -- 'web','app','pos'
    -- Audit
    created_at      DATETIME(3)      NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    updated_at      DATETIME(3)      NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
    PRIMARY KEY (id),
    UNIQUE KEY uq_orders_uuid             (uuid),
    KEY idx_orders_customer_id            (customer_id),
    KEY idx_orders_status                 (status),
    KEY idx_orders_created_at             (created_at),
    KEY idx_orders_customer_status        (customer_id, status),  -- Composite for customer order lists
    CONSTRAINT fk_orders_customer
        FOREIGN KEY (customer_id) REFERENCES customers (id),
    CONSTRAINT fk_orders_address
        FOREIGN KEY (address_id) REFERENCES customer_addresses (id)
        ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================================================
-- order_items — Chi tiết đơn hàng
-- =============================================================================
CREATE TABLE order_items (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    order_id        BIGINT UNSIGNED NOT NULL,
    product_id      BIGINT UNSIGNED NOT NULL,
    product_sku     VARCHAR(100)    NOT NULL,               -- Snapshot at order time / Snapshot lúc đặt hàng
    product_name    VARCHAR(500)    NOT NULL,               -- Snapshot / Snapshot
    unit_price      DECIMAL(12,2)   NOT NULL,
    quantity        INT UNSIGNED    NOT NULL,
    discount        DECIMAL(12,2)   NOT NULL DEFAULT 0.00,
    line_total      DECIMAL(14,2)   GENERATED ALWAYS AS (unit_price * quantity - discount) STORED NOT NULL,
    created_at      DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    PRIMARY KEY (id),
    KEY idx_order_items_order_id   (order_id),
    KEY idx_order_items_product_id (product_id),
    CONSTRAINT fk_order_items_order
        FOREIGN KEY (order_id) REFERENCES orders (id)
        ON DELETE CASCADE,
    CONSTRAINT fk_order_items_product
        FOREIGN KEY (product_id) REFERENCES products (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================================================
-- payments — Giao dịch thanh toán
-- =============================================================================
CREATE TABLE payments (
    id                  BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    uuid                CHAR(36)        NOT NULL,
    order_id            BIGINT UNSIGNED NOT NULL,
    method              ENUM('card','bank_transfer','cod','wallet','qr') NOT NULL,
    status              ENUM('pending','processing','completed','failed','refunded') NOT NULL DEFAULT 'pending',
    amount              DECIMAL(14,2)   NOT NULL,
    currency            CHAR(3)         NOT NULL DEFAULT 'VND',
    gateway             VARCHAR(50)     NULL,               -- 'vnpay','momo','stripe'
    gateway_txn_id      VARCHAR(255)    NULL,               -- External transaction ID / ID giao dịch bên ngoài
    gateway_response    JSON            NULL,               -- Raw gateway response / Phản hồi thô từ gateway
    -- Idempotency key / Khóa mãn đẳng
    idempotency_key     VARCHAR(255)    NULL,
    processed_at        DATETIME(3)     NULL,
    created_at          DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    updated_at          DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
    PRIMARY KEY (id),
    UNIQUE KEY uq_payments_uuid             (uuid),
    UNIQUE KEY uq_payments_idempotency_key  (idempotency_key),
    KEY idx_payments_order_id               (order_id),
    KEY idx_payments_status                 (status),
    KEY idx_payments_gateway_txn_id         (gateway_txn_id),
    CONSTRAINT fk_payments_order
        FOREIGN KEY (order_id) REFERENCES orders (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================================================
-- audit_log — Bảng kiểm toán hành động người dùng
-- =============================================================================
CREATE TABLE audit_log (
    id          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    table_name  VARCHAR(100)    NOT NULL,
    record_id   BIGINT UNSIGNED NOT NULL,
    action      ENUM('INSERT','UPDATE','DELETE') NOT NULL,
    changed_by  BIGINT UNSIGNED NULL,                      -- user/system ID
    old_values  JSON            NULL,
    new_values  JSON            NULL,
    created_at  DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    PRIMARY KEY (id),
    KEY idx_audit_log_table_record  (table_name, record_id),
    KEY idx_audit_log_created_at    (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================================================
-- outbox — Outbox pattern for reliable event publishing
-- Bảng outbox cho việc phát sự kiện đáng tin cậy
-- =============================================================================
CREATE TABLE outbox (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    aggregate_type  VARCHAR(100)    NOT NULL,               -- 'order','payment','customer'
    aggregate_id    VARCHAR(100)    NOT NULL,
    event_type      VARCHAR(100)    NOT NULL,               -- 'order.created','payment.completed'
    payload         JSON            NOT NULL,
    status          ENUM('pending','published','failed') NOT NULL DEFAULT 'pending',
    published_at    DATETIME(3)     NULL,
    retry_count     TINYINT         NOT NULL DEFAULT 0,
    created_at      DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    PRIMARY KEY (id),
    KEY idx_outbox_status_created   (status, created_at),
    KEY idx_outbox_aggregate        (aggregate_type, aggregate_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
