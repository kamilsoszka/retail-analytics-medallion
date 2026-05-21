-- -------------------------------------------------------------------
-- 05_silver_gold_validation
-- Data quality checks for silver and gold layers
-- Compatible with final schema: promoid=0, hour, returnreason='No return'
-- Updated: correct gold table names (vw_ prefix)
-- -------------------------------------------------------------------

-- Use silver tables after transformation
-- If you need bronze checks, replace `02_silver_db` with `01_bronze_db`
-- and prefix table names with `bronze_` instead of `silver_`

-- 1. Row counts (all tables)
SELECT 'dimdate' AS table_name, COUNT(*) AS row_count FROM `02_silver_db`.`silver_dimdate`
UNION ALL SELECT 'dimcustomer', COUNT(*) FROM `02_silver_db`.`silver_dimcustomer`
UNION ALL SELECT 'dimproduct', COUNT(*) FROM `02_silver_db`.`silver_dimproduct`
UNION ALL SELECT 'dimstore', COUNT(*) FROM `02_silver_db`.`silver_dimstore`
UNION ALL SELECT 'dimpromotion', COUNT(*) FROM `02_silver_db`.`silver_dimpromotion`
UNION ALL SELECT 'factsales', COUNT(*) FROM `02_silver_db`.`silver_factsales`
ORDER BY table_name;

-- 2. Primary key uniqueness (duplicate counts)
SELECT 'dimdate' AS table_name, COUNT(*) - COUNT(DISTINCT datekey) AS duplicates FROM `02_silver_db`.`silver_dimdate`
UNION ALL SELECT 'dimcustomer', COUNT(*) - COUNT(DISTINCT customerid) FROM `02_silver_db`.`silver_dimcustomer`
UNION ALL SELECT 'dimproduct', COUNT(*) - COUNT(DISTINCT productid) FROM `02_silver_db`.`silver_dimproduct`
UNION ALL SELECT 'dimstore', COUNT(*) - COUNT(DISTINCT storeid) FROM `02_silver_db`.`silver_dimstore`
UNION ALL SELECT 'dimpromotion', COUNT(*) - COUNT(DISTINCT promoid) FROM `02_silver_db`.`silver_dimpromotion`
UNION ALL SELECT 'factsales', COUNT(*) - COUNT(DISTINCT salesid) FROM `02_silver_db`.`silver_factsales`
ORDER BY table_name;

-- 3. Financial summary (non‑return transactions)
SELECT 
    COUNT(*) AS transactions,
    SUM(qty) AS total_quantity,
    SUM(grossvalue - discountamount) AS net_revenue_before_tax,
    SUM(net) AS net_revenue_including_tax,
    SUM(taxamount) AS total_tax,
    SUM(discountamount) AS total_discount
FROM `02_silver_db`.`silver_factsales`
WHERE isreturn = 0;

-- 4. Sample of 10 rows (including hour and returnreason)
SELECT salesid, datekey, productid, customerid, storeid, promoid, qty, unitprice, net, grossvalue, discountamount, taxamount, isreturn, hour, returnreason
FROM `02_silver_db`.`silver_factsales`
ORDER BY salesid
LIMIT 10;

-- 5. Orphan checks (promoid = 0 is allowed)
SELECT 'missing datekey' AS constraint_name, COUNT(*) FROM `02_silver_db`.`silver_factsales` f 
LEFT JOIN `02_silver_db`.`silver_dimdate` d ON f.datekey = d.datekey WHERE d.datekey IS NULL
UNION ALL
SELECT 'missing productid', COUNT(*) FROM `02_silver_db`.`silver_factsales` f 
LEFT JOIN `02_silver_db`.`silver_dimproduct` p ON f.productid = p.productid WHERE p.productid IS NULL
UNION ALL
SELECT 'missing customerid', COUNT(*) FROM `02_silver_db`.`silver_factsales` f 
LEFT JOIN `02_silver_db`.`silver_dimcustomer` c ON f.customerid = c.customerid WHERE c.customerid IS NULL
UNION ALL
SELECT 'missing storeid', COUNT(*) FROM `02_silver_db`.`silver_factsales` f 
LEFT JOIN `02_silver_db`.`silver_dimstore` s ON f.storeid = s.storeid WHERE s.storeid IS NULL
UNION ALL
SELECT 'missing promoid', COUNT(*) FROM `02_silver_db`.`silver_factsales` f 
LEFT JOIN `02_silver_db`.`silver_dimpromotion` p ON f.promoid = p.promoid WHERE p.promoid IS NULL
ORDER BY constraint_name;

-- 6. Percentage range checks (margin_pct, tax_rate, discount_pct)
SELECT 'margin_pct' AS column_name, COUNT(*) AS out_of_range FROM `02_silver_db`.`silver_dimproduct` WHERE margin_pct < 0 OR margin_pct > 1
UNION ALL
SELECT 'tax_rate', COUNT(*) FROM `02_silver_db`.`silver_dimproduct` WHERE tax_rate < 0 OR tax_rate > 1
UNION ALL
SELECT 'discount_pct', COUNT(*) FROM `02_silver_db`.`silver_dimpromotion` WHERE discount_pct < 0 OR discount_pct > 1
ORDER BY column_name;

-- 7. Hour column validation (0-23, not null)
SELECT 'hour_null' AS check_name, COUNT(*) FROM `02_silver_db`.`silver_factsales` WHERE hour IS NULL
UNION ALL
SELECT 'hour_out_of_range', COUNT(*) FROM `02_silver_db`.`silver_factsales` WHERE hour < 0 OR hour > 23;

-- 8. Returnreason validation
SELECT 'returnreason_null' AS check_name, COUNT(*) FROM `02_silver_db`.`silver_factsales` WHERE returnreason IS NULL
UNION ALL
SELECT 'returnreason_missing_for_nonreturn', COUNT(*) FROM `02_silver_db`.`silver_factsales` WHERE isreturn = 0 AND returnreason != 'No return'
UNION ALL
SELECT 'returnreason_missing_for_return', COUNT(*) FROM `02_silver_db`.`silver_factsales` WHERE isreturn = 1 AND returnreason = 'No return';

-- 9. Deliverydays integrity (In-Store = 0, others >0)
SELECT 'deliverydays_nonzero_for_instore' AS check_name, COUNT(*) 
FROM `02_silver_db`.`silver_factsales` WHERE channel = 'In-Store' AND deliverydays != 0
UNION ALL
SELECT 'deliverydays_zero_for_online', COUNT(*) 
FROM `02_silver_db`.`silver_factsales` WHERE channel IN ('Online', 'Mobile App') AND deliverydays = 0 AND isreturn = 0;

-- 10. Quick product margin summary from gold table (corrected name with vw_ prefix)
SELECT COUNT(*) AS rows, SUM(total_revenue) AS total_revenue, AVG(margin_pct) AS avg_margin_pct
FROM `03_gold_db`.`vw_001_product_category_margin`;