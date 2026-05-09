-- =============================================================================
-- Production Diagnostics Query Pack
-- Gói Truy Vấn Chẩn Đoán Production
-- =============================================================================
-- Run these when investigating performance problems
-- Chạy khi điều tra vấn đề hiệu năng
-- =============================================================================

-- ─── 1. Active Queries / Truy Vấn Đang Chạy ──────────────────────────────────
SELECT
    ID                      AS connection_id,
    USER                    AS user_host,
    DB                      AS db,
    COMMAND                 AS command,
    TIME                    AS running_seconds,
    STATE                   AS state,
    LEFT(INFO, 300)         AS query_snippet
FROM information_schema.PROCESSLIST
WHERE COMMAND != 'Sleep'
  AND TIME > 1
ORDER BY TIME DESC;

-- ─── 2. Waiting Transactions / Giao Dịch Đang Chờ ────────────────────────────
SELECT
    r.trx_id               AS waiting_trx,
    r.trx_mysql_thread_id  AS waiting_thread,
    r.trx_query            AS waiting_query,
    b.trx_id               AS blocking_trx,
    b.trx_mysql_thread_id  AS blocking_thread,
    b.trx_query            AS blocking_query,
    TIMESTAMPDIFF(SECOND, r.trx_wait_started, NOW()) AS wait_seconds
FROM information_schema.INNODB_TRX r
JOIN information_schema.INNODB_TRX b ON b.trx_id = r.trx_wait_for_trx_id
ORDER BY wait_seconds DESC;

-- ─── 3. Lock Details / Chi Tiết Lock ─────────────────────────────────────────
SELECT
    ENGINE_LOCK_ID,
    ENGINE_TRANSACTION_ID   AS trx_id,
    THREAD_ID,
    OBJECT_SCHEMA           AS db,
    OBJECT_NAME             AS table_name,
    INDEX_NAME,
    LOCK_TYPE,
    LOCK_MODE,
    LOCK_STATUS,
    LOCK_DATA
FROM performance_schema.data_locks
ORDER BY LOCK_STATUS DESC, ENGINE_TRANSACTION_ID;

-- ─── 4. Top Queries by Total Time / Top Truy Vấn Theo Tổng Thời Gian ─────────
SELECT
    SCHEMA_NAME                                   AS db,
    ROUND(SUM_TIMER_WAIT / 1e9 / 1e3, 2)         AS total_sec,
    ROUND(AVG_TIMER_WAIT / 1e9, 2)               AS avg_ms,
    COUNT_STAR                                    AS calls,
    SUM_ROWS_EXAMINED                             AS rows_examined,
    ROUND(SUM_ROWS_EXAMINED / COUNT_STAR)        AS avg_rows_examined,
    SUBSTR(DIGEST_TEXT, 1, 150)                  AS query
FROM performance_schema.events_statements_summary_by_digest
WHERE SCHEMA_NAME IS NOT NULL
  AND COUNT_STAR > 5
ORDER BY SUM_TIMER_WAIT DESC
LIMIT 20;

-- ─── 5. Table IO Waits / Chờ IO Bảng ─────────────────────────────────────────
SELECT
    OBJECT_SCHEMA           AS db,
    OBJECT_NAME             AS table_name,
    COUNT_FETCH             AS reads,
    COUNT_INSERT            AS inserts,
    COUNT_UPDATE            AS updates,
    COUNT_DELETE            AS deletes,
    ROUND(SUM_TIMER_FETCH / 1e12, 3)     AS read_sec,
    ROUND(SUM_TIMER_INSERT / 1e12, 3)    AS insert_sec,
    ROUND(SUM_TIMER_UPDATE / 1e12, 3)    AS update_sec
FROM performance_schema.table_io_waits_summary_by_table
WHERE OBJECT_SCHEMA NOT IN ('mysql','performance_schema','sys','information_schema')
ORDER BY READ_SEC + INSERT_SEC + UPDATE_SEC DESC
LIMIT 15;

-- ─── 6. InnoDB Status Snapshot / Snapshot Trạng Thái InnoDB ──────────────────
SHOW ENGINE INNODB STATUS\G

-- ─── 7. Key Variable Snapshot / Snapshot Biến Quan Trọng ─────────────────────
SELECT VARIABLE_NAME, VARIABLE_VALUE
FROM performance_schema.global_status
WHERE VARIABLE_NAME IN (
    'Threads_connected',
    'Threads_running',
    'Slow_queries',
    'Innodb_buffer_pool_reads',
    'Innodb_buffer_pool_read_requests',
    'Innodb_deadlocks',
    'Innodb_row_lock_waits',
    'Innodb_row_lock_time_avg',
    'Bytes_sent',
    'Bytes_received',
    'Questions',
    'Com_select',
    'Com_insert',
    'Com_update',
    'Com_delete'
)
ORDER BY VARIABLE_NAME;
