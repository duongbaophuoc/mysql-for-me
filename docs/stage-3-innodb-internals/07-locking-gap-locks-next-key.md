# Locking: Gap Locks & Next-Key Locks / Gap Lock & Next-Key Lock

## Overview / Tổng Quan

InnoDB has several lock types beyond basic row locks. Understanding them is key to diagnosing deadlocks and lock waits.
_InnoDB có nhiều loại lock ngoài lock hàng cơ bản. Hiểu chúng là chìa khóa để chẩn đoán deadlock và chờ lock._

---

## Lock Types / Các Loại Lock

```
Record Lock:        Locks a specific index record / Khóa bản ghi index cụ thể
Gap Lock:           Locks a gap before a record (no record locked) / Khóa khoảng trống trước bản ghi
Next-Key Lock:      Record Lock + Gap Lock = "lock this record and the gap before it"
Insert Intention:   Signals intent to insert in a gap
```

---

## Record Locks / Khóa Bản Ghi

```sql
-- Explicit record lock / Khóa bản ghi tường minh
SELECT * FROM orders WHERE id = 100 FOR UPDATE;
-- Locks exactly row id=100 / Khóa chính xác hàng id=100
-- Other transactions can still INSERT id=99 or id=101
-- Giao dịch khác vẫn có thể INSERT id=99 hoặc id=101
```

---

## Gap Locks / Khóa Khoảng Trống

```sql
-- REPEATABLE READ with a range query acquires Gap Locks
-- REPEATABLE READ với truy vấn phạm vi lấy Gap Lock

-- If orders has IDs: 1, 5, 10, 15, 20
-- Range query: / Truy vấn phạm vi:
SELECT * FROM orders WHERE id BETWEEN 6 AND 14 FOR UPDATE;

-- Gap locks prevent: / Gap lock ngăn:
--   INSERT id=7,8,9,10,11,12,13  ← all in the gap (6–14)
-- This prevents PHANTOM READS / Ngăn đọc phantom
-- But increases lock contention! / Nhưng tăng tranh chấp lock!
```

---

## Next-Key Locks / Khóa Next-Key

```sql
-- Default lock in REPEATABLE READ for range predicates
-- Lock mặc định trong REPEATABLE READ cho mệnh đề phạm vi
-- Next-Key Lock = Gap before record + Record itself

-- Example with IDs [1, 5, 10]:
-- Scanning WHERE id > 3 AND id < 8 acquires:
--   Next-key lock on (3, 5]: gap before 5 + record 5
--   Gap lock on (5, 10): gap before 10 (no record at 8)
```

---

## How to Reduce Gap Lock Contention / Giảm Tranh Chấp Gap Lock

```sql
-- Switch to READ COMMITTED (no gap locks!)
-- Chuyển sang READ COMMITTED (không có gap lock!)
SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;

-- Use exact PK lookups / Dùng tra cứu PK chính xác
SELECT * FROM orders WHERE id = 100 FOR UPDATE;  -- record lock only

-- Avoid: range queries under REPEATABLE READ
-- Tránh: truy vấn phạm vi trong REPEATABLE READ
-- SELECT * FROM orders WHERE created_at > '2024-01-01' FOR UPDATE;  -- gap locks!
```

---

## INSERT Intention Locks / Khóa Ý Định Chèn

```sql
-- When inserting, InnoDB places an INSERT INTENTION lock on the gap
-- Khi chèn, InnoDB đặt lock INSERT INTENTION lên khoảng trống
-- Multiple inserts into the same gap don't block each other
-- Nhiều lần chèn vào cùng khoảng trống không chặn nhau

-- But IF another transaction holds a GAP lock on that range:
-- Nhưng NẾU giao dịch khác giữ GAP lock trên phạm vi đó:
-- The INSERT INTENTION lock must wait → potential deadlock
-- INSERT INTENTION lock phải chờ → deadlock tiềm ẩn
```

---

## Diagnosing Lock Issues / Chẩn Đoán Vấn Đề Lock

```sql
-- See current locks held / Xem lock đang giữ
SELECT ENGINE_LOCK_ID, ENGINE_TRANSACTION_ID,
       LOCK_TYPE, LOCK_MODE, LOCK_STATUS,
       LOCK_DATA
FROM performance_schema.data_locks;

-- LOCK_MODE values:
-- S (shared), X (exclusive), IS, IX (intention shared/exclusive)
-- GAP (gap lock), REC_NOT_GAP (record only), NEXT_KEY
```
