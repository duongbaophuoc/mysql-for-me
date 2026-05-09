-- =============================================================================
-- Docker Initialization Script / Script Khởi Tạo Docker
-- Runs on first container start / Chạy lần đầu khởi động container
-- =============================================================================

-- Create replication user / Tạo user replication
CREATE USER IF NOT EXISTS 'replicator'@'%'
    IDENTIFIED WITH mysql_native_password BY 'repl_secret';
GRANT REPLICATION SLAVE ON *.* TO 'replicator'@'%';

-- Create read-only user for replicas / User chỉ đọc cho replica
CREATE USER IF NOT EXISTS 'readonly_user'@'%'
    IDENTIFIED WITH mysql_native_password BY 'readonly_secret';
GRANT SELECT ON shop_db.* TO 'readonly_user'@'%';

-- Create monitoring user / User giám sát
CREATE USER IF NOT EXISTS 'exporter'@'%'
    IDENTIFIED WITH mysql_native_password BY 'exporter_secret';
GRANT PROCESS, REPLICATION CLIENT, SELECT ON *.* TO 'exporter'@'%';
GRANT SELECT ON performance_schema.* TO 'exporter'@'%';

-- Create analytics_dw database / Tạo CSDL analytics
CREATE DATABASE IF NOT EXISTS analytics_dw
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

GRANT ALL PRIVILEGES ON analytics_dw.* TO 'app_user'@'%';

FLUSH PRIVILEGES;
