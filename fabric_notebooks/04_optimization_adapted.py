# ============================================================================
# 04_optimization.py
# ============================================================================
# Author:       DataGen AI
# Date:         2026-05-23
# Description:  Compaction & Z‑ordering of Delta tables across all layers.
# ============================================================================

from delta.tables import DeltaTable
from pyspark.sql import SparkSession

spark = SparkSession.builder.getOrCreate()
spark.conf.set("spark.sql.adaptive.enabled", "true")

RUN_VACUUM = False

def zorder_columns(table_name):
    name = table_name.lower()
    if "date" in name: return ["datekey"]
    elif "customer" in name: return ["customerid"]
    elif "product" in name: return ["productid", "category"]
    elif "store" in name: return ["storeid", "region"]
    elif "promo" in name: return ["promoid"]
    elif "sales" in name or "fact" in name: return ["salesid", "datekey", "productid", "customerid", "storeid"]
    else: return None

for schema in ["`01_bronze_db`", "`02_silver_db`", "`03_gold_db`"]:
    for row in spark.sql(f"SHOW TABLES IN {schema}").collect():
        full_name = f"{schema}.{row.tableName}"
        print(f"Optimizing {full_name}")
        try:
            detail = spark.sql(f"DESCRIBE DETAIL {full_name}")
            loc = detail.select("location").head()[0]
            files = detail.select("numFiles").head()[0]
            delta_table = DeltaTable.forPath(spark, loc)
            if files > 20:
                delta_table.optimize().executeCompaction()
                print(f"  Compacted ({files} files)")
            else:
                print(f"  Skipped compaction ({files} files)")

            cols = zorder_columns(row.tableName)
            if cols:
                existing_cols = spark.table(full_name).limit(1).columns
                valid = [c for c in cols if c in existing_cols]
                if valid:
                    delta_table.optimize().executeZOrderBy(valid)
                    print(f"  Z-ordered on {valid}")

            if RUN_VACUUM:
                delta_table.vacuum(168)
                print("  Vacuumed")
        except Exception as e:
            print(f"  Error: {e}")

print("Optimization completed.")
# ============================================================================
# End of 04_optimization.py
# ============================================================================