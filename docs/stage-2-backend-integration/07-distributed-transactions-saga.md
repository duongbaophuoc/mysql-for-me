# Distributed Transactions & Saga Pattern / Giao Dịch Phân Tán & Mẫu Saga

## Overview / Tổng Quan

In a **monolith**, ACID transactions are easy — one database, one commit. In **microservices**, data is spread across multiple services each with their own database.
_Trong **monolith**, giao dịch ACID dễ dàng — một CSDL, một commit. Trong **microservices**, dữ liệu trải rộng qua nhiều service mỗi cái có CSDL riêng._

---

## The Distributed Transaction Problem / Vấn Đề Giao Dịch Phân Tán

```
Order Service (MySQL A)    Payment Service (MySQL B)    Inventory (MySQL C)
─────────────────────────────────────────────────────────────────────────
BEGIN                      BEGIN                         BEGIN
INSERT order               CHARGE customer               RESERVE items
                                ↓
                        Network failure!
                        Mạng thất bại!

Order exists in MySQL A    Payment NOT charged           Items NOT reserved
→ Inconsistent state / Trạng thái không nhất quán!
```

**2PC (Two-Phase Commit)** solves this but is slow and MySQL doesn't support it across different services natively.
_2PC giải quyết điều này nhưng chậm và MySQL không hỗ trợ natively qua các service khác nhau._

---

## Solution: Saga Pattern / Giải Pháp: Mẫu Saga

Break a distributed transaction into a sequence of **local transactions** with **compensating transactions** for rollback.
_Chia giao dịch phân tán thành chuỗi **giao dịch cục bộ** với **giao dịch bù trừ** để rollback._

---

## Choreography Saga / Saga Biên Đạo

Each service publishes events, others react:
_Mỗi service phát sự kiện, các service khác phản ứng:_

```
Order Service                Payment Service           Inventory Service
─────────┬─────────────────────────┬────────────────────────────┬────────
         │ OrderCreated event      │                            │
         │───────────────────────►│                            │
         │                        │ PaymentProcessed event     │
         │                        │──────────────────────────►│
         │                        │                            │ reserve
         │ OrderConfirmed ◄────────────────────────────────────│
```

**Compensating transactions** on failure:
_Giao dịch bù trừ khi thất bại:_

```
PaymentFailed event → Order Service: CANCEL order
InventoryFailed event → Payment Service: REFUND payment
```

---

## Outbox Pattern for Reliable Events / Mẫu Outbox Cho Sự Kiện Đáng Tin Cậy

The **critical problem**: How to atomically write to DB AND publish an event?
_Bài toán quan trọng: Làm sao để ghi vào DB VÀ phát sự kiện đồng thời?_

```sql
-- Outbox table (already in shop_db schema) / Bảng outbox (đã có trong schema shop_db)
CREATE TABLE outbox_events (
    id           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    aggregate_id BIGINT UNSIGNED NOT NULL,     -- order_id, customer_id
    event_type   VARCHAR(100)    NOT NULL,     -- 'OrderCreated', 'PaymentProcessed'
    payload      JSON            NOT NULL,
    status       ENUM('pending','published','failed') NOT NULL DEFAULT 'pending',
    created_at   DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    PRIMARY KEY (id),
    KEY idx_pending_events (status, created_at)
);

-- Atomic: save order AND queue event / Nguyên tử: lưu đơn hàng VÀ đưa vào hàng đợi
START TRANSACTION;
    INSERT INTO orders (customer_id, total_amount, status)
    VALUES (5, 500000, 'pending');
    
    INSERT INTO outbox_events (aggregate_id, event_type, payload)
    VALUES (LAST_INSERT_ID(), 'OrderCreated',
            JSON_OBJECT('order_id', LAST_INSERT_ID(), 'customer_id', 5));
COMMIT;
-- Both succeed or both fail — no inconsistency! / Cả hai thành công hoặc thất bại
```

### Outbox Publisher / Trình Phát Outbox

```python
# Background worker: poll outbox and publish / Worker nền: poll outbox và phát
async def publish_outbox_events():
    while True:
        events = await db.query(
            """SELECT id, event_type, payload FROM outbox_events
               WHERE status = 'pending'
               ORDER BY created_at ASC LIMIT 100"""
        )
        for event in events:
            try:
                await kafka.produce(event.event_type, event.payload)
                await db.execute(
                    "UPDATE outbox_events SET status='published' WHERE id=%s",
                    event.id
                )
            except Exception:
                await db.execute(
                    "UPDATE outbox_events SET status='failed' WHERE id=%s",
                    event.id
                )
        await asyncio.sleep(1)  # Poll every second / Poll mỗi giây
```

---

## Orchestration Saga / Saga Điều Phối

A **Saga Orchestrator** centrally coordinates all steps:
_**Saga Orchestrator** điều phối tập trung tất cả bước:_

```
Saga Orchestrator
        │
        ├── Step 1: Create Order → Order Service
        │   ↓ failure → compensate: Cancel Order
        ├── Step 2: Charge Payment → Payment Service
        │   ↓ failure → compensate: Refund
        └── Step 3: Reserve Inventory → Inventory Service
            ↓ failure → compensate: Release Reservation + Refund
```

**Tools / Công cụ**: Temporal, Netflix Conductor, Apache Camel Saga
