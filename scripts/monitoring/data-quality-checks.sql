-- =============================================================================
-- Data Quality Checks
-- Kiểm Tra Chất Lượng Dữ Liệu
-- =============================================================================
-- Run periodically to detect data integrity issues in shop_db
-- Chạy định kỳ để phát hiện vấn đề toàn vẹn dữ liệu trong shop_db
-- =============================================================================

USE shop_db;

SET @checks_passed = 0;
SET @checks_failed = 0;
SET @check_results = '';

-- Helper: / Trợ giúp:
-- Pass if count = 0 / Đạt nếu count = 0

-- ─── CHECK 1: Orphaned order_items / Mặt hàng mồ côi ─────────────────────
SET @orphan_items = (
    SELECT COUNT(*) FROM order_items oi
    LEFT JOIN orders o ON o.id = oi.order_id
    WHERE o.id IS NULL
);
SET @checks_passed = @checks_passed + IF(@orphan_items = 0, 1, 0);
SET @checks_failed = @checks_failed + IF(@orphan_items > 0, 1, 0);
SELECT
    'CHECK 1' AS check_id,
    'Orphaned order_items / Mặt hàng mồ côi' AS description,
    IF(@orphan_items = 0, '✅ PASS', '❌ FAIL') AS result,
    @orphan_items AS issue_count;

-- ─── CHECK 2: Orders with negative totals / Đơn hàng tổng âm ────────────────
SET @neg_totals = (
    SELECT COUNT(*) FROM orders WHERE total_amount < 0
);
SELECT
    'CHECK 2',
    'Negative order totals / Tổng đơn hàng âm',
    IF(@neg_totals = 0, '✅ PASS', '❌ FAIL'),
    @neg_totals;

-- ─── CHECK 3: Duplicate emails / Email trùng lặp ────────────────────────────
SET @dup_emails = (
    SELECT COUNT(*) FROM (
        SELECT email, COUNT(*) c FROM customers
        WHERE deleted_at IS NULL GROUP BY email HAVING c > 1
    ) t
);
SELECT
    'CHECK 3',
    'Duplicate customer emails / Email trùng lặp',
    IF(@dup_emails = 0, '✅ PASS', '❌ FAIL'),
    @dup_emails;

-- ─── CHECK 4: Payments without matching orders / Thanh toán không có đơn ──────
SET @orphan_payments = (
    SELECT COUNT(*) FROM payments p
    LEFT JOIN orders o ON o.id = p.order_id
    WHERE o.id IS NULL
);
SELECT
    'CHECK 4',
    'Payments without orders / Thanh toán không có đơn hàng',
    IF(@orphan_payments = 0, '✅ PASS', '❌ FAIL'),
    @orphan_payments;

-- ─── CHECK 5: Orders stuck in pending > 7 days / Đơn hàng kẹt pending ───────
SET @stuck_orders = (
    SELECT COUNT(*) FROM orders
    WHERE status = 'pending'
      AND created_at < DATE_SUB(NOW(), INTERVAL 7 DAY)
);
SELECT
    'CHECK 5',
    'Orders stuck pending > 7 days / Đơn hàng kẹt pending > 7 ngày',
    IF(@stuck_orders = 0, '✅ PASS', CONCAT('⚠️ WARN (', @stuck_orders, ')')),
    @stuck_orders;

-- ─── CHECK 6: Products with zero or null price / Sản phẩm giá 0 hoặc null ────
SET @zero_price = (
    SELECT COUNT(*) FROM products
    WHERE (price IS NULL OR price <= 0) AND status = 'active'
);
SELECT
    'CHECK 6',
    'Active products with invalid price / Sản phẩm active giá không hợp lệ',
    IF(@zero_price = 0, '✅ PASS', '❌ FAIL'),
    @zero_price;

-- ─── CHECK 7: Outbox events stuck (failed to publish) / Sự kiện outbox kẹt ───
SET @stuck_outbox = (
    SELECT COUNT(*) FROM outbox_events
    WHERE status = 'failed'
      AND created_at > DATE_SUB(NOW(), INTERVAL 1 HOUR)
);
SELECT
    'CHECK 7',
    'Failed outbox events in last hour / Sự kiện outbox thất bại trong giờ qua',
    IF(@stuck_outbox = 0, '✅ PASS', CONCAT('⚠️ WARN (', @stuck_outbox, ')')),
    @stuck_outbox;

-- ─── SUMMARY / TÓM TẮT ───────────────────────────────────────────────────────
SELECT
    CONCAT(@checks_passed, ' passed, ', @checks_failed, ' failed') AS summary,
    IF(@checks_failed = 0, '✅ ALL CHECKS PASSED', '❌ SOME CHECKS FAILED') AS overall;
