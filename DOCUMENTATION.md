# Retail Analytics – Complete Documentation (Final)

**Project Overview** – The database models a multi‑channel retail chain with 5 million sales transactions (2023‑01‑01 to today). All percentages are fractions. `promoid = 0` is dummy for no promotion (converted to NULL). Star schema with five dimensions and one fact table.

**dim_date**
| Column | Type | Description |
|--------|------|-------------|
| datekey | INT | YYYYMMDD surrogate key |
| fulldate | DATE | calendar date |
| year | SMALLINT | year |
| quarternumber | TINYINT | 1‑4 |
| quartername | NCHAR(2) | Q1‑Q4 |
| monthnumber | TINYINT | 1‑12 |
| monthname | NVARCHAR(20) | January, … |
| weekdaynumber | TINYINT | 1=Monday..7=Sunday |
| weekdayname | NVARCHAR(20) | Monday, … |
| isweekend | BIT | 1 if weekend |
| yearmonth | NCHAR(7) | YYYY‑MM |
| yearmonthnumber | INT | YYYYMM |
| yearquarter | NVARCHAR(7) | YYYY‑QX |
| yearquarternumber | INT | YYYY*10+Q |
| yearweek | NVARCHAR(8) | YYYY‑Www |
| yearweeknumber | INT | YYYY*100+week |
| isholiday | BIT | 1 if Dec/Jan/July |

**dim_customer**
| Column | Type | Description |
|--------|------|-------------|
| customerid | INT | PK |
| fullname | NVARCHAR(100) | first + last (suffix if duplicate) |
| email | NVARCHAR(100) | unique email |
| age | TINYINT | 18‑75 |
| gender | NVARCHAR(20) | Male/Female/Non‑binary |
| city | NVARCHAR(50) | residence city |
| tier | NVARCHAR(20) | Bronze/Silver/Gold/Platinum |
| points | INT | loyalty points |
| isactive | BIT | 1 = active |
| lang | NVARCHAR(10) | en,de,fr,es,pl,it |
| totalspend | DECIMAL(18,2) | lifetime spend USD |
| regdate | DATE | registration date |
| annualincome | DECIMAL(18,2) | USD |
| incomebracket | NVARCHAR(20) | Low/Medium/High/Very High/Ultra High |
| education | NVARCHAR(50) | High School/Bachelor/Master/PhD |
| maritalstatus | NVARCHAR(20) | Single/Married/Divorced/Widowed |
| childrencount | TINYINT | number of children |
| loyaltysegment | NVARCHAR(20) | same as tier |
| satisfactionscore | DECIMAL(5,1) | 1.0‑5.0 |
| dayssincelastpurchase | INT | days since last transaction |
| hassubscription | BIT | newsletter subscription |
| preferredcontact | NVARCHAR(20) | Email/SMS/Phone/Mail |
| spendmultiplier | DECIMAL(10,3) | spending behaviour factor |

**dim_product**
| Column | Type | Description |
|--------|------|-------------|
| productid | INT | PK |
| name | NVARCHAR(150) | brand + adjective + noun + variant |
| category | NVARCHAR(50) | Electronics/Home/Sports/Kids/Garden |
| brand | NVARCHAR(50) | brand name |
| unitcost | DECIMAL(18,2) | cost price USD |
| unitprice | DECIMAL(18,2) | base selling price (before market multiplier) |
| margin_pct | DECIMAL(5,4) | (price‑cost)/price |
| weight | DECIMAL(10,2) | kg |
| color | NVARCHAR(20) | Red/Blue/Green/Black/White/Gray/Silver/Gold |
| material | NVARCHAR(50) | Plastic/Metal/Wood/Glass/Fabric |
| supplierid | INT | 1‑50 |
| isactive | BIT | 1 = still sold |
| minstock | INT | reorder level |
| tax_rate | DECIMAL(5,4) | 0.10 or 0.21 |
| haswarranty | BIT | 1 = warranty offered |
| ecofriendly | BIT | 1 = ecoscore > 100 |
| seasonalityfactor | DECIMAL(5,2) | demand multiplier (0.7‑1.3) |
| warrantymonths | TINYINT | 0,12,24,36 |
| ecoscore | TINYINT | 20‑200 |
| releaseyear | SMALLINT | 2018‑2025 |
| skucount | INT | number of variants |
| isdiscontinued | BIT | 1 = discontinued |
| productrating | DECIMAL(3,1) | 1.0‑5.0 |
| stockstatus | NVARCHAR(20) | In Stock / Low Stock / Out of Stock |

**dim_store**
| Column | Type | Description |
|--------|------|-------------|
| storeid | INT | PK |
| storename | NVARCHAR(150) | chain + city + suffix |
| city | NVARCHAR(50) | location city |
| type | NVARCHAR(50) | Supermarket/Hypermarket/Convenience/Department |
| staff | SMALLINT | number of employees |
| sizem2 | INT | square meters |
| hascafe | BIT | 1 = café present |
| openingyear | SMALLINT | year opened |
| region | NVARCHAR(50) | North/South/East/West/Central |
| renovationyear | SMALLINT | last renovation (0 = never) |
| parkingspots | SMALLINT | parking spaces |
| storerating | DECIMAL(3,1) | 2.0‑5.0 |
| hasdeliveryservice | BIT | 1 = delivery available |
| floornumber | TINYINT | 1‑5 |
| distancetocitycenterkm | DECIMAL(8,1) | km |
| annualrentcost | DECIMAL(18,2) | USD |
| storesizemultiplier | DECIMAL(10,3) | relative size (0.3‑4.0) |

**dim_promotion**
| Column | Type | Description |
|--------|------|-------------|
| promoid | INT | PK, 0 = no promotion (converted to NULL in database) |
| promoname | NVARCHAR(150) | unique name |
| discount_pct | DECIMAL(5,3) | percentage discount (fraction) |
| discount_fixed | DECIMAL(10,2) | fixed USD discount |
| type | NVARCHAR(50) | Percentage/Fixed Amount/BOGO/Free Shipping |
| isactive | BIT | 1 = currently active |
| minspend | INT | USD threshold |
| channel | NVARCHAR(50) | Email/SMS/App/InStore/All/Online |
| budget | DECIMAL(18,2) | USD |
| startdate | DATE | start date |
| enddate | DATE | end date |
| targetaudience | NVARCHAR(50) | All/New/Loyal/HighSpend |
| maxdiscountcap | DECIMAL(18,2) | max discount USD |
| isstackable | BIT | 1 = can combine |
| redemption_rate | DECIMAL(5,3) | target redemption rate (0.02‑0.35) |
| coderequired | BIT | 1 = promo code needed |
| promoupliftfactor | DECIMAL(6,3) | sales multiplier (1.0‑2.2) |

**factsales**
| Column | Type | Description |
|--------|------|-------------|
| salesid | BIGINT | PK |
| datekey | INT | FK → dim_date |
| productid | INT | FK → dim_product |
| customerid | INT | FK → dim_customer |
| storeid | INT | FK → dim_store |
| promoid | INT | FK → dim_promotion (NULL = no promotion) |
| qty | TINYINT | 1‑10 |
| unitprice | DECIMAL(18,2) | actual selling price (base * market index * seasonality) |
| tax_rate | DECIMAL(5,4) | 0.10 or 0.21 |
| net | DECIMAL(18,2) | gross – discount + tax |
| payment | NVARCHAR(20) | Card/Cash/Bank Transfer/Digital Wallet/PayPal |
| channel | NVARCHAR(20) | Online/In‑Store/Mobile App/Phone Order |
| grossvalue | DECIMAL(18,2) | qty * unitprice |
| discountamount | DECIMAL(18,2) | total discount applied |
| taxamount | DECIMAL(18,2) | tax paid |
| shipcost | DECIMAL(18,2) | shipping cost (0 for in‑store) |
| isreturn | BIT | 1 = return transaction |
| shipweight | DECIMAL(10,2) | kg (qty * product weight) |
| discountapplied | BIT | 1 = any discount used |
| returnreason | NVARCHAR(50) | NULL if not a return |
| deliverydays | TINYINT | 0 for in‑store, 1‑12 for online |

**All code examples (T‑SQL, DAX, Python) – copy everything below this line**

```sql
SELECT SUM(net) AS total_revenue FROM dbo.factsales WHERE isreturn = 0;
SELECT SUM(f.qty * p.unitcost) AS total_cogs FROM dbo.factsales f JOIN dbo.dimproduct p ON f.productid = p.productid WHERE f.isreturn = 0;
SELECT SUM(f.net - f.qty * p.unitcost) AS gross_profit FROM dbo.factsales f JOIN dbo.dimproduct p ON f.productid = p.productid WHERE f.isreturn = 0;
SELECT (SUM(f.net - f.qty * p.unitcost) / NULLIF(SUM(f.net), 0)) AS gross_margin_pct FROM dbo.factsales f JOIN dbo.dimproduct p ON f.productid = p.productid WHERE f.isreturn = 0;
SELECT SUM(net) / COUNT(DISTINCT salesid) AS avg_basket_value FROM dbo.factsales WHERE isreturn = 0;
SELECT 1.0 * SUM(CASE WHEN isreturn = 1 THEN 1 ELSE 0 END) / COUNT(*) AS return_rate FROM dbo.factsales;
SELECT 1.0 * SUM(CASE WHEN discountapplied = 1 THEN 1 ELSE 0 END) / COUNT(*) AS discount_penetration FROM dbo.factsales WHERE isreturn = 0;

WITH monthly_revenue AS (
    SELECT YEAR(d.fulldate) AS yr, MONTH(d.fulldate) AS mn, SUM(f.net) AS revenue
    FROM dbo.factsales f JOIN dbo.dimdate d ON f.datekey = d.datekey
    WHERE f.isreturn = 0
    GROUP BY YEAR(d.fulldate), MONTH(d.fulldate)
)
SELECT curr.yr, curr.mn, curr.revenue, prev.revenue AS prev_year_revenue,
       (curr.revenue - prev.revenue)/NULLIF(prev.revenue,0) AS yoy_growth
FROM monthly_revenue curr LEFT JOIN monthly_revenue prev ON curr.mn = prev.mn AND curr.yr = prev.yr + 1
ORDER BY curr.yr, curr.mn;

WITH daily_sales AS (
    SELECT d.fulldate, SUM(f.net) AS daily_total
    FROM dbo.factsales f JOIN dbo.dimdate d ON f.datekey = d.datekey
    WHERE f.isreturn = 0
    GROUP BY d.fulldate
)
SELECT fulldate, daily_total,
       AVG(daily_total) OVER (ORDER BY fulldate ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS ma_7days,
       AVG(daily_total) OVER (ORDER BY fulldate ROWS BETWEEN 29 PRECEDING AND CURRENT ROW) AS ma_30days
FROM daily_sales ORDER BY fulldate;

SELECT d.isweekend, AVG(f.net) AS avg_sales, SUM(f.net) AS total_sales, COUNT(*) AS tx_count
FROM dbo.factsales f JOIN dbo.dimdate d ON f.datekey = d.datekey
WHERE f.isreturn = 0
GROUP BY d.isweekend;

WITH first_purchase AS (
    SELECT customerid, MIN(d.fulldate) AS first_date
    FROM dbo.factsales f JOIN dbo.dimdate d ON f.datekey = d.datekey
    WHERE f.isreturn = 0
    GROUP BY customerid
)
SELECT fp.first_date, DATEDIFF(month, fp.first_date, d.fulldate) AS months_since_first, SUM(f.net) AS cohort_revenue
FROM first_purchase fp JOIN dbo.factsales f ON fp.customerid = f.customerid JOIN dbo.dimdate d ON f.datekey = d.datekey
WHERE f.isreturn = 0
GROUP BY fp.first_date, DATEDIFF(month, fp.first_date, d.fulldate)
ORDER BY fp.first_date, months_since_first;

WITH daily_sales AS (
    SELECT d.fulldate, SUM(f.net) AS daily_total
    FROM dbo.factsales f JOIN dbo.dimdate d ON f.datekey = d.datekey
    WHERE f.isreturn = 0
    GROUP BY d.fulldate
)
SELECT fulldate, daily_total,
       PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY daily_total) OVER (ORDER BY fulldate ROWS BETWEEN 89 PRECEDING AND CURRENT ROW) AS p90_90days
FROM daily_sales;

SELECT c.tier, COUNT(DISTINCT c.customerid) AS cust_count, SUM(f.net) AS revenue, SUM(f.net)/COUNT(DISTINCT c.customerid) AS avg_clv
FROM dbo.dimcustomer c JOIN dbo.factsales f ON c.customerid = f.customerid
WHERE f.isreturn = 0
GROUP BY c.tier;

WITH rfm_raw AS (
    SELECT customerid, DATEDIFF(day, MAX(d.fulldate), GETDATE()) AS recency, COUNT(*) AS frequency, SUM(net) AS monetary
    FROM dbo.factsales f JOIN dbo.dimdate d ON f.datekey = d.datekey
    WHERE f.isreturn = 0
    GROUP BY customerid
)
SELECT customerid,
       NTILE(5) OVER (ORDER BY recency DESC) AS r_score,
       NTILE(5) OVER (ORDER BY frequency) AS f_score,
       NTILE(5) OVER (ORDER BY monetary) AS m_score,
       CONCAT(r_score, f_score, m_score) AS rfm_cell,
       CASE WHEN r_score >=4 AND f_score>=4 AND m_score>=4 THEN 'Champions'
            WHEN r_score <=2 AND f_score <=2 THEN 'At Risk'
            ELSE 'Other' END AS segment
FROM rfm_raw;

SELECT COUNT(DISTINCT customerid) AS churned_customers,
       100.0 * COUNT(DISTINCT customerid) / (SELECT COUNT(*) FROM dimcustomer) AS churn_rate_pct
FROM dbo.dimcustomer c
WHERE NOT EXISTS (SELECT 1 FROM dbo.factsales f JOIN dbo.dimdate d ON f.datekey = d.datekey
                  WHERE f.customerid = c.customerid AND f.isreturn = 0 AND d.fulldate >= DATEADD(day, -90, GETDATE()));

SELECT c.tier, f.channel, AVG(f.net) AS avg_order_value, COUNT(*) AS orders
FROM dbo.factsales f JOIN dbo.dimcustomer c ON f.customerid = c.customerid
WHERE f.isreturn = 0
GROUP BY c.tier, f.channel ORDER BY c.tier, avg_order_value DESC;

WITH customer_type AS (
    SELECT customerid, MIN(d.fulldate) AS first_date
    FROM dbo.factsales f JOIN dbo.dimdate d ON f.datekey = d.datekey
    WHERE f.isreturn = 0
    GROUP BY customerid
)
SELECT CASE WHEN d.fulldate = ct.first_date THEN 'New' ELSE 'Returning' END AS cust_type,
       SUM(f.net) AS revenue, COUNT(DISTINCT f.salesid) AS orders, AVG(f.net) AS avg_order_value
FROM dbo.factsales f JOIN dbo.dimdate d ON f.datekey = d.datekey JOIN customer_type ct ON f.customerid = ct.customerid
WHERE f.isreturn = 0
GROUP BY CASE WHEN d.fulldate = ct.first_date THEN 'New' ELSE 'Returning' END;

SELECT TOP 10 p.name, SUM(f.net) AS revenue, SUM(f.qty) AS units_sold
FROM dbo.factsales f JOIN dbo.dimproduct p ON f.productid = p.productid
WHERE f.isreturn = 0
GROUP BY p.name ORDER BY revenue DESC;

SELECT TOP 10 p.name, p.margin_pct, SUM(f.net) AS revenue
FROM dbo.factsales f JOIN dbo.dimproduct p ON f.productid = p.productid
WHERE f.isreturn = 0 AND p.isactive = 1
GROUP BY p.name, p.margin_pct ORDER BY p.margin_pct ASC;

SELECT p.category, SUM(f.net) AS revenue, 100.0 * SUM(f.net) / SUM(SUM(f.net)) OVER () AS revenue_pct
FROM dbo.factsales f JOIN dbo.dimproduct p ON f.productid = p.productid
WHERE f.isreturn = 0
GROUP BY p.category ORDER BY revenue DESC;

WITH pairs AS (
    SELECT f1.productid AS prod1, f2.productid AS prod2, COUNT(*) AS pair_count
    FROM dbo.factsales f1 JOIN dbo.factsales f2 ON f1.salesid = f2.salesid AND f1.productid < f2.productid
    WHERE f1.isreturn = 0 AND f2.isreturn = 0
    GROUP BY f1.productid, f2.productid
)
SELECT TOP 20 p1.name AS product_A, p2.name AS product_B, pp.pair_count,
       100.0 * pp.pair_count / (SELECT COUNT(DISTINCT salesid) FROM dbo.factsales WHERE isreturn=0) AS support_pct,
       100.0 * pp.pair_count / (SELECT COUNT(DISTINCT salesid) FROM dbo.factsales WHERE productid=pp.prod1 AND isreturn=0) AS confidence
FROM pairs pp
JOIN dbo.dimproduct p1 ON pp.prod1 = p1.productid
JOIN dbo.dimproduct p2 ON pp.prod2 = p2.productid
WHERE pp.pair_count > 10
ORDER BY confidence DESC;

SELECT p.category, CORR(f.qty, f.unitprice) AS price_elasticity_correlation
FROM dbo.factsales f JOIN dbo.dimproduct p ON f.productid = p.productid
WHERE f.isreturn = 0 AND f.qty>0 AND f.unitprice>0
GROUP BY p.category;

SELECT s.storename, s.city, s.type, SUM(f.net) AS revenue, SUM(f.net)/s.sizem2 AS revenue_per_m2,
       RANK() OVER (ORDER BY SUM(f.net)/s.sizem2 DESC) AS rank_per_m2
FROM dbo.factsales f JOIN dbo.dimstore s ON f.storeid = s.storeid
WHERE f.isreturn = 0
GROUP BY s.storeid, s.storename, s.city, s.type, s.sizem2
ORDER BY revenue_per_m2 DESC;

SELECT s.region, s.type, SUM(f.net) AS revenue, COUNT(DISTINCT f.salesid) AS transactions
FROM dbo.factsales f JOIN dbo.dimstore s ON f.storeid = s.storeid
WHERE f.isreturn = 0
GROUP BY s.region, s.type ORDER BY s.region, revenue DESC;

SELECT CASE WHEN s.distancetocitycenterkm < 2 THEN 'Core (<2km)'
            WHEN s.distancetocitycenterkm BETWEEN 2 AND 5 THEN 'Inner (2-5km)'
            WHEN s.distancetocitycenterkm BETWEEN 5 AND 10 THEN 'Outer (5-10km)'
            ELSE 'Suburban (>10km)' END AS distance_zone,
       AVG(f.net) AS avg_basket, SUM(f.net) AS revenue, COUNT(DISTINCT f.salesid) AS tx_count
FROM dbo.factsales f JOIN dbo.dimstore s ON f.storeid = s.storeid
WHERE f.isreturn = 0
GROUP BY CASE WHEN s.distancetocitycenterkm < 2 THEN 'Core (<2km)'
              WHEN s.distancetocitycenterkm BETWEEN 2 AND 5 THEN 'Inner (2-5km)'
              WHEN s.distancetocitycenterkm BETWEEN 5 AND 10 THEN 'Outer (5-10km)'
              ELSE 'Suburban (>10km)' END;

WITH promo_performance AS (
    SELECT productid, CASE WHEN promoid IS NOT NULL THEN 'Promo' ELSE 'No Promo' END AS promo_flag,
           AVG(qty) AS avg_qty, AVG(unitprice) AS avg_price, SUM(net) AS revenue
    FROM dbo.factsales WHERE isreturn = 0
    GROUP BY productid, CASE WHEN promoid IS NOT NULL THEN 'Promo' ELSE 'No Promo' END
)
SELECT p.name,
       MAX(CASE WHEN promo_flag='Promo' THEN avg_qty END) AS promo_qty,
       MAX(CASE WHEN promo_flag='No Promo' THEN avg_qty END) AS nonpromo_qty,
       (MAX(CASE WHEN promo_flag='Promo' THEN avg_qty END)/NULLIF(MAX(CASE WHEN promo_flag='No Promo' THEN avg_qty END),0)-1) AS qty_uplift_pct
FROM promo_performance pp JOIN dbo.dimproduct p ON pp.productid = p.productid
GROUP BY p.name
HAVING MAX(CASE WHEN promo_flag='Promo' THEN avg_qty END) IS NOT NULL
   AND MAX(CASE WHEN promo_flag='No Promo' THEN avg_qty END) IS NOT NULL
ORDER BY qty_uplift_pct DESC;

SELECT channel, COUNT(*) AS total_tx, SUM(CASE WHEN discountapplied=1 THEN 1 ELSE 0 END) AS disc_tx,
       100.0 * SUM(CASE WHEN discountapplied=1 THEN 1 ELSE 0 END)/COUNT(*) AS discount_rate_pct
FROM dbo.factsales WHERE isreturn = 0
GROUP BY channel ORDER BY discount_rate_pct DESC;

WITH store_daily AS (
    SELECT s.storeid, d.fulldate, SUM(f.net) AS daily_revenue,
           MAX(CASE WHEN f.promoid IS NOT NULL THEN 1 ELSE 0 END) AS had_promo
    FROM dbo.factsales f JOIN dbo.dimdate d ON f.datekey = d.datekey JOIN dbo.dimstore s ON f.storeid = s.storeid
    WHERE f.isreturn = 0
    GROUP BY s.storeid, d.fulldate
)
SELECT had_promo, AVG(daily_revenue) AS avg_daily_revenue FROM store_daily GROUP BY had_promo;

WITH weekly_stats AS (
    SELECT d.yearweek, SUM(f.net) AS weekly_sales,
           AVG(SUM(f.net)) OVER (ORDER BY d.yearweek ROWS BETWEEN 4 PRECEDING AND 4 FOLLOWING) AS ma_5weeks,
           STDEV(SUM(f.net)) OVER (ORDER BY d.yearweek ROWS BETWEEN 4 PRECEDING AND 4 FOLLOWING) AS sd_5weeks
    FROM dbo.factsales f JOIN dbo.dimdate d ON f.datekey = d.datekey
    WHERE f.isreturn = 0
    GROUP BY d.yearweek
)
SELECT yearweek, weekly_sales, ma_5weeks, sd_5weeks,
       CASE WHEN weekly_sales > ma_5weeks + 3*sd_5weeks THEN 'High Anomaly'
            WHEN weekly_sales < ma_5weeks - 3*sd_5weeks THEN 'Low Anomaly'
            ELSE 'Normal' END AS anomaly_flag
FROM weekly_stats ORDER BY yearweek;

SELECT p.category, COUNT(*) AS total_sold, SUM(CASE WHEN f.isreturn=1 THEN 1 ELSE 0 END) AS returned,
       100.0 * SUM(CASE WHEN f.isreturn=1 THEN 1 ELSE 0 END)/COUNT(*) AS return_rate_pct,
       AVG(CASE WHEN f.isreturn=1 THEN f.deliverydays ELSE NULL END) AS avg_delivery_days_returns
FROM dbo.factsales f JOIN dbo.dimproduct p ON f.productid = p.productid
GROUP BY p.category ORDER BY return_rate_pct DESC;

SELECT 'fact_sales' AS tbl, COUNT(*) AS orphan
FROM dbo.factsales f LEFT JOIN dbo.dimdate d ON f.datekey = d.datekey WHERE d.datekey IS NULL
UNION ALL
SELECT 'fact_sales', COUNT(*)
FROM dbo.factsales f LEFT JOIN dbo.dimproduct p ON f.productid = p.productid WHERE p.productid IS NULL
UNION ALL
SELECT 'fact_sales', COUNT(*)
FROM dbo.factsales f LEFT JOIN dbo.dimcustomer c ON f.customerid = c.customerid WHERE c.customerid IS NULL
UNION ALL
SELECT 'fact_sales', COUNT(*)
FROM dbo.factsales f LEFT JOIN dbo.dimstore s ON f.storeid = s.storeid WHERE s.storeid IS NULL
UNION ALL
SELECT 'fact_sales', COUNT(*)
FROM dbo.factsales f LEFT JOIN dbo.dimpromotion p ON f.promoid = p.promoid WHERE f.promoid IS NOT NULL AND p.promoid IS NULL;

Total Revenue = SUMX(FILTER(factsales, factsales[isreturn]=0), factsales[net])
Total COGS = SUMX(FILTER(factsales, factsales[isreturn]=0), factsales[qty] * RELATED(dimproduct[unitcost]))
Gross Profit = [Total Revenue] - [Total COGS]
Gross Margin % = DIVIDE([Gross Profit], [Total Revenue], 0)
Average Basket Value = DIVIDE([Total Revenue], DISTINCTCOUNT(FILTER(factsales, factsales[isreturn]=0), factsales[salesid]))
Return Rate = DIVIDE(COUNTROWS(FILTER(factsales, factsales[isreturn]=1)), COUNTROWS(factsales), 0)
Discount Penetration = DIVIDE(COUNTROWS(FILTER(factsales, factsales[discountapplied]=1 && factsales[isreturn]=0)), COUNTROWS(FILTER(factsales, factsales[isreturn]=0)), 0)
Running Revenue = CALCULATE([Total Revenue], FILTER(ALL(dimdate), dimdate[fulldate] <= MAX(dimdate[fulldate])))
YoY Revenue = VAR Curr = [Total Revenue] VAR Prev = CALCULATE([Total Revenue], SAMEPERIODLASTYEAR(dimdate[fulldate])) RETURN DIVIDE(Curr - Prev, Prev, 0)
MoM Revenue = VAR Curr = [Total Revenue] VAR Prev = CALCULATE([Total Revenue], DATEADD(dimdate[fulldate], -1, MONTH)) RETURN DIVIDE(Curr - Prev, Prev, 0)
7D Moving Avg = CALCULATE(AVERAGEX(DATESINPERIOD(dimdate[fulldate], LASTDATE(dimdate[fulldate]), -7, DAY), [Total Revenue]), ALL(dimdate))
30D Moving Avg = CALCULATE(AVERAGEX(DATESINPERIOD(dimdate[fulldate], LASTDATE(dimdate[fulldate]), -30, DAY), [Total Revenue]), ALL(dimdate))
YTD Revenue = TOTALYTD([Total Revenue], dimdate[fulldate])
MTD Revenue = TOTALMTD([Total Revenue], dimdate[fulldate])
Revenue SPLY = CALCULATE([Total Revenue], SAMEPERIODLASTYEAR(dimdate[fulldate]))
YTD vs PYTD = [YTD Revenue] - CALCULATE([Total Revenue], DATESYTD(SAMEPERIODLASTYEAR(dimdate[fulldate])))
Rolling 12M Revenue = CALCULATE([Total Revenue], DATESINPERIOD(dimdate[fulldate], LASTDATE(dimdate[fulldate]), -12, MONTH))
Weekday Index = DIVIDE(AVERAGEX(VALUES(dimdate[weekdayname]), CALCULATE([Total Revenue], ALL(dimdate))), [Total Revenue], 0) * 100
RFM Score = VAR R = RANKX(ALL(dimcustomer), CALCULATE(MAX(factsales[datekey])), , DESC, Dense) VAR F = RANKX(ALL(dimcustomer), COUNTROWS(factsales), , DESC, Dense) VAR M = RANKX(ALL(dimcustomer), [Total Revenue], , DESC, Dense) RETURN R & F & M
Customer Segment = VAR Rec = RANKX(ALL(dimcustomer), CALCULATE(MAX(factsales[datekey])), , DESC, Dense) VAR Freq = RANKX(ALL(dimcustomer), COUNTROWS(factsales), , DESC, Dense) VAR Mon = RANKX(ALL(dimcustomer), [Total Revenue], , DESC, Dense) RETURN SWITCH(TRUE(), Rec<=2 && Freq<=2 && Mon<=2, "Champions", Rec<=3 && Freq<=3, "Loyal", Rec>=4 && Freq>=4, "At Risk", "Other")
CLV = DIVIDE([Total Revenue], DISTINCTCOUNT(dimcustomer[customerid]))
New Customer Revenue = VAR CurrentCust = VALUES(dimcustomer[customerid]) VAR NewCust = FILTER(CurrentCust, CALCULATE(MIN(factsales[datekey])) = MAX(dimdate[fulldate])) RETURN CALCULATE([Total Revenue], NewCust)
Repeat Customer Revenue = [Total Revenue] - [New Customer Revenue]
Repeat Purchase Rate = VAR Returning = COUNTROWS(FILTER(VALUES(dimcustomer[customerid]), CALCULATE(COUNTROWS(factsales)) > 1)) VAR AllCust = DISTINCTCOUNT(dimcustomer[customerid]) RETURN DIVIDE(Returning, AllCust, 0)
Avg Frequency = DIVIDE(COUNTROWS(factsales), DISTINCTCOUNT(dimcustomer[customerid]), 0)
Churn Rate = VAR Active = CALCULATETABLE(VALUES(dimcustomer[customerid]), DATESINPERIOD(dimdate[fulldate], LASTDATE(dimdate[fulldate]), -90, DAY)) VAR AllCust = VALUES(dimcustomer[customerid]) VAR Churned = COUNTROWS(EXCEPT(AllCust, Active)) RETURN DIVIDE(Churned, COUNTROWS(AllCust), 0)
Top10 Products = TOPN(10, ALL(dimproduct[name]), [Total Revenue])
Category Contribution = DIVIDE(SUMX(FILTER(factsales, RELATED(dimproduct[category]) = SELECTEDVALUE(dimproduct[category])), factsales[net]), [Total Revenue], 0)
Avg Price by Category = AVERAGEX(VALUES(dimproduct[category]), CALCULATE(AVERAGE(factsales[unitprice])))
Product Margin $ = SUMX(factsales, factsales[net] - factsales[qty] * RELATED(dimproduct[unitcost]))
Product Margin % = DIVIDE([Product Margin $], [Total Revenue], 0)
Sales Velocity = DIVIDE(SUM(factsales[qty]), DATEDIFF(MIN(dimdate[fulldate]), MAX(dimdate[fulldate]), DAY), 0)
Revenue per m2 = DIVIDE([Total Revenue], SUM(dimstore[sizem2]), 0)
High Rating Sales = CALCULATE([Total Revenue], dimstore[storerating] > 4)
City Avg Basket = AVERAGEX(VALUES(dimstore[city]), CALCULATE([Average Basket Value], ALL(dimstore)))
Promo Uplift = VAR Promo = CALCULATE([Total Revenue], factsales[promoid] > 0) VAR NonPromo = CALCULATE([Total Revenue], factsales[promoid] = 0) RETURN DIVIDE(Promo - NonPromo, NonPromo, 0)
Avg Discount % = AVERAGEX(FILTER(factsales, factsales[discountapplied] = 1), factsales[discountamount] / factsales[grossvalue])
Price-Qty Correlation = VAR Products = VALUES(dimproduct[productid]) VAR Covar = SUMX(Products, (AVERAGEX(RELATEDTABLE(factsales), factsales[unitprice]) - AVERAGE(factsales[unitprice])) * (AVERAGEX(RELATEDTABLE(factsales), factsales[qty]) - AVERAGE(factsales[qty]))) VAR StdPrice = STDEVX.P(Products, AVERAGEX(RELATEDTABLE(factsales), factsales[unitprice])) VAR StdQty = STDEVX.P(Products, AVERAGEX(RELATEDTABLE(factsales), factsales[qty])) RETURN DIVIDE(Covar, StdPrice * StdQty, 0)

import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
from datetime import datetime
import os
from scipy import stats
from sklearn.cluster import KMeans
from sklearn.preprocessing import StandardScaler
from itertools import combinations
from collections import Counter

OUTPUT_DIR = "c:/data"
print("Loading CSV files...")
fact = pd.read_csv(os.path.join(OUTPUT_DIR, "fact_sales.csv"))
date = pd.read_csv(os.path.join(OUTPUT_DIR, "dim_date.csv"))
prod = pd.read_csv(os.path.join(OUTPUT_DIR, "dim_product.csv"))
cust = pd.read_csv(os.path.join(OUTPUT_DIR, "dim_customer.csv"))
store = pd.read_csv(os.path.join(OUTPUT_DIR, "dim_store.csv"))
promo = pd.read_csv(os.path.join(OUTPUT_DIR, "dim_promotion.csv"))

merged = fact.merge(date, on='datekey').merge(prod, on='productid').merge(cust, on='customerid').merge(store, on='storeid')
merged['fulldate'] = pd.to_datetime(merged['fulldate'])

print("="*60)
print("BASIC STATISTICS")
print(f"Total sales (excl returns): ${merged[merged['isreturn']==0]['net'].sum():,.2f}")
print(f"Total returns amount: ${merged[merged['isreturn']==1]['net'].abs().sum():,.2f}")
print(f"Average basket (non-return): ${merged[merged['isreturn']==0]['net'].mean():,.2f}")
print(f"Return rate: {merged['isreturn'].mean():.2%}")
print(f"Discount penetration: {merged['discountapplied'].mean():.2%}")

daily_sales = merged.groupby('fulldate')['grossvalue'].sum().reset_index().sort_values('fulldate')
daily_sales['7d_ma'] = daily_sales['grossvalue'].rolling(7).mean()
daily_sales['30d_ma'] = daily_sales['grossvalue'].rolling(30).mean()
daily_sales['zscore'] = np.abs(stats.zscore(daily_sales['grossvalue']))
daily_sales['is_outlier'] = daily_sales['zscore'] > 3

monthly = merged.groupby([merged['fulldate'].dt.year, merged['fulldate'].dt.month])['net'].sum().reset_index()
monthly.columns = ['year', 'month', 'revenue']
monthly['prev_year_revenue'] = monthly.groupby('month')['revenue'].shift(1)
monthly['yoy_growth'] = (monthly['revenue'] - monthly['prev_year_revenue']) / monthly['prev_year_revenue']

latest_date = merged['fulldate'].max()
rfm = merged[merged['isreturn']==0].groupby('customerid').agg({
    'fulldate': lambda x: (latest_date - x.max()).days,
    'salesid': 'count',
    'net': 'sum'
}).reset_index()
rfm.columns = ['customerid', 'recency', 'frequency', 'monetary']
rfm['r_score'] = pd.qcut(rfm['recency'], 4, labels=[4,3,2,1])
rfm['f_score'] = pd.qcut(rfm['frequency'].rank(method='first'), 4, labels=[1,2,3,4])
rfm['m_score'] = pd.qcut(rfm['monetary'], 4, labels=[1,2,3,4])
rfm['rfm_score'] = rfm['r_score'].astype(str) + rfm['f_score'].astype(str) + rfm['m_score'].astype(str)

scaler = StandardScaler()
rfm_scaled = scaler.fit_transform(np.log1p(rfm[['recency', 'frequency', 'monetary']]))
kmeans = KMeans(n_clusters=5, random_state=42, n_init=10)
rfm['cluster'] = kmeans.fit_predict(rfm_scaled)

sample_trans = merged[merged['isreturn']==0].groupby('salesid')['productid'].agg(list).sample(100000, random_state=42)
pair_counts = Counter()
for basket in sample_trans:
    if len(basket) > 1:
        for pair in combinations(sorted(basket), 2):
            pair_counts[pair] += 1
top_pairs = pd.DataFrame(pair_counts.most_common(20), columns=['pair', 'count'])
top_pairs[['prod1', 'prod2']] = pd.DataFrame(top_pairs['pair'].tolist(), index=top_pairs.index)
top_pairs = top_pairs.merge(prod[['productid', 'name']], left_on='prod1', right_on='productid')
top_pairs = top_pairs.merge(prod[['productid', 'name']], left_on='prod2', right_on='productid', suffixes=('_A', '_B'))

merged['has_promo'] = merged['promoid'] > 0
daily_promo = merged.groupby(['fulldate', 'has_promo'])['net'].sum().reset_index()
promo_days = daily_promo[daily_promo['has_promo']==True].set_index('fulldate')['net']
nonpromo_days = daily_promo[daily_promo['has_promo']==False].set_index('fulldate')['net']
common = promo_days.index.intersection(nonpromo_days.index)
avg_promo = promo_days[common].mean()
avg_nonpromo = nonpromo_days[common].mean()
uplift = (avg_promo - avg_nonpromo) / avg_nonpromo

elasticity = merged[merged['isreturn']==0].groupby('category').apply(
    lambda x: np.polyfit(np.log(x['unitprice']), np.log(x['qty']), 1)[0]
).reset_index(name='price_elasticity')

plt.style.use('ggplot')
fig, axes = plt.subplots(3, 3, figsize=(18, 16))
axes = axes.flatten()
axes[0].plot(daily_sales['fulldate'], daily_sales['grossvalue'], alpha=0.3, label='Daily')
axes[0].plot(daily_sales['fulldate'], daily_sales['7d_ma'], label='7-day MA')
axes[0].plot(daily_sales['fulldate'], daily_sales['30d_ma'], label='30-day MA')
axes[0].scatter(daily_sales[daily_sales['is_outlier']]['fulldate'], daily_sales[daily_sales['is_outlier']]['grossvalue'], color='red', label='Outliers')
axes[0].set_title('Daily Sales with Moving Averages')
axes[0].legend()
axes[1].bar(monthly['month'].astype(str) + '-' + monthly['year'].astype(str), monthly['yoy_growth'], color='teal')
axes[1].set_title('YoY Monthly Growth')
axes[1].tick_params(axis='x', rotation=45)
cat_sales = merged[merged['isreturn']==0].groupby('category')['net'].sum()
axes[2].pie(cat_sales, labels=cat_sales.index, autopct='%1.1f%%', startangle=90)
axes[2].set_title('Revenue by Category')
rfm_melt = rfm.melt(id_vars=['cluster'], value_vars=['recency', 'frequency', 'monetary'], var_name='metric', value_name='value')
sns.boxplot(x='cluster', y='value', hue='metric', data=rfm_melt, ax=axes[3])
axes[3].set_title('RFM Metrics by K-Means Cluster')
axes[3].set_yscale('log')
return_by_channel = merged.groupby('channel')['isreturn'].mean().reset_index()
sns.barplot(x='channel', y='isreturn', data=return_by_channel, ax=axes[4], palette='Reds')
axes[4].set_title('Return Rate by Channel')
merged['promo_flag'] = merged['has_promo'].map({True: 'With Promo', False: 'No Promo'})
sns.boxplot(x='promo_flag', y='net', data=merged[merged['isreturn']==0].sample(10000), ax=axes[5])
axes[5].set_title('Transaction Value: Promo vs No Promo')
axes[5].set_yscale('log')
sample_cust = merged[merged['isreturn']==0].sample(50000)
sns.scatterplot(x='age', y='net', hue='tier', data=sample_cust, alpha=0.5, ax=axes[6])
axes[6].set_title('Age vs Transaction Value (by Tier)')
axes[6].set_yscale('log')
store_perf = merged[merged['isreturn']==0].groupby('storeid').agg({'net': 'sum', 'storerating': 'first', 'sizem2': 'first'}).reset_index()
store_perf['rev_per_m2'] = store_perf['net'] / store_perf['sizem2']
sns.regplot(x='storerating', y='rev_per_m2', data=store_perf, ax=axes[7], scatter_kws={'alpha':0.5})
axes[7].set_title('Store Rating vs Revenue per m²')
sns.barplot(x='category', y='price_elasticity', data=elasticity, ax=axes[8], palette='coolwarm')
axes[8].axhline(y=-1, linestyle='--', color='red', label='Unit elastic')
axes[8].set_title('Price Elasticity by Category')
axes[8].legend()
plt.tight_layout()
plt.savefig(os.path.join(OUTPUT_DIR, 'extended_analysis.png'), dpi=150)
print(f"Plot saved to {OUTPUT_DIR}/extended_analysis.png")

monthly_summary = merged[merged['isreturn']==0].groupby([merged['fulldate'].dt.year, merged['fulldate'].dt.month]).agg({
    'net': 'sum', 'salesid': 'count', 'qty': 'sum', 'discountapplied': 'mean', 'isreturn': 'mean'
}).reset_index()
monthly_summary.columns = ['year', 'month', 'total_revenue', 'transaction_count', 'units_sold', 'discount_penetration', 'return_rate']
monthly_summary.to_csv(os.path.join(OUTPUT_DIR, 'monthly_summary.csv'), index=False)
rfm.to_csv(os.path.join(OUTPUT_DIR, 'rfm_scores.csv'), index=False)
top_pairs[['name_A', 'name_B', 'count']].head(20).to_csv(os.path.join(OUTPUT_DIR, 'top_product_pairs.csv'), index=False)
print("Analysis complete. Exported: monthly_summary.csv, rfm_scores.csv, top_product_pairs.csv")

**End of Documentation – Project Summary**

We have built a complete retail analytics pipeline based on the Medallion Architecture (Bronze → Silver → Gold). The work includes:

- **Python data generator** (`generator.py`) – produces 5 million realistic sales transactions with a soft‑landing trend, correct `deliverydays` for in‑store sales, discontinued products correctly flagged, and `NULL` for no promotion. The generator deletes old CSV files before writing to ensure fresh data.

- **SQL Server loader** (`01_create_database.sql`) – creates the `retailanalytics` database, loads all dimensions and the fact table, enforces foreign keys, adds a clustered columnstore index, and forces `deliverydays = 0` for `In-Store` transactions even if the CSV contains wrong values.

- **Model validation** (`02_model_validation.sql`) – confirms the star schema, foreign keys, columnstore index, and referential integrity.

- **Data quality checks** (`03_data_quality_checks.sql`) – runs over 30 tests (nulls, ranges, financial equations, return logic, etc.) – all pass.

- **Analytical views** (`04_analytical_views.sql`) – creates 10 gold views answering key business questions (product margin, promotion uplift, customer RFM, returns, channel performance, seasonality, store performance, Pareto, delivery impact, warranty/eco impact).

- **DAX measures** – provided for Power BI (basic and extended).

- **Python verification script** – loads all CSVs, performs statistical checks, and exports visualisations.

All tests passed, and the data is clean and ready for analytics. The project demonstrates a production‑ready retail data pipeline.

**Generated on 2025-05-19.**