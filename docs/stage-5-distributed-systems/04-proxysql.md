# ProxySQL / ProxySQL

## Overview / Tổng Quan

**ProxySQL** is a high-performance MySQL proxy that provides:
_**ProxySQL** là MySQL proxy hiệu năng cao cung cấp:_

- Read/write splitting / Phân tách đọc/ghi
- Connection pooling / Gộp kết nối
- Query routing / Định tuyến truy vấn
- Query rewriting / Viết lại truy vấn
- Failover handling / Xử lý failover
- Connection multiplexing / Ghép kênh kết nối

---

## Quick Setup / Thiết Lập Nhanh

```bash
# ProxySQL is already in docker-compose.yml
# ProxySQL đã có trong docker-compose.yml
docker compose -f docker/docker-compose.yml up -d

# Connect to ProxySQL admin interface / Kết nối giao diện admin
mysql -h 127.0.0.1 -P 6032 -u admin -padmin
```

---

## Core Configuration / Cấu Hình Cốt Lõi

```sql
-- 1. Define MySQL servers / Định nghĩa MySQL server
INSERT INTO mysql_servers (hostgroup_id, hostname, port, weight) VALUES
    (10, 'mysql-primary',  3306, 1000),   -- HG10: writes
    (20, 'mysql-replica1', 3306, 1000),   -- HG20: reads
    (20, 'mysql-replica2', 3306, 1000);

-- 2. Create DB user / Tạo user DB
INSERT INTO mysql_users (username, password, default_hostgroup) VALUES
    ('app_user', 'secret', 10);   -- default to write HG

-- 3. Query routing rules / Quy tắc định tuyến truy vấn
INSERT INTO mysql_query_rules (rule_id, active, match_pattern, destination_hostgroup, apply) VALUES
    (1, 1, '^SELECT.*FOR UPDATE', 10, 1),  -- SELECT FOR UPDATE → primary
    (2, 1, '^SELECT',             20, 1);  -- all other SELECTs → replicas

-- 4. Apply and persist / Áp dụng và lưu
LOAD MYSQL SERVERS TO RUNTIME;
LOAD MYSQL USERS TO RUNTIME;
LOAD MYSQL QUERY RULES TO RUNTIME;
SAVE MYSQL SERVERS TO DISK;
SAVE MYSQL USERS TO DISK;
SAVE MYSQL QUERY RULES TO DISK;
```

---

## Connection Multiplexing / Ghép Kênh Kết Nối

```
Without ProxySQL / Không ProxySQL:
  1000 app threads × 1 connection each = 1000 MySQL connections
  1000 thread × 1 kết nối = 1000 kết nối MySQL

With ProxySQL / Có ProxySQL:
  1000 app threads → ProxySQL (multiplexes) → 100 MySQL connections
  70% fewer connections to MySQL! / Ít hơn 70% kết nối MySQL!
```

---

## Monitoring ProxySQL / Giám Sát ProxySQL

```sql
-- Query stats / Thống kê truy vấn
SELECT hostgroup, sum_time/1000000 AS sum_time_ms,
       count_star AS queries,
       digest_text AS query
FROM stats_mysql_query_digest
ORDER BY sum_time DESC LIMIT 10;

-- Connection pool stats / Thống kê pool kết nối
SELECT * FROM stats_mysql_connection_pool;

-- Server health / Sức khỏe server
SELECT hostgroup_id, hostname, port, status, Queries
FROM stats_mysql_processlist;
```

---

## Query Rewriting / Viết Lại Truy Vấn

```sql
-- Rewrite a slow query at proxy level / Viết lại truy vấn chậm ở cấp proxy
INSERT INTO mysql_query_rules (rule_id, active, match_pattern, replace_pattern) VALUES
    (10, 1,
     'SELECT \* FROM products WHERE category = (\S+)',
     'SELECT id, name, price FROM products USE INDEX (idx_category) WHERE category = \1'
    );
```
