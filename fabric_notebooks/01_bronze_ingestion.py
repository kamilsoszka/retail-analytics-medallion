# -------------------------------------------------------------------
# 01_bronze_ingestion
# Load CSV files into 01_bronze_db with audit columns
# Compatible with final generator (hour column, promoid=0, returnreason='No return')
# Optimized: adds file existence check, repartitions fact table for better parallelism
# -------------------------------------------------------------------

from pyspark.sql import SparkSession
from pyspark.sql.functions import input_file_name, current_timestamp, lit
from notebookutils import mssparkutils

spark = SparkSession.builder.getOrCreate()

# Use backticks because schema names start with a digit
bronze_schema = "`01_bronze_db`"
spark.sql(f"CREATE DATABASE IF NOT EXISTS {bronze_schema}")

# Ensure other schemas exist
spark.sql("CREATE DATABASE IF NOT EXISTS `02_silver_db`")
spark.sql("CREATE DATABASE IF NOT EXISTS `03_gold_db`")

# Drop existing bronze tables to avoid conflicts (clean start)
existing = spark.sql(f"SHOW TABLES IN {bronze_schema}").collect()
for t in existing:
    spark.sql(f"DROP TABLE IF EXISTS {bronze_schema}.{t.tableName}")

# CSV files – note: no dim_manager.csv (generator doesn't produce it)
csv_files = [
    ("raw/dim_date.csv",        "bronze_dimdate"),
    ("raw/dim_customer.csv",    "bronze_dimcustomer"),
    ("raw/dim_product.csv",     "bronze_dimproduct"),
    ("raw/dim_store.csv",       "bronze_dimstore"),
    ("raw/dim_promotion.csv",   "bronze_dimpromotion"),
    ("raw/fact_sales.csv",      "bronze_factsales")
]

for csv_path, table_name in csv_files:
    full_path = f"Files/{csv_path}"
    if not mssparkutils.fs.exists(full_path):
        print(f"File not found: {full_path}")
        continue

    # Read CSV with header and schema inference
    df = spark.read.option("header", "true").option("inferSchema", "true").csv(full_path)

    # Add audit columns
    df = df.withColumn("_source_file", input_file_name()) \
           .withColumn("_ingestion_ts", current_timestamp()) \
           .withColumn("_file_name", lit(csv_path))

    # Repartition the large fact table for better write performance
    if "fact" in table_name:
        # Use datekey for partitioning if available, else a fixed number
        if "datekey" in df.columns:
            df = df.repartition("datekey")
        else:
            df = df.repartition(20)   # 20 partitions for 10M rows

    # Write as Delta table (overwrite mode)
    df.write.format("delta").mode("overwrite").saveAsTable(f"{bronze_schema}.{table_name}")

    row_count = df.count()
    print(f"Loaded {row_count:,} rows into {bronze_schema}.{table_name}")

print("Bronze ingestion completed.")