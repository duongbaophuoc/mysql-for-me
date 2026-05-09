-- =============================================================================
-- Lab 01: Deadlock Analysis — Setup Script
-- Lab 01: Phân Tích Bế Tắc — Script Thiết Lập
-- =============================================================================

USE shop_db;

-- Ensure we have clean test data / Đảm bảo dữ liệu test sạch
-- Reset orders 1 and 2 to 'pending' / Đặt lại đơn hàng 1 và 2 về 'pending'
UPDATE orders   SET status = 'pending'   WHERE id IN (1, 2);
UPDATE payments SET status = 'pending'   WHERE order_id IN (1, 2);

-- Verify starting state / Xác minh trạng thái bắt đầu
SELECT 'orders' AS tbl, id, status FROM orders   WHERE id IN (1, 2)
UNION ALL
SELECT 'payments',   id, status FROM payments WHERE order_id IN (1, 2);

-- Enable InnoDB deadlock logging / Bật ghi log bế tắc InnoDB
SET GLOBAL innodb_print_all_deadlocks = ON;

-- Show current lock timeout / Hiển thị timeout lock hiện tại
-- Default is 50 seconds; reduce for faster deadlock detection in lab
-- Mặc định 50 giây; giảm để phát hiện bế tắc nhanh hơn trong lab
SET GLOBAL innodb_lock_wait_timeout = 10;

SELECT 'Setup complete. Open two terminals and follow the lab README.' AS instruction;
SELECT 'Thiết lập hoàn tất. Mở hai terminals và thực hiện theo README.' AS huong_dan;
