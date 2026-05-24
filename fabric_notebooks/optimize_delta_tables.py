# ============================================================================
# optimize_delta_tables.py
# ============================================================================
# Author:           DataGen AI
# Created:           2026-05-23
# Last modified:     2026-05-24 03:30:00 UTC
# Suggested name:    optimize_delta_tables.py
# Description:
#   Fabric notebook – Delta table maintenance.
#   Walks through all tables in the Bronze, Silver, and Gold schemas and
#   performs two operations:
#     1. Compaction (bin‑packing) – only if the table has more than 20 files.
#     2. Z‑ordering on frequently filtered columns (datekey, customerid,
#        productid, etc.) to improve query performance.
#   An optional VACUUM step (disabled by default) can remove old file
#   versions after 7 days.
#
# Execution order (medallion architecture):
#   1. ingest_bronze_layer.py
#   2. transform_silver_layer.py
#   3. create_gold_views.py
#   4. optimize_delta_tables.py   ← this notebook
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
# ---------------------------------------------------------------------------
def zorder_columns(table_name: str):
    """
    Returns a list of columns for Z‑ordering based on the table name.
    Common filter columns are chosen:
      - date‑related tables → datekey
      - customer‑related → customerid
      - product‑related → productid, category
      - store‑related → storeid, region
      - promotion‑related → promoid
      - fact/sales → salesid, datekey, productid, customerid, storeid
    """
    name = table_name.lower()
    if "date" in name:
        return ["datekey"]
    elif "customer" in name:
        return ["customerid"]
    elif "product" in name:
        return ["productid", "category"]
    elif "store" in name:
        return ["storeid", "region"]
    elif "promo" in name:
        return ["promoid"]
    elif "sales" in name or "fact" in name:
        return ["salesid", "datekey", "productid", "customerid", "storeid"]
    else:
        return None

# ---------------------------------------------------------------------------
# 3. Iterate over all schemas and tables, apply compaction and Z‑ordering
# ---------------------------------------------------------------------------
schemas = ["`01_bronze_db`", "`02_silver_db`", "`03_gold_db`"]

for schema in schemas:
    tables = spark.sql(f"SHOW TABLES IN {schema}").collect()
    for row in tables:
        table_name = row.tableName
        full_name  = f"{schema}.{table_name}"
        print(f"Optimizing {full_name}")

        try:
            # Get Delta table location and current file count
            detail      = spark.sql(f"DESCRIBE DETAIL {full_name}")
            loc         = detail.select("location").head()[0]
            num_files   = detail.select("numFiles").head()[0]
            delta_table = DeltaTable.forPath(spark, loc)

            # Compaction only for tables with many small files (>20)
            if num_files > 20:
                delta_table.optimize().executeCompaction()
                print(f"  ✔ Compacted ({num_files} files)")
            else:
                print(f"  ⏭ Skipped compaction – only {num_files} files")

            # Apply Z‑ordering on recommended columns (only if they exist)
            z_cols = zorder_columns(table_name)
            if z_cols:
                # Verify columns actually exist in the table
                existing_cols = spark.table(full_name).limit(1).columns
                valid_cols    = [c for c in z_cols if c in existing_cols]
                if valid_cols:
                    delta_table.optimize().executeZOrderBy(valid_cols)
                    print(f"  ✔ Z‑ordered on {valid_cols}")

            # Optional VACUUM (not run by default)
            if RUN_VACUUM:
                delta_table.vacuum(168)   # retain 168 hours (7 days)
                print("  ✔ Vacuumed (retention 168h)")

        except Exception as e:
            print(f"  ✘ Error on {full_name}: {e}")

print("\nDelta table optimization completed.")
# ============================================================================
# End of optimize_delta_tables.py
# ============================================================================