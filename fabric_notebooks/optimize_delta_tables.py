# ============================================================================
# optimize_delta_tables.py
# ============================================================================
# Author:           DataGen AI & Assistant
# Created:          2026-05-23
# Last modified:    2026-05-25 19:54:00 UTC
# Suggested name:   optimize_delta_tables.py
# Description:
#   Fabric notebook – Delta table maintenance.
#   Optimized to combine compaction and Z-ordering into a single, efficient
#   pass to prevent double I/O writes. Restructured Z-ordering keys on the
#   10M-row factsheet to dodge the curse of dimensionality.
#   Walks through all tables in the Bronze, Silver, and Gold schemas.
# ============================================================================

from delta.tables import DeltaTable
from pyspark.sql import SparkSession

# ---------------------------------------------------------------------------
# 1. Initialise Spark session and enable adaptive query execution
# ---------------------------------------------------------------------------
spark = SparkSession.builder.getOrCreate()
spark.conf.set("spark.sql.adaptive.enabled", "true")

# Set to True if you want to run VACUUM (removes old files older than 7 days)
RUN_VACUUM = False

# ---------------------------------------------------------------------------
# 2. Helper – determine the best Z‑order columns for a given table name
#    Restructured: Z-ordering works best on 1 to 3 highly filtered columns.
#    Removed monotonically increasing transaction IDs and low-benefit fields.
# ---------------------------------------------------------------------------
def zorder_columns(table_name: str):
    """
    Returns a list of columns for Z‑ordering based on the table name.
    Common filter columns are chosen:
      - date‑related tables → datekey
      - customer‑related → customerid
      - product‑related → productid
      - store‑related → storeid
      - promotion‑related → promoid
      - fact/sales → datekey, productid, customerid (3 core analytical dimensions)
    """
    name = table_name.lower()
    if "date" in name:
        return ["datekey"]
    elif "customer" in name:
        return ["customerid"]
    elif "product" in name:
        return ["productid"]
    elif "store" in name:
        return ["storeid"]
    elif "promo" in name:
        return ["promoid"]
    elif "sales" in name or "fact" in name:
        # Reduced to 3 columns to maximize multi-dimensional clustering effectiveness
        # (salesid removed as it is never used for range filters or analytical slices)
        return ["datekey", "productid", "customerid"]
    else:
        return None

# ---------------------------------------------------------------------------
# 3. Iterate over all schemas and tables, apply compaction and Z‑ordering
# ---------------------------------------------------------------------------
schemas = ["`01_bronze_db`", "`02_silver_db`", "`03_gold_db`"]

for schema in schemas:
    tables = spark.sql(f"SHOW TABLES IN {schema}").collect()
    for row in tables:
        # Skip temporary Spark views/tables as they cannot be optimized
        if row.isTemporary:
            continue
            
        table_name = row.tableName
        full_name  = f"{schema}.{table_name}"
        print(f"Optimizing {full_name}...")

        try:
            # Get Delta table location and current file count
            detail      = spark.sql(f"DESCRIBE DETAIL {full_name}")
            loc         = detail.select("location").head()[0]
            num_files   = detail.select("numFiles").head()[0]
            delta_table = DeltaTable.forPath(spark, loc)

            # Determine available and valid Z-order columns
            z_cols = zorder_columns(table_name)
            valid_cols = []
            if z_cols:
                existing_cols = spark.table(full_name).limit(1).columns
                valid_cols = [c for c in z_cols if c in existing_cols]

            # --- SINGLE-PASS OPTIMIZATION LOGIC ---
            # Standard executeZOrderBy inherently performs compaction (bin-packing).
            # By combining these steps, we prevent double write I/O operations.
            if valid_cols:
                print(f"  -> Running single-pass OPTIMIZE with Z-ORDER BY on {valid_cols}")
                delta_table.optimize().executeZOrderBy(valid_cols)
                print(f"  ✔ Table optimized and Z-ordered successfully.")
            elif num_files > 20:
                print(f"  -> Running standard compaction (bin-packing) on {num_files} files...")
                delta_table.optimize().executeCompaction()
                print(f"  ✔ Table compacted successfully.")
            else:
                print(f"  ⏭ Skipped optimization – only {num_files} files and no Z-order columns.")

            # Optional VACUUM (cleanup of old file versions)
            if RUN_VACUUM:
                delta_table.vacuum(168)   # retain 168 hours (7 days)
                print("  ✔ Vacuumed (retention 168h)")

        except Exception as e:
            print(f"  ✘ Error on {full_name}: {e}")

print("\nDelta table optimization completed.")
# ============================================================================
# End of optimize_delta_tables.py
# ============================================================================