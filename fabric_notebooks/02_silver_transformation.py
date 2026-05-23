# -------------------------------------------------------------------
# 02_silver_transformation.py
# Author: DataGen AI
# Date: 2026-05-23
# Purpose: Clean, cast, deduplicate, and write to 02_silver_db.
#          Ensures dummy promotion (promoid=0).
#          Tables are dropped before creation (clean overwrite).
# Compatible with final generator: hour, returnreason='No return'
# Optimized: repartitioning for fact, coalesce for dimensions.
# -------------------------------------------------------------------

from pyspark.sql import SparkSession
from pyspark.sql.functions import col, when, current_timestamp
from pyspark.sql.types import DecimalType, ByteType

spark = SparkSession.builder.getOrCreate()

bronze_schema = "`01_bronze_db`"
silver_schema = "`02_silver_db`"
spark.sql(f"CREATE DATABASE IF NOT EXISTS {silver_schema}")

# Clean start: drop all existing silver tables
for row in spark.sql(f"SHOW TABLES IN {silver_schema}").collect():
    spark.sql(f"DROP TABLE IF EXISTS {silver_schema}.{row.tableName}")

# High precision (money, quantities)
decimal_cols_high = ["unitprice", "unitcost", "grossvalue", "discountamount",
                     "taxamount", "shipcost", "annualrentcost", "budget", "maxdiscountcap"]
# Percentage / rate columns (stored as percent, e.g., 25.00)
decimal_cols_percent = ["margin_pct", "discount_pct", "redemption_rate",
                        "promoupliftfactor", "tax_rate", "storesizemultiplier", "spendmultiplier"]

for tbl in spark.sql(f"SHOW TABLES IN {bronze_schema}").collect():
    bronze_name = tbl.tableName
    # No manager table exists; skip if needed
    if "manager" in bronze_name.lower():
        continue

    entity = bronze_name.replace("bronze_", "")
    silver_name = f"silver_{entity}"
    print(f"Processing {bronze_name} -> {silver_name}")

    df = spark.table(f"{bronze_schema}.{bronze_name}")

    # Cast numeric columns to appropriate decimal types
    for c in decimal_cols_high:
        if c in df.columns:
            df = df.withColumn(c, col(c).cast(DecimalType(18,2)))
    for c in decimal_cols_percent:
        if c in df.columns:
            # Use Decimal(5,2) for typical percentages, but others may need more precision
            if c in ("margin_pct", "discount_pct"):
                df = df.withColumn(c, col(c).cast(DecimalType(5,2)))
            else:
                df = df.withColumn(c, col(c).cast(DecimalType(10,4)))

    # Cast hour to tiny integer
    if "hour" in df.columns:
        df = df.withColumn("hour", col("hour").cast(ByteType()))

    # Replace empty strings with NULL for string columns
    for c in df.columns:
        if df.schema[c].dataType.typeName() == "string":
            df = df.withColumn(c, when(col(c) == "", None).otherwise(col(c)))

    # Remove exact duplicate rows
    df = df.dropDuplicates()

    # Add processing timestamp
    df = df.withColumn("_silver_processed_ts", current_timestamp())

    # Write strategy: large fact table repartitioned, dimensions coalesced
    if "factsales" in entity:
        if "datekey" in df.columns:
            df = df.repartition(col("datekey"))
    else:
        df = df.coalesce(4)

    df.write.format("delta").mode("overwrite").option("mergeSchema", "true") \
      .saveAsTable(f"{silver_schema}.{silver_name}")

    print(f"Created {silver_schema}.{silver_name} with {df.count():,} rows")

# Ensure dummy promotion row (promoid=0) exists
print("Checking dummy promotion (promoid=0)...")
dummy_exists = spark.sql(f"SELECT COUNT(*) FROM {silver_schema}.silver_dimpromotion WHERE promoid = 0").collect()[0][0] > 0
if not dummy_exists:
    spark.sql(f"""
        INSERT INTO {silver_schema}.silver_dimpromotion
        (promoid, promoname, discount_pct, discount_fixed, type, isactive, minspend, channel,
         budget, startdate, enddate, targetaudience, maxdiscountcap, isstackable,
         redemption_rate, coderequired, promoupliftfactor)
        VALUES (0, 'No Promotion', 0.00, 0.00, 'None', 1, 0, 'All', 0.00,
                '2000-01-01', '2099-12-31', 'All', 0.00, 0, 0.000, 0, 1.000)
    """)
    print("Dummy promotion inserted.")
else:
    print("Dummy promotion already exists.")

print("Silver transformation completed.")