# Retail Analytics – Complete Documentation

**Suggested file name:** `complete_documentation.md`  
**Author:** DataGen AI  
**Date:** 2026-05-24  
**Description:** Full technical documentation of the retailanalytics star schema, data generation rules, query reference (T‑SQL, DAX, Python), and dashboard screenshots. All percentage columns are stored as decimal fractions, monetary values use thousand separators with zero decimals, and percentage displays show two decimal places.

---

## Project Overview

The database models a multi-channel retail chain (**Online, In-Store, Mobile App, Phone Order**) with **10 million sales transactions** generated from 2023-01-01 to the current date (dynamic).

The data generator produces a realistic revenue trend:
- **First half** – slight decline from 60k to 50k daily net sales
- **Middle section** – flat/stagnation
- **Last 30 %** – strong rise from 50k to 95k daily net sales

All percentage columns (`margin_pct`, `discount_pct`, `tax_rate`, `redemption_rate`, `seasonalityfactor`) are stored as **decimal fractions** (e.g. `0.1196` = 11.96 %). In Power BI, applying the "Percentage" format displays the correct value automatically.

---

## Dashboard Screenshots

### Revenue Trend

![Revenue Trend](../images/revenue_trend.jpg)

*Visualising the enforced daily net-sales pattern (decline → flat → strong rise).*

---

### Payment Matrix

![Payment Matrix](../images/payment_matrix.jpg)

*Breakdown of payment methods by channel.*

---

### Monthly Revenue

![Monthly Revenue](../images/monthly_revenue.jpg)

*Seasonal revenue pattern with clear peaks in December.*

---

## Data Rules & Business Logic

| Rule | Detail |
|------|--------|
| **Margins** | Stored as decimal fractions. Range: −10 % to 30 %. Negative margins are **allowed** and do not cause validation errors. |
| **Promotions** | `promoid = 0` = "No Promotion" (dedicated row exists in `dim_promotion`) |
| **Returns** | `returnreason = 'No return'` for non-return rows, never NULL |
| **In-Store delivery** | `deliverydays = 0` for all In-Store transactions |
| **Hour** | Column `hour` (0–23) always populated, never NULL |
| **Gender** | Only `Male` / `Female` values |
| **Percentages** | All stored as decimal fractions, ready for Power BI % formatting |
| **Quantity scaling** | Daily net-sales targets met by scaling `qty`, preserving intrinsic product margins |
| **Discount flag** | `discountapplied` set **after** rounding `discountamount` to avoid false mismatches |
| **Variance** | Wide spread in store sizes (0.1–10.0), customer incomes (bi-modal), and product margins (prescribed distribution) |

### Product margin distribution

| Margin range | Share of products |
|---|---|
| Exactly 30 % | 5 % |
| 20 %–29 % | 5 % |
| Exactly 15 % | 5 % |
| 5 %–10 % | 50 % |
| 0 %–5 % | 30 % |
| −10 %–0 % (negative) | 5 % |

---

## Table Definitions

### dim_date

| Column | Type | Description |
|--------|------|-------------|
| datekey | INT | YYYYMMDD surrogate key (PK) |
| fulldate | DATE | Calendar date |
| year | SMALLINT | Year |
| quarternumber | TINYINT | 1–4 |
| quartername | NCHAR(2) | Q1–Q4 |
| monthnumber | TINYINT | 1–12 |
| monthname | NVARCHAR(20) | January … |
| weekdaynumber | TINYINT | 1=Monday … 7=Sunday |
| weekdayname | NVARCHAR(20) | Monday … |
| isweekend | TINYINT | 1 if weekend |
| yearmonth | NCHAR(7) | YYYY-MM |
| yearmonthnumber | INT | YYYYMM |
| yearquarter | NVARCHAR(7) | YYYY-QX |
| yearquarternumber | INT | YYYY×10+Q |
| yearweek | NVARCHAR(8) | YYYY-Www |
| yearweeknumber | INT | YYYY×100+week |
| isholiday | TINYINT | 1 if Dec/Jan/July |

### dim_customer

| Column | Type | Description |
|--------|------|-------------|
| customerid | INT | PK |
| fullname | NVARCHAR(100) | First + last (suffix if duplicate) |
| email | NVARCHAR(100) | Unique |
| age | TINYINT | 18–75 |
| gender | NVARCHAR(20) | Male / Female |
| city | NVARCHAR(50) | Residence city |
| tier | NVARCHAR(20) | Bronze / Silver / Gold / Platinum |
| points | INT | Loyalty points |
| isactive | TINYINT | 1 = active |
| lang | NVARCHAR(10) | en, de, fr, es, pl, it |
| totalspend | DECIMAL(18,2) | Lifetime spend (USD) |
| regdate | DATE | Registration date |
| annualincome | DECIMAL(18,2) | USD |
| incomebracket | NVARCHAR(20) | Low / Medium / High / Very High / Ultra High |
| education | NVARCHAR(50) | High School / Bachelor / Master / PhD |
| maritalstatus | NVARCHAR(20) | Single / Married / Divorced / Widowed |
| childrencount | TINYINT | Number of children |
| loyaltysegment | NVARCHAR(20) | Same as tier |
| satisfactionscore | DECIMAL(5,1) | 1.0–5.0 |
| dayssincelastpurchase | INT | Days since last transaction |
| hassubscription | TINYINT | Newsletter subscription |
| preferredcontact | NVARCHAR(20) | Email / SMS / Phone / Mail |
| spendmultiplier | DECIMAL(10,3) | Spending behaviour factor |

### dim_product

| Column | Type | Description |
|--------|------|-------------|
| productid | INT | PK |
| name | NVARCHAR(150) | Brand + adjective + noun + variant |
| category | NVARCHAR(50) | Electronics / Home / Sports / Kids / Garden |
| brand | NVARCHAR(50) | Brand name |
| unitcost | DECIMAL(18,2) | Cost price (USD) |
| unitprice | DECIMAL(18,2) | Base selling price |
| margin_pct | DECIMAL(5,4) | Profit margin as fraction (e.g. `0.1196` = 11.96 %, range −0.1000..0.3000) |
| weight | DECIMAL(10,2) | kg |
| color | NVARCHAR(20) | Red / Blue / Green / Black / White / Gray / Silver / Gold |
| material | NVARCHAR(50) | Plastic / Metal / Wood / Glass / Fabric |
| supplierid | INT | 1–50 |
| isactive | TINYINT | 1 = still sold |
| minstock | INT | Reorder level |
| tax_rate | DECIMAL(5,4) | 0.10 or 0.21 (fraction) |
| haswarranty | TINYINT | 1 = warranty offered |
| ecofriendly | TINYINT | 1 = ecoscore > 100 |
| seasonalityfactor | DECIMAL(5,2) | Demand multiplier (0.7–1.3) |
| warrantymonths | TINYINT | 0, 12, 24, 36 |
| ecoscore | TINYINT | 20–200 |
| releaseyear | SMALLINT | 2018–2025 |
| skucount | INT | Number of variants |
| isdiscontinued | TINYINT | 1 = discontinued |
| productrating | DECIMAL(3,1) | 1.0–5.0 |
| stockstatus | NVARCHAR(20) | In Stock / Low Stock / Out of Stock |

### dim_store

| Column | Type | Description |
|--------|------|-------------|
| storeid | INT | PK |
| storename | NVARCHAR(150) | Chain + city + suffix (unique) |
| city | NVARCHAR(50) | Location city |
| type | NVARCHAR(50) | Supermarket / Hypermarket / Convenience / Department |
| staff | SMALLINT | Number of employees |
| sizem2 | INT | Square meters |
| hascafe | TINYINT | 1 = café present |
| openingyear | SMALLINT | Year opened |
| region | NVARCHAR(50) | North / South / East / West / Central |
| renovationyear | SMALLINT | Last renovation (0 = never) |
| parkingspots | SMALLINT | Parking spaces |
| storerating | DECIMAL(3,1) | 2.0–5.0 |
| hasdeliveryservice | TINYINT | 1 = delivery available |
| floornumber | TINYINT | 1–5 |
| distancetocitycenterkm | DECIMAL(8,1) | km |
| annualrentcost | DECIMAL(18,2) | USD |
| storesizemultiplier | DECIMAL(10,3) | Relative size (0.1–10.0) |

### dim_promotion

| Column | Type | Description |
|--------|------|-------------|
| promoid | INT | PK (0 = "No Promotion", 1..100 = real promotions) |
| promoname | NVARCHAR(150) | Unique name |
| discount_pct | DECIMAL(5,4) | Discount as fraction (e.g. `0.2500` = 25 %) |
| discount_fixed | DECIMAL(10,2) | Fixed USD discount |
| type | NVARCHAR(50) | Percentage / Fixed Amount / BOGO / Free Shipping |
| isactive | TINYINT | 1 = currently active |
| minspend | INT | USD threshold |
| channel | NVARCHAR(50) | Email / SMS / App / InStore / All / Online |
| budget | DECIMAL(18,2) | USD |
| startdate | DATE | Start date |
| enddate | DATE | End date |
| targetaudience | NVARCHAR(50) | All / New / Loyal / HighSpend |
| maxdiscountcap | DECIMAL(18,2) | Max discount USD |
| isstackable | TINYINT | 1 = can combine |
| redemption_rate | DECIMAL(5,3) | Target redemption rate (0.02–0.35, fraction) |
| coderequired | TINYINT | 1 = promo code needed |
| promoupliftfactor | DECIMAL(6,3) | Sales multiplier (1.0–2.2) |

### fact_sales

| Column | Type | Description |
|--------|------|-------------|
| salesid | BIGINT | PK |
| datekey | INT | FK → dim_date |
| productid | INT | FK → dim_product |
| customerid | INT | FK → dim_customer |
| storeid | INT | FK → dim_store |
| promoid | INT | FK → dim_promotion (0 = no promotion) |
| qty | TINYINT | 1–10 (scaled to meet daily target) |
| unitprice | DECIMAL(18,2) | Actual selling price |
| tax_rate | DECIMAL(5,4) | 0.10 or 0.21 (fraction) |
| net | DECIMAL(18,2) | gross – discount + tax |
| payment | NVARCHAR(20) | Card / Cash / Bank Transfer / Digital Wallet / PayPal |
| channel | NVARCHAR(20) | Online / In-Store / Mobile App / Phone Order |
| grossvalue | DECIMAL(18,2) | qty × unitprice |
| discountamount | DECIMAL(18,2) | Total discount applied |
| taxamount | DECIMAL(18,2) | Tax paid |
| shipcost | DECIMAL(18,2) | Shipping cost (0 for in-store) |
| isreturn | TINYINT | 1 = return transaction |
| shipweight | DECIMAL(10,2) | kg (qty × product weight) |
| discountapplied | TINYINT | 1 = any discount used |
| returnreason | NVARCHAR(50) | `'No return'` if isreturn=0; specific reason otherwise |
| deliverydays | TINYINT | 0 for in-store, 1–10 for online/mobile/phone |
| hour | TINYINT | Hour of transaction (0–23), never NULL |

---

## Comprehensive Query Reference

Monetary values formatted with thousand separators, zero decimal places. Percentages with two decimal places.

### 1. Total revenue (excl. returns)

**T-SQL:**
```sql
SELECT FORMAT(SUM(net), 'N0') AS total_revenue
FROM dbo.factsales
WHERE isreturn = 0;
```

**DAX:**
```dax
Total Revenue = SUMX(FILTER(factsales, factsales[isreturn]=0), factsales[net])
```

**Python:**
```python
total_revenue = df[df['isreturn']==0]['net'].sum()
print(f"Total revenue: {total_revenue:,.0f}")
```

### 2. Total COGS

**T-SQL:**
```sql
SELECT FORMAT(SUM(f.qty * p.unitcost), 'N0') AS total_cogs
FROM dbo.factsales f
JOIN dbo.dimproduct p ON f.productid = p.productid
WHERE f.isreturn = 0;
```

**DAX:**
```dax
Total COGS = SUMX(
    FILTER(factsales, factsales[isreturn]=0),
    factsales[qty] * RELATED(dimproduct[unitcost])
)
```

**Python:**
```python
total_cogs = (nonret['qty'] * nonret['unitcost']).sum()
print(f"Total COGS: {total_cogs:,.0f}")
```

### 3. Gross profit

**T-SQL:**
```sql
SELECT FORMAT(SUM(f.net) - SUM(f.qty * p.unitcost), 'N0') AS gross_profit
FROM dbo.factsales f
JOIN dbo.dimproduct p ON f.productid = p.productid
WHERE f.isreturn = 0;
```

**DAX:**
```dax
Gross Profit = [Total Revenue] - [Total COGS]
```

**Python:**
```python
gross_profit = total_revenue - total_cogs
print(f"Gross profit: {gross_profit:,.0f}")
```

### 4. Gross margin %

**T-SQL:**
```sql
SELECT FORMAT(
    (SUM(f.net - f.qty * p.unitcost) / NULLIF(SUM(f.net), 0)) * 100,
    'N2') + '%' AS gross_margin_pct
FROM dbo.factsales f
JOIN dbo.dimproduct p ON f.productid = p.productid
WHERE f.isreturn = 0;
```

**DAX:**
```dax
Gross Margin % = DIVIDE([Gross Profit], [Total Revenue], 0)
```

**Python:**
```python
gross_margin_pct = (gross_profit / total_revenue * 100) if total_revenue else 0
print(f"Gross margin %: {gross_margin_pct:.2f}%")
```

### 5. Return rate

**T-SQL:**
```sql
SELECT FORMAT(AVG(CAST(isreturn AS DECIMAL(10,4))) * 100, 'N2') + '%' AS return_rate
FROM dbo.factsales;
```

**DAX:**
```dax
Return Rate = DIVIDE(
    COUNTROWS(FILTER(factsales, factsales[isreturn]=1)),
    COUNTROWS(factsales), 0)
```

**Python:**
```python
return_rate = df['isreturn'].mean() * 100
print(f"Return rate: {return_rate:.2f}%")
```

### 6. Discount penetration

**T-SQL:**
```sql
SELECT FORMAT(AVG(CAST(discountapplied AS DECIMAL(10,4))) * 100, 'N2') + '%' AS discount_penetration
FROM dbo.factsales
WHERE isreturn = 0;
```

**Python:**
```python
disc_pen = nonret['discountapplied'].mean() * 100
print(f"Discount penetration: {disc_pen:.2f}%")
```

### 7. Revenue by channel

**T-SQL:**
```sql
SELECT channel, FORMAT(SUM(net), 'N0') AS revenue
FROM dbo.factsales
WHERE isreturn = 0
GROUP BY channel
ORDER BY SUM(net) DESC;
```

**Python:**
```python
channel_revenue = df[df['isreturn']==0].groupby('channel')['net'].sum().sort_values(ascending=False)
```

### 8. Revenue by product category

**T-SQL:**
```sql
SELECT p.category, FORMAT(SUM(f.net), 'N0') AS revenue
FROM dbo.factsales f
JOIN dbo.dimproduct p ON f.productid = p.productid
WHERE f.isreturn = 0
GROUP BY p.category
ORDER BY SUM(f.net) DESC;
```

**Python:**
```python
cat_rev = merged.groupby('category')['net'].sum().sort_values(ascending=False)
```

### 9. 7-day moving average of daily sales

**T-SQL:**
```sql
WITH daily AS (
    SELECT d.fulldate, SUM(f.net) AS daily_total
    FROM dbo.factsales f
    JOIN dbo.dimdate d ON f.datekey = d.datekey
    WHERE f.isreturn = 0
    GROUP BY d.fulldate
)
SELECT fulldate,
       FORMAT(daily_total, 'N0') AS daily_total,
       FORMAT(AVG(daily_total) OVER (
           ORDER BY fulldate ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
       ), 'N0') AS ma_7days
FROM daily
ORDER BY fulldate;
```

**DAX:**
```dax
7D Moving Avg = CALCULATE(
    AVERAGEX(
        DATESINPERIOD(dimdate[fulldate], LASTDATE(dimdate[fulldate]), -7, DAY),
        [Total Revenue]
    ),
    ALL(dimdate)
)
```

**Python:**
```python
daily['ma_7days'] = daily['net'].rolling(7).mean()
```

### 10. Promotion effect

**T-SQL:**
```sql
WITH promo_days AS (
    SELECT d.fulldate,
           MAX(CASE WHEN f.promoid > 0 THEN 1 ELSE 0 END) AS has_promo,
           SUM(f.net) AS daily_revenue
    FROM dbo.factsales f
    JOIN dbo.dimdate d ON f.datekey = d.datekey
    WHERE f.isreturn = 0
    GROUP BY d.fulldate
)
SELECT has_promo, FORMAT(AVG(daily_revenue), 'N0') AS avg_revenue
FROM promo_days
GROUP BY has_promo;
```

**DAX:**
```dax
Promo Uplift =
VAR Promo    = CALCULATE([Total Revenue], factsales[promoid] > 0)
VAR NonPromo = CALCULATE([Total Revenue], factsales[promoid] = 0)
RETURN DIVIDE(Promo - NonPromo, NonPromo, 0)
```

**Python:**
```python
uplift = (avg_promo - avg_non) / avg_non
```

---

## Scripts Reference (Updated 2026-05-24)

### Python Data Generation
| Script | Description |
|--------|-------------|
| `generate_retail_data.py` | Generates all CSV files with realistic distributions, quantity scaling, and fraction-based percentages |

### SQL Server Scripts (Execution Order)
| # | Script | Description |
|---|--------|-------------|
| 1 | `build_retailanalytics_database.sql` | Creates database, tables, loads all CSV files, adds primary/foreign keys, clustered columnstore index, basic views |
| 2 | `create_analytical_views.sql` | Creates 17 analytical views with fraction-based margin/discount columns |
| 3 | `validate_retail_data_quality.sql` | Comprehensive data quality checks (60+ tests) |
| 4 | `analyze_product_margins.sql` | Detailed margin distribution analysis with histogram and formatted percentages |
| 5 | `validate_star_schema_model.sql` | Star schema integrity, FK validation, columnstore index check |
| 6 | `quick_data_quality_checks.sql` | Lightweight sanity checks with thousand separators and percentage formatting |

### Microsoft Fabric Notebooks (Execution Order)
| # | Script | Description |
|---|--------|-------------|
| 1 | `ingest_bronze_layer.py` | Loads CSV files into Bronze Delta tables with audit columns |
| 2 | `transform_silver_layer.py` | Cleans, casts types (fractions to DECIMAL(5,4)), deduplicates, ensures dummy promotion row |
| 3 | `create_gold_views.py` | Creates 17 materialized Gold analytical tables with fraction-based margins |
| 4 | `optimize_delta_tables.py` | Delta Lake compaction and Z-ordering across all layers |
| 5 | `validate_fabric_layers.sql` | Data quality checks for Silver and Gold layers in Fabric SQL Endpoint |
| 6 | `analyze_silver_data.py` | Analytical queries on Silver data with formatted output (thousand separators, percentages) |

---

## How to Update Dashboard Screenshots

1. Place your new screenshot files in the `images/` folder at the root of the repository.
2. File names must match exactly: `revenue_trend.jpg`, `payment_matrix.jpg`, `monthly_revenue.jpg`.
3. Push to GitHub — images will appear automatically in both README and this documentation.

> **Note for docs folder:** This file lives in `docs/`. Image paths use `../images/` to reference the `images/` folder one level up. If you move this file, update the paths accordingly.

---

## License

MIT – free to use, modify, and distribute.