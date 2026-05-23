# ============================================================================
# 06_analysis_queries.py
# ============================================================================
# Author:       DataGen AI
# Date:         2026-05-23
# Description:  Analytical queries on silver data for quick insights.
#               All _pct columns are fractions (0.0–1.0).
#               Results are multiplied by 100 for display as percentages.
# ============================================================================

from pyspark.sql import SparkSession
from pyspark.sql.functions import col, sum as spark_sum, avg, desc, substring, when, min, countDistinct

spark = SparkSession.builder.getOrCreate()

fact = spark.table("02_silver_db.silver_factsales")
prod = spark.table("02_silver_db.silver_dimproduct")
store = spark.table("02_silver_db.silver_dimstore")
date = spark.table("02_silver_db.silver_dimdate")

def to_float(val):
    return float(val) if val is not None else 0.0

# 1. Total revenue
total_rev = to_float(fact.filter(col("isreturn") == 0).select(spark_sum("net")).head()[0])
print(f"Total revenue: {total_rev:,.2f}")

# 2. Total COGS
merged = fact.join(prod, "productid").filter(col("isreturn") == 0)
total_cogs = to_float(merged.select(spark_sum(col("qty") * col("unitcost"))).head()[0])
print(f"Total COGS: {total_cogs:,.2f}")

# 3. Gross profit & margin
gross = total_rev - total_cogs
margin = gross / total_rev if total_rev else 0
print(f"Gross profit: {gross:,.2f}  Margin: {margin*100:.2f}%")

# 4. Average basket
baskets = to_float(fact.filter(col("isreturn") == 0).select(countDistinct("salesid")).head()[0])
avg_basket = total_rev / baskets if baskets else 0
print(f"Avg basket: {avg_basket:,.2f}")

# 5. Return rate
ret_rate = to_float(fact.select(avg("isreturn")).head()[0])
print(f"Return rate: {ret_rate*100:.2f}%")

# 6. Discount penetration
disc_pen = to_float(fact.filter(col("isreturn") == 0).select(avg("discountapplied")).head()[0])
print(f"Discount penetration: {disc_pen*100:.2f}%")

# 7. Revenue by category
print("\nRevenue by category:")
fact.join(prod, "productid").filter(col("isreturn") == 0).groupBy("category") \
    .agg(spark_sum("net").alias("revenue")).orderBy(desc("revenue")).show(10, False)

# 8. Revenue by region
print("\nRevenue by region:")
fact.join(store, "storeid").filter(col("isreturn") == 0).groupBy("region") \
    .agg(spark_sum("net").alias("revenue")).orderBy(desc("revenue")).show(10, False)

# 9. Top 10 products
print("\nTop 10 products by revenue:")
fact.join(prod, "productid").filter(col("isreturn") == 0).groupBy("name") \
    .agg(spark_sum("net").alias("revenue")).orderBy(desc("revenue")).limit(10).show(10, False)

# 10. Monthly revenue trend
print("\nMonthly revenue trend:")
fact.join(date, "datekey").filter(col("isreturn") == 0) \
    .withColumn("yearmonth", substring("fulldate", 1, 7)).groupBy("yearmonth") \
    .agg(spark_sum("net").alias("revenue")).orderBy("yearmonth").show(50, False)

# 11. Average discount % for discounted transactions
disc_tx = fact.filter((col("isreturn") == 0) & (col("discountapplied") == 1))
avg_disc_pct = to_float(disc_tx.select(avg(col("discountamount") / col("grossvalue"))).head()[0])
print(f"\nAverage discount %: {avg_disc_pct*100:.2f}%")

# 12. Average delivery days by channel
print("\nAverage delivery days by channel:")
fact.filter(col("isreturn") == 0).groupBy("channel") \
    .agg(avg("deliverydays").alias("avg_days")).show(10, False)

# 13. Return rate by category
print("\nReturn rate by category:")
fact.join(prod, "productid").groupBy("category") \
    .agg(avg("isreturn").alias("return_rate")).show(10, False)

# 14. New vs returning customer avg basket
first_purchase = fact.groupBy("customerid").agg(min("datekey").alias("first_key"))
merged_first = fact.join(first_purchase, "customerid") \
    .withColumn("is_new", when(col("datekey") == col("first_key"), 1).otherwise(0))
nonret_first = merged_first.filter(col("isreturn") == 0)
avg_new = to_float(nonret_first.filter(col("is_new") == 1).select(avg("net")).head()[0])
avg_ret = to_float(nonret_first.filter(col("is_new") == 0).select(avg("net")).head()[0])
print(f"\nNew customers avg basket: {avg_new:,.2f}")
print(f"Returning customers avg basket: {avg_ret:,.2f}")

# 15. Weekend vs weekday revenue
print("\nWeekend vs Weekday revenue:")
fact.join(date, "datekey").filter(col("isreturn") == 0).groupBy("isweekend") \
    .agg(spark_sum("net").alias("revenue")).orderBy("isweekend").show()

# 16. Top 10 stores by revenue
print("\nTop 10 stores by revenue:")
fact.join(store, "storeid").filter(col("isreturn") == 0).groupBy("storename") \
    .agg(spark_sum("net").alias("revenue")).orderBy(desc("revenue")).limit(10).show(10, False)

print("\nAnalysis completed.")
# ============================================================================
# End of 06_analysis_queries.py
# ============================================================================