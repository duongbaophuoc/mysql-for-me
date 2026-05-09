-- =============================================================================
-- Lab 07: Sharding Simulation — Setup & Queries
-- Lab 07: Mô Phỏng Phân Mảnh — Thiết Lập & Truy Vấn
-- =============================================================================

-- =============================================================================
-- SETUP: Create 3 shard databases / Tạo 3 CSDL shard
-- Run on the same MySQL instance (simulating separate shards)
-- Chạy trên cùng MySQL instance (mô phỏng các shard riêng biệt)
-- =============================================================================

CREATE DATABASE IF NOT EXISTS shard_0;  -- customer_id % 3 = 0
CREATE DATABASE IF NOT EXISTS shard_1;  -- customer_id % 3 = 1
CREATE DATABASE IF NOT EXISTS shard_2;  -- customer_id % 3 = 2

-- Create identical schema on each shard / Tạo schema giống hệt trên mỗi shard
CREATE TABLE IF NOT EXISTS shard_0.orders LIKE shop_db.orders;
CREATE TABLE IF NOT EXISTS shard_1.orders LIKE shop_db.orders;
CREATE TABLE IF NOT EXISTS shard_2.orders LIKE shop_db.orders;

-- =============================================================================
-- POPULATE: Route existing orders to shards based on customer_id % 3
-- Định tuyến đơn hàng hiện có đến shard dựa trên customer_id % 3
-- =============================================================================

-- Shard 0: customers 0, 3, 6, ... / Khách hàng 0, 3, 6, ...
INSERT INTO shard_0.orders
SELECT * FROM shop_db.orders WHERE customer_id % 3 = 0;

-- Shard 1: customers 1, 4, 7, ...
INSERT INTO shard_1.orders
SELECT * FROM shop_db.orders WHERE customer_id % 3 = 1;

-- Shard 2: customers 2, 5, 8, ...
INSERT INTO shard_2.orders
SELECT * FROM shop_db.orders WHERE customer_id % 3 = 2;

-- Verify distribution / Xác minh phân phối
SELECT 'shard_0' AS shard, COUNT(*) AS orders FROM shard_0.orders
UNION ALL
SELECT 'shard_1',          COUNT(*)            FROM shard_1.orders
UNION ALL
SELECT 'shard_2',          COUNT(*)            FROM shard_2.orders;

-- =============================================================================
-- EXERCISE 1: Single-shard query (with shard key)
-- Truy vấn một shard (có shard key)  — FAST / NHANH
-- =============================================================================

-- customer_id=5  → 5 % 3 = 2 → query shard_2
EXPLAIN
SELECT id, total_amount, status
FROM shard_2.orders
WHERE customer_id = 5
ORDER BY created_at DESC;
-- type=ref (index lookup) — excellent! / Tuyệt vời!

-- =============================================================================
-- EXERCISE 2: Cross-shard aggregation (no shard key)
-- Tổng hợp liên shard (không có shard key) — SLOW / CHẬM
-- Application must merge results from all 3 shards:
-- Ứng dụng phải gộp kết quả từ cả 3 shard:
-- =============================================================================

-- Simulate what application must do / Mô phỏng những gì ứng dụng phải làm
SELECT 'shard_0' AS source, COUNT(*) AS pending_orders
FROM shard_0.orders WHERE status = 'pending'   -- full scan on shard_0
UNION ALL
SELECT 'shard_1', COUNT(*)
FROM shard_1.orders WHERE status = 'pending'   -- full scan on shard_1
UNION ALL
SELECT 'shard_2', COUNT(*)
FROM shard_2.orders WHERE status = 'pending';  -- full scan on shard_2
-- 3 separate queries → application sums them
-- Vấn đề của cross-shard query!

-- =============================================================================
-- EXERCISE 3: Scatter-gather pattern
-- Mẫu Scatter-Gather
-- =============================================================================

-- Application broadcasts to all shards, collects, merges:
-- Ứng dụng phát tới mọi shard, thu thập, gộp:
/*
  shard_results = []
  for shard in [shard_0, shard_1, shard_2]:
      results = shard.query("SELECT ... WHERE status='pending' LIMIT 10")
      shard_results.extend(results)
  
  # Sort merged results
  shard_results.sort(key=lambda x: x.created_at, reverse=True)
  return shard_results[:10]  # top 10 across all shards
*/

-- =============================================================================
-- CLEANUP / DỌN DẸP
-- =============================================================================
-- DROP DATABASE IF EXISTS shard_0;
-- DROP DATABASE IF EXISTS shard_1;
-- DROP DATABASE IF EXISTS shard_2;
