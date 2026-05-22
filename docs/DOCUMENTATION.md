Retail Analytics – Complete Documentation (Final)

Project Overview – The database models a multi-channel retail chain (Online, In-Store, Mobile App, Phone Order) with 10 million sales transactions generated from 2023-01-01 to the current date (dynamic). The data generator produces a realistic trend: first half of the timeline: slight decline from 60k to 50k (moderate drop); middle section: stagnation (flat); last 30% of time: strong rise from 50k to 95k (final growth).

All percentages are stored as fractions (e.g., 0.15 = 15%). Promotions: promoid = 0 means "No Promotion" (a dedicated row exists in dimpromotion). Returns: returnreason = 'No return' for non-return transactions (never NULL). Delivery: deliverydays = 0 for all In-Store transactions. Hour: column hour (0-23) is always populated, never NULL. The schema follows a star design with five dimensions and one fact table.

Table Definitions

dim_date
| Column | Type | Description |
|--------|------|-------------|
| datekey | INT | YYYYMMDD surrogate key (PK) |
| fulldate | DATE | calendar date |
| year | SMALLINT | year |
| quarternumber | TINYINT | 1-4 |
| quartername | NCHAR(2) | Q1-Q4 |
| monthnumber | TINYINT | 1-12 |
| monthname | NVARCHAR(20) | January … |
| weekdaynumber | TINYINT | 1=Monday .. 7=Sunday |
| weekdayname | NVARCHAR(20) | Monday … |
| isweekend | TINYINT | 1 if weekend |
| yearmonth | NCHAR(7) | YYYY-MM |
| yearmonthnumber | INT | YYYYMM |
| yearquarter | NVARCHAR(7) | YYYY-QX |
| yearquarternumber | INT | YYYY*10+Q |
| yearweek | NVARCHAR(8) | YYYY-Www |
| yearweeknumber | INT | YYYY*100+week |
| isholiday | TINYINT | 1 if Dec/Jan/July |

dim_customer
| Column | Type | Description |
|--------|------|-------------|
| customerid | INT | PK |
| fullname | NVARCHAR(100) | first + last (suffix if duplicate) |
| email | NVARCHAR(100) | unique |
| age | TINYINT | 18-75 |
| gender | NVARCHAR(20) | Male / Female / Non-binary |
| city | NVARCHAR(50) | residence city |
| tier | NVARCHAR(20) | Bronze / Silver / Gold / Platinum |
| points | INT | loyalty points |
| isactive | TINYINT | 1 = active |
| lang | NVARCHAR(10) | en, de, fr, es, pl, it |
| totalspend | DECIMAL(18,2) | lifetime spend (USD) |
| regdate | DATE | registration date |
| annualincome | DECIMAL(18,2) | USD |
| incomebracket | NVARCHAR(20) | Low / Medium / High / Very High / Ultra High |
| education | NVARCHAR(50) | High School / Bachelor / Master / PhD |
| maritalstatus | NVARCHAR(20) | Single / Married / Divorced / Widowed |
| childrencount | TINYINT | number of children |
| loyaltysegment | NVARCHAR(20) | same as tier |
| satisfactionscore | DECIMAL(5,1) | 1.0-5.0 |
| dayssincelastpurchase | INT | days since last transaction |
| hassubscription | TINYINT | newsletter subscription |
| preferredcontact | NVARCHAR(20) | Email / SMS / Phone / Mail |
| spendmultiplier | DECIMAL(10,3) | spending behaviour factor |

dim_product
| Column | Type | Description |
|--------|------|-------------|
| productid | INT | PK |
| name | NVARCHAR(150) | brand + adjective + noun + variant |
| category | NVARCHAR(50) | Electronics / Home / Sports / Kids / Garden |
| brand | NVARCHAR(50) | brand name |
| unitcost | DECIMAL(18,2) | cost price (USD) |
| unitprice | DECIMAL(18,2) | base selling price (before market multiplier) |
| margin_pct | DECIMAL(5,4) | (price-cost)/price |
| weight | DECIMAL(10,2) | kg |
| color | NVARCHAR(20) | Red / Blue / Green / Black / White / Gray / Silver / Gold |
| material | NVARCHAR(50) | Plastic / Metal / Wood / Glass / Fabric |
| supplierid | INT | 1-50 |
| isactive | TINYINT | 1 = still sold |
| minstock | INT | reorder level |
| tax_rate | DECIMAL(5,4) | 0.10 or 0.21 |
| haswarranty | TINYINT | 1 = warranty offered |
| ecofriendly | TINYINT | 1 = ecoscore > 100 |
| seasonalityfactor | DECIMAL(5,2) | demand multiplier (0.7-1.3) |
| warrantymonths | TINYINT | 0,12,24,36 |
| ecoscore | TINYINT | 20-200 |
| releaseyear | SMALLINT | 2018-2025 |
| skucount | INT | number of variants |
| isdiscontinued | TINYINT | 1 = discontinued |
| productrating | DECIMAL(3,1) | 1.0-5.0 |
| stockstatus | NVARCHAR(20) | In Stock / Low Stock / Out of Stock |

dim_store
| Column | Type | Description |
|--------|------|-------------|
| storeid | INT | PK |
| storename | NVARCHAR(150) | chain + city + suffix (unique) |
| city | NVARCHAR(50) | location city |
| type | NVARCHAR(50) | Supermarket / Hypermarket / Convenience / Department |
| staff | SMALLINT | number of employees |
| sizem2 | INT | square meters |
| hascafe | TINYINT | 1 = café present |
| openingyear | SMALLINT | year opened |
| region | NVARCHAR(50) | North / South / East / West / Central |
| renovationyear | SMALLINT | last renovation (0 = never) |
| parkingspots | SMALLINT | parking spaces |
| storerating | DECIMAL(3,1) | 2.0-5.0 |
| hasdeliveryservice | TINYINT | 1 = delivery available |
| floornumber | TINYINT | 1-5 |
| distancetocitycenterkm | DECIMAL(8,1) | km |
| annualrentcost | DECIMAL(18,2) | USD |
| storesizemultiplier | DECIMAL(10,3) | relative size (0.3-4.0) |

dim_promotion
| Column | Type | Description |
|--------|------|-------------|
| promoid | INT | PK (0 = "No Promotion", 1..100 = real promotions) |
| promoname | NVARCHAR(150) | unique name |
| discount_pct | DECIMAL(5,3) | percentage discount (fraction) |
| discount_fixed | DECIMAL(10,2) | fixed USD discount |
| type | NVARCHAR(50) | Percentage / Fixed Amount / BOGO / Free Shipping |
| isactive | TINYINT | 1 = currently active |
| minspend | INT | USD threshold |
| channel | NVARCHAR(50) | Email / SMS / App / InStore / All / Online |
| budget | DECIMAL(18,2) | USD |
| startdate | DATE | start date |
| enddate | DATE | end date |
| targetaudience | NVARCHAR(50) | All / New / Loyal / HighSpend |
| maxdiscountcap | DECIMAL(18,2) | max discount USD |
| isstackable | TINYINT | 1 = can combine |
| redemption_rate | DECIMAL(5,3) | target redemption rate (0.02-0.35) |
| coderequired | TINYINT | 1 = promo code needed |
| promoupliftfactor | DECIMAL(6,3) | sales multiplier (1.0-2.2) |

factsales
| Column | Type | Description |
|--------|------|-------------|
| salesid | BIGINT | PK |
| datekey | INT | FK to dim_date |
| productid | INT | FK to dim_product |
| customerid | INT | FK to dim_customer |
| storeid | INT | FK to dim_store |
| promoid | INT | FK to dim_promotion (0 = no promotion) |
| qty | TINYINT | 1-10 |
| unitprice | DECIMAL(18,2) | actual selling price |
| tax_rate | DECIMAL(5,4) | 0.10 or 0.21 |
| net | DECIMAL(18,2) | gross – discount + tax |
| payment | NVARCHAR(20) | Card / Cash / Bank Transfer / Digital Wallet / PayPal |
| channel | NVARCHAR(20) | Online / In-Store / Mobile App / Phone Order |
| grossvalue | DECIMAL(18,2) | qty × unitprice |
| discountamount | DECIMAL(18,2) | total discount applied |
| taxamount | DECIMAL(18,2) | tax paid |
| shipcost | DECIMAL(18,2) | shipping cost (0 for in-store) |
| isreturn | TINYINT | 1 = return transaction |
| shipweight | DECIMAL(10,2) | kg (qty × product weight) |
| discountapplied | TINYINT | 1 = any discount used |
| returnreason | NVARCHAR(50) | 'No return' if isreturn=0; specific reason otherwise |
| deliverydays | TINYINT | 0 for in-store, 1-10 for online/mobile/phone |
| hour | TINYINT | hour of transaction (0-23), never NULL |

Selected SQL Queries (examples)

Total revenue (excl. returns):
SELECT SUM(net) FROM dbo.factsales WHERE isreturn = 0;

Total COGS:
SELECT SUM(f.qty * p.unitcost) FROM dbo.factsales f JOIN dbo.dimproduct p ON f.productid = p.productid WHERE f.isreturn = 0;

Gross profit:
SELECT SUM(f.net - f.qty * p.unitcost) FROM dbo.factsales f JOIN dbo.dimproduct p ON f.productid = p.productid WHERE f.isreturn = 0;

Gross margin percentage:
SELECT (SUM(f.net - f.qty * p.unitcost) / NULLIF(SUM(f.net), 0)) FROM dbo.factsales f JOIN dbo.dimproduct p ON f.productid = p.productid WHERE f.isreturn = 0;

Return rate:
SELECT 1.0 * SUM(CASE WHEN isreturn = 1 THEN 1 ELSE 0 END) / COUNT(*) FROM dbo.factsales;

Discount penetration:
SELECT 1.0 * SUM(CASE WHEN discountapplied = 1 THEN 1 ELSE 0 END) / COUNT(*) FROM dbo.factsales WHERE isreturn = 0;

Orphan checks (all foreign keys must be valid):
SELECT 'fact_sales' AS tbl, COUNT(*) FROM dbo.factsales f LEFT JOIN dbo.dimdate d ON f.datekey = d.datekey WHERE d.datekey IS NULL
UNION ALL
SELECT 'fact_sales', COUNT(*) FROM dbo.factsales f LEFT JOIN dbo.dimproduct p ON f.productid = p.productid WHERE p.productid IS NULL
UNION ALL
SELECT 'fact_sales', COUNT(*) FROM dbo.factsales f LEFT JOIN dbo.dimcustomer c ON f.customerid = c.customerid WHERE c.customerid IS NULL
UNION ALL
SELECT 'fact_sales', COUNT(*) FROM dbo.factsales f LEFT JOIN dbo.dimstore s ON f.storeid = s.storeid WHERE s.storeid IS NULL
UNION ALL
SELECT 'fact_sales', COUNT(*) FROM dbo.factsales f LEFT JOIN dbo.dimpromotion p ON f.promoid = p.promoid WHERE p.promoid IS NULL;

Selected DAX Measures (Power BI)

Total Revenue = SUMX(FILTER(factsales, factsales[isreturn]=0), factsales[net])

Total COGS = SUMX(FILTER(factsales, factsales[isreturn]=0), factsales[qty] * RELATED(dimproduct[unitcost]))

Gross Profit = [Total Revenue] - [Total COGS]

Gross Margin % = DIVIDE([Gross Profit], [Total Revenue], 0)

Average Basket Value = DIVIDE([Total Revenue], DISTINCTCOUNT(FILTER(factsales, factsales[isreturn]=0), factsales[salesid]))

Return Rate = DIVIDE(COUNTROWS(FILTER(factsales, factsales[isreturn]=1)), COUNTROWS(factsales), 0)

Discount Penetration = DIVIDE(COUNTROWS(FILTER(factsales, factsales[discountapplied]=1 && factsales[isreturn]=0)), COUNTROWS(FILTER(factsales, factsales[isreturn]=0)), 0)

YTD Revenue = TOTALYTD([Total Revenue], dimdate[fulldate])

YoY Revenue = VAR Curr = [Total Revenue] VAR Prev = CALCULATE([Total Revenue], SAMEPERIODLASTYEAR(dimdate[fulldate])) RETURN DIVIDE(Curr - Prev, Prev, 0)

Promo Uplift = VAR Promo = CALCULATE([Total Revenue], factsales[promoid] > 0) VAR NonPromo = CALCULATE([Total Revenue], factsales[promoid] = 0) RETURN DIVIDE(Promo - NonPromo, NonPromo, 0)

Selected Python Analysis

import pandas as pd
import numpy as np
from sklearn.cluster import KMeans
from sklearn.preprocessing import StandardScaler

OUTPUT_DIR = "c:/data"
fact = pd.read_csv(os.path.join(OUTPUT_DIR, "fact_sales.csv"))
merged = fact.merge(pd.read_csv(os.path.join(OUTPUT_DIR, "dim_date.csv")), on='datekey')
daily_sales = merged.groupby('fulldate')['grossvalue'].sum().reset_index()
daily_sales['7d_ma'] = daily_sales['grossvalue'].rolling(7).mean()
daily_sales['30d_ma'] = daily_sales['grossvalue'].rolling(30).mean()

rfm = merged[merged['isreturn']==0].groupby('customerid').agg({
    'fulldate': lambda x: (merged['fulldate'].max() - x.max()).days,
    'salesid': 'count',
    'net': 'sum'
}).reset_index()
rfm.columns = ['customerid', 'recency', 'frequency', 'monetary']
scaler = StandardScaler()
rfm_scaled = scaler.fit_transform(rfm[['recency', 'frequency', 'monetary']])
kmeans = KMeans(n_clusters=5, random_state=42)
rfm['segment'] = kmeans.fit_predict(rfm_scaled)

License
MIT – free to use, modify, and distribute.