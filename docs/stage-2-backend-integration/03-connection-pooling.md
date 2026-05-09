# Connection Pooling / Gộp Kết Nối

## Overview / Tổng Quan

Every MySQL connection costs CPU + memory on the server. Creating a new connection for each request can take **50–200ms** — longer than the query itself.
_Mỗi kết nối MySQL tốn CPU + bộ nhớ. Tạo kết nối mới cho mỗi request có thể mất **50–200ms** — lâu hơn chính truy vấn._

**Connection pooling** reuses existing connections.
_**Gộp kết nối** tái sử dụng kết nối hiện có._

---

## Pool Sizing Formula / Công Thức Kích Thước Pool

```
Optimal pool size ≠ max_connections / Kích thước pool tối ưu ≠ max_connections

Formula / Công thức:
pool_size = (workers × avg_query_concurrent_connections) + buffer

Example / Ví dụ:
  - 4 application servers / 4 server ứng dụng
  - Each with 8 worker threads / Mỗi server 8 thread
  - Average 2 concurrent DB connections per thread
  pool_size = 4 × 8 × 2 = 64 connections total
```

---

## Python — SQLAlchemy Connection Pool

```python
from sqlalchemy import create_engine

engine = create_engine(
    "mysql+mysqlconnector://user:pass@localhost/shop_db",
    # Pool settings / Cài đặt pool
    pool_size=10,          # Persistent connections / Kết nối bền vững
    max_overflow=20,       # Extra connections under load / Kết nối thêm khi tải cao
    pool_timeout=30,       # Wait for connection / Thời gian chờ kết nối
    pool_recycle=3600,     # Recycle connections every 1hr (prevent stale) / Tái chế sau 1 giờ
    pool_pre_ping=True,    # Test connection before use / Kiểm tra trước khi dùng
)
```

---

## Node.js — mysql2 Pool

```javascript
const mysql = require('mysql2/promise');

const pool = mysql.createPool({
    host: 'localhost',
    port: 3306,
    user: 'app_user',
    password: 'secret',
    database: 'shop_db',
    // Pool settings / Cài đặt pool
    connectionLimit: 10,       // max connections / kết nối tối đa
    waitForConnections: true,  // queue requests / xếp hàng request
    queueLimit: 0,             // unlimited queue / không giới hạn hàng đợi
    connectTimeout: 10000,     // 10s connection timeout
    enableKeepAlive: true,
    keepAliveInitialDelay: 0,
});

// Always use pool (not single connection) / Luôn dùng pool
async function getOrders(status) {
    const [rows] = await pool.query(
        'SELECT id, total_amount FROM orders WHERE status = ?', [status]
    );
    return rows;
    // Connection automatically returned to pool / Kết nối tự động trả về pool
}
```

---

## ProxySQL — Database-Side Connection Pooling
## ProxySQL — Gộp Kết Nối Phía CSDL

ProxySQL sits between your application and MySQL, providing connection multiplexing:
_ProxySQL nằm giữa ứng dụng và MySQL, cung cấp ghép kênh kết nối:_

```
App (1000 connections) → ProxySQL → MySQL (50 connections)
Ứng dụng (1000 kết nối) → ProxySQL → MySQL (50 kết nối)
```

```sql
-- ProxySQL admin / Admin ProxySQL
-- Add MySQL servers / Thêm server MySQL
INSERT INTO mysql_servers (hostgroup_id, hostname, port) VALUES
    (1, 'mysql-primary', 3306),   -- hostgroup 1: writes
    (2, 'mysql-replica1', 3306),  -- hostgroup 2: reads
    (2, 'mysql-replica2', 3306);

-- Route reads to replicas, writes to primary
-- Định tuyến đọc đến replica, ghi đến primary
INSERT INTO mysql_query_rules (rule_id, active, match_pattern, destination_hostgroup)
VALUES
    (1, 1, '^SELECT', 2),   -- SELECTs → replica pool
    (2, 1, '.*',      1);   -- everything else → primary

LOAD MYSQL SERVERS TO RUNTIME;
SAVE MYSQL SERVERS TO DISK;
```

---

## Monitoring Pool Health / Giám Sát Sức Khỏe Pool

```sql
-- Check current connections / Kiểm tra kết nối hiện tại
SHOW STATUS LIKE 'Threads_connected';   -- active connections
SHOW STATUS LIKE 'Threads_running';     -- actively executing queries
SHOW STATUS LIKE 'Connection_errors%';  -- connection errors

-- Max connections ever / Kết nối tối đa từng đạt được
SHOW STATUS LIKE 'Max_used_connections';

-- Connection attempts / Số lần kết nối
SHOW STATUS LIKE 'Connections';
```

---

## Anti-Patterns / Chống Mẫu

```python
# ❌ BAD: new connection per request / Kết nối mới mỗi request
def get_order(order_id):
    conn = mysql.connect(host='localhost', ...)   # 50-200ms overhead!
    result = conn.execute('SELECT ...')
    conn.close()
    return result

# ✅ GOOD: pool at module level / Pool ở cấp module
engine = create_engine(...)   # created once at startup

def get_order(order_id):
    with engine.connect() as conn:    # borrowed from pool in ~0.1ms
        return conn.execute('SELECT ...').fetchone()
```
