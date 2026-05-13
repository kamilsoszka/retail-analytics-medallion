# Notebook: 04_optimization_adapted
from delta.tables import DeltaTable
from pyspark.sql import SparkSession

spark = SparkSession.builder.getOrCreate()
spark.conf.set("spark.sql.adaptive.enabled", "true")
RUN_VACUUM = False

def get_zorder_columns(table_name):
    table_lower = table_name.lower()
    if "date" in table_lower:
        return ["datekey"]
    elif "customer" in table_lower:
        return ["customerid"]
    elif "product" in table_lower:
        return ["productid", "category"]
    elif "store" in table_lower:
        return ["storeid", "region"]
    elif "promotion" in table_lower or "promo" in table_lower:
        return ["promoid"]
    elif "sales" in table_lower or "fact" in table_lower:
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
            location_df = spark.sql(f"DESCRIBE DETAIL {full_name}")
            delta_path = location_df.select("location").collect()[0][0]
            delta_table = DeltaTable.forPath(spark, delta_path)
            file_count = spark.sql(f"DESCRIBE DETAIL {full_name}").select("numFiles").collect()[0][0]
            if file_count > 20:
                delta_table.optimize().executeCompaction()
                print(f"  Compacted {full_name} (files: {file_count})")
            else:
                print(f"  Skipping compaction – only {file_count} files")
            z_cols = get_zorder_columns(tbl.tableName)
            if z_cols:
                sample_df = spark.table(full_name).limit(1)
                existing_cols = set(sample_df.columns)
                valid_cols = [c for c in z_cols if c in existing_cols]
                if valid_cols:
                    delta_table.optimize().executeZOrderBy(valid_cols)
                    print(f"  Z-ordered on {valid_cols}")
            if RUN_VACUUM:
                delta_table.vacuum(168)
        except Exception as e:
            print(f"  Error: {e}")
print("Optimization done.")