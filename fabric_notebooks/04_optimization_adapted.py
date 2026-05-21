# -------------------------------------------------------------------
# 04_optimization
# Optimize Delta tables in bronze, silver, and gold layers
# - Compaction (bin-packing) for tables with >20 files
# - Z‑ordering on frequently filtered columns (datekey, productid, etc.)
# - Optional vacuum (retention 168 hours)
# -------------------------------------------------------------------

from delta.tables import DeltaTable
from pyspark.sql import SparkSession

spark = SparkSession.builder.getOrCreate()
spark.conf.set("spark.sql.adaptive.enabled", "true")

# Set to True if you want to run VACUUM (removes old files older than 7 days)
RUN_VACUUM = False

def get_zorder_columns(table_name):
    """Return recommended Z‑order columns based on table name."""
    name_lower = table_name.lower()
    if "date" in name_lower:
        return ["datekey"]
    elif "customer" in name_lower:
        return ["customerid"]
    elif "product" in name_lower:
        return ["productid", "category"]
    elif "store" in name_lower:
        return ["storeid", "region"]
    elif "promotion" in name_lower or "promo" in name_lower:
        return ["promoid"]
    elif "sales" in name_lower or "fact" in name_lower:
        return ["salesid", "datekey", "productid", "customerid", "storeid"]
    else:
        return None

schemas = ["`01_bronze_db`", "`02_silver_db`", "`03_gold_db`"]

for schema in schemas:
    tables = spark.sql(f"SHOW TABLES IN {schema}").collect()
    for tbl in tables:
        full_name = f"{schema}.{tbl.tableName}"
        print(f"Processing {full_name}")

        try:
            # Get Delta table location and metadata
            location_df = spark.sql(f"DESCRIBE DETAIL {full_name}")
            delta_path = location_df.select("location").collect()[0][0]
            delta_table = DeltaTable.forPath(spark, delta_path)

            # Get file count from table statistics
            file_count = spark.sql(f"DESCRIBE DETAIL {full_name}").select("numFiles").collect()[0][0]
            if file_count > 20:
                delta_table.optimize().executeCompaction()
                print(f"  ✔ Compacted {full_name} (files: {file_count})")
            else:
                print(f"  ⏭ Skipping compaction – only {file_count} files")

            # Z‑ordering on recommended columns
            z_cols = get_zorder_columns(tbl.tableName)
            if z_cols:
                # Verify columns exist
                sample_df = spark.table(full_name).limit(1)
                existing_cols = set(sample_df.columns)
                valid_cols = [c for c in z_cols if c in existing_cols]
                if valid_cols:
                    delta_table.optimize().executeZOrderBy(valid_cols)
                    print(f"  ✔ Z-ordered {full_name} on {valid_cols}")

            # Vacuum old files (only if enabled)
            if RUN_VACUUM:
                delta_table.vacuum(168)   # retain 7 days
                print(f"  ✔ Vacuumed {full_name} (retention 168h)")

        except Exception as e:
            print(f"  ✘ Error on {full_name}: {e}")

print("Optimization completed.")