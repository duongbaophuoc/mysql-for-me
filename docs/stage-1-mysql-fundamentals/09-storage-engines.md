# Storage Engines / Công Cụ Lưu Trữ

## Overview / Tổng Quan

MySQL supports pluggable storage engines — different engines store and retrieve data differently.
_MySQL hỗ trợ storage engine có thể cắm vào — các engine khác nhau lưu trữ và truy xuất dữ liệu khác nhau._

**In production, always use InnoDB unless you have a very specific reason not to.**
_**Trong production, luôn dùng InnoDB trừ khi có lý do rất cụ thể để không dùng.**_

---

## Engine Comparison / So Sánh Engine

| Feature | InnoDB | MyISAM | MEMORY | ARCHIVE |
|---------|--------|--------|--------|---------|
| Transactions | ✅ ACID | ❌ | ❌ | ❌ |
| Foreign Keys | ✅ | ❌ | ❌ | ❌ |
| Row-level Locking | ✅ | ❌ (table) | ✅ | ❌ |
| MVCC | ✅ | ❌ | ❌ | ❌ |
| Crash Recovery | ✅ WAL | ❌ | ❌ | ❌ |
| Full-text Index | ✅ (5.6+) | ✅ | ❌ | ❌ |
| Compression | ✅ | ✅ | ❌ | ✅ |
| Data survives restart | ✅ | ✅ | ❌ | ✅ |
| Use case | Everything | Legacy | Cache | Write-once logs |

---

## InnoDB — The Default / Mặc Định

InnoDB is the default and recommended engine for all MySQL 5.5+ tables.
_InnoDB là engine mặc định và được khuyến nghị cho tất cả bảng MySQL 5.5+._

### Key Features / Tính Năng Chính

```sql
-- Create InnoDB table (default in MySQL 8.0) / Tạo bảng InnoDB (mặc định)
CREATE TABLE orders (
    id          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    customer_id BIGINT UNSIGNED NOT NULL,
    total       DECIMAL(14,2)   NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (customer_id) REFERENCES customers(id)
) ENGINE=InnoDB;  -- This is implied if not specified / Mặc định nếu không chỉ định
```

### How InnoDB Stores Data / Cách InnoDB Lưu Trữ Dữ Liệu

```
.ibd file (one per table in MySQL 8.0+)
├── Data segment (B+ tree pages, 16KB each)
│   └── Clustered on PRIMARY KEY
├── Index segment (secondary index B+ trees)
└── Rollback segment (undo log pages for MVCC)
```

```sql
-- Check InnoDB status / Kiểm tra trạng thái InnoDB
SHOW ENGINE INNODB STATUS\G

-- Table file location / Vị trí file bảng
SHOW VARIABLES LIKE 'innodb_data_home_dir';
-- /var/lib/mysql/ → shop_db/orders.ibd
```

---

## MyISAM — Legacy Engine

MyISAM was the default before MySQL 5.5. Avoid it in new designs.
_MyISAM là mặc định trước MySQL 5.5. Tránh dùng trong thiết kế mới._

```sql
CREATE TABLE search_cache (
    id      INT NOT NULL AUTO_INCREMENT,
    keyword VARCHAR(200),
    result  TEXT,
    PRIMARY KEY (id),
    FULLTEXT (keyword)   -- MyISAM full-text search
) ENGINE=MyISAM;         -- Replaced by InnoDB FULLTEXT in 5.6+
```

### Why MyISAM Fails Production / Tại Sao MyISAM Thất Bại Trong Production

```sql
-- MyISAM uses table-level locking / MyISAM dùng lock cấp bảng
-- This means: while one thread is writing, ALL reads are blocked!
-- Nghĩa là: khi một thread đang ghi, TẤT CẢ đọc bị chặn!

-- Concurrent writes are serialized / Ghi đồng thời bị nối tiếp hóa
-- Fatal for high-concurrency applications / Gây chết người cho ứng dụng cao đồng thời
```

---

## MEMORY Engine — In-Memory Tables

```sql
-- Store session data, lookup tables, temporary aggregates
-- Lưu dữ liệu phiên, bảng tra cứu, tổng hợp tạm thời
CREATE TABLE rate_limit_cache (
    ip_address  VARCHAR(45) NOT NULL,
    request_count INT       NOT NULL DEFAULT 0,
    window_start  DATETIME  NOT NULL,
    PRIMARY KEY (ip_address)
) ENGINE=MEMORY;

-- ⚠️ Data is lost on MySQL restart / Dữ liệu mất khi MySQL khởi động lại
-- ⚠️ Table size limited by max_heap_table_size variable
-- ⚠️ No BLOB/TEXT columns supported
```

---

## ARCHIVE Engine — Compressed Historical Data

```sql
-- Suited for write-once, read-rarely logs / Phù hợp cho log ghi một lần, đọc hiếm
CREATE TABLE access_log_archive (
    id         BIGINT NOT NULL AUTO_INCREMENT,
    timestamp  DATETIME NOT NULL,
    ip         VARCHAR(45),
    path       VARCHAR(500),
    status     SMALLINT,
    PRIMARY KEY (id)
) ENGINE=ARCHIVE;

-- ~75% compression vs InnoDB / ~75% nén so với InnoDB
-- INSERT only — no UPDATE/DELETE / Chỉ INSERT — không UPDATE/DELETE
```

---

## Checking Table Engines / Kiểm Tra Engine Bảng

```sql
-- Check engine for all tables in shop_db / Kiểm tra engine tất cả bảng
SELECT
    table_name,
    engine,
    table_rows,
    ROUND(data_length / 1024 / 1024, 2) AS data_mb,
    ROUND(index_length / 1024 / 1024, 2) AS index_mb
FROM information_schema.TABLES
WHERE table_schema = 'shop_db'
ORDER BY data_length DESC;

-- Convert a table to InnoDB / Chuyển đổi bảng sang InnoDB
ALTER TABLE old_myisam_table ENGINE=InnoDB;
-- ⚠️ This locks the table! Use gh-ost for production tables
-- ⚠️ Lệnh này lock bảng! Dùng gh-ost cho bảng production
```

---

## Decision Guide / Hướng Dẫn Quyết Định

```
Need ACID transactions?    → InnoDB (always)
Need foreign keys?         → InnoDB (always)
High-concurrency writes?   → InnoDB (always)
Temporary session cache?   → MEMORY or Redis
Log archival (write-once)? → ARCHIVE or partitioned InnoDB
Full-text search?          → InnoDB (MySQL 5.6+) or Elasticsearch
```
