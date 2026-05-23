
---

### `docs/DOCUMENTATION.md` (podfolder `docs`)

```markdown
# Retail Analytics – Complete Documentation (Final)

## Project Overview
The database models a multi‑channel retail chain (Online, In‑Store, Mobile App, Phone Order) with 10 million sales transactions generated from 2023‑01‑01 to the current date (dynamic). The data generator produces a realistic trend: first half of the timeline – slight decline from 60k to 50k (moderate drop); middle section – stagnation (flat); last 30 % of time – strong rise from 50k to 95k (final growth).

All percentage‑related columns (`margin_pct` in `dim_product`, `discount_pct` in `dim_promotion`) are stored as **decimal fractions** (e.g. `0.1196` = 11.96 %). In Power BI a standard “Percentage” format will display the correct value. Other rate columns (`tax_rate`, `redemption_rate`, `seasonalityfactor`) are also decimal fractions (e.g. `0.21` = 21 %).

Product margin follows a realistic distribution:
- 5 % of products have a margin of exactly 30 %,
- 5 % have a margin between 29 % and 20 %,
- 5 % have a margin of exactly 15 %,
- 50 % have a margin between 10 % and 5 %,
- 30 % have a margin between 5 % and 0 %,
- 5 % have a negative margin between 0 % and –10 %.
Negative margins are allowed and do **not** cause validation errors.

Promotions: `promoid = 0` means “No Promotion” (a dedicated row exists in `dimpromotion`).  
Returns: `returnreason = 'No return'` for non‑return transactions (never NULL).  
Delivery: `deliverydays = 0` for all In‑Store transactions.  
Hour: column `hour` (0‑23) is always populated, never NULL.  
The schema follows a star design with five dimensions and one fact table.

---

## Table Definitions

### dim_date
| Column | Type | Description |
|--------|------|-------------|
| datekey | INT | YYYYMMDD surrogate key (PK) |
| fulldate | DATE | calendar date |
| year | SMALLINT | year |
| quarternumber | TINYINT | 1‑4 |
| quartername | NCHAR(2) | Q1‑Q4 |
| monthnumber | TINYINT | 1‑12 |
| monthname | NVARCHAR(20) | January … |
| weekdaynumber | TINYINT | 1=Monday .. 7=Sunday |
| weekdayname | NVARCHAR(20) | Monday … |
| isweekend | TINYINT | 1 if weekend |
| yearmonth | NCHAR(7) | YYYY‑MM |
| yearmonthnumber | INT | YYYYMM |
| yearquarter | NVARCHAR(7) | YYYY‑QX |
| yearquarternumber | INT | YYYY*10+Q |
| yearweek | NVARCHAR(8) | YYYY‑Www |
| yearweeknumber | INT | YYYY*100+week |
| isholiday | TINYINT | 1 if Dec/Jan/July |

### dim_customer
| Column | Type | Description |
|--------|------|-------------|
| customerid | INT | PK |
| fullname | NVARCHAR(100) | first + last (suffix if duplicate) |
| email | NVARCHAR(100) | unique |
| age | TINYINT | 18‑75 |
| gender | NVARCHAR(20) | Male / Female (only two genders) |
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
| satisfactionscore | DECIMAL(5,1) | 1.0‑5.0 |
| dayssincelastpurchase | INT | days since last transaction |
| hassubscription | TINYINT | newsletter subscription |
| preferredcontact | NVARCHAR(20) | Email / SMS / Phone / Mail |
| spendmultiplier | DECIMAL(10,3) | spending behaviour factor |

### dim_product
| Column | Type | Description |
|--------|------|-------------|
| productid | INT | PK |
| name | NVARCHAR(150) | brand + adjective + noun + variant |
| category | NVARCHAR(50) | Electronics / Home / Sports / Kids / Garden |
| brand | NVARCHAR(50) | brand name |
| unitcost | DECIMAL(18,2) | cost price (USD) |
| unitprice | DECIMAL(18,2) | base selling price (before market multiplier) |
| margin_pct | DECIMAL(5,4) | profit margin as fraction (e.g. 0.1196 = 11.96 %, range –0.1000..0.3000) |
| weight | DECIMAL(10,2) | kg |
| color | NVARCHAR(20) | Red / Blue / Green / Black / White / Gray / Silver / Gold |
| material | NVARCHAR(50) | Plastic / Metal / Wood / Glass / Fabric |
| supplierid | INT | 1‑50 |
| isactive | TINYINT | 1 = still sold |
| minstock | INT | reorder level |
| tax_rate | DECIMAL(5,4) | 0.10 or 0.21 (fraction) |
| haswarranty | TINYINT | 1 = warranty offered |
| ecofriendly | TINYINT | 1 = ecoscore > 100 |
| seasonalityfactor | DECIMAL(5,2) | demand multiplier (0.7‑1.3) |
| warrantymonths | TINYINT | 0,12,24,36 |
| ecoscore | TINYINT | 20‑200 |
| releaseyear | SMALLINT | 2018‑2025 |
| skucount | INT | number of variants |
| isdiscontinued | TINYINT | 1 = discontinued |
| productrating | DECIMAL(3,1) | 1.0‑5.0 |
| stockstatus | NVARCHAR(20) | In Stock / Low Stock / Out of Stock |

### dim_store
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
| storerating | DECIMAL(3,1) | 2.0‑5.0 |
| hasdeliveryservice | TINYINT | 1 = delivery available |
| floornumber | TINYINT | 1‑5 |
| distancetocitycenterkm | DECIMAL(8,1) | km |
| annualrentcost | DECIMAL(18,2) | USD |
| storesizemultiplier | DECIMAL(10,3) | relative size (0.1‑10.0, wide spread) |

### dim_promotion
| Column | Type | Description |
|--------|------|-------------|
| promoid | INT | PK (0 = “No Promotion”, 1..100 = real promotions) |
| promoname | NVARCHAR(150) | unique name |
| discount_pct | DECIMAL(5,4) | discount as fraction (e.g. 0.2500 = 25 %) |
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
| redemption_rate | DECIMAL(5,3) | target redemption rate (0.02‑0.35, fraction) |
| coderequired | TINYINT | 1 = promo code needed |
| promoupliftfactor | DECIMAL(6,3) | sales multiplier (1.0‑2.2) |

### factsales
| Column | Type | Description |
|--------|------|-------------|
| salesid | BIGINT | PK |
| datekey | INT | FK to dim_date |
| productid | INT | FK to dim_product |
| customerid | INT | FK to dim_customer |
| storeid | INT | FK to dim_store |
| promoid | INT | FK to dim_promotion (0 = no promotion) |
| qty | TINYINT | 1‑10 (scaled to meet daily target) |
| unitprice | DECIMAL(18,2) | actual selling price |
| tax_rate | DECIMAL(5,4) | 0.10 or 0.21 (fraction) |
| net | DECIMAL(18,2) | gross – discount + tax |
| payment | NVARCHAR(20) | Card / Cash / Bank Transfer / Digital Wallet / PayPal |
| channel | NVARCHAR(20) | Online / In‑Store / Mobile App / Phone Order |
| grossvalue | DECIMAL(18,2) | qty × unitprice |
| discountamount | DECIMAL(18,2) | total discount applied |
| taxamount | DECIMAL(18,2) | tax paid |
| shipcost | DECIMAL(18,2) | shipping cost (0 for in‑store) |
| isreturn | TINYINT | 1 = return transaction |
| shipweight | DECIMAL(10,2) | kg (qty × product weight) |
| discountapplied | TINYINT | 1 = any discount used |
| returnreason | NVARCHAR(50) | 'No return' if isreturn=0; specific reason otherwise |
| deliverydays | TINYINT | 0 for in‑store, 1‑10 for online/mobile/phone |
| hour | TINYINT | hour of transaction (0‑23), never NULL |

---

## Comprehensive Query Reference

Each business question is answered with T‑SQL, DAX, and Python (pandas) examples. Monetary values are in USD and formatted with thousand separators / zero decimal places. Percentages are shown with two decimal places.

### 1. Total revenue (excl. returns)
**T‑SQL:**  
`SELECT FORMAT(SUM(net), 'N0') AS total_revenue FROM dbo.factsales WHERE isreturn = 0;`  
**DAX:**  
`Total Revenue = SUMX(FILTER(factsales, factsales[isreturn]=0), factsales[net])`  
**Python:**  
`total_revenue = df[df['isreturn']==0]['net'].sum()`  
`print(f"Total revenue: {total_revenue:,.0f}")`

### 2. Total COGS
**T‑SQL:**  
`SELECT FORMAT(SUM(f.qty * p.unitcost), 'N0') AS total_cogs FROM dbo.factsales f JOIN dbo.dimproduct p ON f.productid = p.productid WHERE f.isreturn = 0;`  
**DAX:**  
`Total COGS = SUMX(FILTER(factsales, factsales[isreturn]=0), factsales[qty] * RELATED(dimproduct[unitcost]))`  
**Python:**  
`total_cogs = (nonret['qty'] * nonret['unitcost']).sum()`  
`print(f"Total COGS: {total_cogs:,.0f}")`

### 3. Gross profit
**T‑SQL:**  
`SELECT FORMAT(SUM(f.net) - SUM(f.qty * p.unitcost), 'N0') AS gross_profit FROM dbo.factsales f JOIN dbo.dimproduct p ON f.productid = p.productid WHERE f.isreturn = 0;`  
**DAX:**  
`Gross Profit = [Total Revenue] - [Total COGS]`  
**Python:**  
`gross_profit = total_revenue - total_cogs`  
`print(f"Gross profit: {gross_profit:,.0f}")`

### 4. Gross margin %
**T‑SQL:**  
`SELECT FORMAT((SUM(f.net - f.qty * p.unitcost) / NULLIF(SUM(f.net), 0)) * 100, 'N2') + '%' AS gross_margin_pct FROM dbo.factsales f JOIN dbo.dimproduct p ON f.productid = p.productid WHERE f.isreturn = 0;`  
**DAX:**  
`Gross Margin % = DIVIDE([Gross Profit], [Total Revenue], 0)`  
**Python:**  
`gross_margin_pct = (gross_profit / total_revenue * 100) if total_revenue else 0`  
`print(f"Gross margin %: {gross_margin_pct:.2f}%")`

### 5. Average basket value
**T‑SQL:**  
`SELECT FORMAT(SUM(net) / COUNT(DISTINCT salesid), 'N0') AS avg_basket_value FROM dbo.factsales WHERE isreturn = 0;`  
**DAX:**  
`Average Basket Value = DIVIDE([Total Revenue], DISTINCTCOUNT(FILTER(factsales, factsales[isreturn]=0), factsales[salesid]))`  
**Python:**  
`avg_basket = total_revenue / num_baskets`  
`print(f"Average basket value: {avg_basket:,.0f}")`

### 6. Return rate
**T‑SQL:**  
`SELECT FORMAT(AVG(CAST(isreturn AS DECIMAL(10,4))) * 100, 'N2') + '%' AS return_rate FROM dbo.factsales;`  
**DAX:**  
`Return Rate = DIVIDE(COUNTROWS(FILTER(factsales, factsales[isreturn]=1)), COUNTROWS(factsales), 0)`  
**Python:**  
`return_rate = df['isreturn'].mean() * 100`  
`print(f"Return rate: {return_rate:.2f}%")`

### 7. Discount penetration
**T‑SQL:**  
`SELECT FORMAT(AVG(CAST(discountapplied AS DECIMAL(10,4))) * 100, 'N2') + '%' AS discount_penetration FROM dbo.factsales WHERE isreturn = 0;`  
**DAX:**  
`Discount Penetration = DIVIDE(COUNTROWS(FILTER(factsales, factsales[discountapplied]=1 && factsales[isreturn]=0)), COUNTROWS(FILTER(factsales, factsales[isreturn]=0)), 0)`  
**Python:**  
`disc_pen = nonret['discountapplied'].mean() * 100`  
`print(f"Discount penetration: {disc_pen:.2f}%")`

### 8. Unique customers
**T‑SQL:**  
`SELECT COUNT(DISTINCT customerid) AS unique_customers FROM dbo.factsales WHERE isreturn = 0;`  
**DAX:**  
`Unique Customers = DISTINCTCOUNT(FILTER(factsales, factsales[isreturn]=0), factsales[customerid])`  
**Python:**  
`unique_customers = df[df['isreturn']==0]['customerid'].nunique()`

### 9. Revenue by channel
**T‑SQL:**  
`SELECT channel, FORMAT(SUM(net), 'N0') AS revenue FROM dbo.factsales WHERE isreturn = 0 GROUP BY channel ORDER BY SUM(net) DESC;`  
**DAX:**  
`Channel Revenue = SUMMARIZE(FILTER(factsales, factsales[isreturn]=0), factsales[channel], "Revenue", SUM(factsales[net]))`  
**Python:**  
`channel_revenue = df[df['isreturn']==0].groupby('channel')['net'].sum().sort_values(ascending=False)`

### 10. Revenue by product category
**T‑SQL:**  
`SELECT p.category, FORMAT(SUM(f.net), 'N0') AS revenue FROM dbo.factsales f JOIN dbo.dimproduct p ON f.productid = p.productid WHERE f.isreturn = 0 GROUP BY p.category ORDER BY SUM(f.net) DESC;`  
**DAX:**  
`Category Revenue = SUMMARIZE(FILTER(factsales, factsales[isreturn]=0), dimproduct[category], "Revenue", SUM(factsales[net]))`  
**Python:**  
`cat_rev = merged.groupby('category')['net'].sum().sort_values(ascending=False)`

### 11. 7‑day moving average of daily sales
**T‑SQL:**
```sql
WITH daily AS (
  SELECT d.fulldate, SUM(f.net) AS daily_total
  FROM dbo.factsales f JOIN dbo.dimdate d ON f.datekey = d.datekey
  WHERE f.isreturn = 0
  GROUP BY d.fulldate
)
SELECT fulldate,
       FORMAT(daily_total, 'N0') AS daily_total,
       FORMAT(AVG(daily_total) OVER (ORDER BY fulldate ROWS BETWEEN 6 PRECEDING AND CURRENT ROW), 'N0') AS ma_7days
FROM daily ORDER BY fulldate;
DAX:
7D Moving Avg = CALCULATE(AVERAGEX(DATESINPERIOD(dimdate[fulldate], LASTDATE(dimdate[fulldate]), -7, DAY), [Total Revenue]), ALL(dimdate))
Python:
daily['ma_7days'] = daily['net'].rolling(7).mean()

12. Promotion effect
T‑SQL:

sql
WITH promo_days AS (
  SELECT d.fulldate,
         MAX(CASE WHEN f.promoid > 0 THEN 1 ELSE 0 END) AS has_promo,
         SUM(f.net) AS daily_revenue
  FROM dbo.factsales f JOIN dbo.dimdate d ON f.datekey = d.datekey
  WHERE f.isreturn = 0
  GROUP BY d.fulldate
)
SELECT has_promo, FORMAT(AVG(daily_revenue), 'N0') AS avg_revenue
FROM promo_days GROUP BY has_promo;
DAX:
Promo Uplift = VAR Promo = CALCULATE([Total Revenue], factsales[promoid] > 0) VAR NonPromo = CALCULATE([Total Revenue], factsales[promoid] = 0) RETURN DIVIDE(Promo - NonPromo, NonPromo, 0)
Python:
uplift = (avg_promo - avg_non) / avg_non

Dashboard Screenshots (Power BI)
Revenue Trend – visualising the enforced daily net‑sales pattern (decline → flat → strong rise)
https://../images/revenue_trend.jpg

Payment Matrix – breakdown of payment methods by channel
https://../images/payment_matrix.jpg

Monthly Revenue – seasonal revenue pattern with clear peaks in December
https://../images/monthly_revenue.jpg

How to update the images:

Place your new screenshot files in the images/ folder inside your GitHub repository.

If the file names are different, replace the paths above (e.g. ../images/revenue_trend.jpg).

After pushing the images to GitHub, the pictures will automatically appear in the documentation.

License
MIT – free to use, modify, and distribute.