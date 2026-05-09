# Idempotency / Tính Mãn Đẳng

## Overview / Tổng Quan

An operation is **idempotent** if performing it multiple times has the same effect as performing it once.
_Một thao tác là **mãn đẳng** nếu thực hiện nhiều lần có cùng kết quả như thực hiện một lần._

**Why it matters**: Networks fail, users double-click, retries happen. Idempotency prevents duplicate orders, double charges, and data corruption.
_**Tại sao quan trọng**: Mạng thất bại, người dùng bấm đúp, retry xảy ra. Tính mãn đẳng ngăn đơn hàng trùng lặp và lỗi dữ liệu._

---

## The Problem / Vấn Đề

```
Timeline without idempotency / Dòng thời gian không có mãn đẳng:

1. Client sends POST /orders (200ms)
2. Server processes, inserts order — SUCCESS
3. Network times out before client receives response
4. Client retries POST /orders
5. Server processes AGAIN — DUPLICATE ORDER!
```

---

## Solution: Idempotency Keys / Giải Pháp: Khóa Mãn Đẳng

```sql
-- Idempotency keys table / Bảng khóa mãn đẳng
CREATE TABLE idempotency_keys (
    idempotency_key  VARCHAR(128)    NOT NULL,
    user_id          BIGINT UNSIGNED NOT NULL,
    endpoint         VARCHAR(255)    NOT NULL,
    request_hash     VARCHAR(64)     NOT NULL,  -- SHA256 of request body
    response_code    SMALLINT        NOT NULL,
    response_body    JSON            NULL,
    created_at       DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    expires_at       DATETIME(3)     NOT NULL,
    PRIMARY KEY (idempotency_key),
    KEY idx_expires (expires_at)     -- for cleanup / để dọn dẹp
) ENGINE=InnoDB;
```

### Application Logic / Logic Ứng Dụng

```python
async def create_order(request, idempotency_key: str):
    # Step 1: Check if we've seen this key before / Bước 1: Kiểm tra xem đã thấy key chưa
    existing = await db.query_one(
        """SELECT response_code, response_body
           FROM idempotency_keys
           WHERE idempotency_key = %s AND user_id = %s
           AND expires_at > NOW()""",
        (idempotency_key, request.user_id)
    )
    if existing:
        # Return cached response / Trả về response đã cache
        return Response(
            status=existing.response_code,
            body=existing.response_body,
            headers={"X-Idempotency-Replayed": "true"}
        )

    # Step 2: Process the request / Bước 2: Xử lý request
    try:
        order = await orders_service.create(request.body)
        response = {"order_id": order.id, "status": "created"}
        status_code = 201
    except Exception as e:
        response = {"error": str(e)}
        status_code = 422

    # Step 3: Store result for future replay / Bước 3: Lưu kết quả để phát lại
    await db.execute(
        """INSERT INTO idempotency_keys
           (idempotency_key, user_id, endpoint, request_hash, response_code, response_body, expires_at)
           VALUES (%s, %s, %s, %s, %s, %s, DATE_ADD(NOW(), INTERVAL 24 HOUR))
           ON DUPLICATE KEY UPDATE response_code = response_code""",  # Don't overwrite!
        (idempotency_key, request.user_id, "/orders",
         sha256(request.body), status_code, json.dumps(response))
    )

    return Response(status=status_code, body=response)
```

---

## Database-Level Idempotency / Mãn Đẳng Cấp CSDL

```sql
-- Use INSERT ... ON DUPLICATE KEY for upserts / Dùng INSERT...ON DUPLICATE KEY
INSERT INTO inventory (product_id, warehouse_code, quantity_available)
VALUES (5, 'WH-HN-01', 100)
ON DUPLICATE KEY UPDATE
    quantity_available = quantity_available + VALUES(quantity_available);
-- Safe to retry! / An toàn để retry!

-- Use unique constraint to prevent duplicate orders / Constraint unique ngăn đơn hàng trùng
ALTER TABLE orders ADD UNIQUE KEY uq_idempotency (customer_id, idempotency_key);

INSERT INTO orders (customer_id, idempotency_key, total_amount, status)
VALUES (5, 'idem-key-abc123', 500000, 'pending')
ON DUPLICATE KEY UPDATE id = id;  -- no-op on duplicate / không làm gì khi trùng
```

---

## HTTP Idempotency Methods / Tính Mãn Đẳng HTTP

| Method | Idempotent? | Safe? |
|--------|------------|-------|
| GET | ✅ | ✅ |
| PUT | ✅ | ❌ |
| DELETE | ✅ | ❌ |
| POST | ❌ (needs key) | ❌ |
| PATCH | ❌ (needs care) | ❌ |
