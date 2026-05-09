# Redo Log & WAL / Nhật Ký Làm Lại & WAL

## Overview / Tổng Quan

The **Redo Log** (Write-Ahead Log / WAL) is InnoDB's crash recovery mechanism.
_**Redo Log** (WAL) là cơ chế phục hồi sự cố của InnoDB._

**Key guarantee**: Committed transactions are recoverable even if MySQL crashes before dirty pages are flushed to disk.
_**Đảm bảo chính**: Giao dịch đã commit có thể khôi phục ngay cả khi MySQL crash trước khi trang bẩn được flush lên đĩa._

---

## Write-Ahead Logging (WAL) Protocol / Giao Thức WAL

```
Transaction COMMIT sequence / Trình tự COMMIT giao dịch:

1. Write changes to Buffer Pool (in-memory) / Ghi thay đổi vào Buffer Pool
2. Write redo log entry to log buffer / Ghi mục redo log vào log buffer
3. Flush log buffer to redo log files on disk / Flush log buffer lên file redo log
   ← THIS IS THE DURABLE COMMIT / ĐÂY LÀ COMMIT BỀN VỮNG
4. Return "commit OK" to application / Trả về "commit OK" cho ứng dụng
5. (Later) Flush dirty pages from Buffer Pool to .ibd files
   (Sau này) Flush trang bẩn từ Buffer Pool về file .ibd
```

---

## Key Configuration / Cấu Hình Quan Trọng

```ini
[mysqld]
# innodb_flush_log_at_trx_commit controls durability / Kiểm soát độ bền vững

# 1 (default, SAFEST): flush to disk on every COMMIT
# 1 (mặc định, AN TOÀN NHẤT): flush lên đĩa mỗi COMMIT
innodb_flush_log_at_trx_commit = 1

# 2 (faster, slight risk): write to OS cache on COMMIT, flush every second
# 2 (nhanh hơn, rủi ro nhỏ): ghi vào OS cache, flush mỗi giây
# Risk: up to 1 second of data loss on OS crash
innodb_flush_log_at_trx_commit = 2

# 0 (fastest, risky): write to log buffer, flush every second
# 0 (nhanh nhất, nguy hiểm): ghi vào log buffer, flush mỗi giây
# Risk: up to 1 second of data loss on MySQL crash
innodb_flush_log_at_trx_commit = 0

# Redo log file size (MySQL 8.0.30+: auto-managed)
# MySQL < 8.0.30:
innodb_log_file_size      = 512M
innodb_log_files_in_group = 2
```

---

## Checkpoint & Fuzzy Checkpoint / Checkpoint

```sql
-- Force a manual checkpoint / Buộc checkpoint thủ công
SET GLOBAL innodb_fast_shutdown = 0;  -- clean shutdown flushes all dirty pages

-- Check checkpoint age / Kiểm tra tuổi checkpoint (from SHOW ENGINE INNODB STATUS)
SHOW ENGINE INNODB STATUS\G
-- Look for / Tìm:
-- Log sequence number     (LSN): current write position
-- Log flushed up to:            what's been written to disk
-- Last checkpoint at:           what's been fully flushed to data files
-- Pages flushed up to:         dirty page flush progress
```

---

## Redo Log Impact on Performance / Tác Động Redo Log Đến Hiệu Năng

```
Larger redo log ✅ Less checkpoint pressure → fewer write stalls
                ❌ Longer crash recovery time

Smaller redo log ✅ Faster crash recovery
                 ❌ More frequent checkpoints → write stalls

MySQL 8.0.30+: innodb_redo_log_capacity (replaces log_file_size)
Example: 8G for production / 8G cho production
SET GLOBAL innodb_redo_log_capacity = 8589934592;  -- 8GB
```

---

## Relationship: Redo Log vs Binary Log

```
Redo Log             │  Binary Log
─────────────────────┼──────────────────────────
InnoDB specific      │  MySQL server level
Physical changes     │  Logical operations
Crash recovery       │  Replication, PITR
Always on            │  Optional (enable log-bin)
```

> **Both** must be written for a transaction to be durable AND replicable.
> Both use the **2-phase commit (XA)** protocol internally.
