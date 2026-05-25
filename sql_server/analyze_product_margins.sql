-- ============================================================================
-- analyze_product_margins.sql
-- ============================================================================
-- Author:           DataGen AI & Assistant
-- Created:          2026-05-23
-- Last modified:    2026-05-25 18:55:00 UTC
-- Suggested name:   analyze_product_margins.sql
-- Description:
--   Performs a detailed analysis of the product margin distribution in the
--   retailanalytics database.  Margins are stored as fractions (-0.10 to
--   0.30). Correctly handles dummy productid = -1 by filtering active products.
--   The script displays:
--     • Basic statistics (min, max, avg, median, standard deviation)
--     • Count of products with margins above 30% or below -10%
--     • Consistency between stored margin_pct and calculated value
--     • Distribution histogram with visual bars
--     • Margin statistics broken down by product category
--     • Sample products within the allowed range
--   Large numeric values (>1000) are formatted with thousand separators and
--   zero decimal places.  Percentage values are displayed with two decimal
--   places (e.g. 12.50%).
-- ============================================================================

USE retailanalytics;
GO

SET NOCOUNT ON;

PRINT '============================================================';
PRINT 'PRODUCT MARGIN ANALYSIS (max 30%, min -10%)';
PRINT '============================================================';
PRINT 'Margin = (UnitPrice - UnitCost) / UnitPrice';
PRINT 'Stored as fraction in margin_pct';
PRINT '============================================================';
PRINT '';

-- ============================================================================
-- 1. BASIC STATISTICS
--    margin_pct is stored as a fraction – multiply by 100 for display.
--    Numeric results > 1000 are shown with thousand separators, 0 decimals.
--    Percentage values are shown with two decimal places.
-- ============================================================================
PRINT '--- 1. BASIC STATISTICS & VALIDATION ---';
WITH MarginCalc AS (
    SELECT
        productid,
        name,
        category,
        unitprice,
        unitcost,
        margin_pct AS stored_margin_pct,
        -- Calculate actual margin as a percentage (0‑100 scale) with division protection
        ((unitprice - unitcost) / NULLIF(unitprice, 0)) * 100 AS actual_margin_pct
    FROM dbo.dimproduct
    WHERE productid > 0 AND unitprice > 0
)
SELECT
    FORMAT(COUNT(*), 'N0')                                              AS total_products,
    FORMAT(MIN(actual_margin_pct), 'N2') + '%'                          AS min_margin_pct,
    FORMAT(MAX(actual_margin_pct), 'N2') + '%'                          AS max_margin_pct,
    FORMAT(AVG(actual_margin_pct), 'N2') + '%'                          AS avg_margin_pct,
    FORMAT(STDEV(actual_margin_pct), 'N2') + '%'                        AS stdev_margin_pct,
    FORMAT((SELECT DISTINCT PERCENTILE_CONT(0.5) WITHIN GROUP
            (ORDER BY actual_margin_pct) OVER() FROM MarginCalc), 'N2') + '%'
                                                                        AS median_margin_pct,
    FORMAT(SUM(CASE WHEN actual_margin_pct > 30.0 THEN 1 ELSE 0 END), 'N0')
                                                                        AS products_above_30pct,
    FORMAT(SUM(CASE WHEN actual_margin_pct < -10.0 THEN 1 ELSE 0 END), 'N0')
                                                                        AS products_below_minus10pct,
    FORMAT(SUM(CASE WHEN actual_margin_pct > 30.0
                         OR actual_margin_pct < -10.0 THEN 1 ELSE 0 END), 'N0')
                                                                        AS products_invalid_margin,
    FORMAT(SUM(CASE WHEN ABS(stored_margin_pct -
                             (actual_margin_pct / 100)) > 0.0001
                    THEN 1 ELSE 0 END), 'N0')
                                                                        AS mismatched_stored_margin
FROM MarginCalc;
GO

-- ============================================================================
-- 2. PRODUCTS WITH MARGIN > 30% (VIOLATIONS)
--    These products exceed the maximum allowed margin.
-- ============================================================================
PRINT '--- 2. PRODUCTS WITH MARGIN > 30% (VIOLATIONS) ---';
SELECT TOP 20
    productid,
    name,
    category,
    unitprice,
    unitcost,
    FORMAT(((unitprice - unitcost) / NULLIF(unitprice, 0)) * 100, 'N2') + '%'     AS actual_margin_pct,
    FORMAT(margin_pct * 100, 'N2') + '%'                                          AS stored_margin_pct,
    'VIOLATION'                                                                   AS remark
FROM dbo.dimproduct
WHERE productid > 0 
  AND unitprice > 0
  AND ((unitprice - unitcost) / NULLIF(unitprice, 0)) * 100 > 30.0
ORDER BY ((unitprice - unitcost) / NULLIF(unitprice, 0)) * 100 DESC;
GO

-- ============================================================================
-- 3. PRODUCTS WITH MARGIN < -10% (LOSSES EXCEEDING ALLOWED NEGATIVE BOUND)
-- ============================================================================
PRINT '--- 3. PRODUCTS WITH MARGIN < -10% ---';
SELECT TOP 20
    productid,
    name,
    category,
    unitprice,
    unitcost,
    FORMAT(((unitprice - unitcost) / NULLIF(unitprice, 0)) * 100, 'N2') + '%'     AS actual_margin_pct,
    FORMAT(margin_pct * 100, 'N2') + '%'                                          AS stored_margin_pct,
    'WARNING'                                                                     AS remark
FROM dbo.dimproduct
WHERE productid > 0 
  AND unitprice > 0
  AND ((unitprice - unitcost) / NULLIF(unitprice, 0)) * 100 < -10.0
ORDER BY ((unitprice - unitcost) / NULLIF(unitprice, 0)) * 100 ASC;
GO

-- ============================================================================
-- 4. MARGIN DISTRIBUTION HISTOGRAM
--    Products are bucketed in 5‑percentage‑point intervals.
--    Optimized: Removes repeated CASE statements using sub-aggregations.
--    A visual bar chart is drawn using the █ character.
-- ============================================================================
PRINT '--- 4. MARGIN DISTRIBUTION (HISTOGRAM) ---';
WITH MarginData AS (
    SELECT 
        ((unitprice - unitcost) / NULLIF(unitprice, 0)) * 100 AS actual_margin_pct
    FROM dbo.dimproduct
    WHERE productid > 0 AND unitprice > 0
),
BucketedData AS (
    SELECT 
        CASE
            WHEN actual_margin_pct < -10  THEN '< -10%'
            WHEN actual_margin_pct <= -5  THEN '-10% to -5%'
            WHEN actual_margin_pct <= 0   THEN '-5% to 0%'
            WHEN actual_margin_pct <= 5   THEN '0-5%'
            WHEN actual_margin_pct <= 10  THEN '5-10%'
            WHEN actual_margin_pct <= 15  THEN '10-15%'
            WHEN actual_margin_pct <= 20  THEN '15-20%'
            WHEN actual_margin_pct <= 25  THEN '20-25%'
            WHEN actual_margin_pct <= 30  THEN '25-30%'
            ELSE '>30% (invalid)'
        END AS margin_bucket
    FROM MarginData
),
HistogramAgg AS (
    SELECT 
        margin_bucket,
        COUNT(*) AS product_count,
        CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER() AS DECIMAL(5,2)) AS percentage
    FROM BucketedData
    GROUP BY margin_bucket
)
SELECT margin_bucket,
       FORMAT(product_count, 'N0')                AS product_count,
       FORMAT(percentage, 'N2') + '%'             AS percentage,
       REPLICATE('█', CAST(percentage / 2 AS INT)) AS bar_chart
FROM HistogramAgg
ORDER BY CASE margin_bucket
    WHEN '< -10%'         THEN 1
    WHEN '-10% to -5%'    THEN 2
    WHEN '-5% to 0%'      THEN 3
    WHEN '0-5%'           THEN 4
    WHEN '5-10%'          THEN 5
    WHEN '10-15%'         THEN 6
    WHEN '15-20%'         THEN 7
    WHEN '20-25%'         THEN 8
    WHEN '25-30%'         THEN 9
    ELSE 10
END;
GO

-- ============================================================================
-- 5. MARGIN STATISTICS BY CATEGORY
--    For each product category the min, max, average margin (as percentages)
--    and the number of violations above 30% are shown.
--    The products column uses thousand separators; margins are formatted as
--    percentages with two decimal places.
-- ============================================================================
PRINT '--- 5. MARGIN STATISTICS BY CATEGORY ---';
SELECT category,
       FORMAT(COUNT(*), 'N0')                                         AS products,
       FORMAT(MIN(((unitprice - unitcost) / NULLIF(unitprice, 0)) * 100), 'N2') + '%'
                                                                       AS min_margin_pct,
       FORMAT(MAX(((unitprice - unitcost) / NULLIF(unitprice, 0)) * 100), 'N2') + '%'
                                                                       AS max_margin_pct,
       FORMAT(AVG(((unitprice - unitcost) / NULLIF(unitprice, 0)) * 100), 'N2') + '%'
                                                                       AS avg_margin_pct,
       FORMAT(SUM(CASE WHEN ((unitprice - unitcost) / NULLIF(unitprice, 0)) * 100 > 30.0
                       THEN 1 ELSE 0 END), 'N0')
                                                                       AS violations_above_30pct
FROM dbo.dimproduct
WHERE productid > 0 AND unitprice > 0
GROUP BY category
ORDER BY AVG(((unitprice - unitcost) / NULLIF(unitprice, 0)) * 100) DESC;
GO

-- ============================================================================
-- 6. CONSISTENCY CHECK – stored margin_pct vs calculated
--    Counts how many products have a stored margin that matches the
--    recalculated value within a tolerance of 0.0001.
--    The inconsistency percentage is shown with two decimal places.
-- ============================================================================
PRINT '--- 6. CONSISTENCY: stored margin_pct vs calculated ---';
SELECT FORMAT(COUNT(*), 'N0')                                          AS total_products,
       FORMAT(SUM(CASE WHEN ABS(margin_pct -
                                ((unitprice - unitcost) /
                                 NULLIF(unitprice, 0))) < 0.0001
                       THEN 1 ELSE 0 END), 'N0')                      AS consistent,
       FORMAT(SUM(CASE WHEN ABS(margin_pct -
                                ((unitprice - unitcost) /
                                 NULLIF(unitprice, 0))) >= 0.0001
                       THEN 1 ELSE 0 END), 'N0')                      AS inconsistent,
       FORMAT(CAST(SUM(CASE WHEN ABS(margin_pct -
                                    ((unitprice - unitcost) /
                                     NULLIF(unitprice, 0))) >= 0.0001
                           THEN 1 ELSE 0 END) * 100.0 /
                   NULLIF(COUNT(*), 0) AS DECIMAL(5,2)), 'N2') + '%'  AS inconsistency_pct
FROM dbo.dimproduct
WHERE productid > 0 AND unitprice > 0;
GO

-- ============================================================================
-- 7. SAMPLE PRODUCTS WITHIN THE ALLOWED MARGIN RANGE
--    Displays a few rows so the user can visually inspect the data.
--    Both stored and calculated margins are shown as percentages.
-- ============================================================================
PRINT '--- 7. SAMPLE PRODUCTS (within allowed margin) ---';
SELECT TOP 10
    productid,
    name,
    category,
    unitprice,
    unitcost,
    FORMAT(margin_pct * 100, 'N2') + '%'                                          AS stored_margin_pct,
    FORMAT(((unitprice - unitcost) / NULLIF(unitprice, 0)) * 100, 'N2') + '%'     AS actual_margin_pct
FROM dbo.dimproduct
WHERE productid > 0 
  AND unitprice > 0
  AND ((unitprice - unitcost) / NULLIF(unitprice, 0)) * 100 BETWEEN -10.0 AND 30.0
ORDER BY productid;
GO

PRINT '============================================================';
PRINT 'ANALYSIS COMPLETE – Margins between -10% and 30% allowed.';
PRINT '============================================================';
-- ============================================================================
-- End of analyze_product_margins.sql
-- ============================================================================