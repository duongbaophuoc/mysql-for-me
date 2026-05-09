# Deadlock Diagnosis & Resolution / Chẩn Đoán & Giải Quyết Deadlock

## Overview / Tổng Quan

A deadlock occurs when two transactions hold locks the other needs, creating a circular wait. MySQL detects this and automatically rolls back the transaction with the least undo log.
_Deadlock xảy ra khi hai giao dịch giữ lock mà bên kia cần, tạo ra vòng chờ. MySQL phát hiện điều này và tự động rollback giao dịch có undo log ít nhất._

---

## Step 1: Detect Deadlock / Phát Hiện Deadlock

```sql
-- Check if deadlocks are occurring / Kiểm tra xem deadlock có đang xảy ra
SHOW STATUS LIKE 'Innodb_deadlocks';

-- View last deadlock in InnoDB status / Xem deadlock cuối cùng
SHOW ENGINE INNODB STATUS\G
-- Look for "LATEST DETECTED DEADLOCK" section
-- Tìm phần "LATEST DETECTED DEADLOCK"

-- Enable deadlock logging / Bật ghi log deadlock
SET GLOBAL innodb_print_all_deadlocks = ON;
-- Deadlocks now appear in MySQL error log / Deadlock xuất hiện trong error log
```

---

## Step 2: Read Deadlock Output / Đọc Kết Quả Deadlock

```
LATEST DETECTED DEADLOCK
─────────────────────────────────────────────
TRANSACTION A:  (orders row 5 → wants customers row 12)
  HOLDS lock on: orders.id=5
  WAITING FOR:   customers.id=12

TRANSACTION B:  (customers row 12 → wants orders row 5)
  HOLDS lock on: customers.id=12
  WAITING FOR:   orders.id=5

→ Circular wait! MySQL kills TRANSACTION A (less undo)
→ Vòng chờ! MySQL kill TRANSACTION A (ít undo hơn)
```

---

## Step 3: Root Cause Analysis / Phân Tích Nguyên Nhân Gốc

```sql
-- Reproduce the deadlock pattern in lab / Tái tạo mẫu deadlock trong lab
-- (see labs/lab-01-deadlock-analysis/)

-- Transaction A: Order → Customer
START TRANSACTION;
UPDATE orders SET status='confirmed' WHERE id=5;      -- locks orders.5
UPDATE customers SET total_orders=total_orders+1 WHERE id=12;  -- wants customers.12
COMMIT;

-- Transaction B: Customer → Order (at the same time)
START TRANSACTION;
UPDATE customers SET last_order_at=NOW() WHERE id=12;  -- locks customers.12
UPDATE orders SET notes='processed' WHERE id=5;         -- wants orders.5
COMMIT;
-- → DEADLOCK!
```

---

## Step 4: Fix the Deadlock / Sửa Deadlock

```sql
-- Solution 1: Consistent lock ordering / Giải pháp 1: Thứ tự lock nhất quán
-- ALWAYS lock in: customers FIRST, then orders / Luôn lock theo thứ tự: customers trước, orders sau

-- Transaction A (fixed) / Giao dịch A (đã sửa):
START TRANSACTION;
UPDATE customers SET total_orders=total_orders+1 WHERE id=12;  -- lock customers first
UPDATE orders SET status='confirmed' WHERE id=5;
COMMIT;

-- Transaction B (fixed):
START TRANSACTION;
UPDATE customers SET last_order_at=NOW() WHERE id=12;  -- same order!
UPDATE orders SET notes='processed' WHERE id=5;
COMMIT;
-- No deadlock! Both wait for customers.12 → released → proceed in order

-- Solution 2: SELECT FOR UPDATE upfront / SELECT FOR UPDATE trước
START TRANSACTION;
SELECT id FROM customers WHERE id=12 FOR UPDATE;  -- acquire lock immediately
SELECT id FROM orders WHERE id=5 FOR UPDATE;      -- acquire lock immediately
-- Now do updates safely
UPDATE customers ...;
UPDATE orders ...;
COMMIT;
```

---

## Monitoring Deadlock Rate / Giám Sát Tỷ Lệ Deadlock

```promql
# Prometheus: deadlock rate / Tỷ lệ deadlock
rate(mysql_global_status_innodb_deadlocks[5m])

# Alert if > 10 deadlocks/min / Cảnh báo nếu > 10 deadlock/phút
- alert: MySQLDeadlockHigh
  expr: rate(mysql_global_status_innodb_deadlocks[1m]) > 10
  annotations:
    summary: "High deadlock rate on {{ $labels.instance }}"
```
