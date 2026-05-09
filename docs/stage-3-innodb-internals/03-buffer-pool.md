# Buffer Pool / Bể Đệm

## Overview / Tổng Quan

The **InnoDB buffer pool** is the most important memory structure in MySQL. It caches data pages (16KB each) and index pages in RAM to avoid disk reads.
_**Buffer pool InnoDB** là cấu trúc bộ nhớ quan trọng nhất trong MySQL. Nó cache trang dữ liệu (16KB mỗi trang) và trang index trong RAM để tránh đọc đĩa._

---

## How the Buffer Pool Works / Cách Buffer Pool Hoạt Động

```
Query: SELECT * FROM orders WHERE id = 123

Step 1 / Bước 1: Check buffer pool / Kiểm tra buffer pool
  → Page found in RAM? → Return immediately (~0.01ms)
  → Page found in RAM? → Trả lại ngay (~0.01ms)

Step 2 / Bước 2: Page not in pool → Read from disk
  → Disk read: 1-10ms (SSD) or 5-20ms (HDD)
  → Load page into buffer pool for future access
  → Đọc đĩa: 1-10ms (SSD) hoặc 5-20ms (HDD)
  → Nạp trang vào buffer pool cho truy cập tương lai
```

---

## Buffer Pool Sizing / Kích Thước Buffer Pool

```ini
# Rule of thumb: 50-70% of available RAM
# Quy tắc kinh nghiệm: 50-70% RAM khả dụng
[mysqld]
innodb_buffer_pool_size = 8G    # For a 16GB RAM server / Server 16GB RAM

# Multiple instances (for multi-core systems with >1GB pool)
# Nhiều instance (cho hệ thống multi-core với pool >1GB)
innodb_buffer_pool_instances = 8  # One per 1GB of pool size
```

---

## Monitoring Buffer Pool / Giám Sát Buffer Pool

```sql
-- Buffer pool hit rate / Tỷ lệ hit buffer pool
SELECT
    ROUND(
        (1 - innodb_buffer_pool_reads /
            innodb_buffer_pool_read_requests) * 100, 4
    ) AS hit_rate_pct,
    innodb_buffer_pool_reads          AS disk_reads,
    innodb_buffer_pool_read_requests  AS total_reads,
    innodb_buffer_pool_pages_total    AS total_pages,
    innodb_buffer_pool_pages_free     AS free_pages,
    innodb_buffer_pool_pages_dirty    AS dirty_pages
FROM (
    SELECT
        VARIABLE_VALUE AS v, VARIABLE_NAME AS n
    FROM performance_schema.global_status
    WHERE VARIABLE_NAME IN (
        'Innodb_buffer_pool_reads',
        'Innodb_buffer_pool_read_requests',
        'Innodb_buffer_pool_pages_total',
        'Innodb_buffer_pool_pages_free',
        'Innodb_buffer_pool_pages_dirty'
    )
) stats
PIVOT ...;

-- Quick check via SHOW STATUS / Kiểm tra nhanh qua SHOW STATUS
SHOW STATUS LIKE 'Innodb_buffer_pool%';
-- Target: Innodb_buffer_pool_reads / Innodb_buffer_pool_read_requests < 0.01
-- (less than 1% disk reads) / (ít hơn 1% đọc đĩa)
```

---

## LRU List & Dirty Page Management / Danh Sách LRU & Quản Lý Trang Bẩn

```
Buffer Pool internal structure / Cấu trúc nội bộ:

┌─────────────────────────────────────────────┐
│  Buffer Pool                                 │
│                                             │
│  New Sublist (5/8 of pool)                  │
│  ─────────────────────────                  │
│  [recently accessed pages]    ← hot pages   │
│                                             │
│  Old Sublist (3/8 of pool)                  │
│  ─────────────────────────                  │
│  [older pages] → evicted when pool is full  │
│                                             │
│  Flush List: dirty pages awaiting write-back│
└─────────────────────────────────────────────┘
```

---

## Warming the Buffer Pool / Làm Nóng Buffer Pool

After a restart, the buffer pool is cold (empty). Slow for the first hours.
_Sau khi khởi động lại, buffer pool lạnh (rỗng). Chậm trong vài giờ đầu._

```ini
# Save & restore buffer pool state on restart / Lưu & khôi phục trạng thái khi khởi động
innodb_buffer_pool_dump_at_shutdown = ON
innodb_buffer_pool_load_at_startup  = ON
innodb_buffer_pool_dump_pct = 100  # Save 100% of pages (adjust for large pools)
```
