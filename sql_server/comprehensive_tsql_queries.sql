-- ============================================================================
-- comprehensive_tsql_queries.sql
-- ============================================================================
-- Author:       DataGen AI & Assistant
-- Date:         2026-05-25
-- Description:  Ready‑to‑run analytical queries and quality checks for
--               retailanalytics. Optimized with "Aggregate-then-Join" patterns
--               to utilize Columnstore Indexes (CCI) on 10M rows.
--               Monetary values use thousand separators and 0 decimal places;
--               percentages use two decimal places and a % sign.  
--               All _pct columns are fractions (margin_pct -0.10..0.30, etc).
-- ============================================================================

USE retailanalytics;
GO

-- ============================================================================
-- ANALYTICAL QUERIES
-- ============================================================================

-- 1. Total revenue (excl. returns)
SELECT FORMAT(SUM(net), 'N0') AS total_revenue
FROM dbo.factsales
WHERE isreturn = 0;

-- 2. Total COGS
-- Optimized: Aggregates quantities first, then joins dimproduct
WITH sales_agg AS (
    SELECT productid, 
           SUM(qty) AS total_qty
    FROM dbo.factsales
    WHERE isreturn = 0
    GROUP BY productid
)
SELECT FORMAT(SUM(CAST(sa.total_qty AS DECIMAL(18,2)) * p.unitcost), 'N0') AS total_cogs
FROM sales_agg sa
INNER JOIN dbo.dimproduct p ON sa.productid = p.productid;

-- 3. Gross profit
-- Optimized: Aggregates net and qty prior to joining dimension
WITH sales_agg AS (
    SELECT productid, 
           SUM(net) AS total_net,
           SUM(qty) AS total_qty
    FROM dbo.factsales
    WHERE isreturn = 0
    GROUP BY productid
)
SELECT FORMAT(SUM(sa.total_net) - SUM(CAST(sa.total_qty AS DECIMAL(18,2)) * p.unitcost), 'N0') AS gross_profit
FROM sales_agg sa
INNER JOIN dbo.dimproduct p ON sa.productid = p.productid;

-- 4. Gross margin %
-- Optimized: Computes aggregates in parallel and evaluates percentage on summary level
WITH sales_agg AS (
    SELECT productid, 
           SUM(net) AS total_net,
           SUM(qty) AS total_qty
    FROM dbo.factsales
    WHERE isreturn = 0
    GROUP BY productid
),
totals AS (
    SELECT SUM(sa.total_net) AS total_revenue,
           SUM(CAST(sa.total_qty AS DECIMAL(18,2)) * p.unitcost) AS total_cost
    FROM sales_agg sa
    INNER JOIN dbo.dimproduct p ON sa.productid = p.productid
)
SELECT FORMAT((total_revenue - total_cost) /
               NULLIF(total_revenue, 0) * 100, 'N2') + '%' AS gross_margin_pct
FROM totals;

-- 5. Average basket value
SELECT FORMAT(SUM(net) / NULLIF(COUNT(DISTINCT salesid), 0), 'N0') AS avg_basket_value
FROM dbo.factsales
WHERE isreturn = 0;

-- 6. Return rate
SELECT FORMAT(AVG(CAST(isreturn AS DECIMAL(10,4))) * 100, 'N2') + '%' AS return_rate
FROM dbo.factsales;

-- 7. Discount penetration
SELECT FORMAT(AVG(CAST(discountapplied AS DECIMAL(10,4))) * 100, 'N2') + '%' AS discount_penetration
FROM dbo.factsales
WHERE isreturn = 0;

-- 8. Revenue by product category
-- Optimized: Aggregates revenue first, then joins dimproduct
WITH sales_agg AS (
    SELECT productid, 
           SUM(net) AS revenue
    FROM dbo.factsales
    WHERE isreturn = 0
    GROUP BY productid
)
SELECT p.category,
       FORMAT(SUM(sa.revenue), 'N0') AS revenue
FROM sales_agg sa
INNER JOIN dbo.dimproduct p ON sa.productid = p.productid
GROUP BY p.category
ORDER BY SUM(sa.revenue) DESC;

-- 9. Revenue by store region
-- Optimized: Aggregates revenue first, then joins dimstore
WITH sales_agg AS (
    SELECT storeid, 
           SUM(net) AS revenue
    FROM dbo.factsales
    WHERE isreturn = 0
    GROUP BY storeid
)
SELECT s.region,
       FORMAT(SUM(sa.revenue), 'N0') AS revenue
FROM sales_agg sa
INNER JOIN dbo.dimstore s ON sa.storeid = s.storeid
GROUP BY s.region
ORDER BY SUM(sa.revenue) DESC;

-- 10. Top 10 products by revenue
-- Optimized: Aggregates revenue first, then joins dimproduct
WITH sales_agg AS (
    SELECT productid, 
           SUM(net) AS revenue
    FROM dbo.factsales
    WHERE isreturn = 0
    GROUP BY productid
)
SELECT TOP 10 p.name,
       FORMAT(sa.revenue, 'N0') AS revenue
FROM sales_agg sa
INNER JOIN dbo.dimproduct p ON sa.productid = p.productid
ORDER BY sa.revenue DESC;

-- 11. Monthly revenue trend (YYYY-MM)
-- Optimized: Uses pre-calculated dimdate yearmonth field instead of CONVERT function
WITH sales_agg AS (
    SELECT datekey, 
           SUM(net) AS revenue
    FROM dbo.factsales
    WHERE isreturn = 0
    GROUP BY datekey
)
SELECT d.yearmonth,
       FORMAT(SUM(sa.revenue), 'N0') AS revenue
FROM sales_agg sa
INNER JOIN dbo.dimdate d ON sa.datekey = d.datekey
GROUP BY d.yearmonth
ORDER BY d.yearmonth;

-- 12. Average discount % (for discounted transactions)
SELECT FORMAT(AVG(discountamount / NULLIF(grossvalue, 0)) * 100, 'N2') + '%' AS avg_discount_pct
FROM dbo.factsales
WHERE isreturn = 0 AND discountapplied = 1 AND grossvalue > 0;

-- 13. Average delivery days by channel
SELECT channel,
       FORMAT(AVG(CAST(deliverydays AS DECIMAL(10,2))), 'N2') AS avg_delivery_days
FROM dbo.factsales
WHERE isreturn = 0
GROUP BY channel;

-- 14. Return rate by product category
-- Optimized: Pre-aggregates returns by product before joining category
WITH sales_agg AS (
    SELECT productid,
           SUM(CASE WHEN isreturn = 1 THEN 1 ELSE 0 END) AS return_count,
           COUNT(*) AS total_count
    FROM dbo.factsales
    GROUP BY productid
)
SELECT p.category,
       FORMAT(CAST(SUM(sa.return_count) AS DECIMAL(10,4)) / NULLIF(SUM(sa.total_count), 0) * 100, 'N2') + '%' AS return_rate
FROM sales_agg sa
INNER JOIN dbo.dimproduct p ON sa.productid = p.productid
GROUP BY p.category
ORDER BY CAST(SUM(sa.return_count) AS DECIMAL(10,4)) / NULLIF(SUM(sa.total_count), 0) DESC;

-- 15. New vs returning customers avg basket (first purchase ever)
WITH first_purchase AS (
    SELECT customerid, MIN(datekey) AS first_datekey
    FROM dbo.factsales
    WHERE isreturn = 0
    GROUP BY customerid
),
sales_metrics AS (
    SELECT f.customerid,
           f.datekey,
           f.net
    FROM dbo.factsales f
    WHERE f.isreturn = 0
)
SELECT
    FORMAT(AVG(CASE WHEN sm.datekey = fp.first_datekey THEN sm.net END), 'N0') AS avg_new_basket,
    FORMAT(AVG(CASE WHEN sm.datekey != fp.first_datekey THEN sm.net END), 'N0') AS avg_returning_basket
FROM sales_metrics sm
INNER JOIN first_purchase fp ON sm.customerid = fp.customerid;

-- 16. Weekend vs weekday revenue
-- Optimized: Aggregates revenue first, then joins dimdate weekend flag
WITH sales_agg AS (
    SELECT datekey, 
           SUM(net) AS revenue
    FROM dbo.factsales
    WHERE isreturn = 0
    GROUP BY datekey
)
SELECT d.isweekend,
       FORMAT(SUM(sa.revenue), 'N0') AS revenue
FROM sales_agg sa
INNER JOIN dbo.dimdate d ON sa.datekey = d.datekey
GROUP BY d.isweekend;

-- 17. Top 10 stores by revenue
-- Optimized: Aggregates revenue first, then joins dimstore name
WITH sales_agg AS (
    SELECT storeid, 
           SUM(net) AS revenue
    FROM dbo.factsales
    WHERE isreturn = 0
    GROUP BY storeid
)
SELECT TOP 10 s.storename,
       FORMAT(sa.revenue, 'N0') AS revenue
FROM sales_agg sa
INNER JOIN dbo.dimstore s ON sa.storeid = s.storeid
ORDER BY sa.revenue DESC;

-- ============================================================================
-- ADDITIONAL QUALITY CHECKS (fraction-based schema)
-- ============================================================================

-- 18. Product margin distribution
-- Optimized: Explicitly excludes dummy productid = -1 from statistical aggregates
SELECT
    FORMAT(MIN(margin_pct) * 100, 'N2') + '%' AS min_margin_pct,
    FORMAT(MAX(margin_pct) * 100, 'N2') + '%' AS max_margin_pct,
    FORMAT(AVG(margin_pct) * 100, 'N2') + '%' AS avg_margin_pct,
    FORMAT(STDEV(margin_pct) * 100, 'N2') + '%' AS stdev_margin_pct
FROM dbo.dimproduct
WHERE productid > 0;

-- 19. Promotion discount fraction distribution (0.0..0.45)
SELECT
    FORMAT(MIN(discount_pct) * 100, 'N2') + '%' AS min_discount_pct,
    FORMAT(MAX(discount_pct) * 100, 'N2') + '%' AS max_discount_pct,
    FORMAT(AVG(discount_pct) * 100, 'N2') + '%' AS avg_discount_pct
FROM dbo.dimpromotion
WHERE promoid > 0;  -- exclude dummy "No Promotion" and "Unknown" rows

-- 20. NULL checks on critical fact columns
SELECT
    SUM(CASE WHEN hour IS NULL THEN 1 ELSE 0 END) AS hour_nulls,
    SUM(CASE WHEN returnreason IS NULL THEN 1 ELSE 0 END) AS returnreason_nulls,
    SUM(CASE WHEN promoid IS NULL THEN 1 ELSE 0 END) AS promoid_nulls
FROM dbo.factsales;

-- 21. In‑Store orders must have deliverydays = 0
SELECT COUNT(*) AS instore_nonzero_delivery
FROM dbo.factsales
WHERE channel = 'In-Store' AND deliverydays > 0;

-- 22. Orphan foreign keys (should all return 0)
-- Optimized: Leverages trusted foreign key metadata structures
SELECT 'datekey' AS fk, COUNT(*) AS orphan_count
FROM dbo.factsales f
LEFT JOIN dbo.dimdate d ON f.datekey = d.datekey
WHERE d.datekey IS NULL
UNION ALL
SELECT 'productid', COUNT(*)
FROM dbo.factsales f
LEFT JOIN dbo.dimproduct p ON f.productid = p.productid
WHERE p.productid IS NULL
UNION ALL
SELECT 'customerid', COUNT(*)
FROM dbo.factsales f
LEFT JOIN dbo.dimcustomer c ON f.customerid = c.customerid
WHERE c.customerid IS NULL
UNION ALL
SELECT 'storeid', COUNT(*)
FROM dbo.factsales f
LEFT JOIN dbo.dimstore s ON f.storeid = s.storeid
WHERE s.storeid IS NULL
UNION ALL
SELECT 'promoid', COUNT(*)
FROM dbo.factsales f
LEFT JOIN dbo.dimpromotion pr ON f.promoid = pr.promoid
WHERE pr.promoid IS NULL;
-- ============================================================================
-- End of comprehensive_tsql_queries.sql
-- ============================================================================