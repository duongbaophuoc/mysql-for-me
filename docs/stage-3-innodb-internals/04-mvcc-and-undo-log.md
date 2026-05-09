# MVCC & Undo Log / MVCC & Nhật Ký Hoàn Tác

## Overview / Tổng Quan

**MVCC (Multi-Version Concurrency Control)** is how InnoDB allows multiple transactions to read and write concurrently without blocking each other.
_**MVCC** là cách InnoDB cho phép nhiều giao dịch đọc và ghi đồng thời mà không chặn nhau._

---

## The Core Idea / Ý Tưởng Cốt Lõi

Instead of locking rows for reads, InnoDB keeps **multiple versions** of each row.
_Thay vì khóa hàng để đọc, InnoDB giữ **nhiều phiên bản** của mỗi hàng._

```
Timeline / Dòng thời gian:

T=1: Transaction A starts (snapshot = T1)
T=2: Transaction B UPDATES order #5 price: 100 → 200
T=3: Transaction A reads order #5 → still sees 100! (its snapshot)
T=4: Transaction B COMMITS
T=5: Transaction A reads order #5 → still sees 100! (repeatable read)
T=6: Transaction A COMMITS
T=7: New transaction C reads order #5 → sees 200 (latest)
```

---

## How the Undo Log Works / Cách Undo Log Hoạt Động

```
Current row in clustered index / Hàng hiện tại trong clustered index:
┌──────────────────────────────────────────────────────┐
│ id=5 | price=200 | trx_id=T2 | roll_ptr ──────────┐  │
└──────────────────────────────────────────────────────┘
                                                     │
                                        ┌────────────▼──────────────────┐
                               Undo Log │ id=5 | price=100 | trx_id=T1  │
                                        └───────────────────────────────┘

Transaction A (started at T1) follows roll_ptr to find
the historical version: price=100
Giao dịch A (bắt đầu tại T1) theo roll_ptr để tìm phiên bản lịch sử
```

---

## Read View / Chế Độ Xem Đọc

When a transaction starts, InnoDB creates a **Read View** — a snapshot of active transactions at that moment.
_Khi giao dịch bắt đầu, InnoDB tạo **Read View** — snapshot giao dịch đang hoạt động tại thời điểm đó._

```sql
-- Each row has two hidden system columns / Mỗi hàng có 2 cột hệ thống ẩn:
-- DB_TRX_ID: transaction ID that last modified the row
-- DB_ROLL_PTR: pointer to undo log entry

-- A transaction can see a row if: / Giao dịch có thể thấy hàng nếu:
-- 1. DB_TRX_ID < min_active_trx_id (committed before snapshot)
-- 2. DB_TRX_ID = current_trx_id (my own changes)
-- Otherwise, follow DB_ROLL_PTR to find a visible version
```

---

## Isolation Levels and MVCC / Cấp Độ Cô Lập và MVCC

```sql
-- READ COMMITTED: New read view for each statement
-- Đọc đã cam kết: Read view mới cho mỗi câu lệnh
SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;

-- REPEATABLE READ (default): Read view created at START TRANSACTION
-- Đọc lặp lại (mặc định): Read view tạo khi START TRANSACTION
SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;

-- Check current isolation level / Kiểm tra cấp độ cô lập hiện tại
SELECT @@transaction_isolation;
```

---

## History List Length — The MVCC Pressure Gauge
## Độ Dài History List — Đồng Hồ Áp Lực MVCC

```sql
-- Check History List Length (HLL) / Kiểm tra độ dài History List
SELECT NAME, COUNT
FROM information_schema.INNODB_METRICS
WHERE NAME = 'trx_rseg_history_len';

-- Also visible in SHOW ENGINE INNODB STATUS / Cũng thấy trong SHOW ENGINE INNODB STATUS
SHOW ENGINE INNODB STATUS\G
-- Look for: "History list length 12345"
-- Normal: < 1000 / Bình thường: < 1000
-- Warning: > 10,000 / Cảnh báo: > 10,000
-- Critical: > 100,000 — purge thread can't keep up! / Purge thread không theo kịp!
```

### What Causes High HLL? / Nguyên Nhân HLL Cao?

```sql
-- Long-running read transactions prevent undo purge!
-- Giao dịch đọc chạy lâu ngăn dọn dẹp undo!

-- Find long-running transactions / Tìm giao dịch chạy lâu:
SELECT
    trx_id,
    trx_state,
    trx_started,
    TIMESTAMPDIFF(SECOND, trx_started, NOW()) AS age_seconds,
    trx_query
FROM information_schema.INNODB_TRX
ORDER BY trx_started ASC;

-- Anything over 60 seconds is dangerous in production
-- Bất cứ thứ gì quá 60 giây là nguy hiểm trong production
```

---

## MVCC and Phantom Reads / MVCC và Đọc Phantom

```sql
-- REPEATABLE READ prevents phantom reads via Gap Locks
-- Đọc lặp lại ngăn đọc phantom qua Gap Lock

START TRANSACTION;
SELECT * FROM orders WHERE total > 1000;   -- sees 50 rows

-- Another transaction inserts order with total=5000 and commits
-- Giao dịch khác chèn đơn hàng total=5000 và commit

SELECT * FROM orders WHERE total > 1000;   -- STILL sees 50 rows!
-- Phantom read prevented by Gap Lock / Đọc phantom bị ngăn bởi Gap Lock
COMMIT;
```
