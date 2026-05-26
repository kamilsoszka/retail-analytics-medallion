# ============================================================================
# create_gold_views.py
# ============================================================================
# Author:           DataGen AI & Assistant
# Created:          2026-05-23
# Last modified:    2026-05-26 09:40:00 UTC
# Suggested name:   create_gold_views.py
# Description:
#   Fabric notebook – Gold layer creation.
#   Reads the Silver layer tables from 02_silver_db and creates 17
#   materialised analytical tables (Delta) in 03_gold_db.
#   Each query has been refactored with "Aggregate-then-Join" patterns
#   to leverage Spark SQL's columnar engine and maximize write performance.
#   All margin and discount columns are kept as fractions (0.0–1.0).
# ============================================================================

from pyspark.sql import SparkSession

# ---------------------------------------------------------------------------
# 1. Initialise Spark session and define schema aliases
# ---------------------------------------------------------------------------
spark = SparkSession.builder.getOrCreate()

target_db = "03_gold_db"
source_db = "02_silver_db"

# Ensure target gold database exists in Spark catalog
spark.sql(f"CREATE DATABASE IF NOT EXISTS `{target_db}`")

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
# Optimized: Aggregates over productid first, then joins product dimensions
create_gold("vw_001_product_category_margin", f"""
WITH sales_agg AS (
    SELECT productid,
           SUM(qty) AS total_qty,
           SUM(grossvalue - discountamount) AS total_revenue
    FROM {f}
    WHERE isreturn = 0
    GROUP BY productid
)
SELECT p.category,
       p.productid,
       p.name,
       sa.total_revenue,
       CAST(sa.total_qty * p.unitcost AS DECIMAL(18,2)) AS total_cost,
       CAST(sa.total_revenue - (sa.total_qty * p.unitcost) AS DECIMAL(18,2)) AS total_margin,
       ROUND((sa.total_revenue - (sa.total_qty * p.unitcost)) / NULLIF(sa.total_revenue, 0), 4) AS margin_pct,
       RANK() OVER (PARTITION BY p.category ORDER BY (sa.total_revenue - (sa.total_qty * p.unitcost)) / NULLIF(sa.total_revenue, 0) DESC) AS rank_in_cat
FROM sales_agg sa
INNER JOIN {p} p ON sa.productid = p.productid
WHERE sa.total_revenue > 0
""")

# 002: Promotion performance vs baseline
# Optimized: Computes distinct transaction counts and product margins in parallel CTEs
create_gold("vw_002_promo_performance", f"""
WITH promo_tx AS (
    SELECT promoid,
           COUNT(DISTINCT salesid) AS num_transactions,
           AVG(CASE WHEN grossvalue > 0 THEN discountamount / grossvalue ELSE 0 END) AS avg_disc_rate
    FROM {f}
    WHERE isreturn = 0
    GROUP BY promoid
),
sales_promo_prod AS (
    SELECT promoid,
           productid,
           SUM(qty) AS total_qty,
           SUM(grossvalue - discountamount) AS revenue
    FROM {f}
    WHERE isreturn = 0
    GROUP BY promoid, productid
),
promo_margin AS (
    SELECT spp.promoid,
           SUM(spp.total_qty) AS total_qty,
           SUM(spp.revenue) AS revenue,
           SUM(spp.revenue - (spp.total_qty * p.unitcost)) AS margin
    FROM sales_promo_prod spp
    INNER JOIN {p} p ON spp.productid = p.productid
    GROUP BY spp.promoid
),
promo_perf AS (
    SELECT pr.promoid,
           pr.promoname,
           pr.type,
           pr.discount_pct,
           pr.promoupliftfactor,
           pt.num_transactions,
           pm.total_qty,
           pm.revenue,
           pm.margin,
           pt.avg_disc_rate
    FROM {pr} pr
    INNER JOIN promo_margin pm ON pr.promoid = pm.promoid
    INNER JOIN promo_tx pt      ON pr.promoid = pt.promoid
    WHERE pr.promoid != 0
),
baseline AS (
    SELECT AVG(f.grossvalue - f.discountamount) AS avg_rev_base,
           AVG(CAST(f.qty AS DECIMAL(18,2))) AS avg_qty_base
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
# Optimized: Structured aggregation steps to scale RFM scoring efficiently
create_gold("vw_003_customer_rfm_segments", f"""
WITH customer_sales AS (
    SELECT f.customerid,
           f.productid,
           SUM(f.qty) AS total_qty,
           SUM(f.grossvalue - f.discountamount) AS net_revenue
    FROM {f} f
    WHERE f.isreturn = 0
    GROUP BY f.customerid, f.productid
),
customer_margins AS (
    SELECT cs.customerid,
           SUM(cs.net_revenue) AS monetary,
           SUM(cs.net_revenue - (cs.total_qty * p.unitcost)) AS margin_total
    FROM customer_sales cs
    INNER JOIN {p} p ON cs.productid = p.productid
    GROUP BY cs.customerid
),
customer_recency_freq AS (
    SELECT f.customerid,
           MAX(f.datekey) AS max_datekey,
           COUNT(DISTINCT f.salesid) AS frequency
    FROM {f} f
    WHERE f.isreturn = 0
    GROUP BY f.customerid
),
customer_base_metrics AS (
    SELECT crf.customerid,
           DATEDIFF(CURRENT_DATE(), d.fulldate) AS recency,
           crf.frequency,
           cm.monetary,
           cm.margin_total
    FROM customer_recency_freq crf
    INNER JOIN customer_margins cm ON crf.customerid = cm.customerid
    INNER JOIN {d} d        ON crf.max_datekey = d.datekey
),
scored AS (
    SELECT *, NTILE(5) OVER (ORDER BY recency DESC) AS recency_score,
           NTILE(5) OVER (ORDER BY frequency) AS frequency_score,
           NTILE(5) OVER (ORDER BY monetary) AS monetary_score
    FROM customer_base_metrics
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
# Optimized: Aggregates on channel-product level before joining dimproduct
create_gold("vw_005_channel_performance", f"""
WITH sales_agg AS (
    SELECT f.channel,
           f.productid,
           COUNT(*) AS transactions,
           SUM(f.deliverydays) AS total_delivery_days,
           SUM(f.shipcost) AS total_shipcost,
           SUM(f.qty) AS total_qty,
           SUM(f.grossvalue - f.discountamount) AS total_net_revenue,
           SUM(CASE WHEN f.isreturn = 1 THEN 1 ELSE 0 END) AS return_count
    FROM {f} f
    GROUP BY f.channel, f.productid
)
SELECT sa.channel,
       SUM(sa.transactions) AS transactions,
       ROUND(CAST(SUM(sa.total_delivery_days) AS DECIMAL(18,2)) / NULLIF(SUM(sa.transactions), 0), 2) AS avg_delivery_days,
       ROUND(SUM(sa.total_shipcost) / NULLIF(SUM(sa.transactions), 0), 2) AS avg_shipping_cost,
       ROUND(CAST(SUM(sa.total_qty) AS DECIMAL(18,2)) / NULLIF(SUM(sa.transactions), 0), 2) AS avg_qty,
       ROUND(SUM(sa.total_net_revenue) / NULLIF(SUM(sa.transactions), 0), 2) AS avg_basket_value,
       ROUND(SUM(sa.total_net_revenue - (sa.total_qty * p.unitcost) - sa.total_shipcost) / NULLIF(SUM(sa.transactions), 0), 2) AS avg_margin_after_shipping,
       ROUND(1.0 * SUM(sa.return_count) / NULLIF(SUM(sa.transactions), 0), 4) AS return_rate
FROM sales_agg sa
INNER JOIN {p} p ON sa.productid = p.productid
GROUP BY sa.channel
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
# Optimized: Avoids complex joins on the full 10M-row fact table prior to aggregation
create_gold("vw_007_store_performance_by_region_type", f"""
WITH sales_agg AS (
    SELECT f.storeid,
           f.productid,
           SUM(f.grossvalue - f.discountamount) AS revenue,
           SUM(f.qty) AS qty
    FROM {f} f
    WHERE f.isreturn = 0
    GROUP BY f.storeid, f.productid
),
store_prod_agg AS (
    SELECT sa.storeid,
           SUM(sa.revenue) AS revenue,
           SUM(sa.revenue - (sa.qty * p.unitcost)) AS margin
    FROM sales_agg sa
    INNER JOIN {p} p ON sa.productid = p.productid
    GROUP BY sa.storeid
),
store_unique_custs AS (
    SELECT f.storeid,
           COUNT(DISTINCT f.customerid) AS unique_customers
    FROM {f} f
    WHERE f.isreturn = 0
    GROUP BY f.storeid
)
SELECT s.region, s.type AS store_type,
       ROUND(AVG(s.storerating), 2) AS avg_rating,
       ROUND(AVG(CAST(s.sizem2 AS DECIMAL(18,2))), 2) AS avg_size_m2,
       ROUND(AVG(s.storesizemultiplier), 4) AS avg_size_multiplier,
       SUM(spa.revenue) AS total_revenue,
       SUM(spa.margin) AS total_margin,
       SUM(suc.unique_customers) AS unique_customers
FROM {s} s
INNER JOIN store_prod_agg spa       ON s.storeid = spa.storeid
INNER JOIN store_unique_custs suc   ON s.storeid = suc.storeid
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
# Optimized: Resolves the hourly metrics pre-joining to speed up Columnstore-style operations
create_gold("vw_011_hourly_sales_margin_analysis", f"""
WITH sales_agg AS (
    SELECT f.hour,
           f.channel,
           f.productid,
           COUNT(*) AS transactions,
           SUM(f.qty) AS items_sold,
           SUM(f.grossvalue - f.discountamount) AS revenue,
           SUM(CASE WHEN f.isreturn = 1 THEN 1 ELSE 0 END) AS return_count,
           SUM(f.deliverydays) AS total_delivery_days
    FROM {f} f
    GROUP BY f.hour, f.channel, f.productid
),
hourly_prod_margin AS (
    SELECT sa.hour,
           sa.channel,
           SUM(sa.transactions) AS transactions,
           SUM(sa.items_sold) AS items_sold,
           SUM(sa.revenue) AS revenue,
           SUM(sa.revenue - (sa.items_sold * p.unitcost)) AS gross_margin,
           SUM(sa.return_count) AS return_count,
           SUM(sa.total_delivery_days) AS total_delivery_days
    FROM sales_agg sa
    INNER JOIN {p} p ON sa.productid = p.productid
    GROUP BY sa.hour, sa.channel
)
SELECT hour, channel, transactions, items_sold,
       ROUND(revenue, 2) AS revenue,
       ROUND(gross_margin, 2) AS gross_margin,
       ROUND(gross_margin / NULLIF(revenue, 0), 4) AS margin_pct,
       ROUND(1.0 * return_count / NULLIF(transactions, 0), 4) AS return_rate,
       ROUND(CAST(total_delivery_days AS DECIMAL(18,2)) / NULLIF(transactions, 0), 2) AS avg_delivery_days,
       RANK() OVER (PARTITION BY channel ORDER BY revenue DESC) AS revenue_rank_in_channel
FROM hourly_prod_margin WHERE hour IS NOT NULL
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
# Optimized: Aggregates product level first, avoiding duplicate row-level groupings
create_gold("vw_015_margin_by_price_tier", f"""
WITH sales_agg AS (
    SELECT f.productid,
           SUM(f.qty) AS total_qty,
           SUM(f.grossvalue - f.discountamount) AS revenue
    FROM {f} f
    WHERE f.isreturn = 0
    GROUP BY f.productid
),
tier_prod_agg AS (
    SELECT CASE WHEN p.unitprice < 50 THEN 'Budget (<50)'
                WHEN p.unitprice < 200 THEN 'Mid (50-200)'
                WHEN p.unitprice < 500 THEN 'Premium (200-500)'
                ELSE 'Luxury (500+)' END AS price_tier,
           p.category,
           p.productid,
           sa.total_qty,
           sa.revenue,
           CAST(sa.revenue - (sa.total_qty * p.unitcost) AS DECIMAL(18,2)) AS total_margin,
           p.margin_pct AS product_margin_pct
    FROM sales_agg sa
    INNER JOIN {p} p ON sa.productid = p.productid
)
SELECT price_tier, category, COUNT(DISTINCT productid) AS products, SUM(total_qty) AS total_qty,
       ROUND(SUM(revenue), 2) AS revenue,
       ROUND(SUM(total_margin), 2) AS total_margin,
       ROUND(SUM(total_margin) / NULLIF(SUM(revenue), 0), 4) AS achieved_margin_pct,
       ROUND(AVG(product_margin_pct), 4) AS avg_product_margin_pct,
       ROUND(AVG(product_margin_pct) - (SUM(total_margin) / NULLIF(SUM(revenue), 0)), 4) AS margin_deviation
FROM tier_prod_agg
GROUP BY price_tier, category
""")

# 016: Recency impact on spend (fraction)
# Optimized: Aggregates future sales to customer level first, preventing massive joins
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
future_agg AS (
    SELECT f.customerid,
           COUNT(DISTINCT f.salesid) AS order_count,
           SUM(f.grossvalue - f.discountamount) AS total_order_value,
           SUM(f.grossvalue - f.discountamount - (f.qty * p.unitcost)) AS total_order_margin
    FROM {f} f
    INNER JOIN {p} p ON f.productid = p.productid
    WHERE f.isreturn = 0
    GROUP BY f.customerid
)
SELECT r.recency_segment,
       COUNT(DISTINCT r.customerid) AS customers,
       ROUND(SUM(f.total_order_value) / NULLIF(SUM(f.order_count), 0), 2) AS avg_order_value,
       ROUND(SUM(f.total_order_margin) / NULLIF(SUM(f.order_count), 0), 2) AS avg_order_margin,
       ROUND(SUM(f.total_order_margin) / NULLIF(SUM(f.total_order_value), 0), 4) AS avg_margin_pct,
       ROUND(CAST(SUM(f.order_count) AS DECIMAL(18,2)) / NULLIF(COUNT(DISTINCT r.customerid), 0), 2) AS avg_orders_per_customer
FROM recency r
LEFT JOIN future_agg f ON r.customerid = f.customerid
GROUP BY r.recency_segment;
""")

# 017: Promotion margin efficiency (fraction)
# Optimized: Collapses product level groupings to promo levels inside parallel CTEs
create_gold("vw_017_promo_margin_efficiency", f"""
WITH sales_agg AS (
    SELECT f.promoid,
           f.productid,
           SUM(f.qty) AS total_qty,
           SUM(f.grossvalue - f.discountamount) AS revenue
    FROM {f} f
    WHERE f.isreturn = 0
    GROUP BY f.promoid, f.productid
),
promo_impact AS (
    SELECT sa.promoid,
           SUM(sa.revenue) AS total_revenue,
           SUM(sa.revenue - (sa.total_qty * p.unitcost)) AS total_margin
    FROM sales_agg sa
    INNER JOIN {p} p ON sa.productid = p.productid
    WHERE sa.promoid != 0
    GROUP BY sa.promoid
),
promo_txn_counts AS (
    SELECT promoid,
           COUNT(DISTINCT salesid) AS actual_txn
    FROM {f}
    WHERE promoid != 0 AND isreturn = 0
    GROUP BY promoid
),
baseline AS (
    SELECT AVG(f.grossvalue - f.discountamount) AS base_basket,
           AVG(f.grossvalue - f.discountamount - (f.qty * p.unitcost)) AS base_margin
    FROM {f} f JOIN {p} p ON f.productid = p.productid
    WHERE f.promoid = 0 AND f.isreturn = 0
)
SELECT pi.promoid, pr.promoname, pr.type, pr.discount_pct,
       ptc.actual_txn AS txn,
       ROUND(pi.total_revenue / NULLIF(ptc.actual_txn, 0), 2) AS avg_basket,
       ROUND(pi.total_margin / NULLIF(ptc.actual_txn, 0), 2) AS avg_margin,
       ROUND((pi.total_revenue / NULLIF(ptc.actual_txn, 0)) - b.base_basket, 2) AS basket_increase,
       ROUND((pi.total_margin / NULLIF(ptc.actual_txn, 0)) - b.base_margin, 2) AS margin_increase,
       ROUND(((pi.total_margin / NULLIF(ptc.actual_txn, 0)) - b.base_margin) / NULLIF(b.base_margin, 0), 4) AS margin_uplift_pct,
       ROUND(pi.total_margin / NULLIF(ptc.actual_txn, 0), 2) AS actual_margin_per_txn,
       RANK() OVER (ORDER BY (pi.total_margin / NULLIF(ptc.actual_txn, 0)) - b.base_margin DESC) AS margin_effectiveness_rank
FROM promo_impact pi
INNER JOIN {pr} pr ON pi.promoid = pr.promoid
INNER JOIN promo_txn_counts ptc ON pi.promoid = ptc.promoid
CROSS JOIN baseline b
""")

print("\n✅ All 17 gold tables created in 03_gold_db (margins as fractions).")
# ============================================================================
# End of create_gold_views.py
# ============================================================================