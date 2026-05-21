-- =====================================================================
-- check_product_margins.sql
-- =====================================================================
-- Author:       AI Assistant
-- Last modified: 2026-05-21 12:00:00 UTC
-- Purpose:      Analyze product margin percentages in retailanalytics database
--               - Verifies that margins are <= 20% as required (generator enforces this)
--               - Shows distribution, statistics, and potential violations
--               - Compatible with final schema (margin_pct stored as decimal)
-- =====================================================================

USE retailanalytics;
GO

PRINT '============================================================';
PRINT 'PRODUCT MARGIN ANALYSIS';
PRINT '============================================================';
PRINT 'Margin is defined as (UnitPrice - UnitCost) / UnitPrice';
PRINT 'Maximum allowed margin: 20% (0.20)';
PRINT '============================================================';
GO

-- =====================================================================
-- 1. Basic statistics and validation
-- =====================================================================
PRINT CHAR(10) + '--- 1. BASIC STATISTICS & VALIDATION ---';
WITH MarginCalc AS (
    SELECT 
        productid,
        name,
        category,
        unitprice,
        unitcost,
        margin_pct AS stored_margin_pct,
        -- Calculate actual margin (as decimal)
        (unitprice - unitcost) / NULLIF(unitprice, 0) AS actual_margin,
        -- Convert to percentage
        ((unitprice - unitcost) / NULLIF(unitprice, 0)) * 100 AS actual_margin_pct
    FROM dbo.dimproduct
    WHERE unitprice > 0
)
SELECT 
    COUNT(*) AS total_products,
    MIN(actual_margin_pct) AS min_margin_pct,
    MAX(actual_margin_pct) AS max_margin_pct,
    AVG(actual_margin_pct) AS avg_margin_pct,
    STDEV(actual_margin_pct) AS stdev_margin_pct,
    -- Median using PERCENTILE_CONT
    (SELECT DISTINCT PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY actual_margin_pct) OVER() FROM MarginCalc) AS median_margin_pct,
    SUM(CASE WHEN actual_margin > 0.20 THEN 1 ELSE 0 END) AS products_above_20pct,
    SUM(CASE WHEN actual_margin < 0 THEN 1 ELSE 0 END) AS products_negative_margin,
    SUM(CASE WHEN actual_margin > 0.20 OR actual_margin < 0 THEN 1 ELSE 0 END) AS products_invalid_margin,
    -- Check consistency between stored margin_pct and calculated margin
    SUM(CASE WHEN ABS(stored_margin_pct - actual_margin) > 0.0001 THEN 1 ELSE 0 END) AS mismatched_stored_margin
FROM MarginCalc;
GO

-- =====================================================================
-- 2. List products with margins exceeding 20% (if any)
-- =====================================================================
PRINT CHAR(10) + '--- 2. PRODUCTS WITH MARGIN > 20% (VIOLATIONS) ---';
SELECT TOP 20
    productid,
    name,
    category,
    unitprice,
    unitcost,
    ((unitprice - unitcost) / unitprice) * 100 AS actual_margin_pct,
    margin_pct AS stored_margin_pct,
    'VIOLATION: Margin exceeds 20% limit' AS remark
FROM dbo.dimproduct
WHERE unitprice > 0
  AND (unitprice - unitcost) / unitprice > 0.20
ORDER BY ((unitprice - unitcost) / unitprice) DESC;
GO

-- =====================================================================
-- 3. List products with negative margin (loss)
-- =====================================================================
PRINT CHAR(10) + '--- 3. PRODUCTS WITH NEGATIVE MARGIN (LOSS) ---';
SELECT TOP 20
    productid,
    name,
    category,
    unitprice,
    unitcost,
    ((unitprice - unitcost) / unitprice) * 100 AS actual_margin_pct,
    margin_pct AS stored_margin_pct,
    'WARNING: Negative margin (loss)' AS remark
FROM dbo.dimproduct
WHERE unitprice > 0
  AND (unitprice - unitcost) / unitprice < 0
ORDER BY ((unitprice - unitcost) / unitprice) ASC;
GO

-- =====================================================================
-- 4. Margin distribution histogram (buckets of 5 percentage points)
-- =====================================================================
PRINT CHAR(10) + '--- 4. MARGIN DISTRIBUTION (HISTOGRAM) ---';
WITH MarginCalc AS (
    SELECT 
        CASE 
            WHEN (unitprice - unitcost) / NULLIF(unitprice, 0) < 0 THEN 'Negative'
            WHEN (unitprice - unitcost) / NULLIF(unitprice, 0) <= 0.05 THEN '0-5%'
            WHEN (unitprice - unitcost) / NULLIF(unitprice, 0) <= 0.10 THEN '5-10%'
            WHEN (unitprice - unitcost) / NULLIF(unitprice, 0) <= 0.15 THEN '10-15%'
            WHEN (unitprice - unitcost) / NULLIF(unitprice, 0) <= 0.20 THEN '15-20%'
            ELSE '>20% (invalid)'
        END AS margin_bucket,
        COUNT(*) AS product_count,
        CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER() AS DECIMAL(5,2)) AS percentage
    FROM dbo.dimproduct
    WHERE unitprice > 0
    GROUP BY 
        CASE 
            WHEN (unitprice - unitcost) / NULLIF(unitprice, 0) < 0 THEN 'Negative'
            WHEN (unitprice - unitcost) / NULLIF(unitprice, 0) <= 0.05 THEN '0-5%'
            WHEN (unitprice - unitcost) / NULLIF(unitprice, 0) <= 0.10 THEN '5-10%'
            WHEN (unitprice - unitcost) / NULLIF(unitprice, 0) <= 0.15 THEN '10-15%'
            WHEN (unitprice - unitcost) / NULLIF(unitprice, 0) <= 0.20 THEN '15-20%'
            ELSE '>20% (invalid)'
        END
)
SELECT 
    margin_bucket,
    product_count,
    percentage,
    REPLICATE('█', CAST(percentage / 2 AS INT)) AS bar_chart
FROM MarginCalc
ORDER BY 
    CASE margin_bucket
        WHEN 'Negative' THEN 1
        WHEN '0-5%' THEN 2
        WHEN '5-10%' THEN 3
        WHEN '10-15%' THEN 4
        WHEN '15-20%' THEN 5
        WHEN '>20% (invalid)' THEN 6
    END;
GO

-- =====================================================================
-- 5. Margin statistics by product category
-- =====================================================================
PRINT CHAR(10) + '--- 5. MARGIN STATISTICS BY CATEGORY ---';
SELECT 
    category,
    COUNT(*) AS products_in_category,
    MIN(((unitprice - unitcost) / NULLIF(unitprice, 0)) * 100) AS min_margin_pct,
    MAX(((unitprice - unitcost) / NULLIF(unitprice, 0)) * 100) AS max_margin_pct,
    AVG(((unitprice - unitcost) / NULLIF(unitprice, 0)) * 100) AS avg_margin_pct,
    SUM(CASE WHEN ((unitprice - unitcost) / NULLIF(unitprice, 0)) > 0.20 THEN 1 ELSE 0 END) AS violations_above_20pct
FROM dbo.dimproduct
WHERE unitprice > 0
GROUP BY category
ORDER BY avg_margin_pct DESC;
GO

-- =====================================================================
-- 6. Check if stored margin_pct column matches calculated margin
-- =====================================================================
PRINT CHAR(10) + '--- 6. CONSISTENCY: stored margin_pct vs calculated ---';
SELECT 
    COUNT(*) AS total_products,
    SUM(CASE WHEN ABS(margin_pct - ((unitprice - unitcost) / NULLIF(unitprice, 0))) < 0.0001 THEN 1 ELSE 0 END) AS consistent,
    SUM(CASE WHEN ABS(margin_pct - ((unitprice - unitcost) / NULLIF(unitprice, 0))) >= 0.0001 THEN 1 ELSE 0 END) AS inconsistent,
    CAST(SUM(CASE WHEN ABS(margin_pct - ((unitprice - unitcost) / NULLIF(unitprice, 0))) >= 0.0001 THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) AS inconsistency_pct
FROM dbo.dimproduct
WHERE unitprice > 0;
GO

-- =====================================================================
-- 7. Display sample of products with correct margins (for reference)
-- =====================================================================
PRINT CHAR(10) + '--- 7. SAMPLE PRODUCTS (first 10, within allowed margin) ---';
SELECT TOP 10
    productid,
    name,
    category,
    unitprice,
    unitcost,
    ((unitprice - unitcost) / unitprice) * 100 AS actual_margin_pct,
    margin_pct AS stored_margin_pct
FROM dbo.dimproduct
WHERE unitprice > 0
  AND ((unitprice - unitcost) / unitprice) BETWEEN 0 AND 0.20
ORDER BY productid;
GO

PRINT CHAR(10) + '============================================================';
PRINT 'ANALYSIS COMPLETE';
PRINT '============================================================';
PRINT 'Expected: All margins should be between 0% and 20%.';
PRINT 'If any violations appear, run the data generation script again.';
PRINT '============================================================';