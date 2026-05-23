# -------------------------------------------------------------------
# 01_bronze_ingestion.py
# Author: DataGen AI
# Date: 2026-05-23
# Purpose: Load CSV files into 01_bronze_db with audit columns.
#          Tables are dropped before creation (clean start).
# Compatible with final generator: hour, promoid=0, returnreason='No return'
# Optimized: file existence check, repartitioning of fact table.
# -------------------------------------------------------------------

from pyspark.sql import SparkSession
from pyspark.sql.functions import input_file_name, current_timestamp, lit
from notebookutils import mssparkutils

spark = SparkSession.builder.getOrCreate()

bronze_schema = "`01_bronze_db`"
spark.sql(f"CREATE DATABASE IF NOT EXISTS {bronze_schema}")
spark.sql("CREATE DATABASE IF NOT EXISTS `02_silver_db`")
spark.sql("CREATE DATABASE IF NOT EXISTS `03_gold_db`")

# Drop existing bronze tables to ensure clean overwrite
existing_tables = spark.sql(f"SHOW TABLES IN {bronze_schema}").collect()
for row in existing_tables:
    spark.sql(f"DROP TABLE IF EXISTS {bronze_schema}.{row.tableName}")

csv_mapping = [
    ("raw/dim_date.csv",       "bronze_dimdate"),
    ("raw/dim_customer.csv",   "bronze_dimcustomer"),
    ("raw/dim_product.csv",    "bronze_dimproduct"),
    ("raw/dim_store.csv",      "bronze_dimstore"),
    ("raw/dim_promotion.csv",  "bronze_dimpromotion"),
    ("raw/fact_sales.csv",     "bronze_factsales"),
]

for csv_path, table_name in csv_mapping:
    full_path = f"Files/{csv_path}"
    if not mssparkutils.fs.exists(full_path):
        print(f"File not found: {full_path}")
        continue

    # Read CSV with header and schema inference
    df = spark.read.option("header", "true").option("inferSchema", "true").csv(full_path)

    # Add audit columns for lineage tracking
    df = df.withColumn("_source_file", input_file_name()) \
           .withColumn("_ingestion_ts", current_timestamp()) \
           .withColumn("_file_name", lit(csv_path))

    # Optimize large fact table by partitioning on datekey if present
    if "fact" in table_name:
        if "datekey" in df.columns:
            df = df.repartition("datekey")
        else:
            df = df.repartition(20)

    # Overwrite target Delta table
    df.write.format("delta").mode("overwrite").saveAsTable(f"{bronze_schema}.{table_name}")

    row_count = df.count()
    print(f"Loaded {row_count:,} rows into {bronze_schema}.{table_name}")

print("Bronze ingestion completed.")