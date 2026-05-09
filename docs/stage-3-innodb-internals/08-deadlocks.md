# Deadlocks / Bế Tắc

## Overview / Tổng Quan

A deadlock occurs when two or more transactions permanently block each other by each holding a lock the other needs.
_Bế tắc xảy ra khi hai hoặc nhiều giao dịch chặn nhau vĩnh viễn vì mỗi giao dịch giữ lock mà giao dịch kia cần._

InnoDB automatically detects deadlocks and rolls back the **cheaper** transaction (the victim).
_InnoDB tự động phát hiện bế tắc và rollback giao dịch **rẻ hơn** (nạn nhân)._

---

## Classic Deadlock Pattern / Mẫu Bế Tắc Điển Hình

```sql
-- Session A / Phiên A                    -- Session B / Phiên B
START TRANSACTION;                        START TRANSACTION;

UPDATE orders                             UPDATE payments
SET status = 'processing'                 SET status = 'completed'
WHERE id = 100;                           WHERE id = 200;
-- A holds lock on order 100             -- B holds lock on payment 200

UPDATE payments                           UPDATE orders
SET status = 'completed'                  SET status = 'delivered'
WHERE id = 200;                           WHERE id = 100;
-- A WAITS for payment 200               -- B WAITS for order 100
-- (B holds it)                          -- (A holds it)

-- DEADLOCK! InnoDB kills one transaction / BẾ TẮC! InnoDB giết một giao dịch
-- ERROR 1213: Deadlock found when trying to get lock
```

---

## Diagnosing Deadlocks / Chẩn Đoán Bế Tắc

```sql
-- Last deadlock information / Thông tin bế tắc cuối
SHOW ENGINE INNODB STATUS\G

-- Look for this section / Tìm phần này:
-- ------------------------
-- LATEST DETECTED DEADLOCK
-- ------------------------
-- Shows: / Hiển thị:
-- Transaction 1: what it was doing, what lock it holds, what it waits for
-- Transaction 2: same
-- Which transaction was chosen as victim / Giao dịch nào được chọn làm nạn nhân
```

```sql
-- Enable deadlock logging in error log / Bật ghi log bế tắc vào error log
SET GLOBAL innodb_print_all_deadlocks = ON;

-- Monitor lock waits in real-time / Giám sát chờ lock theo thời gian thực
SELECT
    r.trx_id            AS waiting_trx,
    r.trx_query         AS waiting_query,
    b.trx_id            AS blocking_trx,
    b.trx_query         AS blocking_query,
    l.lock_table,
    l.lock_index
FROM information_schema.INNODB_LOCK_WAITS w
JOIN information_schema.INNODB_TRX        r ON r.trx_id = w.requesting_trx_id
JOIN information_schema.INNODB_TRX        b ON b.trx_id = w.blocking_trx_id
JOIN information_schema.INNODB_LOCKS      l ON l.lock_id = w.requested_lock_id;
```

---

## Prevention Strategies / Chiến Lược Phòng Ngừa

### 1. Always lock in the same order / Luôn lock theo cùng thứ tự

```sql
-- BAD: inconsistent order / Tệ: thứ tự không nhất quán
-- T1: locks orders(100) then payments(200)
-- T2: locks payments(200) then orders(100) → DEADLOCK!

-- GOOD: always: orders first, then payments / Tốt: luôn: orders trước, payments sau
-- T1: locks orders(100) then payments(200)
-- T2: locks orders(100) — waits → then payments(200) → NO deadlock
```

### 2. Keep transactions short / Giữ giao dịch ngắn

```sql
-- BAD: long transaction / Tệ: giao dịch dài
START TRANSACTION;
  -- ... 10 UPDATEs ...
  -- ... application logic ...
  -- ... HTTP call ... ← locks held during HTTP!
COMMIT;

-- GOOD: minimal lock time / Tốt: thời gian lock tối thiểu
-- Do all prep work BEFORE the transaction
-- Thực hiện mọi công việc chuẩn bị TRƯỚC giao dịch
START TRANSACTION;
  UPDATE orders SET status = 'processing' WHERE id = :id;
  INSERT INTO payments (...) VALUES (...);
COMMIT;
-- Transaction < 10ms / Giao dịch < 10ms
```

### 3. Use SELECT FOR UPDATE carefully / Dùng SELECT FOR UPDATE cẩn thận

```sql
-- Acquire locks in the right order / Lấy lock theo thứ tự đúng
START TRANSACTION;

-- Lock the order first / Lock đơn hàng trước
SELECT id FROM orders WHERE id = 100 FOR UPDATE;
-- Lock the payment / Sau đó lock thanh toán
SELECT id FROM payments WHERE order_id = 100 FOR UPDATE;

UPDATE orders SET status = 'processing' WHERE id = 100;
UPDATE payments SET status = 'completed' WHERE order_id = 100;
COMMIT;
```

### 4. Use lower isolation level where appropriate
_Dùng cấp cô lập thấp hơn khi phù hợp_

```sql
-- READ COMMITTED reduces gap locking → fewer deadlocks
-- READ COMMITTED giảm gap lock → ít bế tắc hơn
SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;
```

---

## Application-Level Retry / Thử Lại Cấp Ứng Dụng

```python
import time
import random
from sqlalchemy.exc import OperationalError

def execute_with_deadlock_retry(session, operation, max_retries=3):
    """Retry on deadlock with exponential backoff"""
    for attempt in range(max_retries):
        try:
            result = operation(session)
            session.commit()
            return result
        except OperationalError as e:
            session.rollback()
            if '1213' in str(e) and attempt < max_retries - 1:
                # Deadlock — wait and retry / Bế tắc — chờ và thử lại
                wait = (2 ** attempt) + random.uniform(0, 0.1)
                time.sleep(wait)
                continue
            raise
```

---

## Summary / Tóm Tắt

| Strategy | Effectiveness | Complexity |
|----------|--------------|------------|
| Consistent lock ordering | ⭐⭐⭐⭐⭐ | Low |
| Short transactions | ⭐⭐⭐⭐⭐ | Low |
| Retry on deadlock | ⭐⭐⭐⭐ | Medium |
| READ COMMITTED isolation | ⭐⭐⭐ | Low |
| Reduce transaction scope | ⭐⭐⭐⭐ | Medium |
