# 📖 Retail Analytics – Complete Technical Documentation

**Suggested file name:** `complete_documentation.md`  
**Author:** DataGen AI & Assistant  
**Date:** 2026-05-25  
**Description:** Full technical documentation of the retailanalytics star schema, data generation rules, query reference (T‑SQL, DAX, Python), and dashboard metrics. All percentage columns are stored as decimal fractions, monetary values use thousand separators with zero decimals, and percentage displays show two decimal places.
**Navigation:** [Go back to README.md](../README.md) 🚀

---

## 📈 Project Overview

The database models a multi-channel retail chain (**Online, In-Store, Mobile App, Phone Order**) with **10 million sales transactions** generated from 2023-01-01 to the current date (dynamic).

The data generator produces a realistic revenue trend:
- **First half** – slight decline from 60k to 50k daily net sales
- **Middle section** – flat/stagnation
- **Last 30%** – strong rise from 50k to 95k daily net sales

All percentage columns (`margin_pct`, `discount_pct`, `tax_rate`, `redemption_rate`, `seasonalityfactor`) are stored as **decimal fractions** (e.g. `0.1196` = 11.96%). In Power BI, applying the "Percentage" format displays the correct value automatically.

---

## 📊 Dashboard Screenshots

### 📈 Revenue Trend
![Revenue Trend](../images/revenue_trend.jpg)
*Visualising the enforced daily net-sales pattern (decline → flat → strong rise).*

---

### 💳 Payment Matrix
![Payment Matrix](../images/payment_matrix.jpg)
*Breakdown of payment methods by channel.*

---

### 📅 Monthly Revenue
![Monthly Revenue](../images/monthly_revenue.jpg)
*Seasonal revenue pattern with clear peaks in December.*

---

## 📏 Data Rules & Business Logic

| Rule | Detail |
|------|--------|
| **Margins** | Stored as decimal fractions. Range: −10% to 30%. Negative margins are **allowed** and represent loss-leader marketing strategies. |
| **Relational Integrity Dummies** | Every dimension table contains a `-1` (and `0` for Promo) technical dummy row representing "Unknown" or "Missing" values to prevent NULLs in fact table FK columns during ETL. |
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
| Exactly 30% | 5% |
| 20%–29% | 5% |
| Exactly 15% | 5% |
| 5%–10% | 50% |
| 0%–5% | 30% |
| −10%–0% (negative) | 5% |

---

## 🗄️ Table Definitions

### 1. `dim_date`
*Includes one technical dummy record (`datekey = -1`) representing an Unknown or Invalid Date.*

| Column | Type | Nullability | Description |
|--------|------|-------------|-------------|
| datekey | INT | NOT NULL | YYYYMMDD surrogate key (PK) |
| fulldate | DATE | NOT NULL | Calendar date |
| year | SMALLINT | NOT NULL | Year |
| quarternumber | TINYINT | NOT NULL | 1–4 |
| quartername | NCHAR(2) | NOT NULL | Q1–Q4 |
| monthnumber | TINYINT | NOT NULL | 1–12 |
| monthname | NVARCHAR(20) | NOT NULL | January … |
| weekdaynumber | TINYINT | NOT NULL | 1=Monday … 7=Sunday |
| weekdayname | NVARCHAR(20) | NOT NULL | Monday … |
| isweekend | TINYINT | NOT NULL | 1 if weekend |
| yearmonth | NCHAR(7) | NOT NULL | YYYY-MM |
| yearmonthnumber | INT | NOT NULL | YYYYMM |
| yearquarter | NVARCHAR(7) | NOT NULL | YYYY-QX |
| yearquarternumber | INT | NOT NULL | YYYY×10+Q |
| yearweek | NVARCHAR(8) | NOT NULL | YYYY-Www |
| yearweeknumber | INT | NOT NULL | YYYY×100+week |
| isholiday | TINYINT | NOT NULL | 1 if Dec/Jan/July |

### 2. `dim_customer`
*Includes one technical dummy record (`customerid = -1`) representing an Unknown Customer.*

| Column | Type | Nullability | Description |
|--------|------|-------------|-------------|
| customerid | INT | NOT NULL | PK |
| fullname | NVARCHAR(100) | NOT NULL | First + last (suffix if duplicate) |
| email | NVARCHAR(100) | NOT NULL | Unique |
| age | TINYINT | NOT NULL | 18–75 |
| gender | NVARCHAR(20) | NOT NULL | Male / Female |
| city | NVARCHAR(50) | NOT NULL | Residence city |
| tier | NVARCHAR(20) | NOT NULL | Bronze / Silver / Gold / Platinum |
| points | INT | NOT NULL | Loyalty points |
| isactive | TINYINT | NOT NULL | 1 = active |
| lang | NVARCHAR(10) | NOT NULL | en, de, fr, es, pl, it |
| totalspend | DECIMAL(18,2) | NOT NULL | Lifetime spend (USD) |
| regdate | DATE | NOT NULL | Registration date |
| annualincome | DECIMAL(18,2) | NOT NULL | USD |
| incomebracket | NVARCHAR(20) | NOT NULL | Low / Medium / High / Very High / Ultra High |
| education | NVARCHAR(50) | NOT NULL | High School / Bachelor / Master / PhD |
| maritalstatus | NVARCHAR(20) | NOT NULL | Single / Married / Divorced / Widowed |
| childrencount | TINYINT | NOT NULL | Number of children |
| loyaltysegment | NVARCHAR(20) | NOT NULL | Same as tier |
| satisfactionscore | DECIMAL(5,1) | NOT NULL | 1.0–5.0 |
| dayssincelastpurchase | INT | NOT NULL | Days since last transaction |
| hassubscription | TINYINT | NOT NULL | Newsletter subscription |
| preferredcontact | NVARCHAR(20) | NOT NULL | Email / SMS / Phone / Mail |
| spendmultiplier | DECIMAL(10,3) | NOT NULL | Spending behaviour factor |

### 3. `dim_product`
*Includes one technical dummy record (`productid = -1`) representing an Unknown Product.*

| Column | Type | Nullability | Description |
|--------|------|-------------|-------------|
| productid | INT | NOT NULL | PK |
| name | NVARCHAR(150) | NOT NULL | Brand + adjective + noun + variant |
| category | NVARCHAR(50) | NOT NULL | Electronics / Home / Sports / Kids / Garden |
| brand | NVARCHAR(50) | NOT NULL | Brand name |
| unitcost | DECIMAL(18,2) | NOT NULL | Cost price (USD) |
| unitprice | DECIMAL(18,2) | NOT NULL | Base selling price |
| margin_pct | DECIMAL(5,4) | NOT NULL | Profit margin as fraction (e.g. `0.1196` = 11.96%, range −0.1000..0.3000) |
| weight | DECIMAL(10,2) | NOT NULL | kg |
| color | NVARCHAR(20) | NOT NULL | Red / Blue / Green / Black / White / Gray / Silver / Gold |
| material | NVARCHAR(50) | NOT NULL | Plastic / Metal / Wood / Glass / Fabric |
| supplierid | INT | NOT NULL | 1–50 |
| isactive | TINYINT | NOT NULL | 1 = still sold |
| minstock | INT | NOT NULL | Reorder level |
| tax_rate | DECIMAL(5,4) | NOT NULL | 0.10 or 0.21 (fraction) |
| haswarranty | TINYINT | NOT NULL | 1 = warranty offered |
| ecofriendly | TINYINT | NOT NULL | 1 = ecoscore > 100 |
| seasonalityfactor | DECIMAL(5,2) | NOT NULL | Demand multiplier (0.7–1.3) |
| warrantymonths | TINYINT | NOT NULL | 0, 12, 24, 36 |
| ecoscore | TINYINT | NOT NULL | 20–200 |
| releaseyear | SMALLINT | NOT NULL | 2018–2025 |
| skucount | INT | NOT NULL | Number of variants |
| isdiscontinued | TINYINT | NOT NULL | 1 = discontinued |
| productrating | DECIMAL(3,1) | NOT NULL | 1.0–5.0 |
| stockstatus | NVARCHAR(20) | NOT NULL | In Stock / Low Stock / Out of Stock |

### 4. `dim_store`
*Includes one technical dummy record (`storeid = -1`) representing an Unknown Store.*

| Column | Type | Nullability | Description |
|--------|------|-------------|-------------|
| storeid | INT | NOT NULL | PK |
| storename | NVARCHAR(150) | NOT NULL | Chain + city + suffix (unique) |
| city | NVARCHAR(50) | NOT NULL | Location city |
| type | NVARCHAR(50) | NOT NULL | Supermarket / Hypermarket / Convenience / Department |
| staff | SMALLINT | NOT NULL | Number of employees |
| sizem2 | INT | NOT NULL | Square meters |
| hascafe | TINYINT | NOT NULL | 1 = café present |
| openingyear | SMALLINT | NOT NULL | Year opened |
| region | NVARCHAR(50) | NOT NULL | North / South / East / West / Central |
| renovationyear | SMALLINT | NOT NULL | Last renovation (0 = never) |
| parkingspots | SMALLINT | NOT NULL | Parking spaces |
| storerating | DECIMAL(3,1) | NOT NULL | 2.0–5.0 |
| hasdeliveryservice | TINYINT | NOT NULL | 1 = delivery available |
| floornumber | TINYINT | NOT NULL | 1–5 |
| distancetocitycenterkm | DECIMAL(8,1) | NOT NULL | km |
| annualrentcost | DECIMAL(18,2) | NOT NULL | USD |
| storesizemultiplier | DECIMAL(10,4) | NOT NULL | Relative size (0.1–10.0) |

### 5. `dim_promotion`
*Includes `promoid = 0` (No Promotion) and `promoid = -1` (Unknown Promotion) technical dummy rows.*

| Column | Type | Nullability | Description |
|--------|------|-------------|-------------|
| promoid | INT | NOT NULL | PK (0 = "No Promotion", 1..100 = real promotions) |
| promoname | NVARCHAR(150) | NOT NULL | Unique name |
| discount_pct | DECIMAL(5,4) | NOT NULL | Discount as fraction (e.g. `0.2500` = 25%) |
| discount_fixed | DECIMAL(10,2) | NOT NULL | Fixed USD discount |
| type | NVARCHAR(50) | NOT NULL | Percentage / Fixed Amount / BOGO / Free Shipping |
| isactive | TINYINT | NOT NULL | 1 = currently active |
| minspend | INT | NOT NULL | USD threshold |
| channel | NVARCHAR(50) | NOT NULL | Email / SMS / App / InStore / All / Online |
| budget | DECIMAL(18,2) | NOT NULL | USD |
| startdate | DATE | NOT NULL | Start date |
| enddate | DATE | NOT NULL | End date |
| targetaudience | NVARCHAR(50) | NOT NULL | All / New / Loyal / HighSpend |
| maxdiscountcap | DECIMAL(18,2) | NOT NULL | Max discount USD |
| isstackable | TINYINT | NOT NULL | 1 = can combine |
| redemption_rate | DECIMAL(5,3) | NOT NULL | Target redemption rate (0.02–0.35, fraction) |
| coderequired | TINYINT | NOT NULL | 1 = promo code needed |
| promoupliftfactor | DECIMAL(6,3) | NOT NULL | Sales multiplier (1.0–2.2) |

### 6. `fact_sales`
*The core transactional table containing 10,000,000 sales and return line items.*

| Column | Type | Nullability | Description |
|--------|------|-------------|-------------|
| salesid | BIGINT | NOT NULL | PK |
| datekey | INT | NOT NULL | FK → dim_date |
| productid | INT | NOT NULL | FK → dim_product |
| customerid | INT | NOT NULL | FK → dim_customer |
| storeid | INT | NOT NULL | FK → dim_store |
| promoid | INT | NOT NULL | FK → dim_promotion (0 = no promotion) |
| qty | INT | NOT NULL | 1–10 (scaled to meet daily target) |
| unitprice | DECIMAL(18,2) | NOT NULL | Actual selling price |
| tax_rate | DECIMAL(5,4) | NOT NULL | 0.10 or 0.21 (fraction) |
| net | DECIMAL(18,2) | NOT NULL | gross – discount + tax |
| payment | NVARCHAR(20) | NOT NULL | Card / Cash / Bank Transfer / Digital Wallet / PayPal |
| channel | NVARCHAR(20) | NOT NULL | Online / In-Store / Mobile App / Phone Order |
| grossvalue | DECIMAL(18,2) | NOT NULL | qty × unitprice |
| discountamount | DECIMAL(18,2) | NOT NULL | Total discount applied |
| taxamount | DECIMAL(18,2) | NOT NULL | Tax paid |
| shipcost | DECIMAL(18,2) | NOT NULL | Shipping cost (0 for in-store) |
| isreturn | TINYINT | NOT NULL | 1 = return transaction |
| shipweight | DECIMAL(10,2) | NOT NULL | kg (qty × product weight) |
| discountapplied | TINYINT | NOT NULL | 1 = any discount used |
| returnreason | NVARCHAR(50) | NOT NULL | `'No return'` if isreturn=0; specific reason otherwise |
| deliverydays | TINYINT | NOT NULL | 0 for in-store, 1–10 for online/mobile/phone |
| hour | TINYINT | NOT NULL | Hour of transaction (0–23), never NULL |

---

## 📈 Comprehensive Query Reference

Each analytical query is optimized using the "Aggregate-then-Join" standard, enabling rapid execution across columns.

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

**T-SQL (Optimized):**
```sql
WITH sales_agg AS (
    SELECT productid, SUM(qty) AS total_qty
    FROM dbo.factsales
    WHERE isreturn = 0
    GROUP BY productid
)
SELECT FORMAT(SUM(CAST(sa.total_qty AS DECIMAL(18,2)) * p.unitcost), 'N0') AS total_cogs
FROM sales_agg sa
INNER JOIN dbo.dimproduct p ON sa.productid = p.productid;
```

**DAX:**
```dax
Total COGS = SUMX(
    FILTER(factsales, factsales[isreturn]=0),
    factsales[qty] * RELATED(dimproduct[unitcost])
)
```

**Python (Optimized):**
```python
# Projecting only needed columns reduces memory footprint of merge by 70%
nonret_merged_prod = nonret_fact[['productid', 'qty']].merge(
    prod[['productid', 'unitcost']], 
    on='productid'
)
total_cogs = (nonret_merged_prod['qty'] * nonret_merged_prod['unitcost']).sum()
print(f"Total COGS: {total_cogs:,.0f}")
```

### 3. Gross profit

**T-SQL (Optimized):**
```sql
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

**T-SQL (Optimized):**
```sql
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
SELECT FORMAT((total_revenue - total_cost) / NULLIF(total_revenue, 0) * 100, 'N2') + '%' AS gross_margin_pct
FROM totals;
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
disc_pen = nonret_fact['discountapplied'].mean() * 100
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
channel_revenue = nonret_fact.groupby('channel')['net'].sum().sort_values(ascending=False)
```

### 8. Revenue by product category

**T-SQL (Optimized):**
```sql
WITH sales_agg AS (
    SELECT productid, SUM(net) AS revenue
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
```

**Python:**
```python
cat_rev = nonret_merged_prod.groupby('category')['net'].sum().sort_values(ascending=False)
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

## 🛠️ Scripts & Notebooks Reference (Updated 2026-05-25)

### 🐍 Python Core & Local Orchestration
| Script | Description |
|--------|-------------|
| `run_pipeline.py` | **End-to-End local pipeline orchestrator.** Automatically runs the python generation subprocess, connects to SQL, handles `GO` batching, runs DB load, views, and outputs DQ and schema verification tables to console. Supports customized separate folder paths. |
| `generate_retail_data.py` | Generates all CSV files with realistic distributions, quantity scaling, and fraction-based percentages. |
| `analyze_csv_data.py` | Standalone analytical script that reads CSV files. Optimized to select only required columns during merges to reduce memory consumption by >70% on 10M rows. |

### 🛢️ SQL Server Scripts (Execution Order)
| # | Script | Description |
|---|--------|-------------|
| 1 | `build_retailanalytics_database.sql` | **ELT DB Builder.** Creates `staging` and `dbo` schemas. Uses fast `BULK INSERT` into staging, inserts into production, and builds Primary Keys, Foreign Keys, and a Clustered Columnstore Index (CCI) *last* for maximum speed. |
| 2 | `create_analytical_views.sql` | Creates 17 analytical views with fraction-based margin/discount columns. Optimized using "Aggregate-then-Join" CTEs. |
| 3 | `validate_retail_data_quality.sql` | Comprehensive data quality checks (60+ tests) properly ignoring dummy rows (`-1`/`0`) in checks. |
| 4 | `analyze_product_margins.sql` | Detailed margin distribution analysis with pure T-SQL visual histogram. |
| 5 | `validate_star_schema_model.sql` | Verifies star schema metadata, CCI presence, and ensures all constraints are fully trusted. |
| 6 | `quick_data_quality_checks.sql` | Lightweight sanity checks with formatted monetary values. |

### ☁️ Microsoft Fabric Notebooks (Execution Order)
| # | Script | Description |
|---|--------|-------------|
| 1 | `ingest_bronze_layer.py` | Loads CSV files into Bronze Delta tables with audit columns. Bypasses `inferSchema` using strict StructType declarations. |
| 2 | `transform_silver_layer.py` | Cleans, casts types, deduplicates, and evaluates all schema shifts in a single projection pass (prevents memory bloat). |
| 3 | `create_gold_views.py` | Creates 17 materialized Gold analytical Delta tables using optimized "Aggregate-then-Join" CTEs. |
| 4 | `optimize_delta_tables.py` | Delta Lake compaction and single-pass Z-ordering on 3 keys (`datekey`, `productid`, `customerid`). |
| 5 | `validate_fabric_layers.sql` | Data quality checks for Silver and Gold layers in Fabric SQL Endpoint. |
| 6 | `analyze_silver_data.py` | Analytical queries on Silver data consolidating multiple head() scans into single Spark jobs. |

---

## 🛠️ How to Update Dashboard Screenshots

1. Place your new screenshot files in the `images/` folder at the root of the repository.
2. File names must match exactly: `revenue_trend.jpg`, `payment_matrix.jpg`, `monthly_revenue.jpg`.
3. Push to GitHub — images will appear automatically in both README and this documentation.

> **Note for docs folder:** This file lives in `docs/`. Image paths use `../images/` to reference the `images/` folder one level up. If you move this file, update the paths accordingly.
> **Related Links:** For an overview of setup and deployment steps, consult the [README.md](../README.md) 🚀.

---

## 📝 License

MIT – free to use, modify, and distribute.