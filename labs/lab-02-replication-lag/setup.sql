-- =============================================================================
-- Lab 02: Replication Lag — Setup & Simulation
-- Lab 02: Độ Trễ Sao Chép — Thiết Lập & Mô Phỏng
-- =============================================================================

-- Step 1: Verify replication is running / Bước 1: Xác minh replication đang chạy
-- Run this on the replica / Chạy trên replica
SHOW REPLICA STATUS\G

-- Step 2: Baseline lag measurement / Đo độ trễ cơ sở
-- ─────────────────────────────────────────────────────
SELECT
    VARIABLE_NAME,
    VARIABLE_VALUE
FROM performance_schema.global_status
WHERE VARIABLE_NAME IN (
    'Seconds_Behind_Master',
    'Replica_IO_Running',
    'Replica_SQL_Running'
);

-- Step 3: CREATE monitoring heartbeat table on PRIMARY
-- Bước 3: Tạo bảng heartbeat giám sát trên PRIMARY
CREATE DATABASE IF NOT EXISTS lab_monitor;

CREATE TABLE IF NOT EXISTS lab_monitor.replication_heartbeat (
    id          INT UNSIGNED NOT NULL AUTO_INCREMENT,
    server_id   INT UNSIGNED NOT NULL,
    created_at  DATETIME(3)  NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    PRIMARY KEY (id)
);

-- Step 4: Simulate LAG — Run this LARGE transaction on PRIMARY
-- Bước 4: Mô phỏng LAG — Chạy giao dịch LỚN này trên PRIMARY
-- This creates a big binlog event that takes time to replicate
-- Tạo sự kiện binlog lớn mất thời gian để sao chép

USE shop_db;

-- Generate load: 100,000 row updates in single transaction (bad practice — but good for lab!)
-- Tạo tải: 100,000 bản ghi cập nhật trong một giao dịch

DELIMITER $$
CREATE PROCEDURE IF NOT EXISTS generate_replication_lag()
BEGIN
    DECLARE i INT DEFAULT 0;
    START TRANSACTION;
    WHILE i < 50000 DO
        UPDATE orders
        SET    notes = CONCAT('LAG_TEST_', NOW(3))
        ORDER  BY RAND()          -- random row each time / hàng ngẫu nhiên mỗi lần
        LIMIT  1;
        SET i = i + 1;
    END WHILE;
    COMMIT;
END$$
DELIMITER ;

-- Call: / Gọi:
-- CALL generate_replication_lag();

-- Step 5: Monitor lag while procedure runs on PRIMARY
-- Bước 5: Giám sát độ trễ trong khi procedure chạy trên PRIMARY
-- Run on REPLICA / Chạy trên REPLICA:

-- watch -n 1 "mysql -h 127.0.0.1 -P 3307 -u root -psecret
--   -e 'SHOW REPLICA STATUS\G' | grep Seconds_Behind"

-- Step 6: Enable parallel replication to reduce lag
-- Bước 6: Bật replication song song để giảm độ trễ
-- Run on REPLICA / Chạy trên REPLICA:
STOP REPLICA SQL_THREAD;
SET GLOBAL replica_parallel_workers = 4;
SET GLOBAL replica_parallel_type    = 'LOGICAL_CLOCK';
SET GLOBAL replica_preserve_commit_order = ON;
START REPLICA SQL_THREAD;

-- Step 7: Compare lag before vs after parallel replication
-- Bước 7: So sánh độ trễ trước vs sau replication song song

-- Step 8: Cleanup
DROP PROCEDURE IF EXISTS generate_replication_lag;
DROP DATABASE  IF EXISTS lab_monitor;
