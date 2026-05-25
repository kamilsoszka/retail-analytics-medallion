-- ============================================================================
-- create_analytical_views.sql
-- ============================================================================
-- Author:           DataGen AI & Assistant
-- Created:          2026-05-23
-- Last modified:    2026-05-25 18:40:00 UTC
-- Suggested name:   create_analytical_views.sql
-- Description:
--   Deploys 17 highly optimized analytical views on top of the retailanalytics star schema.
--   Optimized using "Aggregate-then-Join" patterns to leverage the Clustered Columnstore
--   Index on factsales, ensuring sub-second response times on 10M rows.
--   All margin and discount columns are stored as decimal fractions (0.0-1.0).
-- ============================================================================

USE retailanalytics;
GO

-- ---------------------------------------------------------------------------
-- 1. HELPER PROCEDURE – adds an MS_Description extended property to a view.
--    The description is visible in SSMS and can be queried from
--    sys.extended_properties.  The procedure first drops any existing
--    description to avoid error 15217.
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_add_view_description
    @view_name   NVARCHAR(128),
    @description NVARCHAR(500)
AS
BEGIN
    DECLARE @schema   NVARCHAR(128) = 'dbo';
    DECLARE @fullname NVARCHAR(256) = @schema + '.' + @view_name;

    IF EXISTS (SELECT 1 FROM sys.extended_properties
               WHERE major_id = OBJECT_ID(@fullname)
                 AND minor_id = 0
                 AND name = 'MS_Description')
    BEGIN
        EXEC sp_dropextendedproperty
            @name        = N'MS_Description',
            @level0type  = N'SCHEMA', @level0name = @schema,
            @level1type  = N'VIEW',   @level1name = @view_name;
    END

    EXEC sp_addextendedproperty
        @name        = N'MS_Description',
        @value       = @description,
        @level0type  = N'SCHEMA', @level0name = @schema,
        @level1type  = N'VIEW',   @level1name = @view_name;
END
GO

-- ============================================================================
-- 2. VIEW 001 – Product category margin analysis
--    Optimized: Aggregates fact table by integer keys first, then joins dimension.
-- ============================================================================
DROP VIEW IF EXISTS dbo.[001_vw_product_category_margin];
GO
CREATE VIEW dbo.[001_vw_product_category_margin]
AS
WITH sales_agg AS (
    SELECT productid,
           SUM(qty)                                       AS total_qty,
           SUM(grossvalue - discountamount)               AS total_revenue
    FROM dbo.factsales
    WHERE isreturn = 0
    GROUP BY productid
)
SELECT p.category,
       p.productid,
       p.name,
       sa.total_revenue,
       CAST(sa.total_qty * p.unitcost AS DECIMAL(18,2))   AS total_cost,
       CAST(sa.total_revenue - (sa.total_qty * p.unitcost) AS DECIMAL(18,2)) AS total_margin,
       ROUND((sa.total_revenue - (sa.total_qty * p.unitcost)) / 
             NULLIF(sa.total_revenue, 0), 4)              AS margin_pct,
       RANK() OVER (PARTITION BY p.category
                    ORDER BY (sa.total_revenue - (sa.total_qty * p.unitcost)) / 
                              NULLIF(sa.total_revenue, 0) DESC) AS rank_in_cat
FROM sales_agg sa
INNER JOIN dbo.dimproduct p ON sa.productid = p.productid
WHERE sa.total_revenue > 0;
GO
EXEC sp_add_view_description '001_vw_product_category_margin',
    'Product margin (fraction) and rank per category. Margins up to 30%.';
GO

-- ============================================================================
-- 3. VIEW 002 – Promotion performance vs baseline
--    Optimized: Avoids joining dimproduct to the full 10M rows.
--    Separates distinct transaction counting and margin evaluation into parallel CTEs.
-- ============================================================================
DROP VIEW IF EXISTS dbo.[002_vw_promo_performance];
GO
CREATE VIEW dbo.[002_vw_promo_performance]
AS
WITH promo_tx AS (
    SELECT promoid,
           COUNT(DISTINCT salesid)                        AS num_transactions,
           AVG(CASE WHEN grossvalue > 0 
                    THEN discountamount / grossvalue 
                    ELSE 0 END)                           AS avg_disc_rate
    FROM dbo.factsales
    WHERE isreturn = 0
    GROUP BY promoid
),
sales_promo_prod AS (
    SELECT promoid,
           productid,
           SUM(qty)                                       AS total_qty,
           SUM(grossvalue - discountamount)               AS revenue
    FROM dbo.factsales
    WHERE isreturn = 0
    GROUP BY promoid, productid
),
promo_margin AS (
    SELECT spp.promoid,
           SUM(spp.total_qty)                             AS total_qty,
           SUM(spp.revenue)                               AS revenue,
           SUM(spp.revenue - (spp.total_qty * p.unitcost)) AS margin
    FROM sales_promo_prod spp
    INNER JOIN dbo.dimproduct p ON spp.productid = p.productid
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
    FROM dbo.dimpromotion pr
    INNER JOIN promo_margin pm ON pr.promoid = pm.promoid
    INNER JOIN promo_tx pt      ON pr.promoid = pt.promoid
    WHERE pr.promoid != 0
),
baseline AS (
    SELECT AVG(f.grossvalue - f.discountamount)          AS avg_rev_base,
           AVG(CAST(f.qty AS DECIMAL(18,2)))             AS avg_qty_base
    FROM dbo.factsales f
    WHERE f.promoid = 0 AND f.isreturn = 0
)
SELECT pp.*,
       ROUND(pp.revenue / NULLIF(pp.num_transactions, 0), 2) AS avg_basket,
       ROUND((pp.revenue / NULLIF(pp.num_transactions, 0) -
              b.avg_rev_base) /
              NULLIF(b.avg_rev_base, 0), 4)                  AS uplift_pct,
       ROUND(pp.margin / NULLIF(pp.revenue, 0), 4)           AS margin_pct,
       RANK() OVER (ORDER BY pp.margin DESC)                 AS margin_rank,
       RANK() OVER (ORDER BY (pp.revenue /
                              NULLIF(pp.num_transactions, 0) -
                              b.avg_rev_base) /
                              NULLIF(b.avg_rev_base, 0) DESC) AS uplift_rank
FROM promo_perf pp CROSS JOIN baseline b;
GO
EXEC sp_add_view_description '002_vw_promo_performance',
    'Promotion performance vs baseline. margin_pct and uplift_pct are fractions.';
GO

-- ============================================================================
-- 4. VIEW 003 – Customer RFM segmentation
--    Optimized: Removes repeated calculations, implements clean CTE steps,
--    and optimizes margin scoring logic.
-- ============================================================================
DROP VIEW IF EXISTS dbo.[003_vw_customer_rfm_segments];
GO
CREATE VIEW dbo.[003_vw_customer_rfm_segments]
AS
WITH customer_sales AS (
    SELECT f.customerid,
           f.productid,
           SUM(f.qty)                                     AS total_qty,
           SUM(f.grossvalue - f.discountamount)           AS net_revenue
    FROM dbo.factsales f
    WHERE f.isreturn = 0
    GROUP BY f.customerid, f.productid
),
customer_margins AS (
    SELECT cs.customerid,
           SUM(cs.net_revenue)                            AS monetary,
           SUM(cs.net_revenue - (cs.total_qty * p.unitcost)) AS margin_total
    FROM customer_sales cs
    INNER JOIN dbo.dimproduct p ON cs.productid = p.productid
    GROUP BY cs.customerid
),
customer_recency_freq AS (
    SELECT f.customerid,
           MAX(f.datekey)                                 AS max_datekey,
           COUNT(DISTINCT f.salesid)                      AS frequency
    FROM dbo.factsales f
    WHERE f.isreturn = 0
    GROUP BY f.customerid
),
customer_base_metrics AS (
    SELECT crf.customerid,
           DATEDIFF(day, d.fulldate, CAST(GETDATE() AS DATE)) AS recency,
           crf.frequency,
           cm.monetary,
           cm.margin_total
    FROM customer_recency_freq crf
    INNER JOIN customer_margins cm ON crf.customerid = cm.customerid
    INNER JOIN dbo.dimdate d        ON crf.max_datekey = d.datekey
),
scored AS (
    SELECT customerid,
           recency,
           frequency,
           monetary,
           margin_total,
           NTILE(5) OVER (ORDER BY recency DESC)          AS recency_score,
           NTILE(5) OVER (ORDER BY frequency ASC)         AS frequency_score,
           NTILE(5) OVER (ORDER BY monetary ASC)          AS monetary_score
    FROM customer_base_metrics
),
segmented AS (
    SELECT customerid,
           monetary,
           margin_total,
           CASE
             WHEN recency_score >= 4 AND frequency_score >= 4 THEN 'Champions'
             WHEN recency_score >= 4 AND frequency_score >= 3 THEN 'Loyal'
             WHEN recency_score >= 3 AND monetary_score  >= 4 THEN 'Big Spenders'
             WHEN recency_score <= 2 AND frequency_score <= 2 THEN 'At Risk'
             WHEN recency_score = 1                           THEN 'Lost'
             ELSE 'Other'
           END                                            AS segment
    FROM scored
)
SELECT segment,
       COUNT(*)                                           AS customers,
       AVG(monetary)                                      AS avg_ltv,
       SUM(monetary)                                      AS total_ltv,
       ROUND(AVG(margin_total / NULLIF(monetary, 0)), 4)  AS avg_margin_pct
FROM segmented
GROUP BY segment;
GO
EXEC sp_add_view_description '003_vw_customer_rfm_segments',
    'RFM customer segments with average margin (fraction).';
GO

-- ============================================================================
-- 5. VIEWS 004-010 – Returns, Channel, Seasonal, Store, Pareto, Delivery, Warranty
-- ============================================================================

-- 004: Returns analysis – count and value of returns by channel and reason
DROP VIEW IF EXISTS dbo.[004_vw_returns_analysis];
GO
CREATE VIEW dbo.[004_vw_returns_analysis]
AS
SELECT f.channel,
       f.returnreason,
       COUNT(*)                                                     AS return_count,
       ROUND(1.0 * COUNT(*) /
             SUM(COUNT(*)) OVER (PARTITION BY f.channel), 4)        AS pct_of_channel_returns,
       SUM(f.shipcost)                                              AS total_shipping_cost_returns,
       AVG(f.grossvalue - f.discountamount)                         AS avg_return_value
FROM dbo.factsales f
WHERE f.isreturn = 1
GROUP BY f.channel, f.returnreason;
GO
EXEC sp_add_view_description '004_vw_returns_analysis',
    'Returns by channel and reason.';
GO

-- 005: Channel performance
--    Optimized: Pre-aggregates fact data on channel-product level before joining dimproduct.
DROP VIEW IF EXISTS dbo.[005_vw_channel_performance];
GO
CREATE VIEW dbo.[005_vw_channel_performance]
AS
WITH sales_agg AS (
    SELECT f.channel,
           f.productid,
           COUNT(*)                                                 AS transactions,
           SUM(f.deliverydays)                                      AS total_delivery_days,
           SUM(f.shipcost)                                          AS total_shipcost,
           SUM(f.qty)                                               AS total_qty,
           SUM(f.grossvalue - f.discountamount)                     AS total_net_revenue,
           SUM(CASE WHEN f.isreturn = 1 THEN 1 ELSE 0 END)          AS return_count
    FROM dbo.factsales f
    GROUP BY f.channel, f.productid
)
SELECT sa.channel,
       SUM(sa.transactions)                                         AS transactions,
       ROUND(CAST(SUM(sa.total_delivery_days) AS DECIMAL(18,2)) / 
             NULLIF(SUM(sa.transactions), 0), 2)                    AS avg_delivery_days,
       ROUND(SUM(sa.total_shipcost) / NULLIF(SUM(sa.transactions), 0), 2) AS avg_shipping_cost,
       ROUND(CAST(SUM(sa.total_qty) AS DECIMAL(18,2)) / 
             NULLIF(SUM(sa.transactions), 0), 2)                    AS avg_qty,
       ROUND(SUM(sa.total_net_revenue) / NULLIF(SUM(sa.transactions), 0), 2) AS avg_basket_value,
       ROUND(SUM(sa.total_net_revenue - (sa.total_qty * p.unitcost) - sa.total_shipcost) / 
             NULLIF(SUM(sa.transactions), 0), 2)                    AS avg_margin_after_shipping,
       ROUND(1.0 * SUM(sa.return_count) / NULLIF(SUM(sa.transactions), 0), 4) AS return_rate
FROM sales_agg sa
INNER JOIN dbo.dimproduct p ON sa.productid = p.productid
GROUP BY sa.channel;
GO
EXEC sp_add_view_description '005_vw_channel_performance',
    'Key metrics by sales channel.';
GO

-- 006: Seasonal category revenue – revenue and quantity per month & category
DROP VIEW IF EXISTS dbo.[006_vw_seasonal_category_revenue];
GO
CREATE VIEW dbo.[006_vw_seasonal_category_revenue]
AS
SELECT d.monthnumber,
       d.monthname,
       p.category,
       SUM(f.grossvalue - f.discountamount)                         AS revenue,
       SUM(f.qty)                                                   AS quantity,
       RANK() OVER (PARTITION BY p.category
                    ORDER BY SUM(f.grossvalue - f.discountamount) DESC) AS rank_in_cat
FROM dbo.factsales f
JOIN dbo.dimdate    d ON f.datekey   = d.datekey
JOIN dbo.dimproduct p ON f.productid = p.productid
WHERE f.isreturn = 0
GROUP BY d.monthnumber, d.monthname, p.category;
GO
EXEC sp_add_view_description '006_vw_seasonal_category_revenue',
    'Monthly revenue by product category.';
GO

-- 007: Store performance by region and type
--    Optimized: Eliminates redundant CASTs and uses sub-aggregations.
DROP VIEW IF EXISTS dbo.[007_vw_store_performance_by_region_type];
GO
CREATE VIEW dbo.[007_vw_store_performance_by_region_type]
AS
WITH sales_agg AS (
    SELECT f.storeid,
           f.productid,
           SUM(f.grossvalue - f.discountamount)                     AS revenue,
           SUM(f.qty)                                               AS qty
    FROM dbo.factsales f
    WHERE f.isreturn = 0
    GROUP BY f.storeid, f.productid
),
store_prod_agg AS (
    SELECT sa.storeid,
           SUM(sa.revenue)                                          AS revenue,
           SUM(sa.revenue - (sa.qty * p.unitcost))                  AS margin
    FROM sales_agg sa
    INNER JOIN dbo.dimproduct p ON sa.productid = p.productid
    GROUP BY sa.storeid
),
store_unique_custs AS (
    SELECT f.storeid,
           COUNT(DISTINCT f.customerid)                             AS unique_customers
    FROM dbo.factsales f
    WHERE f.isreturn = 0
    GROUP BY f.storeid
)
SELECT s.region,
       s.type                                                       AS store_type,
       ROUND(AVG(s.storerating), 2)                                 AS avg_rating,
       ROUND(AVG(CAST(s.sizem2 AS DECIMAL(18,2))), 2)               AS avg_size_m2,
       ROUND(AVG(s.storesizemultiplier), 4)                         AS avg_size_multiplier,
       SUM(spa.revenue)                                             AS total_revenue,
       SUM(spa.margin)                                              AS total_margin,
       SUM(suc.unique_customers)                                    AS unique_customers
FROM dbo.dimstore s
INNER JOIN store_prod_agg spa       ON s.storeid = spa.storeid
INNER JOIN store_unique_custs suc   ON s.storeid = suc.storeid
GROUP BY s.region, s.type;
GO
EXEC sp_add_view_description '007_vw_store_performance_by_region_type',
    'Store performance aggregated by region and type.';
GO

-- 008: Pareto margin analysis – how many products contribute 80% of total margin
DROP VIEW IF EXISTS dbo.[008_vw_pareto_margin_analysis];
GO
CREATE VIEW dbo.[008_vw_pareto_margin_analysis]
AS
WITH product_margin AS (
    SELECT p.productid, p.name, p.category,
           SUM(f.grossvalue - f.discountamount -
               (f.qty * p.unitcost))                                AS margin
    FROM dbo.factsales f
    INNER JOIN dbo.dimproduct p ON f.productid = p.productid
    WHERE f.isreturn = 0
    GROUP BY p.productid, p.name, p.category
),
running AS (
    SELECT *,
           SUM(margin) OVER (ORDER BY margin DESC)                  AS running_margin,
           1.0 * SUM(margin) OVER (ORDER BY margin DESC) /
                 NULLIF(SUM(margin) OVER (), 0)                     AS running_pct
    FROM product_margin
)
SELECT COUNT(*)            AS product_cnt,
       MIN(running_pct)    AS min_pct_contribution,
       MAX(running_pct)    AS max_pct_contribution
FROM running
WHERE running_pct <= 0.8;
GO
EXEC sp_add_view_description '008_vw_pareto_margin_analysis',
    'How many products contribute 80% of total margin.';
GO

-- 009: Delivery speed impact on returns (online/mobile only)
DROP VIEW IF EXISTS dbo.[009_vw_delivery_speed_impact];
GO
CREATE VIEW dbo.[009_vw_delivery_speed_impact]
AS
WITH delivery_groups AS (
    SELECT f.channel, p.category,
           CASE WHEN f.deliverydays <= 2 THEN 'Fast (1-2 days)'
                WHEN f.deliverydays <= 5 THEN 'Standard (3-5 days)'
                ELSE 'Long (>5 days)' END                           AS delivery_speed,
           f.isreturn,
           f.grossvalue - f.discountamount                          AS order_value
    FROM dbo.factsales f
    INNER JOIN dbo.dimproduct p ON f.productid = p.productid
    WHERE f.channel IN ('Online', 'Mobile App')
)
SELECT channel, category, delivery_speed,
       COUNT(*)                                                     AS total_orders,
       SUM(CASE WHEN isreturn = 1 THEN 1 ELSE 0 END)                AS returns,
       ROUND(1.0 * SUM(CASE WHEN isreturn = 1 THEN 1 ELSE 0 END) /
             COUNT(*), 4)                                           AS return_rate,
       AVG(order_value)                                             AS avg_order_value
FROM delivery_groups
GROUP BY channel, category, delivery_speed;
GO
EXEC sp_add_view_description '009_vw_delivery_speed_impact',
    'Return rate by delivery speed for online channels.';
GO

-- 010: Warranty & eco‑friendly impact
DROP VIEW IF EXISTS dbo.[010_vw_warranty_eco_impact];
GO
CREATE VIEW dbo.[010_vw_warranty_eco_impact]
AS
SELECT p.haswarranty,
       p.ecofriendly,
       AVG(f.qty)                                                   AS avg_qty_per_transaction,
       AVG(f.grossvalue - f.discountamount)                         AS avg_revenue,
       ROUND(1.0 * SUM(CASE WHEN f.isreturn = 1 THEN 1 ELSE 0 END) /
             COUNT(*), 4)                                           AS return_rate,
       COUNT(DISTINCT f.customerid)                                 AS unique_buyers
FROM dbo.factsales f
INNER JOIN dbo.dimproduct p ON f.productid = p.productid
GROUP BY p.haswarranty, p.ecofriendly;
GO
EXEC sp_add_view_description '010_vw_warranty_eco_impact',
    'Impact of warranty and eco certification.';
GO

-- ============================================================================
-- 6. VIEWS 011-017 – Advanced and Complex Analytical View Paths
-- ============================================================================

-- 011: Hourly sales & margin analysis
--    Optimized: Aggregates on integer keys and drops joining dimension values on 10M rows.
DROP VIEW IF EXISTS dbo.[011_vw_hourly_sales_margin_analysis];
GO
CREATE VIEW dbo.[011_vw_hourly_sales_margin_analysis]
AS
WITH sales_agg AS (
    SELECT f.hour,
           f.channel,
           f.productid,
           COUNT(*)                                                 AS transactions,
           SUM(f.qty)                                               AS items_sold,
           SUM(f.grossvalue - f.discountamount)                     AS revenue,
           SUM(CASE WHEN f.isreturn = 1 THEN 1 ELSE 0 END)          AS return_count,
           SUM(f.deliverydays)                                      AS total_delivery_days
    FROM dbo.factsales f
    GROUP BY f.hour, f.channel, f.productid
),
hourly_prod_margin AS (
    SELECT sa.hour,
           sa.channel,
           SUM(sa.transactions)                                     AS transactions,
           SUM(sa.items_sold)                                       AS items_sold,
           SUM(sa.revenue)                                          AS revenue,
           SUM(sa.revenue - (sa.items_sold * p.unitcost))           AS gross_margin,
           SUM(sa.return_count)                                     AS return_count,
           SUM(sa.total_delivery_days)                              AS total_delivery_days
    FROM sales_agg sa
    INNER JOIN dbo.dimproduct p ON sa.productid = p.productid
    GROUP BY sa.hour, sa.channel
)
SELECT hour, channel, transactions, items_sold,
       ROUND(revenue, 2)                                            AS revenue,
       ROUND(gross_margin, 2)                                       AS gross_margin,
       ROUND(gross_margin / NULLIF(revenue, 0), 4)                  AS margin_pct,
       ROUND(1.0 * return_count / NULLIF(transactions, 0), 4)       AS return_rate,
       ROUND(CAST(total_delivery_days AS DECIMAL(18,2)) / 
             NULLIF(transactions, 0), 2)                            AS avg_delivery_days,
       RANK() OVER (PARTITION BY channel ORDER BY revenue DESC)     AS revenue_rank_in_channel
FROM hourly_prod_margin
WHERE hour IS NOT NULL;
GO
EXEC sp_add_view_description '011_vw_hourly_sales_margin_analysis',
    'Hourly breakdown of sales and margin (fraction) per channel.';
GO

-- 012: Pareto revenue & margin combined – how many products drive 80% of each
DROP VIEW IF EXISTS dbo.[012_vw_pareto_revenue_margin];
GO
CREATE VIEW dbo.[012_vw_pareto_revenue_margin]
AS
WITH prod_agg AS (
    SELECT p.productid, p.name, p.category,
           SUM(f.grossvalue - f.discountamount)                     AS revenue,
           SUM(f.grossvalue - f.discountamount -
               (f.qty * p.unitcost))                                AS margin
    FROM dbo.factsales f
    INNER JOIN dbo.dimproduct p ON f.productid = p.productid
    WHERE f.isreturn = 0
    GROUP BY p.productid, p.name, p.category
),
run AS (
    SELECT *,
           SUM(revenue) OVER (ORDER BY revenue DESC)                AS run_rev,
           SUM(revenue) OVER ()                                     AS tot_rev,
           SUM(margin) OVER (ORDER BY margin DESC)                  AS run_mar,
           SUM(margin) OVER ()                                      AS tot_mar
    FROM prod_agg
)
SELECT COUNT(*)                                                     AS products_needed_for_80pct_revenue,
       MIN(CASE WHEN run_rev / tot_rev >= 0.8
                THEN revenue END)                                   AS min_rev_in_top80,
       COUNT(CASE WHEN run_mar / tot_mar <= 0.8
                  THEN 1 END)                                       AS products_needed_for_80pct_margin,
       MIN(CASE WHEN run_mar / tot_mar >= 0.8
                THEN margin END)                                    AS min_margin_in_top80
FROM run
WHERE run_rev / tot_rev <= 0.8 OR run_mar / tot_mar <= 0.8;
GO
EXEC sp_add_view_description '012_vw_pareto_revenue_margin',
    'Pareto analysis for revenue and margin.';
GO

-- 013: Basket analysis – top 100 product pairs bought together
--    Aggregates co-occurrences on salesid and joins item metrics.
DROP VIEW IF EXISTS dbo.[013_vw_basket_analysis];
GO
CREATE VIEW dbo.[013_vw_basket_analysis]
AS
WITH pairs AS (
    SELECT f1.productid AS product_a,
           f2.productid AS product_b,
           COUNT(*)     AS co_occurrence
    FROM dbo.factsales f1
    INNER JOIN dbo.factsales f2
        ON f1.salesid = f2.salesid AND f1.productid < f2.productid
    WHERE f1.isreturn = 0 AND f2.isreturn = 0
    GROUP BY f1.productid, f2.productid
),
pop AS (
    SELECT productid,
           COUNT(DISTINCT salesid) AS total_baskets
    FROM dbo.factsales
    WHERE isreturn = 0
    GROUP BY productid
)
SELECT TOP 100
       pa.product_a,
       pa.product_b,
       pa.co_occurrence,
       p1.total_baskets                                              AS baskets_a,
       p2.total_baskets                                              AS baskets_b,
       ROUND(1.0 * pa.co_occurrence / p1.total_baskets, 4)          AS lift_a_to_b,
       ROUND(1.0 * pa.co_occurrence / p2.total_baskets, 4)          AS lift_b_to_a
FROM pairs pa
INNER JOIN pop p1 ON pa.product_a = p1.productid
INNER JOIN pop p2 ON pa.product_b = p2.productid
ORDER BY pa.co_occurrence DESC;
GO
EXEC sp_add_view_description '013_vw_basket_analysis',
    'Top 100 product pairs bought together.';
GO

-- 014: Detailed delivery speed impact on margin
DROP VIEW IF EXISTS dbo.[014_vw_delivery_speed_impact_detailed];
GO
CREATE VIEW dbo.[014_vw_delivery_speed_impact_detailed]
AS
SELECT delivery_speed, channel, orders, returns,
       ROUND(1.0 * returns / NULLIF(orders, 0), 4)                  AS return_rate,
       avg_order_value,
       avg_margin,
       ROUND(avg_margin / NULLIF(avg_order_value, 0), 4)            AS margin_pct,
       avg_shipcost
FROM (
    SELECT CASE WHEN f.deliverydays <= 2 THEN 'Fast (1-2)'
                WHEN f.deliverydays <= 5 THEN 'Normal (3-5)'
                ELSE 'Slow (6+)' END                                 AS delivery_speed,
           f.channel,
           COUNT(*)                                                  AS orders,
           SUM(CASE WHEN f.isreturn = 1 THEN 1 ELSE 0 END)          AS returns,
           ROUND(AVG(f.grossvalue - f.discountamount), 2)            AS avg_order_value,
           ROUND(AVG(f.grossvalue - f.discountamount -
                     (f.qty * p.unitcost)), 2)                       AS avg_margin,
           ROUND(AVG(f.shipcost), 2)                                 AS avg_shipcost
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

-- 015: Margin by price tier and category
--    Optimized: Implements the aggregate-then-join pattern to avoid joining strings.
DROP VIEW IF EXISTS dbo.[015_vw_margin_by_price_tier];
GO
CREATE VIEW dbo.[015_vw_margin_by_price_tier]
AS
WITH sales_agg AS (
    SELECT f.productid,
           SUM(f.qty)                                               AS total_qty,
           SUM(f.grossvalue - f.discountamount)                     AS revenue
    FROM dbo.factsales f
    WHERE f.isreturn = 0
    GROUP BY f.productid
),
tier_prod_agg AS (
    SELECT CASE WHEN p.unitprice < 50  THEN 'Budget (<50)'
                WHEN p.unitprice < 200 THEN 'Mid (50-200)'
                WHEN p.unitprice < 500 THEN 'Premium (200-500)'
                ELSE 'Luxury (500+)' END                            AS price_tier,
           p.category,
           p.productid,
           sa.total_qty,
           sa.revenue,
           CAST(sa.revenue - (sa.total_qty * p.unitcost) AS DECIMAL(18,2)) AS total_margin,
           p.margin_pct                                             AS product_margin_pct
    FROM sales_agg sa
    INNER JOIN dbo.dimproduct p ON sa.productid = p.productid
)
SELECT price_tier,
       category,
       COUNT(DISTINCT productid)                                    AS products,
       SUM(total_qty)                                               AS total_qty,
       ROUND(SUM(revenue), 2)                                       AS revenue,
       ROUND(SUM(total_margin), 2)                                  AS total_margin,
       ROUND(SUM(total_margin) / NULLIF(SUM(revenue), 0), 4)        AS achieved_margin_pct,
       ROUND(AVG(product_margin_pct), 4)                            AS avg_product_margin_pct,
       ROUND(AVG(product_margin_pct) - 
             (SUM(total_margin) / NULLIF(SUM(revenue), 0)), 4)      AS margin_deviation
FROM tier_prod_agg
GROUP BY price_tier, category;
GO
EXEC sp_add_view_description '015_vw_margin_by_price_tier',
    'Margin (fraction) by price tier and category, comparing intrinsic vs achieved.';
GO

-- 016: Recency impact on spend
--    Optimized: Collapses detail-level left joins to pre-aggregated customer tables first.
DROP VIEW IF EXISTS dbo.[016_vw_recency_impact_on_spend];
GO
CREATE VIEW dbo.[016_vw_recency_impact_on_spend]
AS
WITH last_purchase AS (
    SELECT customerid, MAX(datekey) AS last_key
    FROM dbo.factsales
    WHERE isreturn = 0
    GROUP BY customerid
),
recency AS (
    SELECT c.customerid,
           DATEDIFF(day, d.fulldate, CAST(GETDATE() AS DATE))       AS days_since_last,
           CASE WHEN DATEDIFF(day, d.fulldate, CAST(GETDATE() AS DATE)) <= 30
                THEN 'Active (0-30 days)'
                WHEN DATEDIFF(day, d.fulldate, CAST(GETDATE() AS DATE)) <= 90
                THEN 'Recent (31-90 days)'
                WHEN DATEDIFF(day, d.fulldate, CAST(GETDATE() AS DATE)) <= 180
                THEN 'Dormant (91-180 days)'
                ELSE 'Churned (>180 days)' END                      AS recency_segment
    FROM last_purchase c
    INNER JOIN dbo.dimdate d ON c.last_key = d.datekey
),
future_agg AS (
    SELECT f.customerid,
           COUNT(DISTINCT f.salesid)                                AS order_count,
           SUM(f.grossvalue - f.discountamount)                     AS total_order_value,
           SUM(f.grossvalue - f.discountamount - (f.qty * p.unitcost)) AS total_order_margin
    FROM dbo.factsales f
    INNER JOIN dbo.dimproduct p ON f.productid = p.productid
    WHERE f.isreturn = 0
    GROUP BY f.customerid
)
SELECT r.recency_segment,
       COUNT(DISTINCT r.customerid)                                 AS customers,
       ROUND(SUM(f.total_order_value) / NULLIF(SUM(f.order_count), 0), 2) AS avg_order_value,
       ROUND(SUM(f.total_order_margin) / NULLIF(SUM(f.order_count), 0), 2) AS avg_order_margin,
       ROUND(SUM(f.total_order_margin) / NULLIF(SUM(f.total_order_value), 0), 4) AS avg_margin_pct,
       ROUND(CAST(SUM(f.order_count) AS DECIMAL(18,2)) / 
             NULLIF(COUNT(DISTINCT r.customerid), 0), 2)            AS avg_orders_per_customer
FROM recency r
LEFT JOIN future_agg f ON r.customerid = f.customerid
GROUP BY r.recency_segment;
GO
EXEC sp_add_view_description '016_vw_recency_impact_on_spend',
    'Recency groups and their average margin (fraction).';
GO

-- 017: Promotion margin efficiency
--    Optimized: Aggregates on promotional levels first and reduces complex detail-level joins.
DROP VIEW IF EXISTS dbo.[017_vw_promo_margin_efficiency];
GO
CREATE VIEW dbo.[017_vw_promo_margin_efficiency]
AS
WITH sales_agg AS (
    SELECT f.promoid,
           f.productid,
           SUM(f.qty)                                               AS total_qty,
           SUM(f.grossvalue - f.discountamount)                     AS revenue
    FROM dbo.factsales f
    WHERE f.isreturn = 0
    GROUP BY f.promoid, f.productid
),
promo_impact AS (
    SELECT sa.promoid,
           SUM(sa.revenue)                                          AS total_revenue,
           SUM(sa.revenue - (sa.total_qty * p.unitcost))            AS total_margin
    FROM sales_agg sa
    INNER JOIN dbo.dimproduct p ON sa.productid = p.productid
    WHERE sa.promoid != 0
    GROUP BY sa.promoid
),
promo_txn_counts AS (
    SELECT promoid,
           COUNT(DISTINCT salesid)                                  AS actual_txn
    FROM dbo.factsales
    WHERE promoid != 0 AND isreturn = 0
    GROUP BY promoid
),
baseline AS (
    SELECT AVG(f.grossvalue - f.discountamount)                    AS base_basket,
           AVG(f.grossvalue - f.discountamount - (f.qty * p.unitcost))  AS base_margin
    FROM dbo.factsales f
    INNER JOIN dbo.dimproduct p ON f.productid = p.productid
    WHERE f.promoid = 0 AND f.isreturn = 0
)
SELECT pi.promoid,
       pr.promoname,
       pr.type,
       pr.discount_pct,
       ptc.actual_txn                                               AS txn,
       ROUND(pi.total_revenue / NULLIF(ptc.actual_txn, 0), 2)       AS avg_basket,
       ROUND(pi.total_margin / NULLIF(ptc.actual_txn, 0), 2)        AS avg_margin,
       ROUND((pi.total_revenue / NULLIF(ptc.actual_txn, 0)) - 
             b.base_basket, 2)                                      AS basket_increase,
       ROUND((pi.total_margin / NULLIF(ptc.actual_txn, 0)) - 
             b.base_margin, 2)                                      AS margin_increase,
       ROUND(((pi.total_margin / NULLIF(ptc.actual_txn, 0)) - b.base_margin) / 
             NULLIF(b.base_margin, 0), 4)                           AS margin_uplift_pct,
       ROUND(pi.total_margin / NULLIF(ptc.actual_txn, 0), 2)        AS actual_margin_per_txn,
       RANK() OVER (ORDER BY ((pi.total_margin / NULLIF(ptc.actual_txn, 0)) - 
                              b.base_margin) DESC)                  AS margin_effectiveness_rank
FROM promo_impact pi
INNER JOIN dbo.dimpromotion pr  ON pi.promoid = pr.promoid
INNER JOIN promo_txn_counts ptc ON pi.promoid = ptc.promoid
CROSS JOIN baseline b;
GO
EXEC sp_add_view_description '017_vw_promo_margin_efficiency',
    'Promotion margin uplift (fraction).';
GO

-- ============================================================================
-- 7. FINAL – List all views with their extended property descriptions
-- ============================================================================
SELECT s.name      AS schema_name,
       v.name      AS view_name,
       ep.value    AS description
FROM sys.views v
INNER JOIN sys.schemas s ON v.schema_id = s.schema_id
LEFT JOIN sys.extended_properties ep
    ON ep.major_id = v.object_id
    AND ep.minor_id = 0
    AND ep.name = 'MS_Description'
WHERE v.name LIKE '[0-9][0-9][0-9]_vw_%'
   OR v.name LIKE '[0-9][0-9][0-9][0-9]_vw_%'
ORDER BY v.name;
GO

-- Clean up helper procedure (no longer needed after deployment)
DROP PROCEDURE IF EXISTS sp_add_view_description;
GO

PRINT '============================================================';
PRINT 'All analytical views created successfully (fraction _pct).';
PRINT '============================================================';
-- ============================================================================
-- End of create_analytical_views.sql
-- ============================================================================