# ============================================================================
# transform_silver_layer.py
# ============================================================================
# Author:           DataGen AI
# Created:           2026-05-23
# Last modified:     2026-05-24 03:10:00 UTC
# Suggested name:    transform_silver_layer.py
# Description:
#   Fabric notebook – Silver layer transformation.
#   Reads Delta tables from the Bronze layer (01_bronze_db), performs
#   data cleaning, type casting, deduplication, and writes the refined
#   data into 02_silver_db.  It also ensures that the dummy promotion
#   row (promoid = 0) exists.
#   All _pct columns (margin_pct, discount_pct, etc.) are kept as
#   decimal fractions with appropriate precision.
#
# Execution order (medallion architecture):
#   1. ingest_bronze_layer.py
#   2. transform_silver_layer.py   ← this notebook
#   3. create_gold_views.py
#   4. optimize_delta_tables.py
# ============================================================================

from pyspark.sql import SparkSession
from pyspark.sql.functions import col, when, current_timestamp
from pyspark.sql.types import DecimalType, ByteType

# ---------------------------------------------------------------------------
# 1. Initialise Spark session and ensure the Silver schema exists
# ---------------------------------------------------------------------------
spark = SparkSession.builder.getOrCreate()

bronze_schema = "`01_bronze_db`"
silver_schema = "`02_silver_db`"

spark.sql(f"CREATE DATABASE IF NOT EXISTS {silver_schema}")

# ---------------------------------------------------------------------------
# 2. Clean start – drop all existing Silver tables for a fresh run
# ---------------------------------------------------------------------------
existing_tables = spark.sql(f"SHOW TABLES IN {silver_schema}").collect()
for row in existing_tables:
    spark.sql(f"DROP TABLE IF EXISTS {silver_schema}.{row.tableName}")
    print(f"Dropped {silver_schema}.{row.tableName}")

# ---------------------------------------------------------------------------
# 3. Define column groups for proper decimal casting
#    - High‑precision monetary columns → DECIMAL(18,2)
#    - Percentage/fraction columns → DECIMAL(5,4) for the main _pct fields,
#      DECIMAL(10,4) for others (redemption_rate, uplift factor, etc.)
# ---------------------------------------------------------------------------
decimal_cols_high = [
    "unitprice", "unitcost", "grossvalue", "discountamount",
    "taxamount", "shipcost", "annualrentcost", "budget", "maxdiscountcap"
]
decimal_cols_pct  = [
    "margin_pct", "discount_pct", "redemption_rate",
    "promoupliftfactor", "tax_rate", "storesizemultiplier", "spendmultiplier"
]

# ---------------------------------------------------------------------------
# 4. Process each Bronze table and write the corresponding Silver table
# ---------------------------------------------------------------------------
for tbl in spark.sql(f"SHOW TABLES IN {bronze_schema}").collect():
    bronze_name = tbl.tableName

    # Skip non‑existing manager table (safety guard)
    if "manager" in bronze_name.lower():
        continue

    entity      = bronze_name.replace("bronze_", "")
    silver_name = f"silver_{entity}"
    print(f"Processing {bronze_name} → {silver_name}")

    # Read the Bronze Delta table
    df = spark.table(f"{bronze_schema}.{bronze_name}")

    # --- 4a. Cast monetary columns to DECIMAL(18,2) ---
    for c in decimal_cols_high:
        if c in df.columns:
            df = df.withColumn(c, col(c).cast(DecimalType(18,2)))

    # --- 4b. Cast percentage/fraction columns ---
    for c in decimal_cols_pct:
        if c in df.columns:
            # margin_pct and discount_pct need 4 decimal places (e.g., 0.1196)
            if c in ("margin_pct", "discount_pct"):
                df = df.withColumn(c, col(c).cast(DecimalType(5,4)))
            else:
                df = df.withColumn(c, col(c).cast(DecimalType(10,4)))

    # --- 4c. Cast hour to TINYINT (ByteType) ---
    if "hour" in df.columns:
        df = df.withColumn("hour", col("hour").cast(ByteType()))

    # --- 4d. Replace empty strings with NULL for all string columns ---
    #     This keeps 'No return' untouched because it is not an empty string.
    for c in df.columns:
        if df.schema[c].dataType.typeName() == "string":
            df = df.withColumn(c, when(col(c) == "", None).otherwise(col(c)))

    # --- 4e. Remove exact duplicate rows ---
    df = df.dropDuplicates()

    # --- 4f. Add a processing timestamp ---
    df = df.withColumn("_silver_processed_ts", current_timestamp())

    # --- 4g. Optimise write parallelism ---
    #     The fact table is repartitioned by datekey; dimension tables are
    #     coalesced into 4 files to avoid many tiny files.
    if "factsales" in entity:
        if "datekey" in df.columns:
            df = df.repartition(col("datekey"))
    else:
        df = df.coalesce(4)

    # --- 4h. Overwrite the Silver Delta table ---
    df.write \
      .format("delta") \
      .mode("overwrite") \
      .option("mergeSchema", "true") \
      .saveAsTable(f"{silver_schema}.{silver_name}")

    row_count = df.count()
    print(f"Created {silver_schema}.{silver_name} with {row_count:,} rows")

# ---------------------------------------------------------------------------
# 5. Ensure the dummy promotion row (promoid = 0) exists
#    This row represents "No Promotion" and is referenced by many fact rows.
# ---------------------------------------------------------------------------
print("Checking dummy promotion (promoid = 0)…")
dummy_exists = spark.sql(
    f"SELECT COUNT(*) FROM {silver_schema}.silver_dimpromotion WHERE promoid = 0"
).collect()[0][0] > 0

if not dummy_exists:
    spark.sql(f"""
        INSERT INTO {silver_schema}.silver_dimpromotion
        (promoid, promoname, discount_pct, discount_fixed, type, isactive, minspend, channel,
         budget, startdate, enddate, targetaudience, maxdiscountcap, isstackable,
         redemption_rate, coderequired, promoupliftfactor)
        VALUES (0, 'No Promotion', 0.0000, 0.00, 'None', 1, 0, 'All', 0.00,
                '2000-01-01', '2099-12-31', 'All', 0.00, 0, 0.000, 0, 1.000)
    """)
    print("Dummy promotion row inserted.")
else:
    print("Dummy promotion row already exists.")

print("Silver layer transformation completed successfully.")
# ============================================================================
# End of transform_silver_layer.py
# ============================================================================