# Notebook: 02_silver_transformation
# Clean, deduplicate, write to 02_silver_db, and ensure dummy promotion (promoid=0) using SQL INSERT

from pyspark.sql import SparkSession
from pyspark.sql.functions import col, when, current_timestamp
from pyspark.sql.types import DecimalType

spark = SparkSession.builder.getOrCreate()

bronze_schema = "`01_bronze_db`"
silver_schema = "`02_silver_db`"

spark.sql(f"CREATE DATABASE IF NOT EXISTS {silver_schema}")

# Drop existing silver tables to start fresh
existing = spark.sql(f"SHOW TABLES IN {silver_schema}").collect()
for t in existing:
    spark.sql(f"DROP TABLE IF EXISTS {silver_schema}.{t.tableName}")

bronze_tables = spark.sql(f"SHOW TABLES IN {bronze_schema}").collect()

for tbl in bronze_tables:
    bronze_name = tbl.tableName
    if "manager" in bronze_name.lower():
        print(f"Skipping {bronze_name} (no manager table)")
        continue
    entity = bronze_name.replace("bronze_", "")
    silver_name = f"silver_{entity}"
    print(f"Processing {bronze_name} -> {silver_name}")

    df = spark.table(f"{bronze_schema}.{bronze_name}")

    # Cast numeric columns
    for c in ["unitprice", "unitcost", "grossvalue", "discountamount", "taxrate_pct", "margin_pct"]:
        if c in df.columns:
            df = df.withColumn(c, col(c).cast(DecimalType(18,2)))

    # Replace empty strings with NULL
    for c in df.columns:
        if df.schema[c].dataType.typeName() == "string":
            df = df.withColumn(c, when(col(c) == "", None).otherwise(col(c)))

    # Deduplicate
    df = df.dropDuplicates()

    # Add audit timestamp
    df = df.withColumn("_silver_processed_ts", current_timestamp())

    # Repartition fact_sales by datekey
    if "factsales" in entity and "datekey" in df.columns:
        df = df.repartition(col("datekey"))

    # Write to silver
    df.write.format("delta").mode("overwrite").option("mergeSchema", "true").saveAsTable(f"{silver_schema}.{silver_name}")
    print(f"Created {silver_schema}.{silver_name} with {df.count()} rows")

# ----- Insert dummy promotion (promoid=0) using SQL to avoid type errors -----
print("Checking for dummy promotion (promoid=0) in silver_dimpromotion...")
dummy_exists = spark.sql(f"SELECT COUNT(*) FROM {silver_schema}.silver_dimpromotion WHERE promoid = 0").collect()[0][0] > 0
if not dummy_exists:
    print("Inserting dummy promotion using SQL INSERT...")
    spark.sql(f"""
        INSERT INTO {silver_schema}.silver_dimpromotion
        (promoid, promoname, discount_pct, discount_fixed, type, isactive, minspend, channel, budget, startdate, enddate, targetaudience, maxdiscountcap, isstackable, redemption_rate_target_pct, coderequired, promoupliftfactor)
        VALUES (
            0, 'No Promotion',
            CAST(0.000 AS DECIMAL(5,3)),
            CAST(0.00 AS DECIMAL(10,2)),
            'None', 1, 0, 'None',
            CAST(0 AS DECIMAL(18,2)),
            '2000-01-01', '2099-12-31', 'All',
            CAST(0 AS DECIMAL(18,2)),
            0, CAST(0.000 AS DECIMAL(5,3)), 0, CAST(1.000 AS DECIMAL(6,3))
        )
    """)
    print("Dummy promotion inserted.")
else:
    print("Dummy promotion already exists.")

print("Silver transformation completed.")