-- =====================================================================
-- 04_analytical_views.sql
-- ANALYTICAL VIEWS (compatible with final schema – no dimmanager)
-- Corrected for promoid = 0 (instead of NULL) and new tables
-- Last updated: 2026-05-21
-- =====================================================================

USE retailanalytics;
GO

-- Drop all existing analytical views
IF OBJECT_ID('dbo.[001_vw_product_category_margin]', 'V') IS NOT NULL DROP VIEW dbo.[001_vw_product_category_margin];
IF OBJECT_ID('dbo.[002_vw_promo_performance]', 'V') IS NOT NULL DROP VIEW dbo.[002_vw_promo_performance];
IF OBJECT_ID('dbo.[003_vw_customer_rfm_segments]', 'V') IS NOT NULL DROP VIEW dbo.[003_vw_customer_rfm_segments];
IF OBJECT_ID('dbo.[004_vw_returns_analysis]', 'V') IS NOT NULL DROP VIEW dbo.[004_vw_returns_analysis];
IF OBJECT_ID('dbo.[005_vw_channel_performance]', 'V') IS NOT NULL DROP VIEW dbo.[005_vw_channel_performance];
IF OBJECT_ID('dbo.[006_vw_seasonal_category_revenue]', 'V') IS NOT NULL DROP VIEW dbo.[006_vw_seasonal_category_revenue];
IF OBJECT_ID('dbo.[007_vw_store_performance_by_region_type]', 'V') IS NOT NULL DROP VIEW dbo.[007_vw_store_performance_by_region_type];
IF OBJECT_ID('dbo.[008_vw_pareto_margin_analysis]', 'V') IS NOT NULL DROP VIEW dbo.[008_vw_pareto_margin_analysis];
IF OBJECT_ID('dbo.[009_vw_delivery_speed_impact]', 'V') IS NOT NULL DROP VIEW dbo.[009_vw_delivery_speed_impact];
IF OBJECT_ID('dbo.[010_vw_warranty_eco_impact]', 'V') IS NOT NULL DROP VIEW dbo.[010_vw_warranty_eco_impact];
GO

-- =====================================================================
-- VIEW 001: Product category margin analysis
-- =====================================================================
CREATE VIEW dbo.[001_vw_product_category_margin]
AS
WITH revenue_cost AS (
    SELECT
        p.category,
        p.productid,
        p.name,
        SUM(f.qty * p.unitcost) AS total_cost,
        SUM(f.grossvalue - f.discountamount) AS total_revenue
    FROM dbo.factsales f
    INNER JOIN dbo.dimproduct p ON f.productid = p.productid
    WHERE f.isreturn = 0
    GROUP BY p.category, p.productid, p.name
)
SELECT
    category,
    productid,
    name,
    total_revenue,
    total_cost,
    total_revenue - total_cost AS total_margin,
    ROUND((total_revenue - total_cost) / NULLIF(total_revenue, 0), 4) AS margin_pct,
    RANK() OVER (PARTITION BY category ORDER BY (total_revenue - total_cost) / NULLIF(total_revenue, 0) DESC) AS rank_in_cat
FROM revenue_cost
WHERE total_revenue > 0;
GO

-- =====================================================================
-- VIEW 002: Promotion performance (corrected: promoid = 0 instead of NULL)
-- =====================================================================
CREATE VIEW dbo.[002_vw_promo_performance]
AS
WITH promo_performance AS (
    SELECT
        p.promoid,
        p.promoname,
        p.type,
        p.discount_pct,
        p.promoupliftfactor,
        COUNT(DISTINCT f.salesid) AS num_transactions,
        SUM(f.qty) AS total_qty,
        SUM(f.grossvalue - f.discountamount) AS revenue,
        SUM(f.grossvalue - f.discountamount - (f.qty * pr.unitcost)) AS margin,
        AVG(CASE WHEN f.grossvalue > 0 THEN f.discountamount / f.grossvalue ELSE 0 END) AS avg_disc_rate
    FROM dbo.factsales f
    JOIN dbo.dimpromotion p ON f.promoid = p.promoid
    JOIN dbo.dimproduct pr ON f.productid = pr.productid
    WHERE p.promoid != 0 AND f.isreturn = 0   -- exclude dummy promo (0)
    GROUP BY p.promoid, p.promoname, p.type, p.discount_pct, p.promoupliftfactor
),
baseline AS (
    SELECT
        AVG(f.grossvalue - f.discountamount) AS avg_revenue_baseline,
        AVG(f.qty) AS avg_qty_baseline
    FROM dbo.factsales f
    WHERE f.promoid = 0 AND f.isreturn = 0   -- transactions with no promotion
)
SELECT
    pp.*,
    ROUND(pp.revenue / NULLIF(pp.num_transactions, 0), 2) AS avg_basket,
    ROUND((pp.revenue / NULLIF(pp.num_transactions, 0) - baseline.avg_revenue_baseline) / NULLIF(baseline.avg_revenue_baseline, 0), 4) AS uplift_pct,
    ROUND(pp.margin / NULLIF(pp.revenue, 0), 4) AS margin_pct,
    RANK() OVER (ORDER BY pp.margin DESC) AS margin_rank,
    RANK() OVER (ORDER BY (pp.revenue / NULLIF(pp.num_transactions, 0) - baseline.avg_revenue_baseline) / NULLIF(baseline.avg_revenue_baseline, 0) DESC) AS uplift_rank
FROM promo_performance pp
CROSS JOIN baseline;
GO

-- =====================================================================
-- VIEW 003: Customer RFM segments
-- =====================================================================
CREATE VIEW dbo.[003_vw_customer_rfm_segments]
AS
WITH customer_rfm AS (
    SELECT
        f.customerid,
        DATEDIFF(day, MAX(d.fulldate), CAST(GETDATE() AS DATE)) AS recency,
        COUNT(DISTINCT f.salesid) AS frequency,
        SUM(f.grossvalue - f.discountamount) AS monetary,
        SUM(f.grossvalue - f.discountamount - (f.qty * p.unitcost)) AS margin_total
    FROM dbo.factsales f
    JOIN dbo.dimdate d ON f.datekey = d.datekey
    JOIN dbo.dimproduct p ON f.productid = p.productid
    WHERE f.isreturn = 0
    GROUP BY f.customerid
),
rfm_scores AS (
    SELECT
        *,
        NTILE(5) OVER (ORDER BY recency DESC) AS recency_score,
        NTILE(5) OVER (ORDER BY frequency) AS frequency_score,
        NTILE(5) OVER (ORDER BY monetary) AS monetary_score
    FROM customer_rfm
),
segments AS (
    SELECT
        *,
        (recency_score + frequency_score + monetary_score) AS rfm_total,
        CASE
            WHEN recency_score >= 4 AND frequency_score >= 4 THEN 'Champions'
            WHEN recency_score >= 4 AND frequency_score >= 3 THEN 'Loyal'
            WHEN recency_score >= 3 AND monetary_score >= 4 THEN 'Big Spenders'
            WHEN recency_score <= 2 AND frequency_score <= 2 THEN 'At Risk'
            WHEN recency_score = 1 THEN 'Lost'
            ELSE 'Other'
        END AS segment
    FROM rfm_scores
)
SELECT
    segment,
    COUNT(*) AS customers,
    AVG(monetary) AS avg_ltv,
    SUM(monetary) AS total_ltv,
    ROUND(AVG(margin_total / NULLIF(monetary, 0)), 4) AS avg_margin_pct
FROM segments
GROUP BY segment;
GO

-- =====================================================================
-- VIEW 004: Returns analysis
-- =====================================================================
CREATE VIEW dbo.[004_vw_returns_analysis]
AS
SELECT
    f.channel,
    f.returnreason,
    COUNT(*) AS return_count,
    ROUND(1.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY f.channel), 4) AS pct_of_channel_returns,
    SUM(f.shipcost) AS total_shipping_cost_returns,
    AVG(f.grossvalue - f.discountamount) AS avg_return_value
FROM dbo.factsales f
WHERE f.isreturn = 1
GROUP BY f.channel, f.returnreason;
GO

-- =====================================================================
-- VIEW 005: Channel performance
-- =====================================================================
CREATE VIEW dbo.[005_vw_channel_performance]
AS
SELECT
    f.channel,
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

-- =====================================================================
-- VIEW 006: Seasonal category revenue
-- =====================================================================
CREATE VIEW dbo.[006_vw_seasonal_category_revenue]
AS
SELECT
    d.monthnumber,
    d.monthname,
    p.category,
    SUM(f.grossvalue - f.discountamount) AS revenue,
    SUM(f.qty) AS quantity,
    RANK() OVER (PARTITION BY p.category ORDER BY SUM(f.grossvalue - f.discountamount) DESC) AS rank_in_cat
FROM dbo.factsales f
JOIN dbo.dimdate d ON f.datekey = d.datekey
JOIN dbo.dimproduct p ON f.productid = p.productid
WHERE f.isreturn = 0
GROUP BY d.monthnumber, d.monthname, p.category;
GO

-- =====================================================================
-- VIEW 007: Store performance by region and type
-- =====================================================================
CREATE VIEW dbo.[007_vw_store_performance_by_region_type]
AS
SELECT
    s.region,
    s.type AS store_type,
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

-- =====================================================================
-- VIEW 008: Pareto margin analysis (80/20 rule)
-- =====================================================================
CREATE VIEW dbo.[008_vw_pareto_margin_analysis]
AS
WITH product_margin AS (
    SELECT
        p.productid,
        p.name,
        p.category,
        SUM(f.grossvalue - f.discountamount - (f.qty * p.unitcost)) AS margin
    FROM dbo.factsales f
    INNER JOIN dbo.dimproduct p ON f.productid = p.productid
    WHERE f.isreturn = 0
    GROUP BY p.productid, p.name, p.category
),
running AS (
    SELECT
        *,
        SUM(margin) OVER (ORDER BY margin DESC) AS running_margin,
        1.0 * SUM(margin) OVER (ORDER BY margin DESC) / NULLIF(SUM(margin) OVER (), 0) AS running_pct
    FROM product_margin
)
SELECT
    COUNT(*) AS product_cnt,
    MIN(running_pct) AS min_pct_contribution,
    MAX(running_pct) AS max_pct_contribution
FROM running
WHERE running_pct <= 0.8;
GO

-- =====================================================================
-- VIEW 009: Delivery speed impact on returns (online/mobile only)
-- =====================================================================
CREATE VIEW dbo.[009_vw_delivery_speed_impact]
AS
WITH delivery_groups AS (
    SELECT
        f.channel,
        p.category,
        CASE
            WHEN f.deliverydays <= 2 THEN 'Fast (1-2 days)'
            WHEN f.deliverydays <= 5 THEN 'Standard (3-5 days)'
            ELSE 'Long (>5 days)'
        END AS delivery_speed,
        f.isreturn,
        f.grossvalue - f.discountamount AS order_value
    FROM dbo.factsales f
    INNER JOIN dbo.dimproduct p ON f.productid = p.productid
    WHERE f.channel IN ('Online', 'Mobile App')
)
SELECT
    channel,
    category,
    delivery_speed,
    COUNT(*) AS total_orders,
    SUM(CASE WHEN isreturn = 1 THEN 1 ELSE 0 END) AS returns,
    ROUND(1.0 * SUM(CASE WHEN isreturn = 1 THEN 1 ELSE 0 END) / COUNT(*), 4) AS return_rate,
    AVG(order_value) AS avg_order_value
FROM delivery_groups
GROUP BY channel, category, delivery_speed;
GO

-- =====================================================================
-- VIEW 010: Warranty and eco-friendly impact
-- =====================================================================
CREATE VIEW dbo.[010_vw_warranty_eco_impact]
AS
SELECT
    p.haswarranty,
    p.ecofriendly,
    AVG(f.qty) AS avg_qty_per_transaction,
    AVG(f.grossvalue - f.discountamount) AS avg_revenue,
    ROUND(1.0 * SUM(CASE WHEN f.isreturn = 1 THEN 1 ELSE 0 END) / COUNT(*), 4) AS return_rate,
    COUNT(DISTINCT f.customerid) AS unique_buyers
FROM dbo.factsales f
INNER JOIN dbo.dimproduct p ON f.productid = p.productid
GROUP BY p.haswarranty, p.ecofriendly;
GO

-- =====================================================================
-- Verification: Show row counts for each view
-- =====================================================================
SELECT 'All analytical views created successfully (compatible with final schema).' AS status;
SELECT '001_vw_product_category_margin' AS ViewName, COUNT(*) AS RecordCount FROM [001_vw_product_category_margin]
UNION ALL SELECT '002_vw_promo_performance', COUNT(*) FROM [002_vw_promo_performance]
UNION ALL SELECT '003_vw_customer_rfm_segments', COUNT(*) FROM [003_vw_customer_rfm_segments]
UNION ALL SELECT '004_vw_returns_analysis', COUNT(*) FROM [004_vw_returns_analysis]
UNION ALL SELECT '005_vw_channel_performance', COUNT(*) FROM [005_vw_channel_performance]
UNION ALL SELECT '006_vw_seasonal_category_revenue', COUNT(*) FROM [006_vw_seasonal_category_revenue]
UNION ALL SELECT '007_vw_store_performance_by_region_type', COUNT(*) FROM [007_vw_store_performance_by_region_type]
UNION ALL SELECT '008_vw_pareto_margin_analysis', COUNT(*) FROM [008_vw_pareto_margin_analysis]
UNION ALL SELECT '009_vw_delivery_speed_impact', COUNT(*) FROM [009_vw_delivery_speed_impact]
UNION ALL SELECT '010_vw_warranty_eco_impact', COUNT(*) FROM [010_vw_warranty_eco_impact];
GO