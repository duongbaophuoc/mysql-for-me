"""
Airflow DAG: MySQL to Data Warehouse ETL Pipeline
DAG Airflow: Pipeline ETL từ MySQL đến Kho Dữ Liệu

Loads data from shop_db (OLTP) to analytics_dw (OLAP)
Nạp dữ liệu từ shop_db (OLTP) vào analytics_dw (OLAP)
"""

from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.operators.mysql_operator import MySqlOperator
from airflow.sensors.sql import SqlSensor
from airflow.utils.dates import days_ago
import logging

logger = logging.getLogger(__name__)

# =============================================================================
# DAG Configuration / Cấu hình DAG
# =============================================================================
default_args = {
    'owner': 'data-engineering',
    'depends_on_past': False,
    'email_on_failure': True,
    'email_on_retry': False,
    'retries': 3,
    'retry_delay': timedelta(minutes=5),
    'retry_exponential_backoff': True,
    'max_retry_delay': timedelta(minutes=30),
}

with DAG(
    dag_id='mysql_to_warehouse_daily',
    description='Daily ETL from shop_db to analytics_dw / ETL hàng ngày từ shop_db sang analytics_dw',
    default_args=default_args,
    start_date=days_ago(1),
    schedule_interval='0 2 * * *',      # 2:00 AM daily / 2 giờ sáng hàng ngày
    catchup=False,
    max_active_runs=1,
    tags=['mysql', 'etl', 'warehouse', 'daily'],
) as dag:

    # -------------------------------------------------------------------------
    # Task 1: Check source availability / Kiểm tra nguồn khả dụng
    # -------------------------------------------------------------------------
    check_source = SqlSensor(
        task_id='check_shop_db_available',
        conn_id='mysql_shop_db',
        sql="SELECT 1 FROM orders LIMIT 1",
        timeout=300,
        poke_interval=30,
    )

    # -------------------------------------------------------------------------
    # Task 2: Extract new orders since last run
    # Trích xuất đơn hàng mới kể từ lần chạy trước
    # -------------------------------------------------------------------------
    def extract_orders(**context):
        """
        Extract orders updated since last successful run.
        Trích xuất đơn hàng được cập nhật kể từ lần chạy thành công trước.
        """
        from airflow.providers.mysql.hooks.mysql import MySqlHook

        mysql_hook = MySqlHook(mysql_conn_id='mysql_shop_db')
        
        # Get last run watermark / Lấy watermark lần chạy trước
        execution_date = context['execution_date']
        prev_execution_date = context['prev_execution_date'] or execution_date - timedelta(days=1)
        
        query = """
            SELECT
                o.id              AS order_id,
                o.uuid            AS order_uuid,
                o.customer_id,
                o.status,
                o.subtotal,
                o.discount_amount,
                o.tax_amount,
                o.shipping_amount,
                o.total_amount,
                o.source,
                o.created_at,
                o.updated_at,
                c.email           AS customer_email,
                c.full_name       AS customer_name
            FROM orders o
            JOIN customers c ON c.id = o.customer_id
            WHERE o.updated_at >= %(start_date)s
              AND o.updated_at <  %(end_date)s
            ORDER BY o.updated_at ASC
        """
        
        records = mysql_hook.get_records(
            query,
            parameters={
                'start_date': prev_execution_date,
                'end_date': execution_date,
            }
        )
        
        logger.info(f"Extracted {len(records)} orders / Trích xuất {len(records)} đơn hàng")
        context['task_instance'].xcom_push(key='order_count', value=len(records))
        return records

    extract_orders_task = PythonOperator(
        task_id='extract_orders',
        python_callable=extract_orders,
        provide_context=True,
    )

    # -------------------------------------------------------------------------
    # Task 3: Transform and load to warehouse / Biến đổi và nạp vào kho
    # -------------------------------------------------------------------------
    def load_to_warehouse(**context):
        """
        Load extracted data into analytics_dw fact_sales table.
        Nạp dữ liệu đã trích xuất vào bảng fact_sales của analytics_dw.
        """
        from airflow.providers.mysql.hooks.mysql import MySqlHook

        records = context['task_instance'].xcom_pull(task_ids='extract_orders')
        if not records:
            logger.info("No records to load / Không có bản ghi để nạp")
            return

        dw_hook = MySqlHook(mysql_conn_id='mysql_analytics_dw')

        # Upsert into fact_sales / Upsert vào fact_sales
        upsert_sql = """
            INSERT INTO fact_sales (
                date_key, customer_sk, product_sk,
                order_nk, order_uuid,
                gross_revenue, net_revenue, order_source,
                dw_inserted_at
            )
            SELECT
                DATE_FORMAT(%(created_at)s, '%%Y%%m%%d') AS date_key,
                dc.customer_sk,
                1                                         AS product_sk,
                %(order_id)s,
                %(order_uuid)s,
                %(total_amount)s                          AS gross_revenue,
                %(total_amount)s - %(discount_amount)s    AS net_revenue,
                %(source)s,
                NOW()
            FROM dim_customer dc
            WHERE dc.customer_nk = %(customer_id)s AND dc.is_current = 1
            ON DUPLICATE KEY UPDATE
                net_revenue = VALUES(net_revenue),
                dw_inserted_at = NOW()
        """

        for record in records:
            dw_hook.run(upsert_sql, parameters=dict(zip(
                ['order_id', 'order_uuid', 'customer_id', 'status',
                 'total_amount', 'discount_amount', 'source', 'created_at'],
                record
            )))

        logger.info(f"Loaded {len(records)} records / Đã nạp {len(records)} bản ghi")

    load_task = PythonOperator(
        task_id='load_to_warehouse',
        python_callable=load_to_warehouse,
        provide_context=True,
    )

    # -------------------------------------------------------------------------
    # Task 4: Refresh materialized aggregates / Làm mới tổng hợp vật thể hóa
    # -------------------------------------------------------------------------
    refresh_aggregates = MySqlOperator(
        task_id='refresh_daily_aggregates',
        mysql_conn_id='mysql_analytics_dw',
        sql="""
            INSERT INTO agg_daily_sales (
                date_key, product_sk,
                orders_count, units_sold,
                gross_revenue, net_revenue,
                avg_order_value, refreshed_at
            )
            SELECT
                date_key,
                product_sk,
                COUNT(*)              AS orders_count,
                SUM(quantity)         AS units_sold,
                SUM(gross_revenue)    AS gross_revenue,
                SUM(net_revenue)      AS net_revenue,
                AVG(gross_revenue)    AS avg_order_value,
                NOW()                 AS refreshed_at
            FROM fact_sales
            WHERE date_key = DATE_FORMAT(DATE_SUB(NOW(), INTERVAL 1 DAY), '%Y%m%d')
            GROUP BY date_key, product_sk
            ON DUPLICATE KEY UPDATE
                orders_count    = VALUES(orders_count),
                units_sold      = VALUES(units_sold),
                gross_revenue   = VALUES(gross_revenue),
                net_revenue     = VALUES(net_revenue),
                avg_order_value = VALUES(avg_order_value),
                refreshed_at    = NOW()
        """,
    )

    # -------------------------------------------------------------------------
    # DAG Dependencies / Phụ thuộc DAG
    # -------------------------------------------------------------------------
    check_source >> extract_orders_task >> load_task >> refresh_aggregates
