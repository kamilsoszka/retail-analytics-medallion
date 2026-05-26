# ============================================================================
# analyze_csv_data.py
# ============================================================================
# Author:       DataGen AI & Assistant
# Created:      2026-05-23
# Last updated: 2026-05-25 20:10:00 UTC
# Description:
#   Standalone analytical script that reads the CSV files produced by
#   `generate_retail_data.py` and computes the same key metrics as the
#   T‑SQL and PySpark counterparts.
#   Optimized for Pandas memory efficiency by projecting only required columns
#   prior to merges and preventing SettingWithCopyWarnings.
#   Correctly filters out dummy (-1 / 0) rows in dimension quality checks.
#   Dynamic paths mapped relative to the project directory for portability.
# ============================================================================

import os
import pandas as pd
import numpy as np

# ---------------------------------------------------------------------------
# 1. Load CSV files – Dynamically mapped relative to the script's directory
# ---------------------------------------------------------------------------
SCRIPT_DIR  = os.path.dirname(os.path.abspath(__file__))
PROJECT_DIR = os.path.dirname(SCRIPT_DIR)
OUTPUT_DIR  = os.path.join(PROJECT_DIR, "csv")

fact  = pd.read_csv(f"{OUTPUT_DIR}/fact_sales.csv")
prod  = pd.read_csv(f"{OUTPUT_DIR}/dim_product.csv")
cust  = pd.read_csv(f"{OUTPUT_DIR}/dim_customer.csv")
store = pd.read_csv(f"{OUTPUT_DIR}/dim_store.csv")
date  = pd.read_csv(f"{OUTPUT_DIR}/dim_date.csv")
promo = pd.read_csv(f"{OUTPUT_DIR}/dim_promotion.csv")

# ---------------------------------------------------------------------------
# 2. Helper functions for consistent formatting
# ---------------------------------------------------------------------------
def fmt_money(value):
    """Return a string with thousand separators and zero decimal places."""
    return f"{value:,.0f}"

def fmt_pct(value):
    """Return a string representing a fraction (0‑1) as XX.XX%."""
    return f"{value * 100:.2f}%"

# ---------------------------------------------------------------------------
# 3. Core financial KPIs
# ---------------------------------------------------------------------------
print("=" * 60)
print("FINANCIAL KEY PERFORMANCE INDICATORS")
print("=" * 60)

# Pre-filtering non-return sales to reduce execution footprint in downstream queries
nonret_fact = fact[fact['isreturn'] == 0].copy()

# 3.1 Total revenue (excluding returns)
total_revenue = nonret_fact['net'].sum()
print(f"Total revenue (excl. returns): {fmt_money(total_revenue)}")

# 3.2 Total COGS
# Memory optimization: Select only required columns before merging 10M rows
nonret_merged_prod = nonret_fact[['productid', 'qty', 'net', 'salesid', 'discountapplied', 'discountamount', 'grossvalue', 'customerid']].merge(
    prod[['productid', 'unitcost', 'category', 'name', 'margin_pct']], 
    on='productid'
)
total_cogs = (nonret_merged_prod['qty'] * nonret_merged_prod['unitcost']).sum()
print(f"Total COGS:                    {fmt_money(total_cogs)}")

# 3.3 Gross profit
gross_profit = total_revenue - total_cogs
print(f"Gross profit:                  {fmt_money(gross_profit)}")

# 3.4 Gross margin percentage
gross_margin_pct = (gross_profit / total_revenue * 100) if total_revenue != 0 else 0
print(f"Gross margin %:                {gross_margin_pct:.2f}%")

# 3.5 Average basket value
# Optimized: Calculates distinct basket counts on flat fact table instead of merged dataset
num_baskets = nonret_fact['salesid'].nunique()
avg_basket  = total_revenue / num_baskets if num_baskets != 0 else 0
print(f"Average basket value:          {fmt_money(avg_basket)}")

# 3.6 Return rate
return_rate = fact['isreturn'].mean() * 100
print(f"Return rate:                   {return_rate:.2f}%")

# 3.7 Discount penetration
disc_pen = nonret_fact['discountapplied'].mean() * 100
print(f"Discount penetration:          {disc_pen:.2f}%")

# ---------------------------------------------------------------------------
# 4. Revenue breakdowns
# ---------------------------------------------------------------------------
print("\n" + "=" * 60)
print("REVENUE BREAKDOWNS")
print("=" * 60)

def print_formatted_table(df, money_cols=None, pct_cols=None):
    """Apply formatting and print a DataFrame with a 1‑based index."""
    result = df.copy()
    if money_cols:
        for c in money_cols:
            if c in result.columns:
                result[c] = result[c].apply(lambda x: f"{x:,.0f}" if pd.notnull(x) else "")
    if pct_cols:
        for c in pct_cols:
            if c in result.columns:
                result[c] = result[c].apply(lambda x: f"{x*100:.2f}%" if pd.notnull(x) else "")
    result.index = result.index + 1
    print(result.to_string())

# 4.1 Revenue by category (uses pre-merged subset)
print("\nRevenue by category:")
rev_cat = nonret_merged_prod.groupby('category')['net'].sum().sort_values(ascending=False).reset_index()
print_formatted_table(rev_cat, money_cols=['net'])

# 4.2 Revenue by region (projects only storeid and net prior to merging)
print("\nRevenue by region:")
nonret_store = nonret_fact[['storeid', 'net']].merge(
    store[['storeid', 'region', 'storename']], 
    on='storeid'
)
rev_region = nonret_store.groupby('region')['net'].sum().sort_values(ascending=False).reset_index()
print_formatted_table(rev_region, money_cols=['net'])

# 4.3 Top 10 products by revenue (uses pre-merged subset)
print("\nTop 10 products by revenue:")
top10 = nonret_merged_prod.groupby('name')['net'].sum().sort_values(ascending=False).head(10).reset_index()
print_formatted_table(top10, money_cols=['net'])

# 4.4 Top 10 stores by revenue
print("\nTop 10 stores by revenue:")
top_stores = nonret_store.groupby('storename')['net'].sum().sort_values(ascending=False).head(10).reset_index()
print_formatted_table(top_stores, money_cols=['net'])

# ---------------------------------------------------------------------------
# 5. Trend analysis
# ---------------------------------------------------------------------------
print("\n" + "=" * 60)
print("TREND & BEHAVIOUR ANALYSIS")
print("=" * 60)

# 5.1 Monthly revenue trend (projects only datekey and net prior to merging)
nonret_date = nonret_fact[['datekey', 'net']].merge(
    date[['datekey', 'fulldate', 'isweekend']], 
    on='datekey'
).copy() # copy prevents SettingWithCopyWarning on string sliced assignment
nonret_date['yearmonth'] = nonret_date['fulldate'].astype(str).str[:7]
monthly = nonret_date.groupby('yearmonth')['net'].sum().reset_index()
print_formatted_table(monthly, money_cols=['net'])

# 5.2 Weekend vs weekday revenue
weekend_rev = nonret_date.groupby('isweekend')['net'].sum().reset_index()
weekend_rev = weekend_rev.sort_values('isweekend', ascending=True)
print("\nWeekend vs Weekday revenue:")
print_formatted_table(weekend_rev[['isweekend','net']], money_cols=['net'])

# ---------------------------------------------------------------------------
# 6. Additional metrics
# ---------------------------------------------------------------------------
print("\n" + "=" * 60)
print("ADDITIONAL METRICS")
print("=" * 60)

# 6.1 Average discount % for discounted transactions
disc_tx = nonret_fact[nonret_fact['discountapplied'] == 1].copy()
disc_tx['discount_pct'] = disc_tx['discountamount'] / disc_tx['grossvalue']
avg_disc_pct = disc_tx['discount_pct'].mean() * 100
print(f"\nAverage discount % (discounted transactions only): {avg_disc_pct:.2f}%")

# 6.2 Average delivery days by channel
delivery_df = nonret_fact.groupby('channel')['deliverydays'].mean().round(2).reset_index()
print_formatted_table(delivery_df)

# 6.3 Return rate by category (projects only productid and isreturn prior to merging)
merged_ret = fact[['productid', 'isreturn']].merge(prod[['productid', 'category']], on='productid')
ret_cat = merged_ret.groupby('category')['isreturn'].mean().reset_index()
print("\nReturn rate by category:")
print_formatted_table(ret_cat, pct_cols=['isreturn'])

# 6.4 New vs returning customers avg basket (optimized projection)
first_purchase = fact[fact['isreturn'] == 0].groupby('customerid')['datekey'].min().reset_index()
first_purchase.columns = ['customerid', 'first_datekey']
merged_first = fact[['customerid', 'datekey', 'isreturn', 'net']].merge(first_purchase, on='customerid')
merged_first['is_new'] = (merged_first['datekey'] == merged_first['first_datekey']).astype(int)
nonret_first = merged_first[merged_first['isreturn'] == 0]
avg_new = nonret_first[nonret_first['is_new'] == 1]['net'].mean()
avg_ret = nonret_first[nonret_first['is_new'] == 0]['net'].mean()
print(f"\nNew customers avg basket:      {fmt_money(avg_new)}")
print(f"Returning customers avg basket: {fmt_money(avg_ret)}")

# ---------------------------------------------------------------------------
# 7. Quick data quality checks
# ---------------------------------------------------------------------------
print("\n" + "=" * 60)
print("DATA QUALITY CHECKS")
print("=" * 60)

# Exclude technical dummy productid = -1 from statistical evaluation
prod_clean = prod[prod['productid'] > 0]

# 7.1 Product margin distribution
print("\nProduct margin distribution (fraction, excluding technical dummy):")
print(prod_clean['margin_pct'].describe())
print(f"  min: {prod_clean['margin_pct'].min():.4f} ({fmt_pct(prod_clean['margin_pct'].min())})")
print(f"  max: {prod_clean['margin_pct'].max():.4f} ({fmt_pct(prod_clean['margin_pct'].max())})")

margin_min = prod_clean['margin_pct'].min()
margin_max = prod_clean['margin_pct'].max()
if margin_min < -0.10 or margin_max > 0.30:
    print(f"WARNING: Margin outside allowed range [-0.10, 0.30]!")
else:
    print("All margins within allowed range [-0.10, 0.30].")

# Exclude technical dummy promoid = -1 / 0 from statistical evaluation
promo_clean = promo[promo['promoid'] > 0]

# 7.2 Promotion discount fractions
print("\nPromotion discount fraction distribution (excluding technical dummies):")
print(promo_clean['discount_pct'].describe())
print(f"  min: {promo_clean['discount_pct'].min():.4f} ({fmt_pct(promo_clean['discount_pct'].min())})")
print(f"  max: {promo_clean['discount_pct'].max():.4f} ({fmt_pct(promo_clean['discount_pct'].max())})")

# 7.3 NULL checks
null_checks = {
    'hour':         fact['hour'].isnull().sum(),
    'returnreason': fact['returnreason'].isnull().sum(),
    'promoid':      fact['promoid'].isnull().sum()
}
print("\nNULL checks (should be 0):")
for col, cnt in null_checks.items():
    print(f"  {col}: {cnt}")

# 7.4 In-Store deliverydays = 0
instore_nonzero = fact[(fact['channel'] == 'In-Store') & (fact['deliverydays'] != 0)].shape[0]
print(f"In-Store orders with non-zero delivery days: {instore_nonzero} (should be 0)")

print("\n" + "=" * 60)
print("ANALYSIS COMPLETED")
print("=" * 60)
# ============================================================================
# End of analyze_csv_data.py
# ============================================================================