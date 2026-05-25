# ============================================================================
# transform_silver_layer.py
# ============================================================================
# Author:           DataGen AI & Assistant
# Created:          2026-05-23
# Last modified:    2026-05-25 19:43:00 UTC
# Suggested name:   transform_silver_layer.py
# Description:
#   Fabric notebook – Silver layer transformation.
#   Reads Delta tables from the Bronze layer (01_bronze_db), performs
#   data cleaning, type casting, deduplication, and writes the refined
#   data into 02_silver_db. Optimized to collapse DataFrame lineages into
#   a single projection pass (avoiding iterative .withColumn memory bloat).
#   Deduplicates efficiently based on primary keys rather than full-row scans.
# ============================================================================

from pyspark.sql import SparkSession
from pyspark.sql.functions import col, when, current_timestamp
from pyspark.sql.types import DecimalType, ByteType

# ---------------------------------------------------------------------------
# 1. Initialise Spark session and ensure the Silver database exists
# ---------------------------------------------------------------------------
spark = SparkSession.builder.getOrCreate()

bronze_schema = "`01_bronze_db`"
silver_schema = "`02_silver_db`"

spark.sql(f"CREATE DATABASE IF NOT EXISTS {silver_schema}")

# ---------------------------------------------------------------------------
# 2. Define column groups for precise database-grade decimal casting
# ---------------------------------------------------------------------------
decimal_cols_high = {
    "unitprice", "unitcost", "grossvalue", "discountamount",
    "taxamount", "shipcost", "annualrentcost", "budget", "maxdiscountcap"
}
decimal_cols_pct  = {
    "margin_pct", "discount_pct", "redemption_rate",
    "promoupliftfactor", "tax_rate", "storesizemultiplier", "spendmultiplier"
}

# Mapping of primary keys per entity to allow fast, hash-based deduplication
pk_mapping = {
    "dimdate":      "datekey",
    "dimcustomer":  "customerid",
    "dimproduct":   "productid",
    "dimstore":     "storeid",
    "dimpromotion": "promoid",
    "factsales":    "salesid"
}

# ---------------------------------------------------------------------------
# 3. Process each Bronze table and write the corresponding Silver table
# ---------------------------------------------------------------------------
for tbl in spark.sql(f"SHOW TABLES IN {bronze_schema}").collect():
    bronze_name = tbl.tableName

    # Skip non‑existing manager table (safety guard)
    if "manager" in bronze_name.lower():
        continue

    entity      = bronze_name.replace("bronze_", "")
    silver_name = f"silver_{entity}"
    print(f"Processing {bronze_name} → {silver_name}...")

    # Read the Bronze Delta table
    df = spark.table(f"{bronze_schema}.{bronze_name}")

    # --- SINGLE PASS PROJECTION & CLEANING ---
    # We build a list of column expressions and evaluate them in one single .select() pass.
    # This prevents logical plan bloat caused by iterative .withColumn calls.
    select_exprs = []
    
    for c in df.columns:
        expr = col(c)

        # 4a. Cast monetary columns to DECIMAL(18,2)
        if c in decimal_cols_high:
            expr = expr.cast(DecimalType(18, 2))

        # 4b. Cast percentage/fraction columns with correct precision
        elif c in decimal_cols_pct:
            if c in ("margin_pct", "discount_pct"):
                expr = expr.cast(DecimalType(5, 4))
            else:
                expr = expr.cast(DecimalType(10, 4))

        # 4c. Cast hour to TINYINT (ByteType)
        elif c == "hour":
            expr = expr.cast(ByteType())

        # 4d. Replace empty strings with NULL for all string columns
        #     Keeps 'No return' untouched because it is not an empty string
        if df.schema[c].dataType.typeName() == "string":
            expr = when(expr == "", None).otherwise(expr)

        # Alias back to original column name to keep schema consistent
        select_exprs.append(expr.alias(c))

    # Apply all transformations in a single Spark projection node
    df = df.select(*select_exprs)

    # --- 4e. Optimized Deduplication ---
    # Deduplicates by primary key (much faster than full row-by-row comparisons)
    if entity in pk_mapping:
        pk_col = pk_mapping[entity]
        df = df.dropDuplicates([pk_col])
    else:
        df = df.dropDuplicates()

    # --- 4f. Add processing timestamp ---
    df = df.withColumn("_silver_processed_ts", current_timestamp())

    # --- 4g. Optimize Write Parallelism ---
    # Repartitioning into 4 uniform files per table to prevent the "Tiny Files"
    # antipattern on OneLake. This maximizes read speeds for the Gold views.
    df = df.repartition(4)

    # --- 4h. Overwrite the Silver Delta table atomically ---
    df.write \
      .format("delta") \
      .mode("overwrite") \
      .option("overwriteSchema", "true") \
      .saveAsTable(f"{silver_schema}.{silver_name}")

    row_count = df.count()
    print(f"✓ Created {silver_schema}.{silver_name} with {row_count:,} rows\n")

# ---------------------------------------------------------------------------
# 5. Ensure the dummy promotion row (promoid = 0) exists
#    Usually loaded natively from Python, but verified here for safety.
# ---------------------------------------------------------------------------
print("Checking dummy promotion (promoid = 0)...")
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