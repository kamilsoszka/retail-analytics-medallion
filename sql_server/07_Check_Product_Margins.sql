-- =====================================================================
-- check_product_margins.sql
-- =====================================================================
-- Author:  AI Assistant
-- Created: 2026-05-21
-- Updated: 2026-05-23 (margin cap 25%, percentage storage)
-- Purpose: Analyze product margin percentages in retailanalytics database
-- =====================================================================

USE retailanalytics;
GO

PRINT '============================================================';
PRINT 'PRODUCT MARGIN ANALYSIS (25% cap, percent storage)';
PRINT '============================================================';
PRINT 'Margin = (UnitPrice - UnitCost) / UnitPrice * 100';
PRINT 'Maximum allowed margin: 25%';
PRINT '============================================================';

-- 1. Basic statistics
WITH MarginCalc AS (
    SELECT 
        productid,
        name,
        category,
        unitprice,
        unitcost,
        margin_pct AS stored_margin_pct,
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
    (SELECT DISTINCT PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY actual_margin_pct) OVER() FROM MarginCalc) AS median_margin_pct,
    SUM(CASE WHEN actual_margin_pct > 25.0 THEN 1 ELSE 0 END) AS products_above_25pct,
    SUM(CASE WHEN actual_margin_pct < 0 THEN 1 ELSE 0 END) AS products_negative_margin,
    SUM(CASE WHEN actual_margin_pct > 25.0 OR actual_margin_pct < 0 THEN 1 ELSE 0 END) AS products_invalid_margin,
    SUM(CASE WHEN ABS(stored_margin_pct - actual_margin_pct) > 0.01 THEN 1 ELSE 0 END) AS mismatched_stored_margin
FROM MarginCalc;
GO

-- 2. Violations >25%
PRINT '--- 2. PRODUCTS WITH MARGIN > 25% ---';
SELECT TOP 20
    productid,
    name,
    category,
    unitprice,
    unitcost,
    ((unitprice - unitcost) / unitprice) * 100 AS actual_margin_pct,
    margin_pct AS stored_margin_pct,
    'VIOLATION' AS remark
FROM dbo.dimproduct
WHERE unitprice > 0
  AND ((unitprice - unitcost) / unitprice) * 100 > 25.0
ORDER BY actual_margin_pct DESC;
GO

-- 3. Negative margins
PRINT '--- 3. PRODUCTS WITH NEGATIVE MARGIN ---';
SELECT TOP 20
    productid,
    name,
    category,
    unitprice,
    unitcost,
    ((unitprice - unitcost) / unitprice) * 100 AS actual_margin_pct,
    margin_pct AS stored_margin_pct,
    'WARNING' AS remark
FROM dbo.dimproduct
WHERE unitprice > 0
  AND ((unitprice - unitcost) / unitprice) * 100 < 0
ORDER BY actual_margin_pct ASC;
GO

-- 4. Distribution histogram (buckets of 5%)
PRINT '--- 4. MARGIN DISTRIBUTION ---';
WITH MarginCalc AS (
    SELECT 
        CASE 
            WHEN ((unitprice - unitcost) / NULLIF(unitprice, 0)) * 100 < 0 THEN 'Negative'
            WHEN ((unitprice - unitcost) / NULLIF(unitprice, 0)) * 100 <= 5 THEN '0-5%'
            WHEN ((unitprice - unitcost) / NULLIF(unitprice, 0)) * 100 <= 10 THEN '5-10%'
            WHEN ((unitprice - unitcost) / NULLIF(unitprice, 0)) * 100 <= 15 THEN '10-15%'
            WHEN ((unitprice - unitcost) / NULLIF(unitprice, 0)) * 100 <= 20 THEN '15-20%'
            WHEN ((unitprice - unitcost) / NULLIF(unitprice, 0)) * 100 <= 25 THEN '20-25%'
            ELSE '>25% (invalid)'
        END AS margin_bucket,
        COUNT(*) AS product_count,
        CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER() AS DECIMAL(5,2)) AS percentage
    FROM dbo.dimproduct
    WHERE unitprice > 0
    GROUP BY 
        CASE 
            WHEN ((unitprice - unitcost) / NULLIF(unitprice, 0)) * 100 < 0 THEN 'Negative'
            WHEN ((unitprice - unitcost) / NULLIF(unitprice, 0)) * 100 <= 5 THEN '0-5%'
            WHEN ((unitprice - unitcost) / NULLIF(unitprice, 0)) * 100 <= 10 THEN '5-10%'
            WHEN ((unitprice - unitcost) / NULLIF(unitprice, 0)) * 100 <= 15 THEN '10-15%'
            WHEN ((unitprice - unitcost) / NULLIF(unitprice, 0)) * 100 <= 20 THEN '15-20%'
            WHEN ((unitprice - unitcost) / NULLIF(unitprice, 0)) * 100 <= 25 THEN '20-25%'
            ELSE '>25% (invalid)'
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
        WHEN '20-25%' THEN 6
        WHEN '>25% (invalid)' THEN 7
    END;
GO

-- 5. By category
PRINT '--- 5. MARGIN STATISTICS BY CATEGORY ---';
SELECT 
    category,
    COUNT(*) AS products,
    MIN(((unitprice - unitcost) / NULLIF(unitprice, 0)) * 100) AS min_margin_pct,
    MAX(((unitprice - unitcost) / NULLIF(unitprice, 0)) * 100) AS max_margin_pct,
    AVG(((unitprice - unitcost) / NULLIF(unitprice, 0)) * 100) AS avg_margin_pct,
    SUM(CASE WHEN ((unitprice - unitcost) / NULLIF(unitprice, 0)) * 100 > 25.0 THEN 1 ELSE 0 END) AS violations_above_25pct
FROM dbo.dimproduct
WHERE unitprice > 0
GROUP BY category
ORDER BY avg_margin_pct DESC;
GO

-- 6. Consistency check
PRINT '--- 6. CONSISTENCY: stored vs calculated ---';
SELECT 
    COUNT(*) AS total_products,
    SUM(CASE WHEN ABS(margin_pct - ((unitprice - unitcost) / NULLIF(unitprice, 0)) * 100) <= 0.01 THEN 1 ELSE 0 END) AS consistent,
    SUM(CASE WHEN ABS(margin_pct - ((unitprice - unitcost) / NULLIF(unitprice, 0)) * 100) > 0.01 THEN 1 ELSE 0 END) AS inconsistent,
    CAST(SUM(CASE WHEN ABS(margin_pct - ((unitprice - unitcost) / NULLIF(unitprice, 0)) * 100) > 0.01 THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) AS inconsistency_pct
FROM dbo.dimproduct
WHERE unitprice > 0;
GO

-- 7. Sample
PRINT '--- 7. SAMPLE PRODUCTS (within allowed margin) ---';
SELECT TOP 10
    productid,
    name,
    category,
    unitprice,
    unitcost,
    margin_pct AS stored_margin_pct,
    ((unitprice - unitcost) / unitprice) * 100 AS actual_margin_pct
FROM dbo.dimproduct
WHERE unitprice > 0
  AND ((unitprice - unitcost) / unitprice) * 100 BETWEEN 0 AND 25.0
ORDER BY productid;
GO

PRINT '============================================================';
PRINT 'ANALYSIS COMPLETE – All margins should be between 0% and 25%.';
PRINT '============================================================';