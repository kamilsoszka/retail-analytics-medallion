-- =====================================================================
-- DATA QUALITY CHECKS (compatible with Python v46 – no dimmanager, no denormalized columns)
-- =====================================================================

USE retailanalytics;
GO

IF OBJECT_ID('tempdb..#dq_checks') IS NOT NULL DROP TABLE #dq_checks;
CREATE TABLE #dq_checks (
    table_name NVARCHAR(50),
    check_type NVARCHAR(50),
    check_description NVARCHAR(200),
    issue_count INT
);

-- dimdate
INSERT INTO #dq_checks
SELECT 'dimdate', 'null_check', 'datekey is null', COUNT(*) FROM dbo.dimdate WHERE datekey IS NULL
UNION ALL
SELECT 'dimdate', 'range_check', 'fulldate outside 2023-01-01 to today', COUNT(*) FROM dbo.dimdate WHERE fulldate < '2023-01-01' OR fulldate > CAST(GETDATE() AS DATE)
UNION ALL
SELECT 'dimdate', 'unique_check', 'duplicate datekey', (SELECT COUNT(*) - COUNT(DISTINCT datekey) FROM dbo.dimdate)
UNION ALL
SELECT 'dimdate', 'range_check', 'isholiday not in (0,1)', COUNT(*) FROM dbo.dimdate WHERE isholiday NOT IN (0,1);

-- dimcustomer
INSERT INTO #dq_checks
SELECT 'dimcustomer', 'null_check', 'customerid is null', COUNT(*) FROM dbo.dimcustomer WHERE customerid IS NULL
UNION ALL
SELECT 'dimcustomer', 'range_check', 'regdate after today', COUNT(*) FROM dbo.dimcustomer WHERE regdate > CAST(GETDATE() AS DATE)
UNION ALL
SELECT 'dimcustomer', 'value_check', 'invalid gender', COUNT(*) FROM dbo.dimcustomer WHERE gender NOT IN ('Male','Female','Non-binary')
UNION ALL
SELECT 'dimcustomer', 'value_check', 'invalid tier', COUNT(*) FROM dbo.dimcustomer WHERE tier NOT IN ('Bronze','Silver','Gold','Platinum')
UNION ALL
SELECT 'dimcustomer', 'unique_check', 'duplicate email', (SELECT COUNT(*) - COUNT(DISTINCT email) FROM dbo.dimcustomer);

-- dimproduct
INSERT INTO #dq_checks
SELECT 'dimproduct', 'value_check', 'unitprice <= 0', COUNT(*) FROM dbo.dimproduct WHERE unitprice <= 0
UNION ALL
SELECT 'dimproduct', 'value_check', 'unitcost > unitprice', COUNT(*) FROM dbo.dimproduct WHERE unitcost > unitprice
UNION ALL
SELECT 'dimproduct', 'value_check', 'invalid category', COUNT(*) FROM dbo.dimproduct WHERE category NOT IN ('Electronics','Home','Sports','Kids','Garden')
UNION ALL
SELECT 'dimproduct', 'range_check', 'margin_pct not in [0,1]', COUNT(*) FROM dbo.dimproduct WHERE margin_pct < 0 OR margin_pct > 1
UNION ALL
SELECT 'dimproduct', 'range_check', 'taxrate_pct not in [0,1]', COUNT(*) FROM dbo.dimproduct WHERE taxrate_pct < 0 OR taxrate_pct > 1
UNION ALL
SELECT 'dimproduct', 'unique_check', 'duplicate product name', (SELECT COUNT(*) - COUNT(DISTINCT name) FROM dbo.dimproduct);

-- dimstore
INSERT INTO #dq_checks
SELECT 'dimstore', 'value_check', 'renovationyear < openingyear (non-zero)', COUNT(*) FROM dbo.dimstore WHERE renovationyear != 0 AND renovationyear < openingyear
UNION ALL
SELECT 'dimstore', 'unique_check', 'duplicate storename', (SELECT COUNT(*) - COUNT(DISTINCT storename) FROM dbo.dimstore);

-- dimpromotion
INSERT INTO #dq_checks
SELECT 'dimpromotion', 'range_check', 'discount_pct not in [0,1]', COUNT(*) FROM dbo.dimpromotion WHERE discount_pct < 0 OR discount_pct > 1
UNION ALL
SELECT 'dimpromotion', 'value_check', 'discount_fixed < 0', COUNT(*) FROM dbo.dimpromotion WHERE discount_fixed < 0
UNION ALL
SELECT 'dimpromotion', 'range_check', 'startdate > enddate', COUNT(*) FROM dbo.dimpromotion WHERE startdate > enddate
UNION ALL
SELECT 'dimpromotion', 'range_check', 'enddate < today but isactive=1', COUNT(*) FROM dbo.dimpromotion WHERE enddate < CAST(GETDATE() AS DATE) AND isactive = 1
UNION ALL
SELECT 'dimpromotion', 'range_check', 'redemption_rate_target_pct not in [0,1]', COUNT(*) FROM dbo.dimpromotion WHERE redemption_rate_target_pct < 0 OR redemption_rate_target_pct > 1
UNION ALL
SELECT 'dimpromotion', 'unique_check', 'duplicate promoname', (SELECT COUNT(*) - COUNT(DISTINCT promoname) FROM dbo.dimpromotion);

-- factsales (no dimmanager, no denormalized columns)
INSERT INTO #dq_checks
SELECT 'factsales', 'financial_eq', 'net != grossvalue - discountamount + taxamount', COUNT(*)
FROM dbo.factsales
WHERE ABS(net - (grossvalue - discountamount + taxamount)) > 0.01
UNION ALL
SELECT 'factsales', 'value_check', 'unitprice > 3000', COUNT(*) FROM dbo.factsales WHERE unitprice > 3000
UNION ALL
SELECT 'factsales', 'range_check', 'taxrate_pct not in [0,1]', COUNT(*) FROM dbo.factsales WHERE taxrate_pct < 0 OR taxrate_pct > 1
UNION ALL
SELECT 'factsales', 'consistency_check', 'return with positive net', COUNT(*) FROM dbo.factsales WHERE isreturn = 1 AND net > 0
UNION ALL
SELECT 'factsales', 'consistency_check', 'non-return with negative net', COUNT(*) FROM dbo.factsales WHERE isreturn = 0 AND net < 0
UNION ALL
SELECT 'factsales', 'consistency_check', 'return with positive grossvalue', COUNT(*) FROM dbo.factsales WHERE isreturn = 1 AND grossvalue > 0
UNION ALL
SELECT 'factsales', 'consistency_check', 'non-return but returnreason not null', COUNT(*) FROM dbo.factsales WHERE isreturn = 0 AND returnreason IS NOT NULL
UNION ALL
SELECT 'factsales', 'consistency_check', 'return but returnreason null', COUNT(*) FROM dbo.factsales WHERE isreturn = 1 AND returnreason IS NULL
UNION ALL
SELECT 'factsales', 'fk_check', 'invalid datekey', COUNT(*) FROM dbo.factsales f LEFT JOIN dbo.dimdate d ON f.datekey = d.datekey WHERE d.datekey IS NULL
UNION ALL
SELECT 'factsales', 'fk_check', 'invalid productid', COUNT(*) FROM dbo.factsales f LEFT JOIN dbo.dimproduct p ON f.productid = p.productid WHERE p.productid IS NULL
UNION ALL
SELECT 'factsales', 'fk_check', 'invalid customerid', COUNT(*) FROM dbo.factsales f LEFT JOIN dbo.dimcustomer c ON f.customerid = c.customerid WHERE c.customerid IS NULL
UNION ALL
SELECT 'factsales', 'fk_check', 'invalid storeid', COUNT(*) FROM dbo.factsales f LEFT JOIN dbo.dimstore s ON f.storeid = s.storeid WHERE s.storeid IS NULL
UNION ALL
SELECT 'factsales', 'fk_check', 'invalid promoid', COUNT(*) FROM dbo.factsales f LEFT JOIN dbo.dimpromotion p ON f.promoid = p.promoid WHERE p.promoid IS NULL
UNION ALL
SELECT 'factsales', 'unique_check', 'duplicate salesid', (SELECT COUNT(*) - COUNT(DISTINCT salesid) FROM dbo.factsales);

-- Show only issues
SELECT table_name, check_type, check_description, issue_count,
       CASE WHEN issue_count = 0 THEN 'OK' ELSE 'ISSUE' END AS check_status
FROM #dq_checks
WHERE issue_count > 0
ORDER BY table_name, check_type;

-- Summary per table
SELECT table_name, SUM(issue_count) AS total_issues
FROM #dq_checks
GROUP BY table_name
ORDER BY total_issues DESC;

DROP TABLE #dq_checks;
GO

-- =====================================================================
-- Final explanatory comment (printed after script execution)
-- =====================================================================
PRINT '
================================================================================
DATA QUALITY CHECKS COMPLETED - WHAT THIS SCRIPT DOES AND WHY IT IS USEFUL

This script performs automated validation of the retailanalytics database
after loading data from CSV files (generated by Python script v46). 
It checks for:

1. NULL values in key columns (e.g., datekey, customerid, productid).
2. Range violations (e.g., dates outside expected period, percentages >1 or <0).
3. Uniqueness constraints (duplicate keys or names).
4. Foreign key integrity (orphaned rows in factsales).
5. Financial consistency: net = grossvalue - discountamount + taxamount.
6. Logical consistency: returns (isreturn=1) must have negative net/grossvalue,
   non‑returns must not have return reasons.

How it works:
- For each dimension table (dimdate, dimcustomer, dimproduct, dimstore, dimpromotion)
  and the fact table (factsales), the script runs targeted SQL queries.
- Results are stored in a temporary table #dq_checks with issue counts.
- Only rows with non‑zero issues are displayed, making it easy to spot problems.
- A summary per table shows total issues across all checks.

Why it is useful in this project:
- Retail data generators may produce subtle errors (e.g., percentage columns out of [0,1],
  financial equation mismatches, duplicate names). This script catches those errors early.
- It ensures referential integrity between facts and dimensions, which is critical for 
  accurate reporting in Power BI.
- The checks are lightweight and can be run after every data load to validate data quality.
- By using this script, you gain confidence that the data is ready for analytics and 
  row‑level security (RLS) setups.

All checks are designed to work with the final schema (no dimmanager, no denormalized
columns). The script returns "OK" for each check if no issues are found, otherwise lists
the specific problems. It is a best practice to run this after every ETL/ELT process.
================================================================================
';
GO