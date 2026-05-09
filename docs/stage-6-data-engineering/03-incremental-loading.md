# Incremental Data Loading / Nạp Dữ Liệu Gia Tăng

## Overview / Tổng Quan

Instead of reloading all data every night (**full refresh**), incremental loading only processes **new or changed rows** since the last run.
_Thay vì tải lại tất cả dữ liệu mỗi đêm, nạp gia tăng chỉ xử lý **hàng mới hoặc đã thay đổi** kể từ lần chạy trước._

---

## Strategies / Chiến Lược

### Timestamp-Based / Dựa Trên Timestamp

```sql
-- Watermark table to track last run / Bảng watermark để theo dõi lần chạy cuối
CREATE TABLE etl_watermarks (
    pipeline_name VARCHAR(100) NOT NULL PRIMARY KEY,
    last_processed DATETIME(3) NOT NULL
);

-- ETL query: only fetch updated records / Chỉ lấy bản ghi cập nhật
SELECT *
FROM shop_db.orders
WHERE updated_at > (
    SELECT last_processed
    FROM analytics_dw.etl_watermarks
    WHERE pipeline_name = 'orders_to_fact_sales'
);

-- After successful load, update watermark / Sau khi nạp thành công, cập nhật watermark
UPDATE analytics_dw.etl_watermarks
SET last_processed = NOW()
WHERE pipeline_name = 'orders_to_fact_sales';
```

### GTID-Based (Most Reliable) / Dựa Trên GTID (Đáng Tin Nhất)

```sql
-- Store last processed GTID set / Lưu GTID set đã xử lý
UPDATE etl_watermarks
SET last_gtid = (SELECT @@GLOBAL.gtid_executed FROM source_db)
WHERE pipeline_name = 'orders_cdc';
-- Next run: only replay binlogs from last_gtid
-- Lần chạy tiếp: chỉ phát lại binlog từ last_gtid
```

---

## Upsert Strategy / Chiến Lược Upsert

```sql
-- INSERT new rows, UPDATE changed rows (UPSERT pattern)
-- Chèn hàng mới, cập nhật hàng thay đổi
INSERT INTO analytics_dw.fact_sales (
    order_nk, date_key, customer_sk, gross_revenue, net_revenue, dw_inserted_at
)
SELECT
    o.id,
    DATE_FORMAT(o.created_at, '%Y%m%d'),
    dc.customer_sk,
    o.total_amount,
    o.total_amount - o.discount_amount,
    NOW()
FROM shop_db.orders o
JOIN analytics_dw.dim_customer dc ON dc.customer_nk = o.customer_id AND dc.is_current = 1
WHERE o.updated_at > :last_watermark
ON DUPLICATE KEY UPDATE
    gross_revenue  = VALUES(gross_revenue),
    net_revenue    = VALUES(net_revenue),
    dw_inserted_at = NOW();
```

---

## Partition Pruning for Large Tables / Cắt Tỉa Phân Vùng Cho Bảng Lớn

```sql
-- fact_sales is partitioned by date_key / fact_sales được phân vùng theo date_key
-- Incremental loads only touch recent partitions
-- Nạp gia tăng chỉ chạm vào phân vùng gần đây

-- Query optimizer will only scan today's partition / Bộ tối ưu chỉ quét phân vùng hôm nay
INSERT INTO fact_sales ...
WHERE date_key = DATE_FORMAT(CURDATE(), '%Y%m%d');
-- InnoDB skips all historical partitions! / InnoDB bỏ qua tất cả phân vùng lịch sử!
```

---

## Handling Late-Arriving Data / Xử Lý Dữ Liệu Đến Muộn

```sql
-- Orders confirmed late (e.g., status updated 3 days after creation)
-- Đơn hàng xác nhận muộn (status cập nhật 3 ngày sau khi tạo)

-- Look back 3 days to catch late updates / Nhìn lại 3 ngày để bắt cập nhật muộn
WHERE o.updated_at > DATE_SUB(:last_watermark, INTERVAL 3 DAY)
-- This may re-insert some rows, so UPSERT (ON DUPLICATE KEY) is essential
-- Có thể chèn lại một số hàng, vì vậy UPSERT là cần thiết
```

---

## dbt Incremental Models / Model Gia Tăng dbt

```sql
-- Already covered in 05-dbt.md
-- Đã đề cập trong 05-dbt.md
{{ config(materialized='incremental', unique_key='order_nk') }}

SELECT ... FROM {{ ref('stg_orders') }}

{% if is_incremental() %}
WHERE updated_at > (SELECT MAX(updated_at) FROM {{ this }})
{% endif %}
```
