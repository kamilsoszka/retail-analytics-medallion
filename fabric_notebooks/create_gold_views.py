# ============================================================================
# create_gold_views.py
# ============================================================================
# Author:           DataGen AI
# Created:           2026-05-23
# Last modified:     2026-05-24 03:20:00 UTC
# Suggested name:    create_gold_views.py
# Description:
#   Fabric notebook – Gold layer creation.
#   Reads the Silver layer tables from 02_silver_db and creates 17
#   materialised analytical tables (Delta) in 03_gold_db.
#   The views correspond to the T‑SQL analytical views and cover:
#     • Product margin & Pareto analysis
#     • Promotion effectiveness vs baseline
#     • RFM customer segmentation
#     • Returns, channel, seasonal, store performance
#     • Delivery speed, warranty, hourly sales
#     • Basket analysis, price‑tier margins, recency impact
#   All margin and discount columns are kept as fractions (0.0–1.0).
#
# Execution order (medallion architecture):
#   1. ingest_bronze_layer.py
#   2. transform_silver_layer.py
#   3. create_gold_views.py   ← this notebook
#   4. optimize_delta_tables.py
# ============================================================================

from pyspark.sql import SparkSession

# ---------------------------------------------------------------------------
# 1. Initialise Spark session and define schema aliases
# ---------------------------------------------------------------------------
spark = SparkSession.builder.getOrCreate()

target_db = "03_gold_db"
source_db = "02_silver_db"

# Short aliases for cleaner SQL strings
f  = f"`{source_db}`.`silver_factsales`"
p  = f"`{source_db}`.`silver_dimproduct`"
pr = f"`{source_db}`.`silver_dimpromotion`"
d  = f"`{source_db}`.`silver_dimdate`"
s  = f"`{source_db}`.`silver_dimstore`"
c  = f"`{source_db}`.`silver_dimcustomer`"

# ---------------------------------------------------------------------------
# 2. Helper function – creates or replaces a Delta table with a given query
# ---------------------------------------------------------------------------
def create_gold(name, query):
    """Create or replace a materialised view (Delta table) in the Gold layer."""
    spark.sql(f"CREATE OR REPLACE TABLE `{target_db}`.`{name}` USING DELTA AS {query}")
    print(f"  ✓ Created {target_db}.{name}")

# ---------------------------------------------------------------------------
# 3. Gold view definitions
# ---------------------------------------------------------------------------
print("Creating 17 gold tables…")

# 001: Product category margin analysis
create_gold("vw_001_product_category_margin", f"""
WITH revenue_cost AS (
    SELECT p.category, p.productid, p.name,
           SUM(f.qty * p.unitcost) AS total_cost,
           SUM(f.grossvalue - f.discountamount) AS total_revenue
    FROM {f} f JOIN {p} p ON f.productid = p.productid
    WHERE f.isreturn = 0
    GROUP BY p.category, p.productid, p.name
)
SELECT category, productid, name, total_revenue, total_cost,
       total_revenue - total_cost AS total_margin,
       ROUND((total_revenue - total_cost) / NULLIF(total_revenue, 0), 4) AS margin_pct,
       RANK() OVER (PARTITION BY category ORDER BY (total_revenue - total_cost) / NULLIF(total_revenue, 0) DESC) AS rank_in_cat
FROM revenue_cost WHERE total_revenue > 0
""")

# 002: Promotion performance vs baseline
create_gold("vw_002_promo_performance", f"""
WITH promo_perf AS (
    SELECT pr.promoid, pr.promoname, pr.type, pr.discount_pct, pr.promoupliftfactor,
           COUNT(DISTINCT f.salesid) AS num_transactions,
           SUM(f.qty) AS total_qty,
           SUM(f.grossvalue - f.discountamount) AS revenue,
           SUM(f.grossvalue - f.discountamount - (f.qty * p.unitcost)) AS margin,
           AVG(CASE WHEN f.grossvalue > 0 THEN f.discountamount / f.grossvalue ELSE 0 END) AS avg_disc_rate
    FROM {f} f
    JOIN {pr} pr ON f.promoid = pr.promoid
    JOIN {p} p ON f.productid = p.productid
    WHERE pr.promoid != 0 AND f.isreturn = 0
    GROUP BY pr.promoid, pr.promoname, pr.type, pr.discount_pct, pr.promoupliftfactor
),
baseline AS (
    SELECT AVG(f.grossvalue - f.discountamount) AS avg_rev_base,
           AVG(f.qty) AS avg_qty_base
    FROM {f} f WHERE f.promoid = 0 AND f.isreturn = 0
)
SELECT pp.*,
       ROUND(pp.revenue / NULLIF(pp.num_transactions, 0), 2) AS avg_basket,
       ROUND((pp.revenue / NULLIF(pp.num_transactions, 0) - b.avg_rev_base) / NULLIF(b.avg_rev_base, 0), 4) AS uplift_pct,
       ROUND(pp.margin / NULLIF(pp.revenue, 0), 4) AS margin_pct,
       RANK() OVER (ORDER BY pp.margin DESC) AS margin_rank,
       RANK() OVER (ORDER BY (pp.revenue / NULLIF(pp.num_transactions, 0) - b.avg_rev_base) / NULLIF(b.avg_rev_base, 0) DESC) AS uplift_rank
FROM promo_perf pp CROSS JOIN baseline b
""")

# 003: Customer RFM segments
create_gold("vw_003_customer_rfm_segments", f"""
WITH customer_rfm AS (
    SELECT f.customerid,
           DATEDIFF(CURRENT_DATE(), MAX(d.fulldate)) AS recency,
           COUNT(DISTINCT f.salesid) AS frequency,
           SUM(f.grossvalue - f.discountamount) AS monetary,
           SUM(f.grossvalue - f.discountamount - (f.qty * p.unitcost)) AS margin_total
    FROM {f} f JOIN {d} d ON f.datekey = d.datekey JOIN {p} p ON f.productid = p.productid
    WHERE f.isreturn = 0
    GROUP BY f.customerid
),
scored AS (
    SELECT *, NTILE(5) OVER (ORDER BY recency DESC) AS recency_score,
           NTILE(5) OVER (ORDER BY frequency) AS frequency_score,
           NTILE(5) OVER (ORDER BY monetary) AS monetary_score
    FROM customer_rfm
)
SELECT CASE
         WHEN recency_score >= 4 AND frequency_score >= 4 THEN 'Champions'
         WHEN recency_score >= 4 AND frequency_score >= 3 THEN 'Loyal'
         WHEN recency_score >= 3 AND monetary_score >= 4 THEN 'Big Spenders'
         WHEN recency_score <= 2 AND frequency_score <= 2 THEN 'At Risk'
         WHEN recency_score = 1 THEN 'Lost'
         ELSE 'Other'
       END AS segment,
       COUNT(*) AS customers, AVG(monetary) AS avg_ltv, SUM(monetary) AS total_ltv,
       ROUND(AVG(margin_total / NULLIF(monetary, 0)), 4) AS avg_margin_pct
FROM scored GROUP BY segment
""")

# 004: Returns analysis
create_gold("vw_004_returns_analysis", f"""
SELECT channel, returnreason,
       COUNT(*) AS return_count,
       ROUND(1.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY channel), 4) AS pct_of_channel_returns,
       SUM(shipcost) AS total_shipping_cost_returns,
       AVG(grossvalue - discountamount) AS avg_return_value
FROM {f} WHERE isreturn = 1
GROUP BY channel, returnreason
""")

# 005: Channel performance
create_gold("vw_005_channel_performance", f"""
SELECT f.channel,
       COUNT(*) AS transactions,
       AVG(f.deliverydays) AS avg_delivery_days,
       AVG(f.shipcost) AS avg_shipping_cost,
       AVG(f.qty) AS avg_qty,
       AVG(f.grossvalue - f.discountamount) AS avg_basket_value,
       AVG(f.grossvalue - f.discountamount - (f.qty * p.unitcost) - f.shipcost) AS avg_margin_after_shipping,
       ROUND(1.0 * SUM(CASE WHEN f.isreturn = 1 THEN 1 ELSE 0 END) / COUNT(*), 4) AS return_rate
FROM {f} f JOIN {p} p ON f.productid = p.productid
GROUP BY f.channel
""")

# 006: Seasonal category revenue
create_gold("vw_006_seasonal_category_revenue", f"""
SELECT d.monthnumber, d.monthname, p.category,
       SUM(f.grossvalue - f.discountamount) AS revenue,
       SUM(f.qty) AS quantity,
       RANK() OVER (PARTITION BY p.category ORDER BY SUM(f.grossvalue - f.discountamount) DESC) AS rank_in_cat
FROM {f} f JOIN {d} d ON f.datekey = d.datekey JOIN {p} p ON f.productid = p.productid
WHERE f.isreturn = 0
GROUP BY d.monthnumber, d.monthname, p.category
""")

# 007: Store performance by region/type
create_gold("vw_007_store_performance_by_region_type", f"""
SELECT s.region, s.type AS store_type,
       AVG(CAST(s.storerating AS DECIMAL(10,2))) AS avg_rating,
       AVG(CAST(s.sizem2 AS DECIMAL(18,2))) AS avg_size_m2,
       AVG(CAST(s.storesizemultiplier AS DECIMAL(10,3))) AS avg_size_multiplier,
       SUM(CAST(f.grossvalue - f.discountamount AS DECIMAL(18,2))) AS total_revenue,
       SUM(CAST(f.grossvalue - f.discountamount - (f.qty * p.unitcost) AS DECIMAL(18,2))) AS total_margin,
       COUNT(DISTINCT f.customerid) AS unique_customers
FROM {f} f JOIN {s} s ON f.storeid = s.storeid JOIN {p} p ON f.productid = p.productid
WHERE f.isreturn = 0
GROUP BY s.region, s.type
""")

# 008: Pareto margin analysis
create_gold("vw_008_pareto_margin_analysis", f"""
WITH product_margin AS (
    SELECT p.productid, p.name, p.category,
           SUM(f.grossvalue - f.discountamount - (f.qty * p.unitcost)) AS margin
    FROM {f} f JOIN {p} p ON f.productid = p.productid
    WHERE f.isreturn = 0
    GROUP BY p.productid, p.name, p.category
),
running AS (
    SELECT *, SUM(margin) OVER (ORDER BY margin DESC) AS running_margin,
           1.0 * SUM(margin) OVER (ORDER BY margin DESC) / NULLIF(SUM(margin) OVER (), 0) AS running_pct
    FROM product_margin
)
SELECT COUNT(*) AS product_cnt,
       MIN(running_pct) AS min_pct_contribution,
       MAX(running_pct) AS max_pct_contribution
FROM running WHERE running_pct <= 0.8
""")

# 009: Delivery speed impact on returns
create_gold("vw_009_delivery_speed_impact", f"""
WITH delivery_groups AS (
    SELECT f.channel, p.category,
           CASE WHEN f.deliverydays <= 2 THEN 'Fast (1-2 days)'
                WHEN f.deliverydays <= 5 THEN 'Standard (3-5 days)'
                ELSE 'Long (>5 days)' END AS delivery_speed,
           f.isreturn, f.grossvalue - f.discountamount AS order_value
    FROM {f} f JOIN {p} p ON f.productid = p.productid
    WHERE f.channel IN ('Online', 'Mobile App')
)
SELECT channel, category, delivery_speed,
       COUNT(*) AS total_orders,
       SUM(CASE WHEN isreturn = 1 THEN 1 ELSE 0 END) AS returns,
       ROUND(1.0 * SUM(CASE WHEN isreturn = 1 THEN 1 ELSE 0 END) / COUNT(*), 4) AS return_rate,
       AVG(order_value) AS avg_order_value
FROM delivery_groups
GROUP BY channel, category, delivery_speed
""")

# 010: Warranty and eco‑friendly impact
create_gold("vw_010_warranty_eco_impact", f"""
SELECT p.haswarranty, p.ecofriendly,
       AVG(f.qty) AS avg_qty_per_transaction,
       AVG(f.grossvalue - f.discountamount) AS avg_revenue,
       ROUND(1.0 * SUM(CASE WHEN f.isreturn = 1 THEN 1 ELSE 0 END) / COUNT(*), 4) AS return_rate,
       COUNT(DISTINCT f.customerid) AS unique_buyers
FROM {f} f JOIN {p} p ON f.productid = p.productid
GROUP BY p.haswarranty, p.ecofriendly
""")

# 011: Hourly sales and margin analysis (fraction)
create_gold("vw_011_hourly_sales_margin_analysis", f"""
WITH hourly AS (
    SELECT f.hour, f.channel,
           COUNT(*) AS transactions,
           SUM(f.qty) AS items_sold,
           SUM(f.grossvalue - f.discountamount) AS revenue,
           SUM(f.grossvalue - f.discountamount - (f.qty * p.unitcost)) AS gross_margin,
           ROUND(1.0 * SUM(CASE WHEN f.isreturn = 1 THEN 1 ELSE 0 END) / COUNT(*), 4) AS return_rate,
           AVG(f.deliverydays) AS avg_delivery_days
    FROM {f} f JOIN {p} p ON f.productid = p.productid
    WHERE f.isreturn = 0
    GROUP BY f.hour, f.channel
)
SELECT hour, channel, transactions, items_sold,
       ROUND(revenue, 2) AS revenue,
       ROUND(gross_margin, 2) AS gross_margin,
       ROUND(gross_margin / NULLIF(revenue, 0), 4) AS margin_pct,
       return_rate, avg_delivery_days,
       RANK() OVER (PARTITION BY channel ORDER BY revenue DESC) AS revenue_rank_in_channel
FROM hourly WHERE hour IS NOT NULL
""")

# 012: Pareto revenue & margin combined
create_gold("vw_012_pareto_revenue_margin", f"""
WITH prod_agg AS (
    SELECT p.productid, p.name, p.category,
           SUM(f.grossvalue - f.discountamount) AS revenue,
           SUM(f.grossvalue - f.discountamount - (f.qty * p.unitcost)) AS margin
    FROM {f} f JOIN {p} p ON f.productid = p.productid
    WHERE f.isreturn = 0
    GROUP BY p.productid, p.name, p.category
),
run AS (
    SELECT *, SUM(revenue) OVER (ORDER BY revenue DESC) AS run_rev, SUM(revenue) OVER () AS tot_rev,
           SUM(margin) OVER (ORDER BY margin DESC) AS run_mar, SUM(margin) OVER () AS tot_mar
    FROM prod_agg
)
SELECT COUNT(*) AS products_needed_for_80pct_revenue,
       MIN(CASE WHEN run_rev / tot_rev >= 0.8 THEN revenue END) AS min_rev_in_top80,
       COUNT(CASE WHEN run_mar / tot_mar <= 0.8 THEN 1 END) AS products_needed_for_80pct_margin,
       MIN(CASE WHEN run_mar / tot_mar >= 0.8 THEN margin END) AS min_margin_in_top80
FROM run
WHERE run_rev / tot_rev <= 0.8 OR run_mar / tot_mar <= 0.8
""")

# 013: Basket analysis – frequently bought together
create_gold("vw_013_basket_analysis", f"""
WITH pairs AS (
    SELECT f1.productid AS product_a, f2.productid AS product_b,
           COUNT(*) AS co_occurrence
    FROM {f} f1
    INNER JOIN {f} f2 ON f1.salesid = f2.salesid AND f1.productid < f2.productid
    WHERE f1.isreturn = 0 AND f2.isreturn = 0
    GROUP BY f1.productid, f2.productid
),
pop AS (
    SELECT productid, COUNT(DISTINCT salesid) AS total_baskets
    FROM {f} WHERE isreturn = 0
    GROUP BY productid
)
SELECT pa.product_a, pa.product_b, pa.co_occurrence,
       p1.total_baskets AS baskets_a, p2.total_baskets AS baskets_b,
       ROUND(1.0 * pa.co_occurrence / p1.total_baskets, 4) AS lift_a_to_b,
       ROUND(1.0 * pa.co_occurrence / p2.total_baskets, 4) AS lift_b_to_a
FROM pairs pa
JOIN pop p1 ON pa.product_a = p1.productid
JOIN pop p2 ON pa.product_b = p2.productid
ORDER BY pa.co_occurrence DESC
LIMIT 100
""")

# 014: Detailed delivery speed impact on margin (fraction)
create_gold("vw_014_delivery_speed_impact_detailed", f"""
WITH stats AS (
    SELECT CASE WHEN f.deliverydays <= 2 THEN 'Fast (1-2)'
                WHEN f.deliverydays <= 5 THEN 'Normal (3-5)'
                ELSE 'Slow (6+)' END AS delivery_speed,
           f.channel,
           COUNT(*) AS orders,
           SUM(CASE WHEN f.isreturn = 1 THEN 1 ELSE 0 END) AS returns,
           ROUND(AVG(f.grossvalue - f.discountamount), 2) AS avg_order_value,
           ROUND(AVG(f.grossvalue - f.discountamount - (f.qty * p.unitcost)), 2) AS avg_margin,
           ROUND(AVG(f.shipcost), 2) AS avg_shipcost
    FROM {f} f JOIN {p} p ON f.productid = p.productid
    WHERE f.channel IN ('Online', 'Mobile App') AND f.deliverydays > 0
    GROUP BY delivery_speed, f.channel
)
SELECT delivery_speed, channel, orders, returns,
       ROUND(1.0 * returns / NULLIF(orders, 0), 4) AS return_rate,
       avg_order_value, avg_margin,
       ROUND(avg_margin / NULLIF(avg_order_value, 0), 4) AS margin_pct,
       avg_shipcost
FROM stats
""")

# 015: Margin by price tier and category (fraction)
create_gold("vw_015_margin_by_price_tier", f"""
WITH tiers AS (
    SELECT CASE WHEN p.unitprice < 50 THEN 'Budget (<50)'
                WHEN p.unitprice < 200 THEN 'Mid (50-200)'
                WHEN p.unitprice < 500 THEN 'Premium (200-500)'
                ELSE 'Luxury (500+)' END AS price_tier,
           p.category,
           COUNT(DISTINCT p.productid) AS products,
           SUM(f.qty) AS total_qty,
           SUM(f.grossvalue - f.discountamount) AS revenue,
           SUM(f.grossvalue - f.discountamount - (f.qty * p.unitcost)) AS total_margin,
           AVG(p.margin_pct) AS avg_product_margin_pct
    FROM {f} f JOIN {p} p ON f.productid = p.productid
    WHERE f.isreturn = 0
    GROUP BY price_tier, p.category
)
SELECT price_tier, category, products, total_qty,
       ROUND(revenue, 2) AS revenue,
       ROUND(total_margin, 2) AS total_margin,
       ROUND(total_margin / NULLIF(revenue, 0), 4) AS achieved_margin_pct,
       avg_product_margin_pct,
       ROUND(avg_product_margin_pct - (total_margin / NULLIF(revenue, 0)), 4) AS margin_deviation
FROM tiers
""")

# 016: Recency impact on spend (fraction)
create_gold("vw_016_recency_impact_on_spend", f"""
WITH last_purchase AS (
    SELECT customerid, MAX(datekey) AS last_key
    FROM {f} WHERE isreturn = 0
    GROUP BY customerid
),
recency AS (
    SELECT c.customerid,
           DATEDIFF(CURRENT_DATE(), d.fulldate) AS days_since_last,
           CASE WHEN DATEDIFF(CURRENT_DATE(), d.fulldate) <= 30 THEN 'Active (0-30 days)'
                WHEN DATEDIFF(CURRENT_DATE(), d.fulldate) <= 90 THEN 'Recent (31-90 days)'
                WHEN DATEDIFF(CURRENT_DATE(), d.fulldate) <= 180 THEN 'Dormant (91-180 days)'
                ELSE 'Churned (>180 days)' END AS recency_segment
    FROM last_purchase c JOIN {d} d ON c.last_key = d.datekey
),
future AS (
    SELECT f.customerid, f.salesid,
           f.grossvalue - f.discountamount AS order_value,
           f.grossvalue - f.discountamount - (f.qty * p.unitcost) AS order_margin
    FROM {f} f JOIN {p} p ON f.productid = p.productid
    WHERE f.isreturn = 0
)
SELECT r.recency_segment,
       COUNT(DISTINCT r.customerid) AS customers,
       AVG(f.order_value) AS avg_order_value,
       AVG(f.order_margin) AS avg_order_margin,
       ROUND(AVG(f.order_margin) / NULLIF(AVG(f.order_value), 0), 4) AS avg_margin_pct,
       COUNT(f.salesid) / COUNT(DISTINCT r.customerid) AS avg_orders_per_customer
FROM recency r
LEFT JOIN future f ON r.customerid = f.customerid
GROUP BY r.recency_segment
""")

# 017: Promotion margin efficiency (fraction)
create_gold("vw_017_promo_margin_efficiency", f"""
WITH promo_impact AS (
    SELECT pr.promoid, pr.promoname, pr.type, pr.discount_pct,
           AVG(f.grossvalue - f.discountamount) AS avg_basket,
           AVG(f.grossvalue - f.discountamount - (f.qty * p.unitcost)) AS avg_margin,
           COUNT(*) AS txn,
           SUM(f.grossvalue - f.discountamount - (f.qty * p.unitcost)) AS total_margin
    FROM {f} f
    JOIN {pr} pr ON f.promoid = pr.promoid
    JOIN {p} p ON f.productid = p.productid
    WHERE pr.promoid != 0 AND f.isreturn = 0
    GROUP BY pr.promoid, pr.promoname, pr.type, pr.discount_pct
),
baseline AS (
    SELECT AVG(f.grossvalue - f.discountamount) AS base_basket,
           AVG(f.grossvalue - f.discountamount - (f.qty * p.unitcost)) AS base_margin
    FROM {f} f JOIN {p} p ON f.productid = p.productid
    WHERE f.promoid = 0 AND f.isreturn = 0
)
SELECT pi.promoid, pi.promoname, pi.type, pi.discount_pct,
       pi.txn, pi.avg_basket, pi.avg_margin,
       ROUND(pi.avg_basket - b.base_basket, 2) AS basket_increase,
       ROUND(pi.avg_margin - b.base_margin, 2) AS margin_increase,
       ROUND((pi.avg_margin - b.base_margin) / NULLIF(b.base_margin, 0), 4) AS margin_uplift_pct,
       ROUND(pi.total_margin / NULLIF(pi.txn, 0), 2) AS actual_margin_per_txn,
       RANK() OVER (ORDER BY (pi.avg_margin - b.base_margin) DESC) AS margin_effectiveness_rank
FROM promo_impact pi CROSS JOIN baseline b
""")

print("\n✅ All 17 gold tables created in 03_gold_db (margins as fractions).")
# ============================================================================
# End of create_gold_views.py
# ============================================================================