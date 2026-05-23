-- =====================================================================
-- deploy_all_analytical_views.sql
-- =====================================================================
-- Author:  AI Assistant
-- Created: 2026-05-23
-- Updated: 2026-05-23 (margin cap 25%, percentage storage)
-- Purpose: Create all analytical views for retailanalytics database
--          Compatible with final schema: 10M rows, hour column, margin ≤25%
-- =====================================================================

USE retailanalytics;
GO

-- Drop all existing numbered views
DECLARE @sql NVARCHAR(MAX) = '';
SELECT @sql = @sql + 'DROP VIEW IF EXISTS ' + QUOTENAME(SCHEMA_NAME(schema_id)) + '.' + QUOTENAME(name) + ';'
FROM sys.views
WHERE name LIKE '[0-9][0-9][0-9]_vw_%' OR name LIKE '[0-9][0-9][0-9][0-9]_vw_%';
EXEC sp_executesql @sql;
GO

-- Helper to add extended property descriptions
CREATE OR ALTER PROCEDURE sp_add_view_description
    @view_name NVARCHAR(128),
    @description NVARCHAR(500)
AS
BEGIN
    DECLARE @schema NVARCHAR(128) = 'dbo';
    DECLARE @fullname NVARCHAR(256) = @schema + '.' + @view_name;
    
    IF EXISTS (SELECT 1 FROM sys.extended_properties 
               WHERE major_id = OBJECT_ID(@fullname) 
                 AND minor_id = 0 
                 AND name = 'MS_Description')
    BEGIN
        EXEC sp_dropextendedproperty 
            @name = N'MS_Description', 
            @level0type = N'SCHEMA', @level0name = @schema,
            @level1type = N'VIEW', @level1name = @view_name;
    END
    
    EXEC sp_addextendedproperty 
        @name = N'MS_Description', 
        @value = @description,
        @level0type = N'SCHEMA', @level0name = @schema,
        @level1type = N'VIEW', @level1name = @view_name;
END
GO

-- ==========================================================================
-- 001: Product category margin analysis (margin shown as percent, cap 25%)
-- ==========================================================================
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
    -- Margin as percentage (e.g., 25.00 = 25%)
    ROUND((total_revenue - total_cost) / NULLIF(total_revenue, 0) * 100, 2) AS margin_pct,
    RANK() OVER (PARTITION BY category ORDER BY (total_revenue - total_cost) / NULLIF(total_revenue, 0) DESC) AS rank_in_cat
FROM revenue_cost
WHERE total_revenue > 0;
GO
EXEC sp_add_view_description 
    '001_vw_product_category_margin',
    'Shows margin per product and category (as percent), ranking within category. Margin cap enforced at 25% in dim_product.';
GO

-- ==========================================================================
-- 002: Promotion performance (margin and uplift as percent, discount_pct as percent)
-- ==========================================================================
CREATE VIEW dbo.[002_vw_promo_performance]
AS
WITH promo_performance AS (
    SELECT
        p.promoid,
        p.promoname,
        p.type,
        p.discount_pct,             -- already percent (e.g., 25.00)
        p.promoupliftfactor,
        COUNT(DISTINCT f.salesid) AS num_transactions,
        SUM(f.qty) AS total_qty,
        SUM(f.grossvalue - f.discountamount) AS revenue,
        SUM(f.grossvalue - f.discountamount - (f.qty * pr.unitcost)) AS margin,
        AVG(CASE WHEN f.grossvalue > 0 THEN f.discountamount / f.grossvalue ELSE 0 END) AS avg_disc_rate
    FROM dbo.factsales f
    JOIN dbo.dimpromotion p ON f.promoid = p.promoid
    JOIN dbo.dimproduct pr ON f.productid = pr.productid
    WHERE p.promoid != 0 AND f.isreturn = 0
    GROUP BY p.promoid, p.promoname, p.type, p.discount_pct, p.promoupliftfactor
),
baseline AS (
    SELECT
        AVG(f.grossvalue - f.discountamount) AS avg_revenue_baseline,
        AVG(f.qty) AS avg_qty_baseline
    FROM dbo.factsales f
    WHERE f.promoid = 0 AND f.isreturn = 0
)
SELECT
    pp.*,
    ROUND(pp.revenue / NULLIF(pp.num_transactions, 0), 2) AS avg_basket,
    ROUND((pp.revenue / NULLIF(pp.num_transactions, 0) - baseline.avg_revenue_baseline) / NULLIF(baseline.avg_revenue_baseline, 0) * 100, 2) AS uplift_pct,
    ROUND(pp.margin / NULLIF(pp.revenue, 0) * 100, 2) AS margin_pct,   -- percent
    RANK() OVER (ORDER BY pp.margin DESC) AS margin_rank,
    RANK() OVER (ORDER BY (pp.revenue / NULLIF(pp.num_transactions, 0) - baseline.avg_revenue_baseline) / NULLIF(baseline.avg_revenue_baseline, 0) DESC) AS uplift_rank
FROM promo_performance pp
CROSS JOIN baseline;
GO
EXEC sp_add_view_description 
    '002_vw_promo_performance',
    'Compares promotions vs baseline. margin_pct, uplift_pct, discount_pct are all percentages (e.g., 25.00).';
GO

-- ==========================================================================
-- 003: Customer RFM segments (margin as percent)
-- ==========================================================================
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
    ROUND(AVG(margin_total / NULLIF(monetary, 0)) * 100, 2) AS avg_margin_pct   -- percent
FROM segments
GROUP BY segment;
GO
EXEC sp_add_view_description 
    '003_vw_customer_rfm_segments',
    'RFM segmentation with average margin per segment (as percent).';
GO

-- ==========================================================================
-- 004: Returns analysis
-- ==========================================================================
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
EXEC sp_add_view_description 
    '004_vw_returns_analysis',
    'Return counts by channel and reason.';
GO

-- ==========================================================================
-- 005: Channel performance
-- ==========================================================================
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
EXEC sp_add_view_description 
    '005_vw_channel_performance',
    'Key metrics per channel.';
GO

-- ==========================================================================
-- 006: Seasonal category revenue
-- ==========================================================================
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
EXEC sp_add_view_description 
    '006_vw_seasonal_category_revenue',
    'Revenue by category and month for seasonality analysis.';
GO

-- ==========================================================================
-- 007: Store performance by region/type
-- ==========================================================================
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
EXEC sp_add_view_description 
    '007_vw_store_performance_by_region_type',
    'Store performance aggregated by region and type.';
GO

-- ==========================================================================
-- 008: Pareto margin analysis
-- ==========================================================================
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
EXEC sp_add_view_description 
    '008_vw_pareto_margin_analysis',
    'How many products contribute 80% of total margin.';
GO

-- ==========================================================================
-- 009: Delivery speed impact on returns
-- ==========================================================================
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
EXEC sp_add_view_description 
    '009_vw_delivery_speed_impact',
    'Return rate by delivery speed for online channels.';
GO

-- ==========================================================================
-- 010: Warranty and eco-friendly impact
-- ==========================================================================
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
EXEC sp_add_view_description 
    '010_vw_warranty_eco_impact',
    'Impact of warranty and eco certification on sales and returns.';
GO

-- ==========================================================================
-- 011: Hourly sales and margin analysis (margin as percent)
-- ==========================================================================
CREATE VIEW dbo.[011_vw_hourly_sales_margin_analysis]
AS
WITH hourly_data AS (
    SELECT
        f.hour,
        f.channel,
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
SELECT
    hour,
    channel,
    transactions,
    items_sold,
    ROUND(revenue, 2) AS revenue,
    ROUND(gross_margin, 2) AS gross_margin,
    ROUND(gross_margin / NULLIF(revenue, 0) * 100, 2) AS margin_pct,   -- percent
    return_rate,
    avg_delivery_days,
    RANK() OVER (PARTITION BY channel ORDER BY revenue DESC) AS revenue_rank_in_channel
FROM hourly_data
WHERE hour IS NOT NULL;
GO
EXEC sp_add_view_description 
    '011_vw_hourly_sales_margin_analysis',
    'Hourly breakdown of sales and margin (percent) per channel.';
GO

-- ==========================================================================
-- 012: Pareto revenue & margin combined
-- ==========================================================================
CREATE VIEW dbo.[012_vw_pareto_revenue_margin]
AS
WITH product_aggregates AS (
    SELECT
        p.productid,
        p.name,
        p.category,
        SUM(f.grossvalue - f.discountamount) AS revenue,
        SUM(f.grossvalue - f.discountamount - (f.qty * p.unitcost)) AS margin
    FROM dbo.factsales f
    INNER JOIN dbo.dimproduct p ON f.productid = p.productid
    WHERE f.isreturn = 0
    GROUP BY p.productid, p.name, p.category
),
running_totals AS (
    SELECT
        *,
        SUM(revenue) OVER (ORDER BY revenue DESC) AS running_revenue,
        SUM(revenue) OVER () AS total_revenue,
        SUM(margin) OVER (ORDER BY margin DESC) AS running_margin,
        SUM(margin) OVER () AS total_margin
    FROM product_aggregates
)
SELECT
    COUNT(*) AS products_needed_for_80pct_revenue,
    MIN(CASE WHEN running_revenue / total_revenue >= 0.8 THEN revenue ELSE NULL END) AS min_revenue_in_top80,
    COUNT(CASE WHEN running_margin / total_margin <= 0.8 THEN 1 END) AS products_needed_for_80pct_margin,
    MIN(CASE WHEN running_margin / total_margin >= 0.8 THEN margin ELSE NULL END) AS min_margin_in_top80
FROM running_totals
WHERE running_revenue / total_revenue <= 0.8 OR running_margin / total_margin <= 0.8;
GO
EXEC sp_add_view_description 
    '012_vw_pareto_revenue_margin',
    'Pareto analysis for revenue and margin – how many products drive 80% of each.';
GO

-- ==========================================================================
-- 013: Basket analysis – frequently bought together
-- ==========================================================================
CREATE VIEW dbo.[013_vw_basket_analysis]
AS
WITH basket_pairs AS (
    SELECT
        f1.productid AS product_a,
        f2.productid AS product_b,
        COUNT(*) AS co_occurrence
    FROM dbo.factsales f1
    INNER JOIN dbo.factsales f2 ON f1.salesid = f2.salesid AND f1.productid < f2.productid
    WHERE f1.isreturn = 0 AND f2.isreturn = 0
    GROUP BY f1.productid, f2.productid
),
product_popularity AS (
    SELECT productid, COUNT(DISTINCT salesid) AS total_baskets
    FROM dbo.factsales
    WHERE isreturn = 0
    GROUP BY productid
)
SELECT TOP 100
    pa.product_a,
    pa.product_b,
    pa.co_occurrence,
    p1.total_baskets AS baskets_product_a,
    p2.total_baskets AS baskets_product_b,
    ROUND(1.0 * pa.co_occurrence / p1.total_baskets, 4) AS lift_a_to_b,
    ROUND(1.0 * pa.co_occurrence / p2.total_baskets, 4) AS lift_b_to_a
FROM basket_pairs pa
INNER JOIN product_popularity p1 ON pa.product_a = p1.productid
INNER JOIN product_popularity p2 ON pa.product_b = p2.productid
ORDER BY pa.co_occurrence DESC;
GO
EXEC sp_add_view_description 
    '013_vw_basket_analysis',
    'Top 100 product pairs bought together (cross‑sell opportunities).';
GO

-- ==========================================================================
-- 014: Detailed delivery speed impact on margin (margin as percent)
-- ==========================================================================
CREATE VIEW dbo.[014_vw_delivery_speed_impact_detailed]
AS
WITH delivery_stats AS (
    SELECT
        CASE
            WHEN f.deliverydays <= 2 THEN 'Fast (1-2)'
            WHEN f.deliverydays <= 5 THEN 'Normal (3-5)'
            ELSE 'Slow (6+)'
        END AS delivery_speed,
        f.channel,
        COUNT(*) AS orders,
        SUM(CASE WHEN f.isreturn = 1 THEN 1 ELSE 0 END) AS returns,
        ROUND(AVG(f.grossvalue - f.discountamount), 2) AS avg_order_value,
        ROUND(AVG(f.grossvalue - f.discountamount - (f.qty * p.unitcost)), 2) AS avg_margin,
        ROUND(AVG(f.shipcost), 2) AS avg_shipcost
    FROM dbo.factsales f
    INNER JOIN dbo.dimproduct p ON f.productid = p.productid
    WHERE f.channel IN ('Online', 'Mobile App')
      AND f.deliverydays > 0
    GROUP BY 
        CASE
            WHEN f.deliverydays <= 2 THEN 'Fast (1-2)'
            WHEN f.deliverydays <= 5 THEN 'Normal (3-5)'
            ELSE 'Slow (6+)'
        END,
        f.channel
)
SELECT
    delivery_speed,
    channel,
    orders,
    returns,
    ROUND(1.0 * returns / NULLIF(orders, 0), 4) AS return_rate,
    avg_order_value,
    avg_margin,
    ROUND(avg_margin / NULLIF(avg_order_value, 0) * 100, 2) AS margin_pct,   -- percent
    avg_shipcost
FROM delivery_stats;
GO
EXEC sp_add_view_description 
    '014_vw_delivery_speed_impact_detailed',
    'Delivery speed impact with margin percentage.';
GO

-- ==========================================================================
-- 015: Margin by price tier and category (using dim_product margin_pct as percent)
-- ==========================================================================
CREATE VIEW dbo.[015_vw_margin_by_price_tier]
AS
WITH price_tiers AS (
    SELECT
        CASE
            WHEN p.unitprice < 50 THEN 'Budget (<50)'
            WHEN p.unitprice < 200 THEN 'Mid (50-200)'
            WHEN p.unitprice < 500 THEN 'Premium (200-500)'
            ELSE 'Luxury (500+)'
        END AS price_tier,
        p.category,
        COUNT(DISTINCT p.productid) AS products,
        SUM(f.qty) AS total_qty,
        SUM(f.grossvalue - f.discountamount) AS revenue,
        SUM(f.grossvalue - f.discountamount - (f.qty * p.unitcost)) AS total_margin,
        AVG(p.margin_pct) AS avg_product_margin_pct   -- already percent (e.g., 25.00)
    FROM dbo.factsales f
    INNER JOIN dbo.dimproduct p ON f.productid = p.productid
    WHERE f.isreturn = 0
    GROUP BY 
        CASE
            WHEN p.unitprice < 50 THEN 'Budget (<50)'
            WHEN p.unitprice < 200 THEN 'Mid (50-200)'
            WHEN p.unitprice < 500 THEN 'Premium (200-500)'
            ELSE 'Luxury (500+)'
        END,
        p.category
)
SELECT
    price_tier,
    category,
    products,
    total_qty,
    ROUND(revenue, 2) AS revenue,
    ROUND(total_margin, 2) AS total_margin,
    ROUND(total_margin / NULLIF(revenue, 0) * 100, 2) AS achieved_margin_pct,   -- percent
    avg_product_margin_pct,
    ROUND(avg_product_margin_pct - (total_margin / NULLIF(revenue, 0) * 100), 2) AS margin_deviation
FROM price_tiers;
GO
EXEC sp_add_view_description 
    '015_vw_margin_by_price_tier',
    'Margin (percent) by price tier and category, comparing built‑in margin vs. achieved.';
GO

-- ==========================================================================
-- 016: Recency impact on spend (margin as percent)
-- ==========================================================================
CREATE VIEW dbo.[016_vw_recency_impact_on_spend]
AS
WITH customer_last_purchase AS (
    SELECT
        customerid,
        MAX(datekey) AS last_purchase_datekey
    FROM dbo.factsales
    WHERE isreturn = 0
    GROUP BY customerid
),
recency_groups AS (
    SELECT
        c.customerid,
        DATEDIFF(day, d.fulldate, GETDATE()) AS days_since_last,
        CASE
            WHEN DATEDIFF(day, d.fulldate, GETDATE()) <= 30 THEN 'Active (0-30 days)'
            WHEN DATEDIFF(day, d.fulldate, GETDATE()) <= 90 THEN 'Recent (31-90 days)'
            WHEN DATEDIFF(day, d.fulldate, GETDATE()) <= 180 THEN 'Dormant (91-180 days)'
            ELSE 'Churned (>180 days)'
        END AS recency_segment
    FROM customer_last_purchase c
    INNER JOIN dbo.dimdate d ON c.last_purchase_datekey = d.datekey
),
future_purchases AS (
    SELECT
        f.customerid,
        f.salesid,
        f.grossvalue - f.discountamount AS order_value,
        f.grossvalue - f.discountamount - (f.qty * p.unitcost) AS order_margin
    FROM dbo.factsales f
    INNER JOIN dbo.dimproduct p ON f.productid = p.productid
    WHERE f.isreturn = 0
)
SELECT
    r.recency_segment,
    COUNT(DISTINCT r.customerid) AS customers,
    AVG(fp.order_value) AS avg_order_value,
    AVG(fp.order_margin) AS avg_order_margin,
    ROUND(AVG(fp.order_margin) / NULLIF(AVG(fp.order_value), 0) * 100, 2) AS avg_margin_pct,   -- percent
    COUNT(fp.salesid) / COUNT(DISTINCT r.customerid) AS avg_orders_per_customer
FROM recency_groups r
LEFT JOIN future_purchases fp ON r.customerid = fp.customerid
GROUP BY r.recency_segment;
GO
EXEC sp_add_view_description 
    '016_vw_recency_impact_on_spend',
    'Customer recency groups and their average order value / margin (percent).';
GO

-- ==========================================================================
-- 017: Promotion margin efficiency (margin uplift as percent)
-- ==========================================================================
CREATE VIEW dbo.[017_vw_promo_margin_efficiency]
AS
WITH promo_impact AS (
    SELECT
        p.promoid,
        p.promoname,
        p.type,
        p.discount_pct,   -- percent
        AVG(f.grossvalue - f.discountamount) AS avg_basket_promo,
        AVG(f.grossvalue - f.discountamount - (f.qty * pr.unitcost)) AS avg_margin_promo,
        COUNT(*) AS transactions_promo,
        SUM(f.grossvalue - f.discountamount - (f.qty * pr.unitcost)) AS total_margin_promo
    FROM dbo.factsales f
    INNER JOIN dbo.dimpromotion p ON f.promoid = p.promoid
    INNER JOIN dbo.dimproduct pr ON f.productid = pr.productid
    WHERE p.promoid != 0 AND f.isreturn = 0
    GROUP BY p.promoid, p.promoname, p.type, p.discount_pct
),
baseline AS (
    SELECT
        AVG(f.grossvalue - f.discountamount) AS avg_baseline_basket,
        AVG(f.grossvalue - f.discountamount - (f.qty * pr.unitcost)) AS avg_baseline_margin,
        COUNT(*) AS baseline_transactions
    FROM dbo.factsales f
    INNER JOIN dbo.dimproduct pr ON f.productid = pr.productid
    WHERE f.promoid = 0 AND f.isreturn = 0
)
SELECT
    pi.promoid,
    pi.promoname,
    pi.type,
    pi.discount_pct,
    pi.transactions_promo,
    pi.avg_basket_promo,
    pi.avg_margin_promo,
    ROUND(pi.avg_basket_promo - baseline.avg_baseline_basket, 2) AS basket_increase,
    ROUND(pi.avg_margin_promo - baseline.avg_baseline_margin, 2) AS margin_increase,
    ROUND((pi.avg_margin_promo - baseline.avg_baseline_margin) / NULLIF(baseline.avg_baseline_margin, 0) * 100, 2) AS margin_uplift_pct,
    ROUND(pi.total_margin_promo / NULLIF(pi.transactions_promo, 0), 2) AS actual_margin_per_txn,
    RANK() OVER (ORDER BY (pi.avg_margin_promo - baseline.avg_baseline_margin) DESC) AS margin_effectiveness_rank
FROM promo_impact pi
CROSS JOIN baseline;
GO
EXEC sp_add_view_description 
    '017_vw_promo_margin_efficiency',
    'Ranks promotions by margin uplift (percentage). Identifies truly profitable promotions.';
GO

-- ==========================================================================
-- Final: list views with descriptions
-- ==========================================================================
SELECT 
    s.name AS schema_name,
    v.name AS view_name,
    ep.value AS description
FROM sys.views v
INNER JOIN sys.schemas s ON v.schema_id = s.schema_id
LEFT JOIN sys.extended_properties ep 
    ON ep.major_id = v.object_id 
    AND ep.minor_id = 0 
    AND ep.name = 'MS_Description'
WHERE v.name LIKE '[0-9][0-9][0-9]_vw_%' OR v.name LIKE '[0-9][0-9][0-9][0-9]_vw_%'
ORDER BY v.name;
GO

DROP PROCEDURE IF EXISTS sp_add_view_description;
GO

PRINT '============================================================';
PRINT 'All views created – margins and discounts stored as percentages.';
PRINT '============================================================';