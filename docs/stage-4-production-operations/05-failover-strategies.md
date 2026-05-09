# Failover Strategies / Chiến Lược Chuyển Đổi Dự Phòng

## Overview / Tổng Quan

Failover is the process of switching from a failed **primary** to a **replica** to restore write capability.
_Failover là quá trình chuyển từ **primary** lỗi sang **replica** để khôi phục khả năng ghi._

**RTO (Recovery Time Objective)**: How long can you tolerate downtime?
_**RTO**: Bạn chịu được mất bao lâu?_

**RPO (Recovery Point Objective)**: How much data loss can you tolerate?
_**RPO**: Bạn chấp nhận mất bao nhiêu dữ liệu?_

---

## Failover Tiers / Cấp Độ Failover

| Tool/Method | RTO | RPO | Complexity | Auto? |
|------------|-----|-----|------------|-------|
| Manual failover | 5–30 min | Seconds | Low | ❌ |
| Orchestrator | 30–60 sec | Seconds | Medium | ✅ |
| InnoDB Cluster | < 10 sec | 0 (sync) | Medium | ✅ |
| ProxySQL reconnect | Transparent | Same as above | Low | ✅ |

---

## Manual Failover Procedure / Quy Trình Failover Thủ Công

See: [`replication/failover-procedure.md`](../../replication/failover-procedure.md) for the complete runbook.
_Xem: `replication/failover-procedure.md` để biết runbook đầy đủ._

### Quick Reference / Tham Chiếu Nhanh

```bash
# 1. Find most up-to-date replica / Tìm replica cập nhật nhất
mysql -h REPLICA -e "SELECT @@gtid_executed" | wc -c
# Higher = more GTIDs = more up-to-date / Cao hơn = nhiều GTID hơn = cập nhật hơn

# 2. Promote it / Thăng cấp
mysql -h NEW_PRIMARY -e "STOP REPLICA; RESET REPLICA ALL; SET GLOBAL read_only=OFF;"

# 3. Point other replicas to new primary / Chỉ replica khác đến primary mới
mysql -h OTHER_REPLICA -e "
  CHANGE REPLICATION SOURCE TO SOURCE_HOST='NEW_PRIMARY', SOURCE_AUTO_POSITION=1;
  START REPLICA;"
```

---

## Orchestrator — Automated Failover / Failover Tự Động

```bash
# Install and configure / Cài đặt và cấu hình
# orchestrator discovers topology via INFORMATION_SCHEMA queries
# orchestrator khám phá topology qua truy vấn INFORMATION_SCHEMA

# Check topology / Kiểm tra topology
orchestrator-client -c topology -i MASTER_HOST

# Trigger graceful failover / Kích hoạt failover thuận tiện
orchestrator-client -c graceful-master-takeover -i MASTER_HOST -d CANDIDATE_REPLICA

# Recovery (after crash) / Phục hồi (sau crash)
orchestrator-client -c recover -i FAILED_MASTER_HOST
```

---

## ProxySQL — Transparent Reconnect / Kết Nối Lại Trong Suốt

```sql
-- Configure health check / Cấu hình kiểm tra sức khỏe
UPDATE global_variables SET variable_value = 1000
WHERE variable_name = 'mysql-monitor_ping_interval';

UPDATE global_variables SET variable_value = 5000
WHERE variable_name = 'mysql-monitor_connect_timeout';

-- ProxySQL automatically routes around failed nodes
-- ProxySQL tự động định tuyến xung quanh node lỗi
```

---

## Read-After-Write During Failover / Đọc Sau Ghi Trong Failover

During failover, there's a window where reads may be stale:
_Trong failover, có khoảng thời gian đọc có thể cũ:_

```python
# Application strategy: route reads to new primary temporarily
# Chiến lược ứng dụng: định tuyến đọc đến primary mới tạm thời
DURING_FAILOVER_SECONDS = 30

def get_connection_for_read():
    if time.time() - last_failover_time < DURING_FAILOVER_SECONDS:
        return primary_connection  # safe reads during recovery
    return replica_connection      # normal operation
```
