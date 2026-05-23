-- ============================================================================
-- deploy_all_analytical_views.sql
-- ============================================================================
-- Author:       DataGen AI
-- Date:         2026-05-23
-- Description:  Creates 17 analytical views in retailanalytics.
--               Drops each view before creation to avoid name conflicts.
--               All margin and discount _pct columns are fractions (0.0–1.0).
-- ============================================================================

USE retailanalytics;
GO

-- Helper procedure for descriptions (unchanged)
CREATE OR ALTER PROCEDURE sp_add_view_description
    @view_name NVARCHAR(128),
    @description NVARCHAR(500)
AS
BEGIN
    DECLARE @schema NVARCHAR(128) = 'dbo';
    DECLARE @fullname NVARCHAR(256) = @schema + '.' + @view_name;
    IF EXISTS (SELECT 1 FROM sys.extended_properties 
               WHERE major_id = OBJECT_ID(@fullname) AND minor_id = 0 AND name = 'MS_Description')
    BEGIN
        EXEC sp_dropextendedproperty @name = N'MS_Description',
            @level0type = N'SCHEMA', @level0name = @schema,
            @level1type = N'VIEW', @level1name = @view_name;
    END
    EXEC sp_addextendedproperty @name = N'MS_Description', @value = @description,
        @level0type = N'SCHEMA', @level0name = @schema,
        @level1type = N'VIEW', @level1name = @view_name;
END
GO

-- 001
DROP VIEW IF EXISTS dbo.[001_vw_product_category_margin];
GO
CREATE VIEW dbo.[001_vw_product_category_margin]
AS
WITH revenue_cost AS (
    SELECT p.category, p.productid, p.name,
           SUM(f.qty * p.unitcost) AS total_cost,
           SUM(f.grossvalue - f.discountamount) AS total_revenue
    FROM dbo.factsales f
    INNER JOIN dbo.dimproduct p ON f.productid = p.productid
    WHERE f.isreturn = 0
    GROUP BY p.category, p.productid, p.name
)
SELECT category, productid, name, total_revenue, total_cost,
       total_revenue - total_cost AS total_margin,
       ROUND((total_revenue - total_cost) / NULLIF(total_revenue, 0), 4) AS margin_pct,
       RANK() OVER (PARTITION BY category ORDER BY (total_revenue - total_cost) / NULLIF(total_revenue, 0) DESC) AS rank_in_cat
FROM revenue_cost
WHERE total_revenue > 0;
GO
EXEC sp_add_view_description '001_vw_product_category_margin',
    'Product margin (fraction) and rank per category. Margins up to 30%.';
GO

-- 002
DROP VIEW IF EXISTS dbo.[002_vw_promo_performance];
GO
CREATE VIEW dbo.[002_vw_promo_performance]
AS
WITH promo_perf AS (
    SELECT pr.promoid, pr.promoname, pr.type, pr.discount_pct, pr.promoupliftfactor,
           COUNT(DISTINCT f.salesid) AS num_transactions,
           SUM(f.qty) AS total_qty,
           SUM(f.grossvalue - f.discountamount) AS revenue,
           SUM(f.grossvalue - f.discountamount - (f.qty * p.unitcost)) AS margin,
           AVG(CASE WHEN f.grossvalue > 0 THEN f.discountamount / f.grossvalue ELSE 0 END) AS avg_disc_rate
    FROM dbo.factsales f
    JOIN dbo.dimpromotion pr ON f.promoid = pr.promoid
    JOIN dbo.dimproduct p ON f.productid = p.productid
    WHERE pr.promoid != 0 AND f.isreturn = 0
    GROUP BY pr.promoid, pr.promoname, pr.type, pr.discount_pct, pr.promoupliftfactor
),
baseline AS (
    SELECT AVG(f.grossvalue - f.discountamount) AS avg_rev_base,
           AVG(f.qty) AS avg_qty_base
    FROM dbo.factsales f WHERE f.promoid = 0 AND f.isreturn = 0
)
SELECT pp.*,
       ROUND(pp.revenue / NULLIF(pp.num_transactions, 0), 2) AS avg_basket,
       ROUND((pp.revenue / NULLIF(pp.num_transactions, 0) - b.avg_rev_base) / NULLIF(b.avg_rev_base, 0), 4) AS uplift_pct,
       ROUND(pp.margin / NULLIF(pp.revenue, 0), 4) AS margin_pct,
       RANK() OVER (ORDER BY pp.margin DESC) AS margin_rank,
       RANK() OVER (ORDER BY (pp.revenue / NULLIF(pp.num_transactions, 0) - b.avg_rev_base) / NULLIF(b.avg_rev_base, 0) DESC) AS uplift_rank
FROM promo_perf pp CROSS JOIN baseline b;
GO
EXEC sp_add_view_description '002_vw_promo_performance',
    'Promotion performance vs baseline. margin_pct and uplift_pct are fractions.';
GO

-- 003 (fixed with subquery)
DROP VIEW IF EXISTS dbo.[003_vw_customer_rfm_segments];
GO
CREATE VIEW dbo.[003_vw_customer_rfm_segments]
AS
SELECT segment,
       COUNT(*) AS customers,
       AVG(monetary) AS avg_ltv,
       SUM(monetary) AS total_ltv,
       ROUND(AVG(margin_pct), 4) AS avg_margin_pct
FROM (
    SELECT CASE
             WHEN recency_score >= 4 AND frequency_score >= 4 THEN 'Champions'
             WHEN recency_score >= 4 AND frequency_score >= 3 THEN 'Loyal'
             WHEN recency_score >= 3 AND monetary_score >= 4 THEN 'Big Spenders'
             WHEN recency_score <= 2 AND frequency_score <= 2 THEN 'At Risk'
             WHEN recency_score = 1 THEN 'Lost'
             ELSE 'Other'
           END AS segment,
           monetary,
           margin_total / NULLIF(monetary, 0) AS margin_pct
    FROM (
        SELECT f.customerid,
               DATEDIFF(day, MAX(d.fulldate), CAST(GETDATE() AS DATE)) AS recency,
               COUNT(DISTINCT f.salesid) AS frequency,
               SUM(f.grossvalue - f.discountamount) AS monetary,
               SUM(f.grossvalue - f.discountamount - (f.qty * p.unitcost)) AS margin_total,
               NTILE(5) OVER (ORDER BY DATEDIFF(day, MAX(d.fulldate), CAST(GETDATE() AS DATE)) DESC) AS recency_score,
               NTILE(5) OVER (ORDER BY COUNT(DISTINCT f.salesid)) AS frequency_score,
               NTILE(5) OVER (ORDER BY SUM(f.grossvalue - f.discountamount)) AS monetary_score
        FROM dbo.factsales f
        JOIN dbo.dimdate d ON f.datekey = d.datekey
        JOIN dbo.dimproduct p ON f.productid = p.productid
        WHERE f.isreturn = 0
        GROUP BY f.customerid
    ) scored
) sub
GROUP BY segment;
GO
EXEC sp_add_view_description '003_vw_customer_rfm_segments',
    'RFM customer segments with average margin (fraction).';
GO

-- 004
DROP VIEW IF EXISTS dbo.[004_vw_returns_analysis];
GO
CREATE VIEW dbo.[004_vw_returns_analysis]
AS
SELECT f.channel, f.returnreason,
       COUNT(*) AS return_count,
       ROUND(1.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY f.channel), 4) AS pct_of_channel_returns,
       SUM(f.shipcost) AS total_shipping_cost_returns,
       AVG(f.grossvalue - f.discountamount) AS avg_return_value
FROM dbo.factsales f
WHERE f.isreturn = 1
GROUP BY f.channel, f.returnreason;
GO
EXEC sp_add_view_description '004_vw_returns_analysis',
    'Returns by channel and reason.';
GO

-- 005
DROP VIEW IF EXISTS dbo.[005_vw_channel_performance];
GO
CREATE VIEW dbo.[005_vw_channel_performance]
AS
SELECT f.channel,
       COUNT(*) AS transactions,
       AVG(f.deliverydays) AS avg_delivery_days,
       AVG(f.shipcost) AS avg_shipping_cost,
       AVG(f.qty) AS avg_qty,
       AVG(f.grossvalue - f.discountamount) AS avg_basket_value,
       AVG(f.grossvalue - f.discountamount - (f.qty * p.unitcost) - f.shipcost) AS avg_margin_after_shipping,
       ROUND(1.0 * SUM(CASE WHEN f.isreturn = 1 THEN 1 ELSE 0 END) / COUNT(*), 4) AS return_rate
FROM dbo.factsales f
INNER JOIN dbo.dimproduct p ON f.productid = p.productid
GROUP BY f.channel;
GO
EXEC sp_add_view_description '005_vw_channel_performance',
    'Key metrics by sales channel.';
GO

-- 006
DROP VIEW IF EXISTS dbo.[006_vw_seasonal_category_revenue];
GO
CREATE VIEW dbo.[006_vw_seasonal_category_revenue]
AS
SELECT d.monthnumber, d.monthname, p.category,
       SUM(f.grossvalue - f.discountamount) AS revenue,
       SUM(f.qty) AS quantity,
       RANK() OVER (PARTITION BY p.category ORDER BY SUM(f.grossvalue - f.discountamount) DESC) AS rank_in_cat
FROM dbo.factsales f
JOIN dbo.dimdate d ON f.datekey = d.datekey
JOIN dbo.dimproduct p ON f.productid = p.productid
WHERE f.isreturn = 0
GROUP BY d.monthnumber, d.monthname, p.category;
GO
EXEC sp_add_view_description '006_vw_seasonal_category_revenue',
    'Monthly revenue by product category.';
GO

-- 007
DROP VIEW IF EXISTS dbo.[007_vw_store_performance_by_region_type];
GO
CREATE VIEW dbo.[007_vw_store_performance_by_region_type]
AS
SELECT s.region, s.type AS store_type,
       AVG(CAST(s.storerating AS DECIMAL(10,2))) AS avg_rating,
       AVG(CAST(s.sizem2 AS DECIMAL(18,2))) AS avg_size_m2,
       AVG(CAST(s.storesizemultiplier AS DECIMAL(10,3))) AS avg_size_multiplier,
       SUM(CAST(f.grossvalue - f.discountamount AS DECIMAL(18,2))) AS total_revenue,
       SUM(CAST(f.grossvalue - f.discountamount - (f.qty * p.unitcost) AS DECIMAL(18,2))) AS total_margin,
       COUNT(DISTINCT f.customerid) AS unique_customers
FROM dbo.factsales f
INNER JOIN dbo.dimstore s ON f.storeid = s.storeid
INNER JOIN dbo.dimproduct p ON f.productid = p.productid
WHERE f.isreturn = 0
GROUP BY s.region, s.type;
GO
EXEC sp_add_view_description '007_vw_store_performance_by_region_type',
    'Store performance aggregated by region and type.';
GO

-- 008
DROP VIEW IF EXISTS dbo.[008_vw_pareto_margin_analysis];
GO
CREATE VIEW dbo.[008_vw_pareto_margin_analysis]
AS
WITH product_margin AS (
    SELECT p.productid, p.name, p.category,
           SUM(f.grossvalue - f.discountamount - (f.qty * p.unitcost)) AS margin
    FROM dbo.factsales f
    INNER JOIN dbo.dimproduct p ON f.productid = p.productid
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
FROM running
WHERE running_pct <= 0.8;
GO
EXEC sp_add_view_description '008_vw_pareto_margin_analysis',
    'How many products contribute 80% of total margin.';
GO

-- 009
DROP VIEW IF EXISTS dbo.[009_vw_delivery_speed_impact];
GO
CREATE VIEW dbo.[009_vw_delivery_speed_impact]
AS
WITH delivery_groups AS (
    SELECT f.channel, p.category,
           CASE WHEN f.deliverydays <= 2 THEN 'Fast (1-2 days)'
                WHEN f.deliverydays <= 5 THEN 'Standard (3-5 days)'
                ELSE 'Long (>5 days)' END AS delivery_speed,
           f.isreturn, f.grossvalue - f.discountamount AS order_value
    FROM dbo.factsales f
    INNER JOIN dbo.dimproduct p ON f.productid = p.productid
    WHERE f.channel IN ('Online', 'Mobile App')
)
SELECT channel, category, delivery_speed,
       COUNT(*) AS total_orders,
       SUM(CASE WHEN isreturn = 1 THEN 1 ELSE 0 END) AS returns,
       ROUND(1.0 * SUM(CASE WHEN isreturn = 1 THEN 1 ELSE 0 END) / COUNT(*), 4) AS return_rate,
       AVG(order_value) AS avg_order_value
FROM delivery_groups
GROUP BY channel, category, delivery_speed;
GO
EXEC sp_add_view_description '009_vw_delivery_speed_impact',
    'Return rate by delivery speed for online channels.';
GO

-- 010
DROP VIEW IF EXISTS dbo.[010_vw_warranty_eco_impact];
GO
CREATE VIEW dbo.[010_vw_warranty_eco_impact]
AS
SELECT p.haswarranty, p.ecofriendly,
       AVG(f.qty) AS avg_qty_per_transaction,
       AVG(f.grossvalue - f.discountamount) AS avg_revenue,
       ROUND(1.0 * SUM(CASE WHEN f.isreturn = 1 THEN 1 ELSE 0 END) / COUNT(*), 4) AS return_rate,
       COUNT(DISTINCT f.customerid) AS unique_buyers
FROM dbo.factsales f
INNER JOIN dbo.dimproduct p ON f.productid = p.productid
GROUP BY p.haswarranty, p.ecofriendly;
GO
EXEC sp_add_view_description '010_vw_warranty_eco_impact',
    'Impact of warranty and eco certification.';
GO

-- 011
DROP VIEW IF EXISTS dbo.[011_vw_hourly_sales_margin_analysis];
GO
CREATE VIEW dbo.[011_vw_hourly_sales_margin_analysis]
AS
WITH hourly AS (
    SELECT f.hour, f.channel,
           COUNT(*) AS transactions,
           SUM(f.qty) AS items_sold,
           SUM(f.grossvalue - f.discountamount) AS revenue,
           SUM(f.grossvalue - f.discountamount - (f.qty * p.unitcost)) AS gross_margin,
           ROUND(1.0 * SUM(CASE WHEN f.isreturn = 1 THEN 1 ELSE 0 END) / COUNT(*), 4) AS return_rate,
           AVG(f.deliverydays) AS avg_delivery_days
    FROM dbo.factsales f
    INNER JOIN dbo.dimproduct p ON f.productid = p.productid
    WHERE f.isreturn = 0
    GROUP BY f.hour, f.channel
)
SELECT hour, channel, transactions, items_sold,
       ROUND(revenue, 2) AS revenue,
       ROUND(gross_margin, 2) AS gross_margin,
       ROUND(gross_margin / NULLIF(revenue, 0), 4) AS margin_pct,
       return_rate, avg_delivery_days,
       RANK() OVER (PARTITION BY channel ORDER BY revenue DESC) AS revenue_rank_in_channel
FROM hourly WHERE hour IS NOT NULL;
GO
EXEC sp_add_view_description '011_vw_hourly_sales_margin_analysis',
    'Hourly breakdown of sales and margin (fraction) per channel.';
GO

-- 012
DROP VIEW IF EXISTS dbo.[012_vw_pareto_revenue_margin];
GO
CREATE VIEW dbo.[012_vw_pareto_revenue_margin]
AS
WITH prod_agg AS (
    SELECT p.productid, p.name, p.category,
           SUM(f.grossvalue - f.discountamount) AS revenue,
           SUM(f.grossvalue - f.discountamount - (f.qty * p.unitcost)) AS margin
    FROM dbo.factsales f
    INNER JOIN dbo.dimproduct p ON f.productid = p.productid
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
WHERE run_rev / tot_rev <= 0.8 OR run_mar / tot_mar <= 0.8;
GO
EXEC sp_add_view_description '012_vw_pareto_revenue_margin',
    'Pareto analysis for revenue and margin.';
GO

-- 013
DROP VIEW IF EXISTS dbo.[013_vw_basket_analysis];
GO
CREATE VIEW dbo.[013_vw_basket_analysis]
AS
WITH pairs AS (
    SELECT f1.productid AS product_a, f2.productid AS product_b,
           COUNT(*) AS co_occurrence
    FROM dbo.factsales f1
    INNER JOIN dbo.factsales f2 ON f1.salesid = f2.salesid AND f1.productid < f2.productid
    WHERE f1.isreturn = 0 AND f2.isreturn = 0
    GROUP BY f1.productid, f2.productid
),
pop AS (
    SELECT productid, COUNT(DISTINCT salesid) AS total_baskets
    FROM dbo.factsales WHERE isreturn = 0
    GROUP BY productid
)
SELECT TOP 100 pa.product_a, pa.product_b, pa.co_occurrence,
       p1.total_baskets AS baskets_a, p2.total_baskets AS baskets_b,
       ROUND(1.0 * pa.co_occurrence / p1.total_baskets, 4) AS lift_a_to_b,
       ROUND(1.0 * pa.co_occurrence / p2.total_baskets, 4) AS lift_b_to_a
FROM pairs pa
INNER JOIN pop p1 ON pa.product_a = p1.productid
INNER JOIN pop p2 ON pa.product_b = p2.productid
ORDER BY pa.co_occurrence DESC;
GO
EXEC sp_add_view_description '013_vw_basket_analysis',
    'Top 100 product pairs bought together.';
GO

-- 014 (fixed with subquery)
DROP VIEW IF EXISTS dbo.[014_vw_delivery_speed_impact_detailed];
GO
CREATE VIEW dbo.[014_vw_delivery_speed_impact_detailed]
AS
SELECT delivery_speed, channel, orders, returns,
       ROUND(1.0 * returns / NULLIF(orders, 0), 4) AS return_rate,
       avg_order_value, avg_margin,
       ROUND(avg_margin / NULLIF(avg_order_value, 0), 4) AS margin_pct,
       avg_shipcost
FROM (
    SELECT CASE WHEN f.deliverydays <= 2 THEN 'Fast (1-2)'
                WHEN f.deliverydays <= 5 THEN 'Normal (3-5)'
                ELSE 'Slow (6+)' END AS delivery_speed,
           f.channel,
           COUNT(*) AS orders,
           SUM(CASE WHEN f.isreturn = 1 THEN 1 ELSE 0 END) AS returns,
           ROUND(AVG(f.grossvalue - f.discountamount), 2) AS avg_order_value,
           ROUND(AVG(f.grossvalue - f.discountamount - (f.qty * p.unitcost)), 2) AS avg_margin,
           ROUND(AVG(f.shipcost), 2) AS avg_shipcost
    FROM dbo.factsales f
    INNER JOIN dbo.dimproduct p ON f.productid = p.productid
    WHERE f.channel IN ('Online', 'Mobile App') AND f.deliverydays > 0
    GROUP BY CASE WHEN f.deliverydays <= 2 THEN 'Fast (1-2)'
                  WHEN f.deliverydays <= 5 THEN 'Normal (3-5)'
                  ELSE 'Slow (6+)' END,
             f.channel
) sub;
GO
EXEC sp_add_view_description '014_vw_delivery_speed_impact_detailed',
    'Delivery speed impact with margin (fraction).';
GO

-- 015 (fixed with subquery)
DROP VIEW IF EXISTS dbo.[015_vw_margin_by_price_tier];
GO
CREATE VIEW dbo.[015_vw_margin_by_price_tier]
AS
SELECT price_tier, category, products, total_qty,
       ROUND(revenue, 2) AS revenue,
       ROUND(total_margin, 2) AS total_margin,
       ROUND(total_margin / NULLIF(revenue, 0), 4) AS achieved_margin_pct,
       avg_product_margin_pct,
       ROUND(avg_product_margin_pct - (total_margin / NULLIF(revenue, 0)), 4) AS margin_deviation
FROM (
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
    FROM dbo.factsales f
    INNER JOIN dbo.dimproduct p ON f.productid = p.productid
    WHERE f.isreturn = 0
    GROUP BY CASE WHEN p.unitprice < 50 THEN 'Budget (<50)'
                  WHEN p.unitprice < 200 THEN 'Mid (50-200)'
                  WHEN p.unitprice < 500 THEN 'Premium (200-500)'
                  ELSE 'Luxury (500+)' END,
             p.category
) sub;
GO
EXEC sp_add_view_description '015_vw_margin_by_price_tier',
    'Margin (fraction) by price tier and category, comparing intrinsic vs achieved.';
GO

-- 016
DROP VIEW IF EXISTS dbo.[016_vw_recency_impact_on_spend];
GO
CREATE VIEW dbo.[016_vw_recency_impact_on_spend]
AS
WITH last_purchase AS (
    SELECT customerid, MAX(datekey) AS last_key
    FROM dbo.factsales WHERE isreturn = 0
    GROUP BY customerid
),
recency AS (
    SELECT c.customerid,
           DATEDIFF(day, d.fulldate, GETDATE()) AS days_since_last,
           CASE WHEN DATEDIFF(day, d.fulldate, GETDATE()) <= 30 THEN 'Active (0-30 days)'
                WHEN DATEDIFF(day, d.fulldate, GETDATE()) <= 90 THEN 'Recent (31-90 days)'
                WHEN DATEDIFF(day, d.fulldate, GETDATE()) <= 180 THEN 'Dormant (91-180 days)'
                ELSE 'Churned (>180 days)' END AS recency_segment
    FROM last_purchase c
    INNER JOIN dbo.dimdate d ON c.last_key = d.datekey
),
future AS (
    SELECT f.customerid, f.salesid,
           f.grossvalue - f.discountamount AS order_value,
           f.grossvalue - f.discountamount - (f.qty * p.unitcost) AS order_margin
    FROM dbo.factsales f
    INNER JOIN dbo.dimproduct p ON f.productid = p.productid
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
GROUP BY r.recency_segment;
GO
EXEC sp_add_view_description '016_vw_recency_impact_on_spend',
    'Recency groups and their average margin (fraction).';
GO

-- 017
DROP VIEW IF EXISTS dbo.[017_vw_promo_margin_efficiency];
GO
CREATE VIEW dbo.[017_vw_promo_margin_efficiency]
AS
WITH promo_impact AS (
    SELECT pr.promoid, pr.promoname, pr.type, pr.discount_pct,
           AVG(f.grossvalue - f.discountamount) AS avg_basket,
           AVG(f.grossvalue - f.discountamount - (f.qty * p.unitcost)) AS avg_margin,
           COUNT(*) AS txn,
           SUM(f.grossvalue - f.discountamount - (f.qty * p.unitcost)) AS total_margin
    FROM dbo.factsales f
    INNER JOIN dbo.dimpromotion pr ON f.promoid = pr.promoid
    INNER JOIN dbo.dimproduct p ON f.productid = p.productid
    WHERE pr.promoid != 0 AND f.isreturn = 0
    GROUP BY pr.promoid, pr.promoname, pr.type, pr.discount_pct
),
baseline AS (
    SELECT AVG(f.grossvalue - f.discountamount) AS base_basket,
           AVG(f.grossvalue - f.discountamount - (f.qty * p.unitcost)) AS base_margin
    FROM dbo.factsales f
    INNER JOIN dbo.dimproduct p ON f.productid = p.productid
    WHERE f.promoid = 0 AND f.isreturn = 0
)
SELECT pi.promoid, pi.promoname, pi.type, pi.discount_pct,
       pi.txn, pi.avg_basket, pi.avg_margin,
       ROUND(pi.avg_basket - b.base_basket, 2) AS basket_increase,
       ROUND(pi.avg_margin - b.base_margin, 2) AS margin_increase,
       ROUND((pi.avg_margin - b.base_margin) / NULLIF(b.base_margin, 0), 4) AS margin_uplift_pct,
       ROUND(pi.total_margin / NULLIF(pi.txn, 0), 2) AS actual_margin_per_txn,
       RANK() OVER (ORDER BY (pi.avg_margin - b.base_margin) DESC) AS margin_effectiveness_rank
FROM promo_impact pi CROSS JOIN baseline b;
GO
EXEC sp_add_view_description '017_vw_promo_margin_efficiency',
    'Promotion margin uplift (fraction).';
GO

-- Final: list views with descriptions
SELECT s.name AS schema_name, v.name AS view_name, ep.value AS description
FROM sys.views v
INNER JOIN sys.schemas s ON v.schema_id = s.schema_id
LEFT JOIN sys.extended_properties ep 
    ON ep.major_id = v.object_id AND ep.minor_id = 0 AND ep.name = 'MS_Description'
WHERE v.name LIKE '[0-9][0-9][0-9]_vw_%' OR v.name LIKE '[0-9][0-9][0-9][0-9]_vw_%'
ORDER BY v.name;
GO

DROP PROCEDURE IF EXISTS sp_add_view_description;
GO

PRINT '============================================================';
PRINT 'All analytical views created successfully (fraction _pct).';
PRINT '============================================================';
-- ============================================================================
-- End of deploy_all_analytical_views.sql
-- ============================================================================