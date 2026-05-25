-- ============================================================================
-- validate_star_schema_model.sql
-- ============================================================================
-- Author:           DataGen AI & Assistant
-- Created:          2026-05-23
-- Last modified:    2026-05-25 18:50:00 UTC
-- Suggested name:   validate_star_schema_model.sql
-- Description:
--   Performs a lightweight structural validation of the retailanalytics
--   star‑schema model.  It verifies:
--     1. That the fact table has foreign keys pointing to all 5 dimensions.
--     2. That the fact table contains only the expected columns.
--     3. That every dimension table has a primary key defined.
--     4. That the fact table has a clustered columnstore index (CCI).
--     5. That all foreign keys on factsales are fully trusted by the optimizer.
--     6. That the database recovery model is set to SIMPLE (prevents log bloat).
--     7. That there are no orphan rows in the fact table (trusted FK-assisted).
-- ============================================================================

USE retailanalytics;
GO

SET NOCOUNT ON;

PRINT '================================================================================';
PRINT 'MODEL VALIDATION – retailanalytics';
PRINT '================================================================================';

-- ---------------------------------------------------------------------------
-- Temporary table to collect the results of each structural check.
-- ---------------------------------------------------------------------------
DROP TABLE IF EXISTS #model_checks;
CREATE TABLE #model_checks (
    check_category    NVARCHAR(50),       -- short category (star_schema, fact_purity, …)
    check_description NVARCHAR(200),      -- human‑readable explanation
    check_result      NVARCHAR(20),       -- OK or ISSUE
    details           NVARCHAR(100)       -- supporting info or counts
);

-- ============================================================================
-- 1. STAR SCHEMA – does the fact table have foreign keys to all 5 dimensions?
--    Expected: exactly 5 foreign keys.
-- ============================================================================
INSERT INTO #model_checks
SELECT 'star_schema',
       'factsales has foreign keys to all 5 dimensions (date, product, customer, store, promotion)',
       CASE WHEN COUNT(*) = 5 THEN 'OK' ELSE 'ISSUE' END,
       CAST(COUNT(*) AS NVARCHAR(100))
FROM sys.foreign_keys
WHERE parent_object_id = OBJECT_ID('dbo.factsales')
  AND referenced_object_id IN (
          OBJECT_ID('dbo.dimdate'),
          OBJECT_ID('dbo.dimproduct'),
          OBJECT_ID('dbo.dimcustomer'),
          OBJECT_ID('dbo.dimstore'),
          OBJECT_ID('dbo.dimpromotion')
      );

-- ============================================================================
-- 2. FACT TABLE PURITY – factsales should contain only the expected columns.
--    Any extra column is flagged as an ISSUE.
-- ============================================================================
INSERT INTO #model_checks
SELECT 'fact_purity',
       'factsales contains only allowed columns (no extra or unexpected columns)',
       CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'ISSUE' END,
       CAST(COUNT(*) AS NVARCHAR(100))
FROM sys.columns
WHERE object_id = OBJECT_ID('dbo.factsales')
  AND name NOT IN (
          'salesid', 'datekey', 'productid', 'customerid', 'storeid', 'promoid',
          'qty', 'unitprice', 'tax_rate', 'net', 'payment', 'channel',
          'grossvalue', 'discountamount', 'taxamount', 'shipcost', 'isreturn',
          'shipweight', 'discountapplied', 'returnreason', 'deliverydays', 'hour'
      );

-- ============================================================================
-- 3. DIMENSION PRIMARY KEYS – every dimension table must have a PK.
--    Expected: 5 distinct tables with a primary key constraint.
-- ============================================================================
INSERT INTO #model_checks
SELECT 'dimension_keys',
       'all five dimension tables (dimdate, dimproduct, dimcustomer, dimstore, dimpromotion) have a primary key',
       CASE WHEN COUNT(DISTINCT parent_object_id) = 5 THEN 'OK' ELSE 'ISSUE' END,
       CAST(COUNT(DISTINCT parent_object_id) AS NVARCHAR(100))
FROM sys.key_constraints
WHERE type = 'PK'
  AND parent_object_id IN (
          OBJECT_ID('dbo.dimdate'),
          OBJECT_ID('dbo.dimproduct'),
          OBJECT_ID('dbo.dimcustomer'),
          OBJECT_ID('dbo.dimstore'),
          OBJECT_ID('dbo.dimpromotion')
      );

-- ============================================================================
-- 4. PERFORMANCE – the fact table should have a clustered columnstore index.
--    This is critical for query speed and compression on 10M rows.
-- ============================================================================
INSERT INTO #model_checks
SELECT 'performance_cci',
       'factsales has a clustered columnstore index (recommended for large fact tables)',
       CASE WHEN COUNT(*) = 1 THEN 'OK' ELSE 'ISSUE' END,
       CAST(COUNT(*) AS NVARCHAR(100))
FROM sys.indexes
WHERE object_id = OBJECT_ID('dbo.factsales')
  AND type_desc = 'CLUSTERED COLUMNSTORE';

-- ============================================================================
-- 5. TRUSTED CONSTRAINTS – are all Foreign Keys trusted by the SQL Server Optimizer?
--    Expected: 0 untrusted foreign keys (all must be fully trusted/validated).
-- ============================================================================
INSERT INTO #model_checks
SELECT 'performance_fk_trust',
       'all foreign keys on factsales are fully TRUSTED by the query optimizer (allows query simplification)',
       CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'ISSUE' END,
       CAST(COUNT(*) AS NVARCHAR(100))
FROM sys.foreign_keys
WHERE parent_object_id = OBJECT_ID('dbo.factsales')
  AND is_not_trusted = 1;

-- ============================================================================
-- 6. CONFIGURATION – is the database recovery model set to SIMPLE?
--    Expected: SIMPLE recovery model to prevent transaction log size explosion.
-- ============================================================================
INSERT INTO #model_checks
SELECT 'db_config',
       'database recovery model is set to SIMPLE (prevents transaction log space exhaustion)',
       CASE WHEN recovery_model_desc = 'SIMPLE' THEN 'OK' ELSE 'ISSUE' END,
       recovery_model_desc
FROM sys.databases
WHERE name = 'retailanalytics';

-- ============================================================================
-- 7. REFERENTIAL INTEGRITY – no orphan rows in the fact table.
--    A single LEFT‑JOIN query checks all five foreign keys at once.
--    promoid = 0 and promoid = -1 are valid dimension keys.
--    Note: Since FKs are trusted, SQL Server evaluates this metadata check instantly.
-- ============================================================================
INSERT INTO #model_checks
SELECT 'referential_integrity',
       'no orphan rows in factsales (all foreign key values have matching dimension rows)',
       CASE WHEN orphan_count = 0 THEN 'OK' ELSE 'ISSUE' END,
       CAST(orphan_count AS NVARCHAR(100))
FROM (
    SELECT COUNT(*) AS orphan_count
    FROM dbo.factsales f
    LEFT JOIN dbo.dimdate      d  ON f.datekey    = d.datekey
    LEFT JOIN dbo.dimproduct   p  ON f.productid  = p.productid
    LEFT JOIN dbo.dimcustomer  c  ON f.customerid = c.customerid
    LEFT JOIN dbo.dimstore     s  ON f.storeid    = s.storeid
    LEFT JOIN dbo.dimpromotion pr ON f.promoid    = pr.promoid
    WHERE d.datekey     IS NULL
       OR p.productid   IS NULL
       OR c.customerid  IS NULL
       OR s.storeid     IS NULL
       OR pr.promoid    IS NULL
) AS orphan_check;

-- ============================================================================
-- 8. FINAL REPORT
--    Displays all checks sorted so that any ISSUE appears first.
-- ============================================================================
SELECT check_category,
       check_description,
       check_result,
       details
FROM #model_checks
ORDER BY CASE WHEN check_result = 'ISSUE' THEN 0 ELSE 1 END,
         check_category;

-- Clean up
DROP TABLE #model_checks;

PRINT '================================================================================';
PRINT 'MODEL VALIDATION COMPLETED.';
PRINT '================================================================================';
GO
-- ============================================================================
-- End of validate_star_schema_model.sql
-- ============================================================================