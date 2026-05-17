# Lab 01 — Solution: Deadlock Analysis / Giải Pháp: Phân Tích Bế Tắc

---

## Root Cause Analysis / Phân Tích Nguyên Nhân Gốc

### Why the Deadlock Occurred / Tại Sao Bế Tắc Xảy Ra

The deadlock was caused by **inconsistent lock acquisition order** between two concurrent transactions.
_Bế tắc xảy ra do **thứ tự khóa không nhất quán** giữa hai giao dịch đồng thời._

| Transaction A | Transaction B |
|---------------|---------------|
| LOCK `orders(1)` ✅ | LOCK `orders(2)` ✅ |
| WAIT `orders(2)` ⏳ | WAIT `orders(1)` ⏳ |
| ← **DEADLOCK** → | ← **DEADLOCK** → |

InnoDB detected the cycle and rolled back the **lower-cost transaction** (Transaction B in most cases).
_InnoDB phát hiện vòng lặp và rollback **giao dịch có chi phí thấp hơn** (thường là Transaction B)._

---

## Reading `SHOW ENGINE INNODB STATUS` / Đọc Output Diagnose

```
LATEST DETECTED DEADLOCK
-------------------------
*** (1) TRANSACTION:
TRANSACTION ..., ACTIVE ... sec starting index read
MySQL thread id ..., query id ... localhost root
UPDATE payments SET status = 'completed' WHERE order_id = 2
*** (1) HOLDS THE LOCK(S):
RECORD LOCKS space id ... page no ... n bits ... index PRIMARY
of table `shop_db`.`orders` trx id ... lock_mode X locks rec but not gap
*** (1) WAITING FOR THIS LOCK TO BE GRANTED:
RECORD LOCKS ... table `shop_db`.`orders` ... lock_mode X locks rec but not gap

*** (2) TRANSACTION:
...
*** WE ROLL BACK TRANSACTION (2)
```

**Key fields to identify / Các trường quan trọng:**
- `HOLDS THE LOCK(S)` — what each transaction already locked
- `WAITING FOR THIS LOCK` — what it's blocked on
- `WE ROLL BACK TRANSACTION (N)` — MySQL's victim choice

---

## Fix Applied / Giải Pháp Đã Áp Dụng

### Principle: Consistent Lock Ordering / Nguyên Tắc: Thứ Tự Khóa Nhất Quán

Always acquire locks in the **same global order** across all transactions.
_Luôn khóa theo **cùng một thứ tự toàn cục** trong tất cả giao dịch._

```sql
-- WRONG ❌ — different lock order
-- Transaction A: orders → payments
-- Transaction B: payments → orders  ← causes deadlock

-- CORRECT ✅ — same lock order always
-- Transaction A: orders → payments
-- Transaction B: orders → payments  ← safe
```

### Additional Defenses / Phòng Vệ Bổ Sung

```sql
-- 1. Set reasonable lock wait timeout / Đặt timeout chờ khóa hợp lý
SET innodb_lock_wait_timeout = 5;

-- 2. Use SELECT ... FOR UPDATE to pre-declare intent
-- Sử dụng SELECT ... FOR UPDATE để khai báo trước
SELECT id FROM orders WHERE id = ? FOR UPDATE;
SELECT id FROM payments WHERE order_id = ? FOR UPDATE;

-- 3. Monitor deadlock frequency / Giám sát tần suất bế tắc
SHOW GLOBAL STATUS LIKE 'Innodb_deadlocks';
```

---

## Prevention Checklist / Danh Sách Phòng Ngừa

- [x] Consistent lock acquisition order across all code paths
- [x] Keep transactions short — commit as early as possible
- [x] Use `innodb_lock_wait_timeout` appropriate for workload
- [x] Add retry logic in application code for `Error 1213`
- [x] Monitor `Innodb_deadlocks` counter in Prometheus
- [x] Review `SHOW ENGINE INNODB STATUS` regularly in production

---

## Application-Level Retry / Retry Ở Tầng Ứng Dụng

```python
import pymysql
import time

def execute_with_retry(conn, fn, max_retries=3):
    """Retry transaction on deadlock (Error 1213)"""
    for attempt in range(max_retries):
        try:
            return fn(conn)
        except pymysql.err.OperationalError as e:
            if e.args[0] == 1213 and attempt < max_retries - 1:
                time.sleep(0.1 * (attempt + 1))  # exponential backoff
                conn.rollback()
                continue
            raise
```

---

_Back to [Lab 01 README](README.md)_
