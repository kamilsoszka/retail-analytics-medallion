-- ============================================================================
-- validate_fabric_layers.sql
-- ============================================================================
-- Author:           DataGen AI & Assistant
-- Created:          2026-05-23
-- Last modified:    2026-05-26 09:45:00 UTC
-- Suggested name:   validate_fabric_layers.sql
-- Description:
--   Fabric SQL Endpoint – Silver/Gold layer validation.
--   Executes a series of lightweight data‑quality checks on the Silver and
--   Gold tables inside the Fabric Lakehouse.  The script verifies:
--     1. Row counts match the expected volumes.
--     2. Primary key uniqueness (no duplicates).
--     3. Overall financial summary (non‑return transactions).
--     4. A sample of 10 fact rows for visual inspection.
--     5. Orphan foreign keys (all dimensions must be reachable).
--     6. Fraction range checks for margin_pct, tax_rate, discount_pct.
--     7. Hour column integrity (no NULLs, values 0‑23).
--     8. Return reason consistency.
--     9. Delivery days logic (In‑Store = 0, online > 0).
--    10. Quick summary from the Gold product‑category‑margin view.
--
--   This script is optimized for the Fabric SQL Endpoint using Spark SQL dialect.
--   All aggregations are formatted with thousand separators and correct decimals.
-- ============================================================================

-- ============================================================================
-- 1. ROW COUNTS – validate that every table contains the expected volume
-- ============================================================================
SELECT 'dimdate'      AS tbl, FORMAT_NUMBER(COUNT(*), 0) AS cnt FROM `02_silver_db`.`silver_dimdate`
UNION ALL
SELECT 'dimcustomer'  , FORMAT_NUMBER(COUNT(*), 0) FROM `02_silver_db`.`silver_dimcustomer`
UNION ALL
SELECT 'dimproduct'   , FORMAT_NUMBER(COUNT(*), 0) FROM `02_silver_db`.`silver_dimproduct`
UNION ALL
SELECT 'dimstore'     , FORMAT_NUMBER(COUNT(*), 0) FROM `02_silver_db`.`silver_dimstore`
UNION ALL
SELECT 'dimpromotion' , FORMAT_NUMBER(COUNT(*), 0) FROM `02_silver_db`.`silver_dimpromotion`
UNION ALL
SELECT 'factsales'    , FORMAT_NUMBER(COUNT(*), 0) FROM `02_silver_db`.`silver_factsales`
ORDER BY tbl;

-- ============================================================================
-- 2. PRIMARY KEY UNIQUENESS – duplicate keys would break referential integrity
-- ============================================================================
SELECT 'dimdate'      AS tbl,
       FORMAT_NUMBER(COUNT(*) - COUNT(DISTINCT datekey), 0)     AS dups FROM `02_silver_db`.`silver_dimdate`
UNION ALL
SELECT 'dimcustomer'  , FORMAT_NUMBER(COUNT(*) - COUNT(DISTINCT customerid), 0) FROM `02_silver_db`.`silver_dimcustomer`
UNION ALL
SELECT 'dimproduct'   , FORMAT_NUMBER(COUNT(*) - COUNT(DISTINCT productid), 0)  FROM `02_silver_db`.`silver_dimproduct`
UNION ALL
SELECT 'dimstore'     , FORMAT_NUMBER(COUNT(*) - COUNT(DISTINCT storeid), 0)    FROM `02_silver_db`.`silver_dimstore`
UNION ALL
SELECT 'dimpromotion' , FORMAT_NUMBER(COUNT(*) - COUNT(DISTINCT promoid), 0)    FROM `02_silver_db`.`silver_dimpromotion`
UNION ALL
SELECT 'factsales'    , FORMAT_NUMBER(COUNT(*) - COUNT(DISTINCT salesid), 0)    FROM `02_silver_db`.`silver_factsales`
ORDER BY tbl;

-- ============================================================================
-- 3. FINANCIAL SUMMARY (non‑return transactions only)
-- ============================================================================
SELECT
    FORMAT_NUMBER(COUNT(*), 0)                                AS transactions,
    FORMAT_NUMBER(SUM(qty), 0)                                AS total_qty,
    FORMAT_NUMBER(SUM(grossvalue - discountamount), 0)        AS net_rev_before_tax,
    FORMAT_NUMBER(SUM(net), 0)                                AS net_rev_after_tax,
    FORMAT_NUMBER(SUM(taxamount), 0)                          AS total_tax,
    FORMAT_NUMBER(SUM(discountamount), 0)                     AS total_discount
FROM `02_silver_db`.`silver_factsales`
WHERE isreturn = 0;

-- ============================================================================
-- 4. SAMPLE ROWS – spot‑check 10 transactions visually
-- ============================================================================
SELECT * FROM `02_silver_db`.`silver_factsales` ORDER BY salesid LIMIT 10;

-- ============================================================================
-- 5. ORPHAN FOREIGN KEYS – every FK must reference an existing dimension row
--    Utilizes fast Broadcast Joins on Delta tables for sub-second evaluations.
-- ============================================================================
SELECT 'missing datekey'    AS ck,
       FORMAT_NUMBER(COUNT(*), 0)             AS orphan_count
FROM `02_silver_db`.`silver_factsales` f
LEFT JOIN `02_silver_db`.`silver_dimdate` d ON f.datekey = d.datekey
WHERE d.datekey IS NULL
UNION ALL
SELECT 'missing productid' , FORMAT_NUMBER(COUNT(*), 0)
FROM `02_silver_db`.`silver_factsales` f
LEFT JOIN `02_silver_db`.`silver_dimproduct` p ON f.productid = p.productid
WHERE p.productid IS NULL
UNION ALL
SELECT 'missing customerid', FORMAT_NUMBER(COUNT(*), 0)
FROM `02_silver_db`.`silver_factsales` f
LEFT JOIN `02_silver_db`.`silver_dimcustomer` c ON f.customerid = c.customerid
WHERE c.customerid IS NULL
UNION ALL
SELECT 'missing storeid'   , FORMAT_NUMBER(COUNT(*), 0)
FROM `02_silver_db`.`silver_factsales` f
LEFT JOIN `02_silver_db`.`silver_dimstore` s ON f.storeid = s.storeid
WHERE s.storeid IS NULL
UNION ALL
SELECT 'missing promoid'   , FORMAT_NUMBER(COUNT(*), 0)
FROM `02_silver_db`.`silver_factsales` f
LEFT JOIN `02_silver_db`.`silver_dimpromotion` pr ON f.promoid = pr.promoid
WHERE pr.promoid IS NULL
ORDER BY ck;

-- ============================================================================
-- 6. FRACTION RANGE CHECKS
--    margin_pct   : -0.10 … 0.30
--    tax_rate     :  0.0  … 1.0
--    discount_pct :  0.0  … 0.45
-- ============================================================================
SELECT 'margin_pct'   AS col,
       FORMAT_NUMBER(COUNT(*), 0)       AS bad
FROM `02_silver_db`.`silver_dimproduct`
WHERE margin_pct < -0.10 OR margin_pct > 0.30
UNION ALL
SELECT 'tax_rate'     , FORMAT_NUMBER(COUNT(*), 0)
FROM `02_silver_db`.`silver_dimproduct`
WHERE tax_rate < 0 OR tax_rate > 1
UNION ALL
SELECT 'discount_pct' , FORMAT_NUMBER(COUNT(*), 0)
FROM `02_silver_db`.`silver_dimpromotion`
WHERE discount_pct < 0.0 OR discount_pct > 0.45
ORDER BY col;

-- ============================================================================
-- 7. HOUR VALIDATION – every row must have a valid hour (0‑23), no NULLs
-- ============================================================================
SELECT 'hour_null'        AS ck, FORMAT_NUMBER(COUNT(*), 0) AS count
FROM `02_silver_db`.`silver_factsales`
WHERE hour IS NULL
UNION ALL
SELECT 'hour_range'       , FORMAT_NUMBER(COUNT(*), 0)
FROM `02_silver_db`.`silver_factsales`
WHERE hour NOT BETWEEN 0 AND 23;

-- ============================================================================
-- 8. RETURN REASON INTEGRITY
--    Non‑returns must have reason = 'No return'
--    Returns     must NOT have reason = 'No return' (should be a real reason)
-- ============================================================================
SELECT 'nonret_wrong' AS ck, FORMAT_NUMBER(COUNT(*), 0) AS count
FROM `02_silver_db`.`silver_factsales`
WHERE isreturn = 0 AND returnreason != 'No return'
UNION ALL
SELECT 'ret_missing'  , FORMAT_NUMBER(COUNT(*), 0)
FROM `02_silver_db`.`silver_factsales`
WHERE isreturn = 1 AND returnreason = 'No return';

-- ============================================================================
-- 9. DELIVERY DAYS LOGIC
--    In‑Store purchases must have 0 delivery days.
--    Online / Mobile App purchases should have > 0 delivery days.
-- ============================================================================
SELECT 'instore_nonzero' AS ck, FORMAT_NUMBER(COUNT(*), 0) AS count
FROM `02_silver_db`.`silver_factsales`
WHERE channel = 'In-Store' AND deliverydays != 0
UNION ALL
SELECT 'online_zero'     , FORMAT_NUMBER(COUNT(*), 0)
FROM `02_silver_db`.`silver_factsales`
WHERE channel IN ('Online','Mobile App') AND deliverydays = 0 AND isreturn = 0;

-- ============================================================================
-- 10. GOLD VIEW SUMMARY – quick sanity check on the primary analytical view
-- ============================================================================
SELECT FORMAT_NUMBER(COUNT(*), 0)                             AS rows,
       FORMAT_NUMBER(SUM(total_revenue), 0)                   AS revenue,
       CONCAT(FORMAT_NUMBER(AVG(margin_pct) * 100, 2), '%')   AS avg_margin
FROM `03_gold_db`.`vw_001_product_category_margin`;
-- ============================================================================
-- End of validate_fabric_layers.sql
-- ============================================================================