-- ============================================================
-- SQL SERVER (T-SQL) – SILVER/GOLD LAYER VALIDATION
-- Compatible with final schema (promoid = 0 for no promotion)
-- Last updated: 2026-05-21
-- ============================================================

-- 1. Row counts
SELECT 'dimdate' AS table_name, COUNT(*) AS row_count FROM dbo.dimdate
UNION ALL SELECT 'dimcustomer', COUNT(*) FROM dbo.dimcustomer
UNION ALL SELECT 'dimproduct', COUNT(*) FROM dbo.dimproduct
UNION ALL SELECT 'dimstore', COUNT(*) FROM dbo.dimstore
UNION ALL SELECT 'dimpromotion', COUNT(*) FROM dbo.dimpromotion
UNION ALL SELECT 'factsales', COUNT(*) FROM dbo.factsales
ORDER BY table_name;

-- 2. PK uniqueness (duplicate counts)
SELECT 'dimdate' AS table_name, COUNT(*) - COUNT(DISTINCT datekey) AS duplicates FROM dbo.dimdate
UNION ALL SELECT 'dimcustomer', COUNT(*) - COUNT(DISTINCT customerid) FROM dbo.dimcustomer
UNION ALL SELECT 'dimproduct', COUNT(*) - COUNT(DISTINCT productid) FROM dbo.dimproduct
UNION ALL SELECT 'dimstore', COUNT(*) - COUNT(DISTINCT storeid) FROM dbo.dimstore
UNION ALL SELECT 'dimpromotion', COUNT(*) - COUNT(DISTINCT promoid) FROM dbo.dimpromotion
UNION ALL SELECT 'factsales', COUNT(*) - COUNT(DISTINCT salesid) FROM dbo.factsales
ORDER BY table_name;

-- 3. Financial summary (non‑return transactions)
SELECT 
    COUNT(*) AS transactions,
    SUM(qty) AS total_quantity,
    SUM(grossvalue - discountamount) AS net_revenue_before_tax,
    SUM(net) AS net_revenue_including_tax,
    SUM(taxamount) AS total_tax,
    SUM(discountamount) AS total_discount
FROM dbo.factsales
WHERE isreturn = 0;

-- 4. Sample of 10 rows (ordered by salesid)
SELECT TOP 10 salesid, datekey, productid, customerid, storeid, promoid, qty, unitprice, net, grossvalue, discountamount, taxamount, isreturn
FROM dbo.factsales
ORDER BY salesid;

-- 5. Orphan check (correct: promoid = 0 is allowed as dummy "No Promotion")
SELECT 'missing datekey' AS constraint_name, COUNT(*) FROM dbo.factsales f 
LEFT JOIN dbo.dimdate d ON f.datekey = d.datekey WHERE d.datekey IS NULL
UNION ALL
SELECT 'missing productid', COUNT(*) FROM dbo.factsales f 
LEFT JOIN dbo.dimproduct p ON f.productid = p.productid WHERE p.productid IS NULL
UNION ALL
SELECT 'missing customerid', COUNT(*) FROM dbo.factsales f 
LEFT JOIN dbo.dimcustomer c ON f.customerid = c.customerid WHERE c.customerid IS NULL
UNION ALL
SELECT 'missing storeid', COUNT(*) FROM dbo.factsales f 
LEFT JOIN dbo.dimstore s ON f.storeid = s.storeid WHERE s.storeid IS NULL
UNION ALL
SELECT 'missing promoid', COUNT(*) FROM dbo.factsales f 
LEFT JOIN dbo.dimpromotion p ON f.promoid = p.promoid WHERE p.promoid IS NULL   -- promoid always has a value (0 or valid)
ORDER BY constraint_name;

-- 6. Percent range checks (fixed column name: tax_rate)
SELECT 'margin_pct' AS column_name, COUNT(*) AS out_of_range FROM dbo.dimproduct WHERE margin_pct < 0 OR margin_pct > 1
UNION ALL
SELECT 'tax_rate', COUNT(*) FROM dbo.dimproduct WHERE tax_rate < 0 OR tax_rate > 1
UNION ALL
SELECT 'discount_pct', COUNT(*) FROM dbo.dimpromotion WHERE discount_pct < 0 OR discount_pct > 1
ORDER BY column_name;

-- 7. Product margin summary (gold view)
SELECT COUNT(*) AS rows, SUM(total_revenue) AS total_revenue, AVG(margin_pct) AS avg_margin_pct
FROM dbo.[001_vw_product_category_margin];