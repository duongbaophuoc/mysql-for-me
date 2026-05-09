# Spark Integration with MySQL / Tích Hợp Spark Với MySQL

## Overview / Tổng Quan

Apache Spark connects to MySQL via JDBC for **large-scale batch processing** — reading millions of rows, doing complex transformations, and writing results back.
_Apache Spark kết nối với MySQL qua JDBC cho **xử lý batch quy mô lớn** — đọc hàng triệu hàng, biến đổi phức tạp, và ghi kết quả lại._

---

## When to Use Spark with MySQL / Khi Nào Dùng Spark Với MySQL

```
Use Spark when / Dùng Spark khi:
  ✅ Processing > 100M rows (too slow for pure SQL)
  ✅ Complex ML feature engineering
  ✅ Cross-system joins (MySQL + S3 + Hive)
  ✅ Historical backfill of large date ranges

Don't use Spark when / Không dùng Spark khi:
  ❌ < 10M rows (dbt/SQL is simpler)
  ❌ Real-time data (use Kafka/Flink instead)
  ❌ Simple SELECT + INSERT (use ETL/dbt)
```

---

## Reading from MySQL / Đọc Từ MySQL

```python
from pyspark.sql import SparkSession

spark = SparkSession.builder \
    .appName("MySQL Spark ETL") \
    .config("spark.jars", "/opt/jars/mysql-connector-j-8.0.33.jar") \
    .getOrCreate()

# Simple JDBC read / Đọc JDBC đơn giản
orders_df = spark.read.format("jdbc") \
    .option("url", "jdbc:mysql://localhost:3306/shop_db") \
    .option("dbtable", "orders") \
    .option("user", "root") \
    .option("password", "secret") \
    .option("driver", "com.mysql.cj.jdbc.Driver") \
    .load()

orders_df.show(5)
orders_df.printSchema()
```

---

## Partitioned Read for Large Tables / Đọc Phân Vùng Cho Bảng Lớn

```python
# Without partition: one task reads entire table → slow!
# Không phân vùng: một task đọc cả bảng → chậm!

# With partition: parallel reads → fast! / Với phân vùng: đọc song song → nhanh!
orders_df = spark.read.format("jdbc") \
    .option("url", "jdbc:mysql://localhost:3306/shop_db") \
    .option("dbtable", "orders") \
    .option("user", "root") \
    .option("password", "secret") \
    .option("driver", "com.mysql.cj.jdbc.Driver") \
    .option("partitionColumn", "id")       \  # numeric column to split on
    .option("lowerBound", "1")             \  # min value
    .option("upperBound", "10000000")      \  # max value (10M rows)
    .option("numPartitions", "20")         \  # 20 parallel readers!
    .load()
# Creates 20 parallel partitions: id 0-500K, 500K-1M, ... 9.5M-10M
# Tạo 20 phân vùng song song: id 0-500K, 500K-1M, ... 9.5M-10M
```

---

## Transformations with PySpark / Biến Đổi Với PySpark

```python
from pyspark.sql import functions as F

# Join orders + customers + items / Join đơn hàng + khách hàng + mặt hàng
customers_df = spark.read.format("jdbc").option("dbtable", "customers").load()
items_df     = spark.read.format("jdbc").option("dbtable", "order_items").load()

enriched_df = orders_df \
    .join(customers_df, orders_df.customer_id == customers_df.id, "left") \
    .join(items_df, orders_df.id == items_df.order_id, "left") \
    .filter(F.col("orders.status") == "delivered") \
    .groupBy(
        F.date_format("orders.created_at", "yyyy-MM").alias("month"),
        "customers.full_name"
    ) \
    .agg(
        F.sum("order_items.line_total").alias("total_revenue"),
        F.count("orders.id").alias("order_count")
    ) \
    .orderBy("month", F.desc("total_revenue"))

enriched_df.show(20)
```

---

## Writing Back to MySQL / Ghi Lại Vào MySQL

```python
# Write Spark results to analytics_dw / Ghi kết quả Spark vào analytics_dw
enriched_df.write.format("jdbc") \
    .option("url", "jdbc:mysql://localhost:3306/analytics_dw") \
    .option("dbtable", "spark_monthly_customer_summary") \
    .option("user", "root") \
    .option("password", "secret") \
    .option("driver", "com.mysql.cj.jdbc.Driver") \
    .mode("overwrite")  \  # "overwrite" truncates + inserts / "append" adds
    .save()
```

---

## Spark Structured Streaming from Kafka / Spark Structured Streaming Từ Kafka

```python
# Real-time streaming: Kafka (Debezium CDC) → Spark → analytics_dw
# Streaming thời gian thực: Kafka → Spark → analytics_dw

from pyspark.sql.functions import from_json, col
from pyspark.sql.types import StructType, LongType, StringType

schema = StructType().add("id", LongType()).add("status", StringType()) \
                     .add("total_amount", "double")

stream_df = spark.readStream.format("kafka") \
    .option("kafka.bootstrap.servers", "kafka:9092") \
    .option("subscribe", "prod.shop_db.orders") \
    .load() \
    .select(from_json(col("value").cast("string"), schema).alias("order")) \
    .select("order.*")

query = stream_df.writeStream \
    .outputMode("append") \
    .format("jdbc") \
    .option("url", "jdbc:mysql://localhost:3306/analytics_dw") \
    .option("dbtable", "streaming_fact_sales") \
    .start()

query.awaitTermination()
```
