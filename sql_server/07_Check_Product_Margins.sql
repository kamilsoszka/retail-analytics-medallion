-- ============================================================================
-- check_product_margins.sql
-- ============================================================================
-- Author:       DataGen AI
-- Date:         2026-05-23
-- Description:  Analyze product margin distribution (fraction -0.10 to 0.30).
-- ============================================================================

USE retailanalytics;
GO

PRINT '============================================================';
PRINT 'PRODUCT MARGIN ANALYSIS (max 30%, min -10%)';
PRINT '============================================================';
PRINT 'Margin = (UnitPrice - UnitCost) / UnitPrice';
PRINT 'Stored as fraction in margin_pct';
PRINT '============================================================';

-- 1. Basic statistics (margin_pct is fraction, multiply by 100 for display)
WITH MarginCalc AS (
    SELECT productid, name, category, unitprice, unitcost, margin_pct AS stored_margin_pct,
           ((unitprice - unitcost) / NULLIF(unitprice, 0)) * 100 AS actual_margin_pct
    FROM dbo.dimproduct WHERE unitprice > 0
)
SELECT COUNT(*) AS total_products,
       MIN(actual_margin_pct) AS min_margin_pct,
       MAX(actual_margin_pct) AS max_margin_pct,
       AVG(actual_margin_pct) AS avg_margin_pct,
       STDEV(actual_margin_pct) AS stdev_margin_pct,
       (SELECT DISTINCT PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY actual_margin_pct) OVER() FROM MarginCalc) AS median_margin_pct,
       SUM(CASE WHEN actual_margin_pct > 30.0 THEN 1 ELSE 0 END) AS products_above_30pct,
       SUM(CASE WHEN actual_margin_pct < -10.0 THEN 1 ELSE 0 END) AS products_below_minus10pct,
       SUM(CASE WHEN actual_margin_pct > 30.0 OR actual_margin_pct < -10.0 THEN 1 ELSE 0 END) AS products_invalid_margin,
       SUM(CASE WHEN ABS(stored_margin_pct - (actual_margin_pct/100)) > 0.0001 THEN 1 ELSE 0 END) AS mismatched_stored_margin
FROM MarginCalc;
GO

-- 2. Violations >30%
PRINT '--- 2. PRODUCTS WITH MARGIN > 30% ---';
SELECT TOP 20 productid, name, category, unitprice, unitcost,
       ((unitprice - unitcost) / unitprice) * 100 AS actual_margin_pct,
       margin_pct AS stored_margin_pct,
       'VIOLATION' AS remark
FROM dbo.dimproduct WHERE unitprice > 0
  AND ((unitprice - unitcost) / unitprice) * 100 > 30.0
ORDER BY actual_margin_pct DESC;
GO

-- 3. Margins below -10%
PRINT '--- 3. PRODUCTS WITH MARGIN < -10% ---';
SELECT TOP 20 productid, name, category, unitprice, unitcost,
       ((unitprice - unitcost) / unitprice) * 100 AS actual_margin_pct,
       margin_pct AS stored_margin_pct,
       'WARNING' AS remark
FROM dbo.dimproduct WHERE unitprice > 0
  AND ((unitprice - unitcost) / unitprice) * 100 < -10.0
ORDER BY actual_margin_pct ASC;
GO

-- 4. Distribution histogram (buckets of 5% up to 30%, plus negative)
PRINT '--- 4. MARGIN DISTRIBUTION ---';
WITH MarginCalc AS (
    SELECT CASE
        WHEN ((unitprice - unitcost) / NULLIF(unitprice, 0)) * 100 < -10 THEN '< -10%'
        WHEN ((unitprice - unitcost) / NULLIF(unitprice, 0)) * 100 <= -5 THEN '-10% to -5%'
        WHEN ((unitprice - unitcost) / NULLIF(unitprice, 0)) * 100 <= 0 THEN '-5% to 0%'
        WHEN ((unitprice - unitcost) / NULLIF(unitprice, 0)) * 100 <= 5 THEN '0-5%'
        WHEN ((unitprice - unitcost) / NULLIF(unitprice, 0)) * 100 <= 10 THEN '5-10%'
        WHEN ((unitprice - unitcost) / NULLIF(unitprice, 0)) * 100 <= 15 THEN '10-15%'
        WHEN ((unitprice - unitcost) / NULLIF(unitprice, 0)) * 100 <= 20 THEN '15-20%'
        WHEN ((unitprice - unitcost) / NULLIF(unitprice, 0)) * 100 <= 25 THEN '20-25%'
        WHEN ((unitprice - unitcost) / NULLIF(unitprice, 0)) * 100 <= 30 THEN '25-30%'
        ELSE '>30% (invalid)'
    END AS margin_bucket,
    COUNT(*) AS product_count,
    CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER() AS DECIMAL(5,2)) AS percentage
    FROM dbo.dimproduct WHERE unitprice > 0
    GROUP BY CASE
        WHEN ((unitprice - unitcost) / NULLIF(unitprice, 0)) * 100 < -10 THEN '< -10%'
        WHEN ((unitprice - unitcost) / NULLIF(unitprice, 0)) * 100 <= -5 THEN '-10% to -5%'
        WHEN ((unitprice - unitcost) / NULLIF(unitprice, 0)) * 100 <= 0 THEN '-5% to 0%'
        WHEN ((unitprice - unitcost) / NULLIF(unitprice, 0)) * 100 <= 5 THEN '0-5%'
        WHEN ((unitprice - unitcost) / NULLIF(unitprice, 0)) * 100 <= 10 THEN '5-10%'
        WHEN ((unitprice - unitcost) / NULLIF(unitprice, 0)) * 100 <= 15 THEN '10-15%'
        WHEN ((unitprice - unitcost) / NULLIF(unitprice, 0)) * 100 <= 20 THEN '15-20%'
        WHEN ((unitprice - unitcost) / NULLIF(unitprice, 0)) * 100 <= 25 THEN '20-25%'
        WHEN ((unitprice - unitcost) / NULLIF(unitprice, 0)) * 100 <= 30 THEN '25-30%'
        ELSE '>30% (invalid)'
    END
)
SELECT margin_bucket, product_count, percentage,
       REPLICATE('█', CAST(percentage / 2 AS INT)) AS bar_chart
FROM MarginCalc
ORDER BY CASE margin_bucket
    WHEN '< -10%' THEN 1
    WHEN '-10% to -5%' THEN 2
    WHEN '-5% to 0%' THEN 3
    WHEN '0-5%' THEN 4
    WHEN '5-10%' THEN 5
    WHEN '10-15%' THEN 6
    WHEN '15-20%' THEN 7
    WHEN '20-25%' THEN 8
    WHEN '25-30%' THEN 9
    ELSE 10
END;
GO

-- 5. By category
PRINT '--- 5. MARGIN STATISTICS BY CATEGORY ---';
SELECT category, COUNT(*) AS products,
       MIN(((unitprice - unitcost) / NULLIF(unitprice, 0)) * 100) AS min_margin_pct,
       MAX(((unitprice - unitcost) / NULLIF(unitprice, 0)) * 100) AS max_margin_pct,
       AVG(((unitprice - unitcost) / NULLIF(unitprice, 0)) * 100) AS avg_margin_pct,
       SUM(CASE WHEN ((unitprice - unitcost) / NULLIF(unitprice, 0)) * 100 > 30.0 THEN 1 ELSE 0 END) AS violations_above_30pct
FROM dbo.dimproduct WHERE unitprice > 0
GROUP BY category ORDER BY avg_margin_pct DESC;
GO

-- 6. Consistency stored vs calculated
PRINT '--- 6. CONSISTENCY: stored vs calculated ---';
SELECT COUNT(*) AS total_products,
       SUM(CASE WHEN ABS(margin_pct - ((unitprice - unitcost) / NULLIF(unitprice, 0))) < 0.0001 THEN 1 ELSE 0 END) AS consistent,
       SUM(CASE WHEN ABS(margin_pct - ((unitprice - unitcost) / NULLIF(unitprice, 0))) >= 0.0001 THEN 1 ELSE 0 END) AS inconsistent,
       CAST(SUM(CASE WHEN ABS(margin_pct - ((unitprice - unitcost) / NULLIF(unitprice, 0))) >= 0.0001 THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) AS inconsistency_pct
FROM dbo.dimproduct WHERE unitprice > 0;
GO

-- 7. Sample
PRINT '--- 7. SAMPLE PRODUCTS (within allowed margin) ---';
SELECT TOP 10 productid, name, category, unitprice, unitcost,
       margin_pct AS stored_margin_pct,
       ((unitprice - unitcost) / unitprice) * 100 AS actual_margin_pct
FROM dbo.dimproduct WHERE unitprice > 0
  AND ((unitprice - unitcost) / unitprice) * 100 BETWEEN -10.0 AND 30.0
ORDER BY productid;
GO

PRINT '============================================================';
PRINT 'ANALYSIS COMPLETE – Margins between -10% and 30% allowed.';
PRINT '============================================================';
-- ============================================================================
-- End of check_product_margins.sql
-- ============================================================================