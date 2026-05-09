# Lab 01 — Deadlock Analysis / Phân Tích Bế Tắc

## Objective / Mục Tiêu

Reproduce, diagnose, and resolve a classic deadlock scenario using the `shop_db` database.
_Tái tạo, chẩn đoán và giải quyết kịch bản bế tắc điển hình sử dụng CSDL `shop_db`._

**Duration / Thời lượng**: ~45 minutes  
**Prerequisites / Điều kiện**: Stage 3 complete, MySQL running via Docker

---

## Setup / Thiết Lập

```bash
# Start MySQL / Khởi động MySQL
docker compose -f docker/docker-compose.yml up -d

# Load shop_db / Nạp shop_db
mysql -h 127.0.0.1 -P 3306 -u root -psecret < sample-db/shop_db/schema.sql
mysql -h 127.0.0.1 -P 3306 -u root -psecret < sample-db/shop_db/seed.sql

# Execute setup script / Thực thi script thiết lập
mysql -h 127.0.0.1 -P 3306 -u root -psecret shop_db < labs/lab-01-deadlock-analysis/setup.sql
```

---

## Step 1: Understand the Scenario / Hiểu Kịch Bản

Two concurrent processes both try to:
_Hai tiến trình đồng thời đều cố gắng:_

1. Confirm an order (update `orders`)
2. Create a payment (update `payments`)

But in **opposite order**, causing a deadlock.
_Nhưng theo **thứ tự ngược nhau**, gây bế tắc._

```
Process A (Order #1):          Process B (Order #2):
LOCK orders(1)                 LOCK orders(2)
LOCK payments(?)  ← WAIT      LOCK payments(?)  ← WAIT
on orders(2)                   on orders(1)
          ↑                           ↑
          └──────── DEADLOCK ─────────┘
```

---

## Step 2: Reproduce the Deadlock / Tái Tạo Bế Tắc

**Open two MySQL sessions** (in separate terminals):
_**Mở hai phiên MySQL** (trong terminals riêng):_

### Session A:
```sql
-- Terminal 1 / Terminal 1
USE shop_db;
START TRANSACTION;
UPDATE orders SET status = 'processing' WHERE id = 1;
-- PAUSE here — don't commit yet / TẠM DỪNG — chưa commit
```

### Session B:
```sql
-- Terminal 2 / Terminal 2
USE shop_db;
START TRANSACTION;
UPDATE orders SET status = 'processing' WHERE id = 2;
UPDATE payments SET status = 'completed' WHERE order_id = 1;
-- This will WAIT for Session A / Sẽ CHỜ Session A
```

### Back to Session A:
```sql
-- Terminal 1 — this creates the deadlock!
UPDATE payments SET status = 'completed' WHERE order_id = 2;
-- ERROR 1213: Deadlock found!
```

---

## Step 3: Investigate / Điều Tra

```sql
-- Check last deadlock / Kiểm tra bế tắc cuối
SHOW ENGINE INNODB STATUS\G

-- Find the "LATEST DETECTED DEADLOCK" section
-- Locate:
--   "TRANSACTION" blocks — which queries were involved?
--   "HOLDS THE LOCK(S)" — what each transaction was holding
--   "WAITING FOR THIS LOCK" — what each was waiting for
--   "WE ROLL BACK TRANSACTION" — which was the victim
```

### Questions / Câu Hỏi

1. Which transaction was rolled back? Why? / Giao dịch nào bị rollback? Tại sao?
2. What indexes were involved in the locking? / Chỉ mục nào liên quan đến locking?
3. How long did the deadlock take to detect? / Mất bao lâu để phát hiện bế tắc?

---

## Step 4: Fix the Deadlock / Sửa Bế Tắc

```sql
-- FIX: Always lock orders then payments in the same order
-- SỬA: Luôn lock orders rồi mới payments theo cùng thứ tự

-- Process A (corrected) / Quy trình A (đã sửa)
START TRANSACTION;
SELECT id FROM orders  WHERE id = 1 FOR UPDATE;   -- lock order first
SELECT id FROM payments WHERE order_id = 1 FOR UPDATE; -- then payment
UPDATE orders SET status = 'processing' WHERE id = 1;
UPDATE payments SET status = 'completed' WHERE order_id = 1;
COMMIT;

-- Process B (corrected) / Quy trình B (đã sửa)
START TRANSACTION;
SELECT id FROM orders  WHERE id = 2 FOR UPDATE;   -- same order!
SELECT id FROM payments WHERE order_id = 2 FOR UPDATE;
UPDATE orders SET status = 'processing' WHERE id = 2;
UPDATE payments SET status = 'completed' WHERE order_id = 2;
COMMIT;
```

---

## Step 5: Verify Fix / Xác Minh Sửa Lỗi

Run both sessions simultaneously with the corrected code — no deadlock should occur.
_Chạy cả hai phiên đồng thời với code đã sửa — không có bế tắc nên xảy ra._

```sql
-- Confirm orders updated / Xác nhận đơn hàng đã cập nhật
SELECT id, status FROM orders WHERE id IN (1, 2);
-- Both should show 'processing' / Cả hai nên hiển thị 'processing'
```

---

## Bonus: Monitor Lock Waits / Thêm: Giám Sát Chờ Lock

```sql
-- Real-time lock monitoring / Giám sát lock theo thời gian thực
SELECT
    r.trx_id AS waiting,
    r.trx_query AS waiting_query,
    b.trx_id AS blocking,
    b.trx_query AS blocking_query
FROM performance_schema.data_lock_waits w
JOIN information_schema.INNODB_TRX r ON r.trx_id = w.REQUESTING_ENGINE_TRANSACTION_ID
JOIN information_schema.INNODB_TRX b ON b.trx_id = w.BLOCKING_ENGINE_TRANSACTION_ID;
```

---

## Solution / Giải Pháp

See [solution.md](solution.md) for the full analysis and explanation.
_Xem solution.md để có phân tích và giải thích đầy đủ._
