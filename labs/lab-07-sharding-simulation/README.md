# Lab 07 — Sharding Simulation / Mô Phỏng Phân Mảnh

## Objective / Mục Tiêu

Simulate a customer-based sharding strategy using MySQL's table partitioning and ProxySQL routing.
_Mô phỏng chiến lược sharding dựa trên khách hàng sử dụng phân vùng bảng MySQL và định tuyến ProxySQL._

**Duration / Thời lượng**: ~75 minutes

---

## Sharding Strategies / Chiến Lược Phân Mảnh

| Strategy | Description | Use Case |
|----------|-------------|----------|
| **Range** | shard_id < 1000 → Shard 1 | Time-series, geographic |
| **Hash** | customer_id % N → Shard | Even distribution |
| **Directory** | Lookup table: customer → shard | Flexible, complex data |
| **Consistent Hash** | Hash ring with virtual nodes | Auto-rebalancing |

We'll simulate **Range Sharding** on `customer_id`.
_Chúng ta sẽ mô phỏng **Range Sharding** trên `customer_id`._

---

## Setup / Thiết Lập

```bash
docker compose -f docker/docker-compose.yml up -d

mysql -h 127.0.0.1 -P 3306 -u root -psecret < labs/lab-07-sharding-simulation/setup.sql
```

---

## Step 1: Create Sharded Tables / Tạo Bảng Phân Mảnh

```sql
-- Simulating 3 logical shards using MySQL PARTITIONING
-- Mô phỏng 3 shard logic sử dụng PARTITIONING MySQL

CREATE TABLE orders_sharded (
    id          BIGINT UNSIGNED  NOT NULL,
    customer_id BIGINT UNSIGNED  NOT NULL,
    status      VARCHAR(20)      NOT NULL,
    total_amount DECIMAL(14,2)   NOT NULL,
    created_at  DATETIME(3)      NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    PRIMARY KEY (id, customer_id)  -- customer_id in PK for partition pruning
) ENGINE=InnoDB
PARTITION BY RANGE (customer_id) (
    PARTITION shard_0   VALUES LESS THAN (1000),      -- Customers 1–999
    PARTITION shard_1   VALUES LESS THAN (2000),      -- Customers 1000–1999
    PARTITION shard_2   VALUES LESS THAN (3000),      -- Customers 2000–2999
    PARTITION shard_future VALUES LESS THAN MAXVALUE  -- Future growth
);
```

---

## Step 2: Simulate Cross-Shard Query / Mô Phỏng Truy Vấn Liên Shard

```sql
-- Single-shard query (FAST — partition pruning)
-- Truy vấn một shard (NHANH — cắt tỉa phân vùng)
EXPLAIN SELECT * FROM orders_sharded
WHERE customer_id = 500              -- hits shard_0 only
  AND status = 'pending';
-- partitions: shard_0

-- Cross-shard query (SLOWER — must query all partitions)
-- Truy vấn liên shard (CHẬM HƠN — phải dùng tất cả phân vùng)
EXPLAIN SELECT * FROM orders_sharded
WHERE status = 'pending';           -- no customer_id filter
-- partitions: shard_0, shard_1, shard_2, shard_future
```

---

## Step 3: The Cross-Shard Problem / Vấn Đề Truy Vấn Liên Shard

```sql
-- Problem: Aggregations across shards / Vấn đề: Tổng hợp liên shard
-- In real sharding (separate servers), this requires:
-- Trong sharding thực (server riêng), điều này đòi hỏi:
-- 1. Query each shard independently / Truy vấn từng shard riêng
-- 2. Aggregate in application memory / Tổng hợp trong bộ nhớ ứng dụng

-- Example: Total revenue across 3 shards
-- Ví dụ: Tổng doanh thu từ 3 shard

-- Shard 0 results / Kết quả shard 0:
SELECT SUM(total_amount) FROM orders_sharded PARTITION (shard_0)
WHERE status = 'delivered';

-- Shard 1 results / Kết quả shard 1:
SELECT SUM(total_amount) FROM orders_sharded PARTITION (shard_1)
WHERE status = 'delivered';

-- Application must aggregate the three results!
-- Ứng dụng phải tổng hợp ba kết quả!
```

---

## Step 4: Shard Rebalancing Problem / Vấn Đề Cân Bằng Lại Shard

```sql
-- What happens when shard_0 grows too large?
-- Điều gì xảy ra khi shard_0 quá lớn?

-- Problem: All customer_id < 1000 in one partition
-- Vấn đề: Tất cả customer_id < 1000 trong một phân vùng

-- Option: ADD PARTITION (only works if current MAXVALUE partition exists)
-- Tùy chọn: THÊM phân vùng

ALTER TABLE orders_sharded
REORGANIZE PARTITION shard_future INTO (
    PARTITION shard_3 VALUES LESS THAN (4000),
    PARTITION shard_future VALUES LESS THAN MAXVALUE
);

-- This requires data movement! Use gh-ost or pt-online-schema-change
-- Điều này đòi hỏi di chuyển dữ liệu! Dùng gh-ost hoặc pt-osc
```

---

## Design Takeaways / Bài Học Thiết Kế

1. **Choose shard key carefully** — it must be in every hot query / **Chọn shard key cẩn thận** — nó phải có trong mọi truy vấn nóng
2. **Avoid cross-shard transactions** — no 2PC across MySQL servers / **Tránh giao dịch liên shard**
3. **Vitess** manages all of this transparently — see Stage 5 docs / **Vitess** quản lý tất cả điều này trong suốt
4. **Partition by customer_id is not the same as network sharding** / **Phân vùng theo customer_id không giống network sharding**
