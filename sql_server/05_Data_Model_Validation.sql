-- ============================================================================
-- model_validation.sql
-- ============================================================================
-- Author:       DataGen AI
-- Date:         2026-05-23
-- Description:  Validates star schema integrity, foreign keys, and CCI.
-- ============================================================================

USE retailanalytics;
GO

SET NOCOUNT ON;

PRINT '================================================================================';
PRINT 'MODEL VALIDATION – retailanalytics';
PRINT '================================================================================';

DROP TABLE IF EXISTS #model_checks;
CREATE TABLE #model_checks (
    check_category NVARCHAR(50),
    check_description NVARCHAR(200),
    check_result NVARCHAR(20),
    details INT
);

INSERT INTO #model_checks
SELECT 'star_schema',
       'factsales has foreign keys to all 5 dimensions',
       CASE WHEN COUNT(*) = 5 THEN 'OK' ELSE 'ISSUE' END,
       COUNT(*)
FROM sys.foreign_keys
WHERE parent_object_id = OBJECT_ID('dbo.factsales')
  AND referenced_object_id IN (OBJECT_ID('dbo.dimdate'), OBJECT_ID('dbo.dimproduct'),
                               OBJECT_ID('dbo.dimcustomer'), OBJECT_ID('dbo.dimstore'),
                               OBJECT_ID('dbo.dimpromotion'));

INSERT INTO #model_checks
SELECT 'fact_purity',
       'factsales contains only allowed columns (no extra columns)',
       CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'ISSUE' END,
       COUNT(*)
FROM sys.columns
WHERE object_id = OBJECT_ID('dbo.factsales')
  AND name NOT IN ('salesid','datekey','productid','customerid','storeid','promoid',
                   'qty','unitprice','tax_rate','net','payment','channel','grossvalue',
                   'discountamount','taxamount','shipcost','isreturn','shipweight',
                   'discountapplied','returnreason','deliverydays','hour');

INSERT INTO #model_checks
SELECT 'dimension_keys',
       'all five dimension tables have a primary key',
       CASE WHEN COUNT(DISTINCT parent_object_id) = 5 THEN 'OK' ELSE 'ISSUE' END,
       COUNT(DISTINCT parent_object_id)
FROM sys.key_constraints
WHERE type = 'PK' AND parent_object_id IN (OBJECT_ID('dbo.dimdate'), OBJECT_ID('dbo.dimproduct'),
                                           OBJECT_ID('dbo.dimcustomer'), OBJECT_ID('dbo.dimstore'),
                                           OBJECT_ID('dbo.dimpromotion'));

INSERT INTO #model_checks
SELECT 'performance',
       'factsales has a clustered columnstore index',
       CASE WHEN COUNT(*) = 1 THEN 'OK' ELSE 'ISSUE' END,
       COUNT(*)
FROM sys.indexes
WHERE object_id = OBJECT_ID('dbo.factsales') AND type_desc = 'CLUSTERED COLUMNSTORE';

INSERT INTO #model_checks
SELECT 'referential_integrity',
       'no orphan rows in factsales (including promoid=0)',
       CASE WHEN orphan_count = 0 THEN 'OK' ELSE 'ISSUE' END,
       orphan_count
FROM (
    SELECT COUNT(*) AS orphan_count
    FROM dbo.factsales f
    LEFT JOIN dbo.dimdate d ON f.datekey = d.datekey
    LEFT JOIN dbo.dimproduct p ON f.productid = p.productid
    LEFT JOIN dbo.dimcustomer c ON f.customerid = c.customerid
    LEFT JOIN dbo.dimstore s ON f.storeid = s.storeid
    LEFT JOIN dbo.dimpromotion pr ON f.promoid = pr.promoid
    WHERE d.datekey IS NULL OR p.productid IS NULL OR c.customerid IS NULL
       OR s.storeid IS NULL OR pr.promoid IS NULL
) AS orphan_check;

SELECT check_category, check_description, check_result, details
FROM #model_checks
ORDER BY CASE WHEN check_result = 'ISSUE' THEN 0 ELSE 1 END, check_category;

DROP TABLE #model_checks;

PRINT '================================================================================';
PRINT 'MODEL VALIDATION COMPLETED.';
PRINT '================================================================================';
GO
-- ============================================================================
-- End of model_validation.sql
-- ============================================================================