-- Notebook: 03_gold_analytics_tables
-- Run this cell as %%sql in the same notebook

CREATE SCHEMA IF NOT EXISTS `03_gold_db`;

-- 001 Product category margin
CREATE OR REPLACE TABLE `03_gold_db`.vw_001_product_category_margin
USING delta AS
WITH revenue_cost AS (
    SELECT p.category, p.productid, p.name,
           SUM(f.qty * p.unitcost) AS total_cost,
           SUM(f.grossvalue - f.discountamount) AS total_revenue
    FROM `02_silver_db`.silver_factsales f
    INNER JOIN `02_silver_db`.silver_dimproduct p ON f.productid = p.productid
    WHERE f.isreturn = 0
    GROUP BY p.category, p.productid, p.name
)
SELECT category, productid, name, total_revenue, total_cost,
       total_revenue - total_cost AS total_margin,
       ROUND((total_revenue - total_cost) / NULLIF(total_revenue, 0), 4) AS margin_pct,
       RANK() OVER (PARTITION BY category ORDER BY (total_revenue - total_cost) / NULLIF(total_revenue, 0) DESC) AS rank_in_cat
FROM revenue_cost WHERE total_revenue > 0;

-- 002 Promotion performance
CREATE OR REPLACE TABLE `03_gold_db`.vw_002_promo_performance
USING delta AS
WITH promo_performance AS (
    SELECT p.promoid, p.promoname, p.type, p.discount_pct, p.promoupliftfactor,
           COUNT(DISTINCT f.salesid) AS num_transactions,
           SUM(f.qty) AS total_qty,
           SUM(f.grossvalue - f.discountamount) AS revenue,
           SUM(f.grossvalue - f.discountamount - (f.qty * pr.unitcost)) AS margin,
           AVG(f.discountamount / NULLIF(f.grossvalue, 0)) AS avg_disc_rate
    FROM `02_silver_db`.silver_factsales f
    JOIN `02_silver_db`.silver_dimpromotion p ON f.promoid = p.promoid
    JOIN `02_silver_db`.silver_dimproduct pr ON f.productid = pr.productid
    WHERE p.promoid > 0 AND f.isreturn = 0
    GROUP BY p.promoid, p.promoname, p.type, p.discount_pct, p.promoupliftfactor
),
baseline AS (
    SELECT AVG(f.grossvalue - f.discountamount) AS avg_revenue_baseline
    FROM `02_silver_db`.silver_factsales f WHERE f.promoid = 0 AND f.isreturn = 0
)
SELECT pp.*,
       ROUND(pp.revenue / NULLIF(pp.num_transactions, 0), 2) AS avg_basket,
       ROUND((pp.revenue / NULLIF(pp.num_transactions, 0) - baseline.avg_revenue_baseline) / NULLIF(baseline.avg_revenue_baseline, 0), 4) AS uplift_pct,
       ROUND(pp.margin / NULLIF(pp.revenue, 0), 4) AS margin_pct,
       RANK() OVER (ORDER BY pp.margin DESC) AS margin_rank,
       RANK() OVER (ORDER BY (pp.revenue / NULLIF(pp.num_transactions, 0) - baseline.avg_revenue_baseline) / NULLIF(baseline.avg_revenue_baseline, 0) DESC) AS uplift_rank
FROM promo_performance pp CROSS JOIN baseline;

-- 003 Customer RFM segments
CREATE OR REPLACE TABLE `03_gold_db`.vw_003_customer_rfm_segments
USING delta AS
WITH customer_rfm AS (
    SELECT f.customerid,
           DATEDIFF(current_date(), MAX(d.fulldate)) AS recency,
           COUNT(DISTINCT f.salesid) AS frequency,
           SUM(f.grossvalue - f.discountamount) AS monetary,
           SUM(f.grossvalue - f.discountamount - (f.qty * p.unitcost)) AS margin_total
    FROM `02_silver_db`.silver_factsales f
    JOIN `02_silver_db`.silver_dimdate d ON f.datekey = d.datekey
    JOIN `02_silver_db`.silver_dimproduct p ON f.productid = p.productid
    WHERE f.isreturn = 0
    GROUP BY f.customerid
),
rfm_scores AS (
    SELECT *, NTILE(5) OVER (ORDER BY recency DESC) AS recency_score,
           NTILE(5) OVER (ORDER BY frequency) AS frequency_score,
           NTILE(5) OVER (ORDER BY monetary) AS monetary_score
    FROM customer_rfm
),
segments AS (
    SELECT *, (recency_score + frequency_score + monetary_score) AS rfm_total,
           CASE WHEN recency_score >= 4 AND frequency_score >= 4 THEN 'Champions'
                WHEN recency_score >= 4 AND frequency_score >= 3 THEN 'Loyal'
                WHEN recency_score >= 3 AND monetary_score >= 4 THEN 'Big Spenders'
                WHEN recency_score <= 2 AND frequency_score <= 2 THEN 'At Risk'
                WHEN recency_score = 1 THEN 'Lost'
                ELSE 'Other' END AS segment
    FROM rfm_scores
)
SELECT segment, COUNT(*) AS customers, AVG(monetary) AS avg_ltv, SUM(monetary) AS total_ltv,
       ROUND(AVG(margin_total / NULLIF(monetary, 0)), 4) AS avg_margin_pct
FROM segments GROUP BY segment;

-- 004 Returns analysis
CREATE OR REPLACE TABLE `03_gold_db`.vw_004_returns_analysis
USING delta AS
SELECT f.channel, COALESCE(f.returnreason, 'Unknown') AS returnreason,
       COUNT(*) AS return_count,
       ROUND(CAST(COUNT(*) AS DOUBLE) / SUM(COUNT(*)) OVER (PARTITION BY f.channel), 4) AS pct_of_channel_returns,
       SUM(f.shipcost) AS total_shipping_cost_returns,
       AVG(f.grossvalue - f.discountamount) AS avg_return_value
FROM `02_silver_db`.silver_factsales f WHERE f.isreturn = 1
GROUP BY f.channel, f.returnreason;

-- 005 Channel performance
CREATE OR REPLACE TABLE `03_gold_db`.vw_005_channel_performance
USING delta AS
SELECT f.channel,
       COUNT(*) AS transactions,
       AVG(f.deliverydays) AS avg_delivery_days,
       AVG(f.shipcost) AS avg_shipping_cost,
       AVG(f.qty) AS avg_qty,
       AVG(f.grossvalue - f.discountamount) AS avg_basket_value,
       AVG(f.grossvalue - f.discountamount - (f.qty * p.unitcost) - f.shipcost) AS avg_margin_after_shipping,
       ROUND(CAST(SUM(CASE WHEN f.isreturn = 1 THEN 1 ELSE 0 END) AS DOUBLE) / COUNT(*), 4) AS return_rate_pct
FROM `02_silver_db`.silver_factsales f
INNER JOIN `02_silver_db`.silver_dimproduct p ON f.productid = p.productid
GROUP BY f.channel;

-- 006 Seasonal category revenue
CREATE OR REPLACE TABLE `03_gold_db`.vw_006_seasonal_category_revenue
USING delta AS
SELECT d.monthnumber, d.monthname, p.category,
       SUM(f.grossvalue - f.discountamount) AS revenue,
       SUM(f.qty) AS quantity,
       RANK() OVER (PARTITION BY p.category ORDER BY SUM(f.grossvalue - f.discountamount) DESC) AS rank_in_cat
FROM `02_silver_db`.silver_factsales f
JOIN `02_silver_db`.silver_dimdate d ON f.datekey = d.datekey
JOIN `02_silver_db`.silver_dimproduct p ON f.productid = p.productid
WHERE f.isreturn = 0
GROUP BY d.monthnumber, d.monthname, p.category;

-- 007 Store performance by region/type
CREATE OR REPLACE TABLE `03_gold_db`.vw_007_store_performance_by_region_type
USING delta AS
SELECT s.region, s.type AS store_type,
       AVG(s.storerating) AS avg_rating,
       AVG(s.sizem2) AS avg_size_m2,
       AVG(s.storesizemultiplier) AS avg_size_multiplier,
       SUM(f.grossvalue - f.discountamount) AS total_revenue,
       SUM(f.grossvalue - f.discountamount - (f.qty * p.unitcost)) AS total_margin,
       COUNT(DISTINCT f.customerid) AS unique_customers
FROM `02_silver_db`.silver_factsales f
INNER JOIN `02_silver_db`.silver_dimstore s ON f.storeid = s.storeid
INNER JOIN `02_silver_db`.silver_dimproduct p ON f.productid = p.productid
WHERE f.isreturn = 0
GROUP BY s.region, s.type;

-- 008 Pareto margin analysis
CREATE OR REPLACE TABLE `03_gold_db`.vw_008_pareto_margin_analysis
USING delta AS
WITH product_margin AS (
    SELECT p.productid, p.name, p.category,
           SUM(f.grossvalue - f.discountamount - (f.qty * p.unitcost)) AS margin
    FROM `02_silver_db`.silver_factsales f
    INNER JOIN `02_silver_db`.silver_dimproduct p ON f.productid = p.productid
    WHERE f.isreturn = 0
    GROUP BY p.productid, p.name, p.category
),
running AS (
    SELECT *, SUM(margin) OVER (ORDER BY margin DESC) AS running_margin,
           1.0 * SUM(margin) OVER (ORDER BY margin DESC) / NULLIF(SUM(margin) OVER (), 0) AS running_pct
    FROM product_margin
)
SELECT COUNT(*) AS product_cnt, MIN(running_pct) AS min_pct_contribution, MAX(running_pct) AS max_pct_contribution
FROM running WHERE running_pct <= 0.8;

-- 009 Delivery speed impact
CREATE OR REPLACE TABLE `03_gold_db`.vw_009_delivery_speed_impact
USING delta AS
WITH delivery_groups AS (
    SELECT f.channel, p.category,
           CASE WHEN f.deliverydays <= 2 THEN 'Fast (1-2 days)'
                WHEN f.deliverydays <= 5 THEN 'Standard (3-5 days)'
                ELSE 'Long (>5 days)' END AS delivery_speed,
           f.isreturn,
           (f.grossvalue - f.discountamount) AS order_value
    FROM `02_silver_db`.silver_factsales f
    INNER JOIN `02_silver_db`.silver_dimproduct p ON f.productid = p.productid
    WHERE f.channel IN ('Online', 'Mobile App')
)
SELECT channel, category, delivery_speed,
       COUNT(*) AS total_orders,
       SUM(CASE WHEN isreturn = 1 THEN 1 ELSE 0 END) AS returns,
       ROUND(CAST(SUM(CASE WHEN isreturn = 1 THEN 1 ELSE 0 END) AS DOUBLE) / COUNT(*), 4) AS return_rate,
       AVG(order_value) AS avg_order_value
FROM delivery_groups GROUP BY channel, category, delivery_speed;

-- 010 Warranty & eco impact
CREATE OR REPLACE TABLE `03_gold_db`.vw_010_warranty_eco_impact
USING delta AS
SELECT p.haswarranty, p.ecofriendly,
       AVG(f.qty) AS avg_qty_per_transaction,
       AVG(f.grossvalue - f.discountamount) AS avg_revenue,
       ROUND(CAST(SUM(CASE WHEN f.isreturn = 1 THEN 1 ELSE 0 END) AS DOUBLE) / COUNT(*), 4) AS return_rate,
       COUNT(DISTINCT f.customerid) AS unique_buyers
FROM `02_silver_db`.silver_factsales f
INNER JOIN `02_silver_db`.silver_dimproduct p ON f.productid = p.productid
GROUP BY p.haswarranty, p.ecofriendly;

SELECT 'All 10 gold tables created.' AS status;