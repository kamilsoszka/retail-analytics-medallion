-- ============================================================================
-- 05_silver_gold_validation.sql
-- ============================================================================
-- Author:       DataGen AI
-- Date:         2026-05-23
-- Description:  Data quality checks for silver and gold layers in Fabric.
--               All _pct columns are fractions (margin_pct -0.10..0.30,
--               discount_pct 0.0..0.45).
-- ============================================================================

-- 1. Row counts
SELECT 'dimdate' AS tbl, COUNT(*) AS cnt FROM `02_silver_db`.`silver_dimdate`
UNION ALL SELECT 'dimcustomer', COUNT(*) FROM `02_silver_db`.`silver_dimcustomer`
UNION ALL SELECT 'dimproduct', COUNT(*) FROM `02_silver_db`.`silver_dimproduct`
UNION ALL SELECT 'dimstore', COUNT(*) FROM `02_silver_db`.`silver_dimstore`
UNION ALL SELECT 'dimpromotion', COUNT(*) FROM `02_silver_db`.`silver_dimpromotion`
UNION ALL SELECT 'factsales', COUNT(*) FROM `02_silver_db`.`silver_factsales`
ORDER BY tbl;

-- 2. Primary key duplicates
SELECT 'dimdate' AS tbl, COUNT(*) - COUNT(DISTINCT datekey) AS dups FROM `02_silver_db`.`silver_dimdate`
UNION ALL SELECT 'dimcustomer', COUNT(*) - COUNT(DISTINCT customerid) FROM `02_silver_db`.`silver_dimcustomer`
UNION ALL SELECT 'dimproduct', COUNT(*) - COUNT(DISTINCT productid) FROM `02_silver_db`.`silver_dimproduct`
UNION ALL SELECT 'dimstore', COUNT(*) - COUNT(DISTINCT storeid) FROM `02_silver_db`.`silver_dimstore`
UNION ALL SELECT 'dimpromotion', COUNT(*) - COUNT(DISTINCT promoid) FROM `02_silver_db`.`silver_dimpromotion`
UNION ALL SELECT 'factsales', COUNT(*) - COUNT(DISTINCT salesid) FROM `02_silver_db`.`silver_factsales`
ORDER BY tbl;

-- 3. Financial summary
SELECT
    COUNT(*) AS transactions,
    SUM(qty) AS total_qty,
    SUM(grossvalue - discountamount) AS net_rev_before_tax,
    SUM(net) AS net_rev_after_tax,
    SUM(taxamount) AS total_tax,
    SUM(discountamount) AS total_discount
FROM `02_silver_db`.`silver_factsales`
WHERE isreturn = 0;

-- 4. Sample rows
SELECT * FROM `02_silver_db`.`silver_factsales` ORDER BY salesid LIMIT 10;

-- 5. Orphan checks
SELECT 'missing datekey' AS ck, COUNT(*) FROM `02_silver_db`.`silver_factsales` f 
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
ORDER BY ck;

-- 6. Fraction range checks (margin_pct -0.10..0.30, discount_pct 0.0..0.45)
SELECT 'margin_pct' AS col, COUNT(*) AS bad
FROM `02_silver_db`.`silver_dimproduct`
WHERE margin_pct < -0.10 OR margin_pct > 0.30
UNION ALL
SELECT 'tax_rate', COUNT(*)
FROM `02_silver_db`.`silver_dimproduct`
WHERE tax_rate < 0 OR tax_rate > 1
UNION ALL
SELECT 'discount_pct', COUNT(*)
FROM `02_silver_db`.`silver_dimpromotion`
WHERE discount_pct < 0.0 OR discount_pct > 0.45
ORDER BY col;

-- 7. Hour validation
SELECT 'hour_null' AS ck, COUNT(*) FROM `02_silver_db`.`silver_factsales` WHERE hour IS NULL
UNION ALL
SELECT 'hour_range', COUNT(*) FROM `02_silver_db`.`silver_factsales` WHERE hour NOT BETWEEN 0 AND 23;

-- 8. Return reason
SELECT 'nonret_wrong' AS ck, COUNT(*) FROM `02_silver_db`.`silver_factsales` WHERE isreturn = 0 AND returnreason != 'No return'
UNION ALL
SELECT 'ret_missing' , COUNT(*) FROM `02_silver_db`.`silver_factsales` WHERE isreturn = 1 AND returnreason = 'No return';

-- 9. Delivery days
SELECT 'instore_nonzero' AS ck, COUNT(*) FROM `02_silver_db`.`silver_factsales` WHERE channel = 'In-Store' AND deliverydays != 0
UNION ALL
SELECT 'online_zero', COUNT(*) FROM `02_silver_db`.`silver_factsales` WHERE channel IN ('Online','Mobile App') AND deliverydays = 0 AND isreturn = 0;

-- 10. Gold view summary
SELECT COUNT(*) AS rows, SUM(total_revenue) AS revenue, AVG(margin_pct) AS avg_margin
FROM `03_gold_db`.`vw_001_product_category_margin`;
-- ============================================================================
-- End of 05_silver_gold_validation.sql
-- ============================================================================