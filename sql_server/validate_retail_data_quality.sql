-- ============================================================================
-- validate_retail_data_quality.sql
-- ============================================================================
-- Author:           DataGen AI
-- Created:           2026-05-23
-- Last modified:     2026-05-24 02:00:00 UTC
-- Suggested name:    validate_retail_data_quality.sql
-- Description:
--   Runs a comprehensive battery of data‑quality checks against the
--   retailanalytics database.  Checks include NULL detection, primary‑key
--   uniqueness, range validation, referential integrity, business‑rule
--   compliance (return reasons, delivery days, discount flags, etc.) and
--   row‑count expectations.
--   All percentage columns (margin_pct, discount_pct) are treated as
--   decimal fractions (margin_pct: –0.10 … 0.30, discount_pct: 0.0 … 0.45).
-- ============================================================================

USE retailanalytics;
GO

SET NOCOUNT ON;

PRINT '================================================================================';
PRINT 'RUNNING DATA QUALITY CHECKS – retailanalytics';
PRINT '================================================================================';
PRINT '';

-- ---------------------------------------------------------------------------
-- Temporary table that collects every test result.
-- Each row is one check – the final report groups and summarises them.
-- ---------------------------------------------------------------------------
DROP TABLE IF EXISTS #dq_checks;
CREATE TABLE #dq_checks (
    id                  INT IDENTITY(1,1),
    table_name          NVARCHAR(50),       -- which table is being checked
    check_group         NVARCHAR(50),       -- category (Null, Range, Logical, FK …)
    check_name          NVARCHAR(100),      -- short unique name for the check
    check_description   NVARCHAR(200),      -- human‑readable description
    issue_count         BIGINT,             -- number of violating rows (0 = clean)
    expected_value      NVARCHAR(100),      -- what the count should be
    actual_value        NVARCHAR(100),      -- string representation of the count
    status              NVARCHAR(20)        -- PASS / FAIL / WARN
);

-- ============================================================================
-- 1. CHECKS FOR dimdate
--    - Primary key and date columns must not be NULL.
--    - Dates must fall within the expected range.
--    - datekey must be unique.
--    - isholiday, isweekend and year/month must be logically consistent.
--    - Row count must cover at least one year.
-- ============================================================================
INSERT INTO #dq_checks
SELECT 'dimdate', 'Null', 'datekey_null',
       'datekey is NULL',
       COUNT(*), '0', CAST(COUNT(*) AS NVARCHAR),
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM dbo.dimdate WHERE datekey IS NULL
UNION ALL
SELECT 'dimdate', 'Null', 'fulldate_null',
       'fulldate is NULL',
       COUNT(*), '0', CAST(COUNT(*) AS NVARCHAR),
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM dbo.dimdate WHERE fulldate IS NULL
UNION ALL
SELECT 'dimdate', 'Range', 'fulldate_out_of_range',
       'fulldate outside expected range (2023-01-01 to today)',
       COUNT(*), '0', CAST(COUNT(*) AS NVARCHAR),
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM dbo.dimdate WHERE fulldate < '2023-01-01' OR fulldate > CAST(GETDATE() AS DATE)
UNION ALL
SELECT 'dimdate', 'Uniqueness', 'duplicate_datekey',
       'duplicate datekey',
       (SELECT COUNT(*) - COUNT(DISTINCT datekey) FROM dbo.dimdate),
       '0', CAST((SELECT COUNT(*) - COUNT(DISTINCT datekey) FROM dbo.dimdate) AS NVARCHAR),
       CASE WHEN (SELECT COUNT(*) - COUNT(DISTINCT datekey) FROM dbo.dimdate) = 0 THEN 'PASS' ELSE 'FAIL' END
UNION ALL
SELECT 'dimdate', 'Logical', 'isholiday_invalid',
       'isholiday not in (0,1)',
       COUNT(*), '0', CAST(COUNT(*) AS NVARCHAR),
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM dbo.dimdate WHERE isholiday NOT IN (0,1)
UNION ALL
SELECT 'dimdate', 'Logical', 'year_month_mismatch',
       'year/month not consistent with fulldate',
       COUNT(*), '0', CAST(COUNT(*) AS NVARCHAR),
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM dbo.dimdate WHERE YEAR(fulldate) != year OR MONTH(fulldate) != monthnumber
UNION ALL
SELECT 'dimdate', 'Completeness', 'missing_weekend_flag',
       'isweekend incorrect (DATEPART weekday logic)',
       COUNT(*), '0', CAST(COUNT(*) AS NVARCHAR),
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM dbo.dimdate
WHERE (DATEPART(weekday, fulldate) IN (1,7) AND isweekend = 0)
   OR (DATEPART(weekday, fulldate) NOT IN (1,7) AND isweekend = 1)
UNION ALL
SELECT 'dimdate', 'Count', 'date_row_count',
       'Row count of dimdate (should be >= 365)',
       COUNT(*), '>=365', CAST(COUNT(*) AS NVARCHAR),
       CASE WHEN COUNT(*) >= 365 THEN 'PASS' ELSE 'WARN' END
FROM dbo.dimdate
UNION ALL
SELECT 'dimdate', 'Range', 'date_coverage_end',
       'Maximum date in dimdate (should be today)',
       0, CAST(GETDATE() AS NVARCHAR), CAST(MAX(fulldate) AS NVARCHAR),
       CASE WHEN MAX(fulldate) = CAST(GETDATE() AS DATE) THEN 'PASS' ELSE 'FAIL' END
FROM dbo.dimdate;

-- ============================================================================
-- 2. CHECKS FOR dimcustomer
--    - Primary key not NULL, e‑mail unique, age range 18‑75.
--    - Gender restricted to Male/Female only.
--    - Tier values must be from the predefined set.
--    - Registration date cannot be in the future.
--    - totspend must be non‑negative.
--    - Basic consistency between tier and income.
-- ============================================================================
INSERT INTO #dq_checks
SELECT 'dimcustomer', 'Null', 'customerid_null',
       'customerid is NULL',
       COUNT(*), '0', CAST(COUNT(*) AS NVARCHAR),
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM dbo.dimcustomer WHERE customerid IS NULL
UNION ALL
SELECT 'dimcustomer', 'Uniqueness', 'duplicate_email',
       'duplicate email address',
       (SELECT COUNT(*) - COUNT(DISTINCT email) FROM dbo.dimcustomer),
       '0', CAST((SELECT COUNT(*) - COUNT(DISTINCT email) FROM dbo.dimcustomer) AS NVARCHAR),
       CASE WHEN (SELECT COUNT(*) - COUNT(DISTINCT email) FROM dbo.dimcustomer) = 0 THEN 'PASS' ELSE 'FAIL' END
UNION ALL
SELECT 'dimcustomer', 'Range', 'age_out_of_bounds',
       'age < 18 or > 75',
       COUNT(*), '0', CAST(COUNT(*) AS NVARCHAR),
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM dbo.dimcustomer WHERE age < 18 OR age > 75
UNION ALL
SELECT 'dimcustomer', 'Value', 'invalid_gender',
       'gender not Male/Female',
       COUNT(*), '0', CAST(COUNT(*) AS NVARCHAR),
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM dbo.dimcustomer WHERE gender NOT IN ('Male','Female')
UNION ALL
SELECT 'dimcustomer', 'Value', 'invalid_tier',
       'tier not in (Bronze, Silver, Gold, Platinum)',
       COUNT(*), '0', CAST(COUNT(*) AS NVARCHAR),
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM dbo.dimcustomer WHERE tier NOT IN ('Bronze','Silver','Gold','Platinum')
UNION ALL
SELECT 'dimcustomer', 'Logical', 'regdate_future',
       'regdate later than today',
       COUNT(*), '0', CAST(COUNT(*) AS NVARCHAR),
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM dbo.dimcustomer WHERE regdate > CAST(GETDATE() AS DATE)
UNION ALL
SELECT 'dimcustomer', 'Logical', 'negative_totalspend',
       'totalspend < 0',
       COUNT(*), '0', CAST(COUNT(*) AS NVARCHAR),
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM dbo.dimcustomer WHERE totalspend < 0
UNION ALL
SELECT 'dimcustomer', 'Consistency', 'tier_income_mismatch',
       'Platinum tier but annualincome < 70000',
       COUNT(*), '0', CAST(COUNT(*) AS NVARCHAR),
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM dbo.dimcustomer WHERE tier = 'Platinum' AND annualincome < 70000
UNION ALL
SELECT 'dimcustomer', 'Consistency', 'bronze_high_income',
       'Bronze tier but annualincome > 100000',
       COUNT(*), '0', CAST(COUNT(*) AS NVARCHAR),
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM dbo.dimcustomer WHERE tier = 'Bronze' AND annualincome > 100000;

-- ============================================================================
-- 3. CHECKS FOR dimproduct
--    - Primary key unique, names unique.
--    - Prices positive, costs non‑negative.
--    - cost > price is only allowed when margin_pct ≤ 0 (negative‑margin products).
--    - margin_pct must lie in [-0.10, 0.30] (fraction).
--    - tax_rate must be 0.10 or 0.21 (check: inside [0,1]).
--    - Category must be one of the five predefined values.
--    - Warranty flag and months must be consistent.
--    - Discontinued products must be inactive.
-- ============================================================================
INSERT INTO #dq_checks
SELECT 'dimproduct', 'Null', 'productid_null',
       'productid is NULL',
       COUNT(*), '0', CAST(COUNT(*) AS NVARCHAR),
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM dbo.dimproduct WHERE productid IS NULL
UNION ALL
SELECT 'dimproduct', 'Uniqueness', 'duplicate_name',
       'duplicate product name',
       (SELECT COUNT(*) - COUNT(DISTINCT name) FROM dbo.dimproduct),
       '0', CAST((SELECT COUNT(*) - COUNT(DISTINCT name) FROM dbo.dimproduct) AS NVARCHAR),
       CASE WHEN (SELECT COUNT(*) - COUNT(DISTINCT name) FROM dbo.dimproduct) = 0 THEN 'PASS' ELSE 'FAIL' END
UNION ALL
SELECT 'dimproduct', 'Range', 'unitprice_le_0',
       'unitprice <= 0',
       COUNT(*), '0', CAST(COUNT(*) AS NVARCHAR),
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM dbo.dimproduct WHERE unitprice <= 0
UNION ALL
SELECT 'dimproduct', 'Range', 'unitcost_negative',
       'unitcost < 0',
       COUNT(*), '0', CAST(COUNT(*) AS NVARCHAR),
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM dbo.dimproduct WHERE unitcost < 0
UNION ALL
-- cost > price is only an error when margin is positive (logically impossible)
SELECT 'dimproduct', 'Logical', 'unitcost_gt_unitprice_pos_margin',
       'unitcost > unitprice while margin > 0 (should be impossible)',
       COUNT(*), '0', CAST(COUNT(*) AS NVARCHAR),
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM dbo.dimproduct WHERE unitcost > unitprice AND margin_pct > 0
UNION ALL
-- margin_pct must be within the defined fraction range
SELECT 'dimproduct', 'Range', 'margin_pct_outside_range',
       'margin_pct not in [-0.10, 0.30] (fraction)',
       COUNT(*), '0', CAST(COUNT(*) AS NVARCHAR),
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM dbo.dimproduct WHERE margin_pct < -0.10 OR margin_pct > 0.30
UNION ALL
SELECT 'dimproduct', 'Range', 'tax_rate_outside_0_1',
       'tax_rate not in [0,1]',
       COUNT(*), '0', CAST(COUNT(*) AS NVARCHAR),
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM dbo.dimproduct WHERE tax_rate < 0 OR tax_rate > 1
UNION ALL
SELECT 'dimproduct', 'Value', 'invalid_category',
       'category not in (Electronics, Home, Sports, Kids, Garden)',
       COUNT(*), '0', CAST(COUNT(*) AS NVARCHAR),
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM dbo.dimproduct
WHERE category NOT IN ('Electronics','Home','Sports','Kids','Garden')
UNION ALL
SELECT 'dimproduct', 'Logical', 'warranty_months_positive',
       'haswarranty=0 but warrantymonths>0',
       COUNT(*), '0', CAST(COUNT(*) AS NVARCHAR),
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM dbo.dimproduct WHERE haswarranty = 0 AND warrantymonths > 0
UNION ALL
SELECT 'dimproduct', 'Logical', 'discontinued_but_active',
       'isdiscontinued=1 but isactive=1',
       COUNT(*), '0', CAST(COUNT(*) AS NVARCHAR),
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM dbo.dimproduct WHERE isdiscontinued = 1 AND isactive = 1;

-- ============================================================================
-- 4. CHECKS FOR dimstore
--    - Primary key unique, names unique.
--    - Renovation year cannot precede opening year.
--    - Staff and rating values must be within reasonable bounds.
-- ============================================================================
INSERT INTO #dq_checks
SELECT 'dimstore', 'Null', 'storeid_null',
       'storeid is NULL',
       COUNT(*), '0', CAST(COUNT(*) AS NVARCHAR),
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM dbo.dimstore WHERE storeid IS NULL
UNION ALL
SELECT 'dimstore', 'Uniqueness', 'duplicate_storename',
       'duplicate store name',
       (SELECT COUNT(*) - COUNT(DISTINCT storename) FROM dbo.dimstore),
       '0', CAST((SELECT COUNT(*) - COUNT(DISTINCT storename) FROM dbo.dimstore) AS NVARCHAR),
       CASE WHEN (SELECT COUNT(*) - COUNT(DISTINCT storename) FROM dbo.dimstore) = 0 THEN 'PASS' ELSE 'FAIL' END
UNION ALL
SELECT 'dimstore', 'Logical', 'renovation_before_opening',
       'renovationyear < openingyear (non‑zero)',
       COUNT(*), '0', CAST(COUNT(*) AS NVARCHAR),
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM dbo.dimstore WHERE renovationyear != 0 AND renovationyear < openingyear
UNION ALL
SELECT 'dimstore', 'Range', 'staff_out_of_bounds',
       'staff <= 0 or > 500',
       COUNT(*), '0', CAST(COUNT(*) AS NVARCHAR),
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM dbo.dimstore WHERE staff <= 0 OR staff > 500
UNION ALL
SELECT 'dimstore', 'Range', 'rating_out_of_bounds',
       'storerating not in [2.0, 5.0]',
       COUNT(*), '0', CAST(COUNT(*) AS NVARCHAR),
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM dbo.dimstore WHERE storerating < 2.0 OR storerating > 5.0;

-- ============================================================================
-- 5. CHECKS FOR dimpromotion
--    - Primary key and name must be unique.
--    - discount_pct must be 0.0‑0.45; discount_fixed must be non‑negative.
--    - startdate cannot be after enddate.
--    - Already‑ended promotions should be marked inactive.
--    - redemption_rate must be between 0 and 1.
-- ============================================================================
INSERT INTO #dq_checks
SELECT 'dimpromotion', 'Null', 'promoid_null',
       'promoid is NULL',
       COUNT(*), '0', CAST(COUNT(*) AS NVARCHAR),
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM dbo.dimpromotion WHERE promoid IS NULL
UNION ALL
SELECT 'dimpromotion', 'Range', 'discount_pct_outside_0_0_45',
       'discount_pct not in [0.0, 0.45] (fraction)',
       COUNT(*), '0', CAST(COUNT(*) AS NVARCHAR),
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM dbo.dimpromotion WHERE discount_pct < 0.0 OR discount_pct > 0.45
UNION ALL
SELECT 'dimpromotion', 'Range', 'discount_fixed_negative',
       'discount_fixed < 0',
       COUNT(*), '0', CAST(COUNT(*) AS NVARCHAR),
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM dbo.dimpromotion WHERE discount_fixed < 0
UNION ALL
SELECT 'dimpromotion', 'Logical', 'startdate_after_enddate',
       'startdate > enddate',
       COUNT(*), '0', CAST(COUNT(*) AS NVARCHAR),
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM dbo.dimpromotion WHERE startdate > enddate
UNION ALL
SELECT 'dimpromotion', 'Logical', 'ended_but_active',
       'enddate < today but still marked isactive=1',
       COUNT(*), '0', CAST(COUNT(*) AS NVARCHAR),
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM dbo.dimpromotion WHERE enddate < CAST(GETDATE() AS DATE) AND isactive = 1
UNION ALL
SELECT 'dimpromotion', 'Range', 'redemption_rate_outside_0_1',
       'redemption_rate not in [0, 1]',
       COUNT(*), '0', CAST(COUNT(*) AS NVARCHAR),
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM dbo.dimpromotion WHERE redemption_rate < 0 OR redemption_rate > 1
UNION ALL
SELECT 'dimpromotion', 'Uniqueness', 'duplicate_promoname',
       'duplicate promotion name',
       (SELECT COUNT(*) - COUNT(DISTINCT promoname) FROM dbo.dimpromotion),
       '0', CAST((SELECT COUNT(*) - COUNT(DISTINCT promoname) FROM dbo.dimpromotion) AS NVARCHAR),
       CASE WHEN (SELECT COUNT(*) - COUNT(DISTINCT promoname) FROM dbo.dimpromotion) = 0 THEN 'PASS' ELSE 'FAIL' END;

-- ============================================================================
-- 6. CHECKS FOR factsales
--    - Financial integrity: net ≈ grossvalue - discountamount + taxamount
--    - Unit price and tax rate within expected ranges
--    - Return logic: returns must have negative net/gross;
--      non‑returns must have 'No return' as reason.
--    - Quantity must be > 0 and ≤ 50 (scaled values may exceed original range)
--    - Hour must be 0‑23, never NULL
--    - deliverydays = 0 exactly for In‑Store channel
--    - shipping cost zero for In‑Store; positive for online non‑returns
--    - discountapplied flag must match discountamount
--    - All foreign keys must reference existing dimension rows
--    - salesid must be unique
--    - Row count should be ≈10 000 000 (±10 %)
-- ============================================================================
INSERT INTO #dq_checks
-- Financial: net calculation check
SELECT 'factsales', 'Financial', 'net_calculation_error',
       'net != grossvalue - discountamount + taxamount (tolerance 0.01)',
       COUNT(*), '0', CAST(COUNT(*) AS NVARCHAR),
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM dbo.factsales
WHERE ABS(net - (grossvalue - discountamount + taxamount)) > 0.01
UNION ALL
-- Range checks on unit price and tax rate
SELECT 'factsales', 'Range', 'unitprice_out_of_bounds',
       'unitprice > 3000 or < 0',
       COUNT(*), '0', CAST(COUNT(*) AS NVARCHAR),
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM dbo.factsales WHERE unitprice > 3000 OR unitprice < 0
UNION ALL
SELECT 'factsales', 'Range', 'tax_rate_outside_0_1',
       'tax_rate not in [0, 1]',
       COUNT(*), '0', CAST(COUNT(*) AS NVARCHAR),
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM dbo.factsales WHERE tax_rate < 0 OR tax_rate > 1
UNION ALL
-- Return transaction logic
SELECT 'factsales', 'Logical', 'return_positive_net',
       'isreturn=1 but net > 0 (returns must have non‑positive net)',
       COUNT(*), '0', CAST(COUNT(*) AS NVARCHAR),
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM dbo.factsales WHERE isreturn = 1 AND net > 0
UNION ALL
SELECT 'factsales', 'Logical', 'nonreturn_negative_net',
       'isreturn=0 and net < 0',
       COUNT(*), '0', CAST(COUNT(*) AS NVARCHAR),
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM dbo.factsales WHERE isreturn = 0 AND net < 0
UNION ALL
SELECT 'factsales', 'Logical', 'return_positive_gross',
       'isreturn=1 but grossvalue > 0',
       COUNT(*), '0', CAST(COUNT(*) AS NVARCHAR),
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM dbo.factsales WHERE isreturn = 1 AND grossvalue > 0
UNION ALL
-- Return reason consistency
SELECT 'factsales', 'Logical', 'nonreturn_has_no_return_reason',
       'isreturn=0 and returnreason != ''No return''',
       COUNT(*), '0', CAST(COUNT(*) AS NVARCHAR),
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM dbo.factsales WHERE isreturn = 0 AND returnreason != 'No return'
UNION ALL
SELECT 'factsales', 'Logical', 'return_missing_reason',
       'isreturn=1 and returnreason = ''No return'' (missing reason)',
       COUNT(*), '0', CAST(COUNT(*) AS NVARCHAR),
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM dbo.factsales WHERE isreturn = 1 AND returnreason = 'No return'
UNION ALL
-- Quantity range (scaled quantities may exceed 10, allow up to 50)
SELECT 'factsales', 'Range', 'qty_out_of_bounds',
       'qty <= 0 or > 50',
       COUNT(*), '0', CAST(COUNT(*) AS NVARCHAR),
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM dbo.factsales WHERE qty <= 0 OR qty > 50
UNION ALL
-- Hour validation
SELECT 'factsales', 'Null', 'hour_null',
       'hour is NULL',
       COUNT(*), '0', CAST(COUNT(*) AS NVARCHAR),
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM dbo.factsales WHERE hour IS NULL
UNION ALL
SELECT 'factsales', 'Range', 'hour_out_of_range',
       'hour not in 0‑23',
       COUNT(*), '0', CAST(COUNT(*) AS NVARCHAR),
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM dbo.factsales WHERE hour < 0 OR hour > 23
UNION ALL
-- Delivery days logic
SELECT 'factsales', 'Logical', 'deliverydays_zero_for_instore',
       'channel=In‑Store but deliverydays > 0',
       COUNT(*), '0', CAST(COUNT(*) AS NVARCHAR),
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM dbo.factsales WHERE channel = 'In-Store' AND deliverydays > 0
UNION ALL
SELECT 'factsales', 'Logical', 'deliverydays_positive_for_online',
       'channel in (Online, Mobile App) but deliverydays = 0',
       COUNT(*), '0', CAST(COUNT(*) AS NVARCHAR),
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM dbo.factsales WHERE channel IN ('Online', 'Mobile App') AND deliverydays = 0
UNION ALL
-- Discount flag consistency
SELECT 'factsales', 'Logical', 'discount_mismatch',
       'discountapplied=1 but discountamount=0',
       COUNT(*), '0', CAST(COUNT(*) AS NVARCHAR),
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM dbo.factsales WHERE discountapplied = 1 AND discountamount = 0
UNION ALL
SELECT 'factsales', 'Logical', 'no_discount_but_amount',
       'discountapplied=0 but discountamount != 0',
       COUNT(*), '0', CAST(COUNT(*) AS NVARCHAR),
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM dbo.factsales WHERE discountapplied = 0 AND discountamount != 0
UNION ALL
-- Shipping cost logic
SELECT 'factsales', 'Logical', 'shipcost_nonzero_for_instore',
       'channel=In‑Store and shipcost > 0',
       COUNT(*), '0', CAST(COUNT(*) AS NVARCHAR),
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM dbo.factsales WHERE channel = 'In-Store' AND shipcost > 0
UNION ALL
SELECT 'factsales', 'Logical', 'shipcost_zero_for_online',
       'channel in (Online, Mobile App) and shipcost = 0 and isreturn=0',
       COUNT(*), '0', CAST(COUNT(*) AS NVARCHAR),
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM dbo.factsales
WHERE channel IN ('Online', 'Mobile App') AND shipcost = 0 AND isreturn = 0
UNION ALL
-- Foreign key validity
SELECT 'factsales', 'FK', 'invalid_datekey',
       'datekey not in dimdate',
       COUNT(*), '0', CAST(COUNT(*) AS NVARCHAR),
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM dbo.factsales f LEFT JOIN dbo.dimdate d ON f.datekey = d.datekey
WHERE d.datekey IS NULL
UNION ALL
SELECT 'factsales', 'FK', 'invalid_productid',
       'productid not in dimproduct',
       COUNT(*), '0', CAST(COUNT(*) AS NVARCHAR),
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM dbo.factsales f LEFT JOIN dbo.dimproduct p ON f.productid = p.productid
WHERE p.productid IS NULL
UNION ALL
SELECT 'factsales', 'FK', 'invalid_customerid',
       'customerid not in dimcustomer',
       COUNT(*), '0', CAST(COUNT(*) AS NVARCHAR),
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM dbo.factsales f LEFT JOIN dbo.dimcustomer c ON f.customerid = c.customerid
WHERE c.customerid IS NULL
UNION ALL
SELECT 'factsales', 'FK', 'invalid_storeid',
       'storeid not in dimstore',
       COUNT(*), '0', CAST(COUNT(*) AS NVARCHAR),
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM dbo.factsales f LEFT JOIN dbo.dimstore s ON f.storeid = s.storeid
WHERE s.storeid IS NULL
UNION ALL
SELECT 'factsales', 'FK', 'invalid_promoid',
       'promoid not in dimpromotion (including 0)',
       COUNT(*), '0', CAST(COUNT(*) AS NVARCHAR),
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM dbo.factsales f LEFT JOIN dbo.dimpromotion pr ON f.promoid = pr.promoid
WHERE pr.promoid IS NULL
UNION ALL
-- Primary key uniqueness
SELECT 'factsales', 'PK', 'duplicate_salesid',
       'duplicate salesid',
       (SELECT COUNT(*) - COUNT(DISTINCT salesid) FROM dbo.factsales),
       '0', CAST((SELECT COUNT(*) - COUNT(DISTINCT salesid) FROM dbo.factsales) AS NVARCHAR),
       CASE WHEN (SELECT COUNT(*) - COUNT(DISTINCT salesid) FROM dbo.factsales) = 0 THEN 'PASS' ELSE 'FAIL' END
UNION ALL
-- Row count expectation
SELECT 'factsales', 'Count', 'fact_row_count',
       'Row count of factsales (should be ~10 000 000)',
       COUNT(*), '10,000,000 ±10%', CAST(COUNT(*) AS NVARCHAR),
       CASE WHEN COUNT(*) BETWEEN 9000000 AND 11000000 THEN 'PASS' ELSE 'WARN' END
FROM dbo.factsales;

-- ============================================================================
-- 7. REPORT GENERATION
--    First, list every FAIL and WARN result.
--    Then show a per‑table summary.
--    Finally, print an overall quality verdict.
-- ============================================================================
PRINT '================================================================================';
PRINT 'DATA QUALITY CHECK RESULTS (only failures and warnings)';
PRINT '================================================================================';

SELECT 
    table_name,
    check_group,
    check_name,
    check_description,
    issue_count,
    expected_value,
    actual_value,
    status
FROM #dq_checks
WHERE status IN ('FAIL', 'WARN')
ORDER BY table_name, check_group, check_name;

PRINT '================================================================================';
PRINT 'SUMMARY BY TABLE';
PRINT '================================================================================';

SELECT 
    table_name,
    COUNT(*) AS total_checks,
    SUM(CASE WHEN status = 'PASS' THEN 1 ELSE 0 END) AS passed,
    SUM(CASE WHEN status = 'WARN' THEN 1 ELSE 0 END) AS warnings,
    SUM(CASE WHEN status = 'FAIL' THEN 1 ELSE 0 END) AS failures
FROM #dq_checks
GROUP BY table_name
ORDER BY table_name;

PRINT '================================================================================';
IF EXISTS (SELECT 1 FROM #dq_checks WHERE status = 'FAIL')
    PRINT '❌ DATA QUALITY ISSUES DETECTED – please review failed checks above.';
ELSE IF EXISTS (SELECT 1 FROM #dq_checks WHERE status = 'WARN')
    PRINT '⚠️  DATA QUALITY WARNINGS – data loaded but some thresholds exceeded.';
ELSE
    PRINT '✅ ALL CHECKS PASSED – data is clean and ready for analytics.';

-- Clean up
DROP TABLE #dq_checks;
GO
-- ============================================================================
-- End of validate_retail_data_quality.sql
-- ============================================================================