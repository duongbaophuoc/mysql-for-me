# Group Replication & InnoDB Cluster / Group Replication & InnoDB Cluster

## Overview / Tổng Quan

MySQL Group Replication provides **multi-primary** or **single-primary** automatic failover with strong consistency guarantees.
_Group Replication MySQL cung cấp failover tự động **multi-primary** hoặc **single-primary** với đảm bảo nhất quán mạnh._

**InnoDB Cluster** = Group Replication + MySQL Router + MySQL Shell admin tools.
_**InnoDB Cluster** = Group Replication + MySQL Router + công cụ admin MySQL Shell._

---

## Architecture / Kiến Trúc

```
Single-Primary Mode / Chế Độ Single-Primary:
   ┌─────────────┐
   │  Primary    │ ← writes
   └──────┬──────┘
          │ Group Replication (consensus protocol)
     ┌────┴────┐
     │Secondary│  │Secondary│  ← reads + auto-promote on primary failure
     └─────────┘  └─────────┘

Multi-Primary Mode / Chế Độ Multi-Primary:
   All nodes accept writes (conflict detection ensures consistency)
   Tất cả node nhận ghi (phát hiện xung đột đảm bảo nhất quán)
```

---

## Setup with MySQL Shell / Thiết Lập Với MySQL Shell

```bash
# Connect with MySQL Shell / Kết nối với MySQL Shell
mysqlsh root:secret@localhost:3306

# Check requirements / Kiểm tra yêu cầu
dba.checkInstanceConfiguration('root:secret@localhost:3306')

# Create the cluster / Tạo cluster
cluster = dba.createCluster('shopCluster')

# Add instances / Thêm instance
cluster.addInstance('root:secret@mysql-replica1:3306')
cluster.addInstance('root:secret@mysql-replica2:3306')

# Check cluster status / Kiểm tra trạng thái cluster
cluster.status()
```

---

## Cluster Status Output / Kết Quả Trạng Thái Cluster

```json
{
  "clusterName": "shopCluster",
  "status": "OK",
  "topology": {
    "mysql-primary": {
      "mode": "R/W",
      "status": "ONLINE",
      "role": "PRIMARY"
    },
    "mysql-replica1": {
      "mode": "R/O",
      "status": "ONLINE",
      "role": "SECONDARY"
    },
    "mysql-replica2": {
      "mode": "R/O",
      "status": "ONLINE",
      "role": "SECONDARY"
    }
  }
}
```

---

## Automatic Failover / Tự Động Chuyển Đổi Dự Phòng

```bash
# Simulate primary failure / Mô phỏng primary lỗi
docker stop mysql-primary

# Within seconds, MySQL Shell detects failure
# Trong vài giây, MySQL Shell phát hiện lỗi
# and elects a new primary via consensus
# và bầu primary mới qua đồng thuận

cluster.status()
# mysql-replica1 is now PRIMARY!
# mysql-replica1 bây giờ là PRIMARY!
```

---

## vs Standard Replication / vs Sao Chép Chuẩn

| Feature | Async Replication | Group Replication |
|---------|------------------|------------------|
| Automatic failover | ❌ Manual | ✅ Automatic |
| Consistency | Eventual | Strong (majority) |
| Write scaling | Single primary | Multi-primary possible |
| Complexity | Low | Medium |
| Overhead | Low | Higher (consensus) |
| Best for | Read scaling | HA requirements |
