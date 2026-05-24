-- ============================================================================
-- quick_data_quality_checks.sql
-- ============================================================================
-- Author:           DataGen AI
-- Created:           2026-05-23
-- Last modified:     2026-05-24 02:20:00 UTC
-- Suggested name:    quick_data_quality_checks.sql
-- Description:
--   A lightweight set of sanity checks for the retailanalytics database.
--   Large numeric values (>1000) are displayed with thousand separators
--   and zero decimal places.  Percentage values (margins, rates) are
--   shown as percentages with two decimal places (e.g. 12.50%).
--   For a comprehensive audit run `validate_retail_data_quality.sql`.
-- ============================================================================

USE retailanalytics;
GO

SET NOCOUNT ON;

PRINT '============================================================';
PRINT 'QUICK DATA QUALITY CHECKS – retailanalytics';
PRINT '============================================================';
PRINT '';

-- ============================================================================
-- 1. ROW COUNTS – formatted with thousand separators, zero decimals
-- ============================================================================
PRINT '--- 1. Row counts ---';
SELECT 'dimdate'      AS table_name,
       FORMAT(COUNT(*), 'N0') AS row_count
FROM dbo.dimdate
UNION ALL
SELECT 'dimcustomer'  , FORMAT(COUNT(*), 'N0') FROM dbo.dimcustomer
UNION ALL
SELECT 'dimproduct'   , FORMAT(COUNT(*), 'N0') FROM dbo.dimproduct
UNION ALL
SELECT 'dimstore'     , FORMAT(COUNT(*), 'N0') FROM dbo.dimstore
UNION ALL
SELECT 'dimpromotion' , FORMAT(COUNT(*), 'N0') FROM dbo.dimpromotion
UNION ALL
SELECT 'factsales'    , FORMAT(COUNT(*), 'N0') FROM dbo.factsales
ORDER BY table_name;

-- ============================================================================
-- 2. PRIMARY KEY DUPLICATES – formatted
-- ============================================================================
PRINT '--- 2. Primary key duplicates ---';
SELECT 'dimdate'      AS table_name,
       COUNT(*) - COUNT(DISTINCT datekey) AS duplicates
FROM dbo.dimdate
UNION ALL
SELECT 'dimcustomer'  , COUNT(*) - COUNT(DISTINCT customerid) FROM dbo.dimcustomer
UNION ALL
SELECT 'dimproduct'   , COUNT(*) - COUNT(DISTINCT productid)  FROM dbo.dimproduct
UNION ALL
SELECT 'dimstore'     , COUNT(*) - COUNT(DISTINCT storeid)    FROM dbo.dimstore
UNION ALL
SELECT 'dimpromotion' , COUNT(*) - COUNT(DISTINCT promoid)    FROM dbo.dimpromotion
UNION ALL
SELECT 'factsales'    , COUNT(*) - COUNT(DISTINCT salesid)    FROM dbo.factsales
ORDER BY table_name;

-- ============================================================================
-- 3. FINANCIAL SUMMARY (non‑return) – formatted
-- ============================================================================
PRINT '--- 3. Financial summary (non‑return) ---';
SELECT
    FORMAT(COUNT(*), 'N0')                         AS transactions,
    FORMAT(SUM(qty), 'N0')                         AS total_quantity,
    FORMAT(SUM(grossvalue - discountamount), 'N0') AS net_revenue_before_tax,
    FORMAT(SUM(net), 'N0')                         AS net_revenue_including_tax,
    FORMAT(SUM(taxamount), 'N0')                   AS total_tax,
    FORMAT(SUM(discountamount), 'N0')              AS total_discount
FROM dbo.factsales
WHERE isreturn = 0;

-- ============================================================================
-- 4. SAMPLE ROWS – raw data for visual inspection
-- ============================================================================
PRINT '--- 4. Sample rows (10) ---';
SELECT TOP 10
    salesid, datekey, productid, customerid, storeid, promoid,
    qty, unitprice, net, grossvalue, discountamount, taxamount,
    isreturn, hour, returnreason
FROM dbo.factsales
ORDER BY salesid;

-- ============================================================================
-- 5. ORPHAN FOREIGN KEYS – formatted
-- ============================================================================
PRINT '--- 5. Orphan foreign keys ---';
SELECT 'missing datekey'    AS constraint_name,
       COUNT(*) AS orphan_count
FROM dbo.factsales f LEFT JOIN dbo.dimdate d ON f.datekey = d.datekey
WHERE d.datekey IS NULL
UNION ALL
SELECT 'missing productid' , COUNT(*)
FROM dbo.factsales f LEFT JOIN dbo.dimproduct p ON f.productid = p.productid
WHERE p.productid IS NULL
UNION ALL
SELECT 'missing customerid', COUNT(*)
FROM dbo.factsales f LEFT JOIN dbo.dimcustomer c ON f.customerid = c.customerid
WHERE c.customerid IS NULL
UNION ALL
SELECT 'missing storeid'   , COUNT(*)
FROM dbo.factsales f LEFT JOIN dbo.dimstore s ON f.storeid = s.storeid
WHERE s.storeid IS NULL
UNION ALL
SELECT 'missing promoid'   , COUNT(*)
FROM dbo.factsales f LEFT JOIN dbo.dimpromotion pr ON f.promoid = pr.promoid
WHERE pr.promoid IS NULL
ORDER BY constraint_name;

-- ============================================================================
-- 6. FRACTION RANGE CHECKS – out_of_range counts formatted
-- ============================================================================
PRINT '--- 6. Fraction range checks ---';
SELECT 'margin_pct'   AS column_name,
       COUNT(*) AS out_of_range
FROM dbo.dimproduct
WHERE margin_pct < -0.10 OR margin_pct > 0.30
UNION ALL
SELECT 'tax_rate'     , COUNT(*)
FROM dbo.dimproduct
WHERE tax_rate < 0 OR tax_rate > 1
UNION ALL
SELECT 'discount_pct' , COUNT(*)
FROM dbo.dimpromotion
WHERE discount_pct < 0.0 OR discount_pct > 0.45
ORDER BY column_name;

-- ============================================================================
-- 7. HOUR VALIDATION – formatted
-- ============================================================================
PRINT '--- 7. Hour validation ---';
SELECT 'hour_null'        AS check_name,
       COUNT(*) AS count
FROM dbo.factsales WHERE hour IS NULL
UNION ALL
SELECT 'hour_out_of_range',
       COUNT(*)
FROM dbo.factsales WHERE hour NOT BETWEEN 0 AND 23;

-- ============================================================================
-- 8. RETURN REASON INTEGRITY – formatted
-- ============================================================================
PRINT '--- 8. Return reason integrity ---';
SELECT 'returnreason_null'        AS check_name,
       COUNT(*) AS count
FROM dbo.factsales WHERE returnreason IS NULL
UNION ALL
SELECT 'nonret_wrong_reason'      ,
       COUNT(*)
FROM dbo.factsales WHERE isreturn = 0 AND returnreason != 'No return'
UNION ALL
SELECT 'ret_missing_reason'       ,
       COUNT(*)
FROM dbo.factsales WHERE isreturn = 1 AND returnreason = 'No return';

-- ============================================================================
-- 9. DELIVERY DAYS LOGIC – formatted
-- ============================================================================
PRINT '--- 9. Delivery days logic ---';
SELECT 'instore_nonzero' AS check_name,
       COUNT(*) AS count
FROM dbo.factsales
WHERE channel = 'In-Store' AND deliverydays != 0
UNION ALL
SELECT 'online_zero'     ,
       COUNT(*)
FROM dbo.factsales
WHERE channel IN ('Online', 'Mobile App') AND deliverydays = 0 AND isreturn = 0;

-- ============================================================================
-- 10. GOLD VIEW SUMMARY – formatted (numbers with thousand separators,
--     margin as percentage with 2 decimal places)
-- ============================================================================
PRINT '--- 10. Gold view summary ---';
IF OBJECT_ID('dbo.[001_vw_product_category_margin]', 'V') IS NOT NULL
BEGIN
    SELECT FORMAT(COUNT(*), 'N0')                     AS rows,
           FORMAT(SUM(total_revenue), 'N0')           AS total_revenue,
           FORMAT(AVG(margin_pct) * 100, 'N2') + '%'  AS avg_margin
    FROM dbo.[001_vw_product_category_margin];
END
ELSE
    PRINT 'View 001_vw_product_category_margin not found – skipping.';
GO

PRINT '============================================================';
PRINT 'QUICK VALIDATION COMPLETED.';
PRINT '============================================================';
-- ============================================================================
-- End of quick_data_quality_checks.sql
-- ============================================================================