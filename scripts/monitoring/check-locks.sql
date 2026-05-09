-- =============================================================================
-- Lock & Blocking Query Diagnostic Script
-- Script Chẩn Đoán Lock & Truy Vấn Đang Bị Chặn
-- =============================================================================

-- 1. Show all actively blocking transactions / Hiển thị giao dịch đang chặn
SELECT
    b.trx_id                                        AS blocking_trx_id,
    b.trx_query                                     AS blocking_query,
    TIMESTAMPDIFF(SECOND, b.trx_started, NOW())     AS blocking_age_s,
    r.trx_id                                        AS waiting_trx_id,
    r.trx_query                                     AS waiting_query,
    TIMESTAMPDIFF(SECOND, r.trx_wait_started, NOW()) AS waiting_for_s
FROM information_schema.INNODB_TRX         b
JOIN performance_schema.data_lock_waits    w
     ON w.BLOCKING_ENGINE_TRANSACTION_ID = b.trx_id
JOIN information_schema.INNODB_TRX         r
     ON r.trx_id = w.REQUESTING_ENGINE_TRANSACTION_ID
ORDER BY blocking_age_s DESC;

-- 2. Current lock wait graph / Đồ thị chờ lock hiện tại
SELECT
    REQUESTING_ENGINE_TRANSACTION_ID  AS waiting_trx,
    BLOCKING_ENGINE_TRANSACTION_ID    AS blocking_trx,
    OBJECT_SCHEMA,
    OBJECT_NAME                        AS locked_table,
    INDEX_NAME                         AS locked_index,
    LOCK_TYPE,                         -- 'TABLE' or 'RECORD'
    LOCK_MODE,                         -- 'S','X','IS','IX','GAP','NEXT-KEY'
    LOCK_STATUS
FROM performance_schema.data_lock_waits dlw
JOIN performance_schema.data_locks      dl USING (ENGINE_LOCK_ID)
ORDER BY blocking_trx;

-- 3. Long-running transactions / Giao dịch chạy lâu
SELECT
    trx_id,
    trx_state,
    TIMESTAMPDIFF(SECOND, trx_started, NOW())  AS age_seconds,
    trx_rows_locked,
    trx_rows_modified,
    LEFT(trx_query, 200)                        AS query_snippet
FROM information_schema.INNODB_TRX
where TIMESTAMPDIFF(SECOND, trx_started, NOW()) > 5
ORDER BY trx_started ASC;

-- 4. Processes holding locks for > 10 seconds / Tiến trình giữ lock > 10 giây
SELECT
    p.ID,
    p.USER,
    p.HOST,
    p.DB,
    p.COMMAND,
    p.TIME,
    p.STATE,
    LEFT(p.INFO, 300) AS query
FROM information_schema.PROCESSLIST p
WHERE p.COMMAND != 'Sleep'
  AND p.TIME > 10
ORDER BY p.TIME DESC;

-- 5. History List Length (MVCC pressure) / Áp lực MVCC
SELECT NAME, COUNT AS value
FROM information_schema.INNODB_METRICS
WHERE NAME IN (
    'trx_rseg_history_len',          -- Undo log queue depth / Độ sâu hàng đợi undo log
    'lock_deadlocks',                -- Deadlock count / Số lần deadlock
    'lock_timeouts',                 -- Lock timeout count / Số lần timeout lock
    'lock_row_lock_time_avg'         -- Average lock wait time / Thời gian chờ lock trung bình
)
ORDER BY NAME;
