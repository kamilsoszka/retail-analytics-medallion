# ============================================================================
# analyze_silver_data.py
# ============================================================================
# Author:           DataGen AI
# Created:           2026-05-23
# Last modified:     2026-05-24 04:00:00 UTC
# Suggested name:    analyze_silver_data.py
# Description:
#   Fabric notebook – analytical queries on Silver layer data.
#   Loads tables from 02_silver_db and computes key business metrics:
#     • Total revenue, COGS, gross profit & margin
#     • Average basket value, return rate, discount penetration
#     • Revenue by category, region, store, product
#     • Monthly revenue trend, delivery days, return rate by category
#     • New vs returning customer basket, weekend/weekday revenue
#   All monetary values are formatted with thousand separators and zero
#   decimal places.  Percentages are displayed with two decimal places
#   (e.g. 12.34%).
#   Results are printed directly to the notebook output.
# ============================================================================

import pandas as pd
from pyspark.sql import SparkSession
from pyspark.sql.functions import (
    col, sum as spark_sum, avg, desc, substring,
    when, min, countDistinct
)

# ---------------------------------------------------------------------------
# 1. Initialise Spark session and load Silver tables
# ---------------------------------------------------------------------------
spark = SparkSession.builder.getOrCreate()

fact  = spark.table("02_silver_db.silver_factsales")
prod  = spark.table("02_silver_db.silver_dimproduct")
store = spark.table("02_silver_db.silver_dimstore")
date  = spark.table("02_silver_db.silver_dimdate")

# ---------------------------------------------------------------------------
# 2. Helper functions
# ---------------------------------------------------------------------------
def to_float(val):
    """Safely convert a Spark aggregate result to a Python float."""
    return float(val) if val is not None else 0.0

def fmt_money(value):
    """Format a number as currency with thousand separators, zero decimals."""
    return f"{value:,.0f}"

def fmt_pct(value):
    """Format a fraction (0‑1) as a percentage with two decimal places."""
    return f"{value * 100:.2f}%"

def spark_df_to_pandas(df, money_cols=None, pct_cols=None, limit=None):
    """
    Convert a Spark DataFrame to a Pandas DataFrame and apply formatting.
    money_cols : list of column names to format with thousand separators.
    pct_cols   : list of column names to format as percentages.
    limit      : optional maximum number of rows to return.
    """
    if limit:
        df = df.limit(limit)
    pdf = df.toPandas()
    if money_cols:
        for c in money_cols:
            if c in pdf.columns:
                pdf[c] = pdf[c].apply(lambda x: f"{x:,.0f}" if pd.notnull(x) else "")
    if pct_cols:
        for c in pct_cols:
            if c in pdf.columns:
                pdf[c] = pdf[c].apply(lambda x: f"{x*100:.2f}%" if pd.notnull(x) else "")
    return pdf

# ---------------------------------------------------------------------------
# 3. Core financial KPIs (scalar values)
# ---------------------------------------------------------------------------
print("=" * 60)
print("FINANCIAL KEY PERFORMANCE INDICATORS")
print("=" * 60)

# 3.1 Total revenue (excluding returns)
total_rev = to_float(
    fact.filter(col("isreturn") == 0)
        .select(spark_sum("net"))
        .head()[0]
)
print(f"Total revenue (excl. returns): {fmt_money(total_rev)}")

# 3.2 Total COGS
merged = fact.join(prod, "productid").filter(col("isreturn") == 0)
total_cogs = to_float(
    merged.select(spark_sum(col("qty") * col("unitcost"))).head()[0]
)
print(f"Total COGS:                    {fmt_money(total_cogs)}")

# 3.3 Gross profit
gross_profit = total_rev - total_cogs
print(f"Gross profit:                  {fmt_money(gross_profit)}")

# 3.4 Gross margin percentage
gross_margin_pct = (gross_profit / total_rev * 100) if total_rev else 0
print(f"Gross margin %:                {gross_margin_pct:.2f}%")

# 3.5 Average basket value
nonret = fact.filter(col("isreturn") == 0)
num_baskets = to_float(nonret.select(countDistinct("salesid")).head()[0])
avg_basket = total_rev / num_baskets if num_baskets else 0
print(f"Average basket value:          {fmt_money(avg_basket)}")

# 3.6 Return rate
ret_rate = to_float(fact.select(avg("isreturn")).head()[0])
print(f"Return rate:                   {fmt_pct(ret_rate)}")

# 3.7 Discount penetration
disc_pen = to_float(
    nonret.select(avg("discountapplied")).head()[0]
)
print(f"Discount penetration:          {fmt_pct(disc_pen)}")

# ---------------------------------------------------------------------------
# 4. Revenue by category, region, top products (tabular, with formatting)
# ---------------------------------------------------------------------------
print("\n" + "=" * 60)
print("REVENUE BREAKDOWNS")
print("=" * 60)

# 4.1 Revenue by category
print("\nRevenue by category:")
cat_rev = spark_df_to_pandas(
    fact.join(prod, "productid")
        .filter(col("isreturn") == 0)
        .groupBy("category")
        .agg(spark_sum("net").alias("revenue"))
        .orderBy(desc("revenue")),
    money_cols=["revenue"]
)
cat_rev.index = cat_rev.index + 1
print(cat_rev.to_string())

# 4.2 Revenue by region
print("\nRevenue by region:")
reg_rev = spark_df_to_pandas(
    fact.join(store, "storeid")
        .filter(col("isreturn") == 0)
        .groupBy("region")
        .agg(spark_sum("net").alias("revenue"))
        .orderBy(desc("revenue")),
    money_cols=["revenue"]
)
reg_rev.index = reg_rev.index + 1
print(reg_rev.to_string())

# 4.3 Top 10 products by revenue
print("\nTop 10 products by revenue:")
top_prod = spark_df_to_pandas(
    fact.join(prod, "productid")
        .filter(col("isreturn") == 0)
        .groupBy("name")
        .agg(spark_sum("net").alias("revenue"))
        .orderBy(desc("revenue"))
        .limit(10),
    money_cols=["revenue"]
)
top_prod.index = top_prod.index + 1
print(top_prod.to_string())

# 4.4 Top 10 stores by revenue
print("\nTop 10 stores by revenue:")
top_store = spark_df_to_pandas(
    fact.join(store, "storeid")
        .filter(col("isreturn") == 0)
        .groupBy("storename")
        .agg(spark_sum("net").alias("revenue"))
        .orderBy(desc("revenue"))
        .limit(10),
    money_cols=["revenue"]
)
top_store.index = top_store.index + 1
print(top_store.to_string())

# ---------------------------------------------------------------------------
# 5. Trend analysis
# ---------------------------------------------------------------------------
print("\n" + "=" * 60)
print("TREND & BEHAVIOUR ANALYSIS")
print("=" * 60)

# 5.1 Monthly revenue trend
print("\nMonthly revenue trend:")
monthly_rev = spark_df_to_pandas(
    fact.join(date, "datekey")
        .filter(col("isreturn") == 0)
        .withColumn("yearmonth", substring("fulldate", 1, 7))
        .groupBy("yearmonth")
        .agg(spark_sum("net").alias("revenue"))
        .orderBy("yearmonth"),
    money_cols=["revenue"]
)
monthly_rev.index = monthly_rev.index + 1
print(monthly_rev.to_string())

# 5.2 Weekend vs weekday revenue
print("\nWeekend vs Weekday revenue:")
weekend_rev = spark_df_to_pandas(
    fact.join(date, "datekey")
        .filter(col("isreturn") == 0)
        .groupBy("isweekend")
        .agg(spark_sum("net").alias("revenue"))
        .orderBy("isweekend"),
    money_cols=["revenue"]
)
weekend_rev.index = weekend_rev.index + 1
print(weekend_rev.to_string())

# ---------------------------------------------------------------------------
# 6. Additional metrics
# ---------------------------------------------------------------------------
print("\n" + "=" * 60)
print("ADDITIONAL METRICS")
print("=" * 60)

# 6.1 Average discount % for discounted transactions
disc_tx = fact.filter((col("isreturn") == 0) & (col("discountapplied") == 1))
avg_disc = to_float(
    disc_tx.select(avg(col("discountamount") / col("grossvalue"))).head()[0]
)
print(f"\nAverage discount % (discounted transactions only): {fmt_pct(avg_disc)}")

# 6.2 Average delivery days by channel
print("\nAverage delivery days by channel:")
delivery_df = spark_df_to_pandas(
    nonret.groupBy("channel")
          .agg(avg("deliverydays").alias("avg_delivery_days")),
    pct_cols=[]  # keep raw number, no formatting needed
)
delivery_df.index = delivery_df.index + 1
print(delivery_df.to_string())

# 6.3 Return rate by category
print("\nReturn rate by category:")
ret_cat = spark_df_to_pandas(
    fact.join(prod, "productid")
        .groupBy("category")
        .agg(avg("isreturn").alias("return_rate")),
    pct_cols=["return_rate"]
)
ret_cat.index = ret_cat.index + 1
print(ret_cat.to_string())

# 6.4 New vs returning customer average basket
first_purchase = fact.groupBy("customerid").agg(min("datekey").alias("first_key"))
merged_first = fact.join(first_purchase, "customerid") \
    .withColumn("is_new", when(col("datekey") == col("first_key"), 1).otherwise(0))
nonret_first = merged_first.filter(col("isreturn") == 0)

avg_new_basket = to_float(
    nonret_first.filter(col("is_new") == 1).select(avg("net")).head()[0]
)
avg_ret_basket = to_float(
    nonret_first.filter(col("is_new") == 0).select(avg("net")).head()[0]
)
print(f"\nNew customers avg basket:      {fmt_money(avg_new_basket)}")
print(f"Returning customers avg basket: {fmt_money(avg_ret_basket)}")

print("\n" + "=" * 60)
print("ANALYSIS COMPLETED")
print("=" * 60)
# ============================================================================
# End of analyze_silver_data.py
# ============================================================================