# ============================================================================
# 02_silver_transformation.py
# ============================================================================
# Author:       DataGen AI
# Date:         2026-05-23
# Description:  Cleans, casts, deduplicates, writes to 02_silver_db.
#               Ensures dummy promotion row (promoid=0).
#               All _pct columns remain as fractions (e.g., margin_pct 0.0000-0.3000).
# ============================================================================

from pyspark.sql import SparkSession
from pyspark.sql.functions import col, when, current_timestamp
from pyspark.sql.types import DecimalType, ByteType

spark = SparkSession.builder.getOrCreate()

bronze_schema = "`01_bronze_db`"
silver_schema = "`02_silver_db`"

spark.sql(f"CREATE DATABASE IF NOT EXISTS {silver_schema}")

# Clean start: drop existing silver tables
for row in spark.sql(f"SHOW TABLES IN {silver_schema}").collect():
    spark.sql(f"DROP TABLE IF EXISTS {silver_schema}.{row.tableName}")

decimal_cols_high = ["unitprice","unitcost","grossvalue","discountamount",
                     "taxamount","shipcost","annualrentcost","budget","maxdiscountcap"]
decimal_cols_pct  = ["margin_pct","discount_pct","redemption_rate",
                     "promoupliftfactor","tax_rate","storesizemultiplier","spendmultiplier"]

for tbl in spark.sql(f"SHOW TABLES IN {bronze_schema}").collect():
    bronze_name = tbl.tableName
    if "manager" in bronze_name.lower():
        continue

    entity = bronze_name.replace("bronze_", "")
    silver_name = f"silver_{entity}"
    print(f"Processing {bronze_name} -> {silver_name}")

    df = spark.table(f"{bronze_schema}.{bronze_name}")

    # Cast high-precision decimals (money)
    for c in decimal_cols_high:
        if c in df.columns:
            df = df.withColumn(c, col(c).cast(DecimalType(18,2)))
    # Cast percentage columns – they are fractions, keep 4 decimal places
    for c in decimal_cols_pct:
        if c in df.columns:
            if c in ("margin_pct", "discount_pct"):
                df = df.withColumn(c, col(c).cast(DecimalType(5,4)))
            else:
                df = df.withColumn(c, col(c).cast(DecimalType(10,4)))

    if "hour" in df.columns:
        df = df.withColumn("hour", col("hour").cast(ByteType()))

    # Replace empty strings with NULL in string columns (preserve 'No return')
    for c in df.columns:
        if df.schema[c].dataType.typeName() == "string":
            df = df.withColumn(c, when(col(c) == "", None).otherwise(col(c)))

    df = df.dropDuplicates()
    df = df.withColumn("_silver_processed_ts", current_timestamp())

    # Repartitioning strategy
    if "factsales" in entity:
        if "datekey" in df.columns:
            df = df.repartition(col("datekey"))
    else:
        df = df.coalesce(4)

    df.write.format("delta").mode("overwrite").option("mergeSchema", "true") \
      .saveAsTable(f"{silver_schema}.{silver_name}")

    print(f"Created {silver_schema}.{silver_name} with {df.count():,} rows")

# Ensure dummy promotion
dummy_exists = spark.sql(f"SELECT COUNT(*) FROM {silver_schema}.silver_dimpromotion WHERE promoid = 0").collect()[0][0] > 0
if not dummy_exists:
    spark.sql(f"""
        INSERT INTO {silver_schema}.silver_dimpromotion
        (promoid, promoname, discount_pct, discount_fixed, type, isactive, minspend, channel,
         budget, startdate, enddate, targetaudience, maxdiscountcap, isstackable,
         redemption_rate, coderequired, promoupliftfactor)
        VALUES (0, 'No Promotion', 0.0000, 0.00, 'None', 1, 0, 'All', 0.00,
                '2000-01-01', '2099-12-31', 'All', 0.00, 0, 0.000, 0, 1.000)
    """)
    print("Dummy promotion inserted.")
else:
    print("Dummy promotion already exists.")

print("Silver transformation completed.")
# ============================================================================
# End of 02_silver_transformation.py
# ============================================================================