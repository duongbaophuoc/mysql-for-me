# Multi-Region MySQL Deployment / Triển Khai MySQL Đa Vùng

## Overview / Tổng Quan

Multi-region MySQL distributes data across geographically separated data centers to achieve:
_MySQL đa vùng phân phối dữ liệu qua các trung tâm dữ liệu tách biệt về mặt địa lý để đạt được:_

- **Low latency** for users in different regions / Độ trễ thấp cho người dùng ở vùng khác nhau
- **Disaster recovery** if an entire region fails / Khôi phục thảm họa nếu toàn bộ vùng lỗi
- **Data residency** compliance (GDPR, etc.) / Tuân thủ lưu trú dữ liệu

---

## Architecture Patterns / Mẫu Kiến Trúc

### Active-Passive (Single Primary) / Thụ Động (Primary Đơn)

```
Region A (VN - Primary) ──binlog──► Region B (SG - Passive Replica)
Region A (VN - Primary) ──binlog──► Region C (US - Passive Replica)

Reads: from local region replica / Đọc từ replica vùng địa phương
Writes: always go to Region A / Ghi luôn đến Vùng A

Failover: promote Region B to primary if Region A fails
Chuyển đổi: thăng cấp Vùng B thành primary nếu Vùng A lỗi
```

### Active-Active (Multi-Primary) / Chủ Động Đôi (Multi-Primary)

```
Region A ◄─────────────────────────► Region B
         bidirectional replication     (conflict resolution needed!)
         sao chép hai chiều            (cần giải quyết xung đột!)

Problem: same row updated in both regions simultaneously
→ Conflict! Which write wins?
→ Xung đột! Lần ghi nào thắng?
```

**Active-active is extremely hard** — avoid unless specifically required.
_**Chủ động đôi cực kỳ khó** — tránh trừ khi cần thiết cụ thể._

---

## Setting Up Cross-Region Replication / Thiết Lập Sao Chép Liên Vùng

```sql
-- On primary (Region A) / Trên primary (Vùng A)
-- Ensure binlog is enabled and GTID is on
-- Đảm bảo binlog bật và GTID bật

-- On cross-region replica (Region B) / Trên replica liên vùng (Vùng B)
CHANGE REPLICATION SOURCE TO
    SOURCE_HOST = 'mysql-primary.region-vn.internal',
    SOURCE_PORT = 3306,
    SOURCE_USER = 'replicator',
    SOURCE_PASSWORD = 'repl_password',
    SOURCE_AUTO_POSITION = 1,
    -- SSL for cross-region security / SSL cho bảo mật liên vùng
    SOURCE_SSL = 1,
    SOURCE_SSL_CA   = '/etc/mysql/ssl/ca.pem',
    SOURCE_SSL_CERT = '/etc/mysql/ssl/client-cert.pem',
    SOURCE_SSL_KEY  = '/etc/mysql/ssl/client-key.pem',
    -- Tune for high-latency network / Điều chỉnh cho mạng độ trễ cao
    SOURCE_CONNECT_RETRY = 10,
    SOURCE_RETRY_COUNT   = 3,
    SOURCE_HEARTBEAT_PERIOD = 30;

START REPLICA;
```

---

## Network Considerations / Cân Nhắc Mạng

```ini
[mysqld]
# For high-latency cross-region links / Cho kết nối liên vùng độ trễ cao
slave_net_timeout         = 60     # wait 60s before reconnect / chờ 60s trước khi kết nối lại
replica_compressed_protocol = ON   # compress binlog traffic / nén lưu lượng binlog

# On primary: tune binlog format for efficiency
binlog_row_image = MINIMAL  # only changed columns, not full row
                             # chỉ cột thay đổi, không phải toàn hàng
```

---

## Data Sharding by Region / Phân Mảnh Dữ Liệu Theo Vùng

```sql
-- Instead of replicating everything, shard data by region
-- Thay vì sao chép mọi thứ, phân mảnh dữ liệu theo vùng

CREATE TABLE customers (
    id        BIGINT UNSIGNED NOT NULL,
    region    ENUM('VN','SG','US') NOT NULL,
    ...
    PRIMARY KEY (id, region)
);

-- Vietnamese customers live in Region A MySQL
-- Khách hàng Việt Nam ở MySQL Vùng A
-- Singapore customers live in Region B MySQL
-- Khách hàng Singapore ở MySQL Vùng B

-- Cross-region queries go through a federated view or API
-- Truy vấn liên vùng qua view liên kết hoặc API
```

---

## ProxySQL for Multi-Region Routing / ProxySQL Cho Định Tuyến Đa Vùng

```sql
-- Route reads to local region replica / Định tuyến đọc đến replica vùng địa phương
INSERT INTO mysql_servers (hostgroup_id, hostname, port, max_latency_ms) VALUES
    (10, 'mysql-primary.vn', 3306, 0),    -- writes: always primary
    (20, 'mysql-replica.vn', 3306, 5),    -- reads: prefer VN (< 5ms)
    (20, 'mysql-replica.sg', 3306, 50),   -- reads: SG fallback (< 50ms)
    (20, 'mysql-replica.us', 3306, 200);  -- reads: US last resort

-- ProxySQL picks the lowest-latency replica automatically
-- ProxySQL tự động chọn replica có độ trễ thấp nhất
```

---

## Monitoring Cross-Region Lag / Giám Sát Độ Trễ Liên Vùng

```sql
-- Cross-region lag is expected to be higher than local / Độ trễ liên vùng cao hơn local
-- VN → SG: 30-50ms RTT → expect ~1s lag under normal load
-- VN → US: 200-300ms RTT → expect ~5-10s lag

SHOW REPLICA STATUS\G
-- Seconds_Behind_Source: 3  ← acceptable for cross-region
-- Seconds_Behind_Source: 60 ← investigate! / điều tra!
```
