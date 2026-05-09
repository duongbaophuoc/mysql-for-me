-- =============================================================================
-- Replication Status Check Queries / Truy Vấn Kiểm Tra Trạng Thái Sao Chép
-- Run on replica nodes / Chạy trên node replica
-- =============================================================================

-- 1. Overall replication status / Trạng thái sao chép tổng thể
SHOW REPLICA STATUS\G

-- 2. GTID-based lag report / Báo cáo trễ dựa trên GTID
SELECT
    CHANNEL_NAME,
    SERVICE_STATE,
    COUNT_TRANSACTIONS_IN_QUEUE             AS txn_in_queue,
    COUNT_TRANSACTIONS_BEHIND_SOURCE        AS txn_behind_source,
    COUNT_TRANSACTIONS_DONE                 AS txn_applied,
    COUNT_TRANSACTIONS_WITH_ERRORS          AS txn_errors
FROM performance_schema.replication_applier_status;

-- 3. Parallel worker status / Trạng thái worker song song
SELECT
    WORKER_ID,
    THREAD_ID,
    SERVICE_STATE,
    LAST_ERROR_MESSAGE,
    APPLYING_TRANSACTION,
    APPLYING_TRANSACTION_RETRIES_COUNT      AS retries
FROM performance_schema.replication_applier_status_by_worker;

-- 4. Connection status / Trạng thái kết nối
SELECT
    CHANNEL_NAME,
    SERVICE_STATE,
    NETWORK_INTERFACE,
    PORT,
    SOURCE_UUID,
    LAST_ERROR_MESSAGE
FROM performance_schema.replication_connection_status;

-- 5. Seconds behind source (quick check) / Trễ tính bằng giây (kiểm tra nhanh)
SELECT
    NOW()                       AS check_time,
    VARIABLE_VALUE              AS seconds_behind_source,
    CASE
        WHEN CAST(VARIABLE_VALUE AS UNSIGNED) = 0     THEN '✅ In sync'
        WHEN CAST(VARIABLE_VALUE AS UNSIGNED) < 30    THEN '⚠️  Minor lag'
        WHEN CAST(VARIABLE_VALUE AS UNSIGNED) < 120   THEN '🟡 Moderate lag'
        ELSE                                               '❌ Critical lag'
    END AS status
FROM performance_schema.global_status
WHERE VARIABLE_NAME = 'Seconds_Behind_Master';

-- 6. Running transactions on primary that may cause lag
-- Giao dịch đang chạy trên primary có thể gây trễ
-- Run this on PRIMARY / Chạy trên PRIMARY:
SELECT
    trx_id,
    TIMESTAMPDIFF(SECOND, trx_started, NOW()) AS running_seconds,
    trx_rows_modified,
    trx_rows_locked,
    LEFT(trx_query, 100)                       AS query
FROM information_schema.INNODB_TRX
WHERE trx_state = 'RUNNING'
ORDER BY trx_started ASC
LIMIT 10;
