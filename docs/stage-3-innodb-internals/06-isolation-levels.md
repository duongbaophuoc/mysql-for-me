# Isolation Levels / Cấp Độ Cô Lập

## Overview / Tổng Quan

SQL defines 4 transaction isolation levels, each trading **performance** for **data consistency**.
_SQL định nghĩa 4 cấp độ cô lập giao dịch, mỗi cấp đánh đổi **hiệu năng** với **tính nhất quán dữ liệu**._

---

## The Four Levels / Bốn Cấp Độ

| Level | Dirty Read | Non-Repeatable Read | Phantom Read | Performance |
|-------|-----------|--------------------|--------------|-----------| 
| **READ UNCOMMITTED** | ✅ possible | ✅ possible | ✅ possible | Fastest |
| **READ COMMITTED** | ❌ prevented | ✅ possible | ✅ possible | Fast |
| **REPEATABLE READ** (default) | ❌ | ❌ | ❌ (gap locks) | Medium |
| **SERIALIZABLE** | ❌ | ❌ | ❌ | Slowest |

---

## Setting Isolation Levels / Đặt Cấp Độ Cô Lập

```sql
-- Session level / Cấp phiên
SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;

-- Global level (affects new connections) / Cấp toàn cục
SET GLOBAL TRANSACTION ISOLATION LEVEL REPEATABLE READ;

-- Check current / Kiểm tra hiện tại
SELECT @@transaction_isolation;
SELECT @@global.transaction_isolation;
```

---

## READ UNCOMMITTED — Never Use in Production
## ĐỌC CHƯA CAM KẾT — Không Bao Giờ Dùng Trong Production

```sql
-- Session A: updates but hasn't committed / Phiên A: cập nhật nhưng chưa commit
START TRANSACTION;
UPDATE orders SET total_amount = 999999 WHERE id = 1;
-- no COMMIT yet!

-- Session B at READ UNCOMMITTED: sees the uncommitted change!
-- Phiên B tại READ UNCOMMITTED: thấy thay đổi chưa commit!
SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
SELECT total_amount FROM orders WHERE id = 1;
-- Returns 999999 even before commit → DIRTY READ / Trả về 999999 trước commit → ĐỌC BẨN
```

---

## READ COMMITTED — Good for Reporting
## ĐỌC ĐÃ CAM KẾT — Tốt Cho Báo Cáo

```sql
-- Session B sees only committed data / Phiên B chỉ thấy dữ liệu đã commit
SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;

START TRANSACTION;
SELECT COUNT(*) FROM orders WHERE status = 'pending';  -- returns 10

-- Session A commits: UPDATE orders SET status='confirmed' WHERE id=5;

SELECT COUNT(*) FROM orders WHERE status = 'pending';  -- returns 9 ← different!
-- NON-REPEATABLE READ: same query returns different result / ĐỌC KHÔNG NHẤT QUÁN
COMMIT;
```

**Advantage**: Reduced lock contention — uses less gap locking than REPEATABLE READ.
_**Ưu điểm**: Giảm tranh chấp lock — ít gap lock hơn REPEATABLE READ._

---

## REPEATABLE READ — InnoDB Default / Mặc Định InnoDB

```sql
-- Default isolation level / Cấp độ mặc định
SELECT @@transaction_isolation;
-- REPEATABLE-READ

START TRANSACTION;   -- Read view created here / Read view được tạo ở đây
SELECT * FROM orders WHERE status = 'pending';  -- sees snapshot at T=now

-- Even if another transaction commits changes, this transaction sees
-- the same data for the duration of the transaction
-- Dù giao dịch khác commit thay đổi, giao dịch này vẫn thấy cùng snapshot

SELECT * FROM orders WHERE status = 'pending';  -- same result! ← REPEATABLE
COMMIT;
```

**Phantom reads** are prevented by **Gap Locks**:
_Đọc phantom được ngăn bởi **Gap Lock**:_

```sql
-- Gap lock prevents INSERT in the scanned range
-- Gap lock ngăn INSERT trong phạm vi đã quét
SELECT * FROM orders WHERE total_amount BETWEEN 100 AND 200;
-- Holds a gap lock: no new orders with total 100-200 can be inserted
-- Giữ gap lock: không thể chèn đơn hàng mới với total 100-200
```

---

## SERIALIZABLE — Strictest / Nghiêm Ngặt Nhất

```sql
SET SESSION TRANSACTION ISOLATION LEVEL SERIALIZABLE;
-- Every SELECT implicitly becomes SELECT ... FOR SHARE
-- Mọi SELECT ngầm trở thành SELECT ... FOR SHARE
-- Prevents all concurrency anomalies but dramatically reduces throughput
-- Ngăn mọi bất thường đồng thời nhưng giảm thông lượng đáng kể
```

---

## InnoDB Default: REPEATABLE READ Recommendation / Khuyến Nghị

- Use **REPEATABLE READ** for OLTP (default, safe, good performance)
- Use **READ COMMITTED** for long-running reports (fewer locks, tolerates staleness)
- Avoid **READ UNCOMMITTED** and **SERIALIZABLE** in production

_Dùng **REPEATABLE READ** cho OLTP (mặc định, an toàn, hiệu năng tốt)_
_Dùng **READ COMMITTED** cho báo cáo chạy lâu (ít lock, chấp nhận cũ)_
