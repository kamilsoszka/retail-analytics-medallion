# 📖 Retail Analytics – Complete Technical Documentation

**Suggested file name:** `complete_documentation.md`  
**Author:** DataGen AI & Assistant  
**Date:** 2026-05-25  
**Description:** Full technical documentation of the retailanalytics star schema, data generation rules, table schemas with suggested business aliases, advanced query reference (T‑SQL, DAX, Python), security roles (RLS), VertiPaq engine optimizations, and dashboard metrics. All percentage columns are stored as decimal fractions, monetary values use thousand separators with zero decimals, and percentage displays show two decimal places.
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

## 🔒 Row-Level Security (RLS) Specification

To enforce data privacy across regional business units, the model implements static Row-Level Security (RLS) within the reporting layer. 

### Regional Security Roles
Security filtering is applied to the `region` column in `dim_store`. Because of the active 1-to-many relationship, filtering the store dimension automatically propagates and filters the `fact_sales` transactional table.

| Role Name | DAX Filter Expression (Power BI) | Business Purpose |
|-----------|---------------------------------|------------------|
| `Regional_Manager_North` | `dimstore[region] = "North"` | Restricts visibility to North region stores and sales. |
| `Regional_Manager_South` | `dimstore[region] = "South"` | Restricts visibility to South region stores and sales. |
| `Regional_Manager_East` | `dimstore[region] = "East"` | Restricts visibility to East region stores and sales. |
| `Regional_Manager_West` | `dimstore[region] = "West"` | Restricts visibility to West region stores and sales. |
| `Regional_Manager_Central` | `dimstore[region] = "Central"` | Restricts visibility to Central region stores and sales. |

### Optional T-SQL Database-Level RLS Implementation
For direct SQL endpoint queries, RLS can be enforced natively in SQL Server using a Security Predicate Function:

```sql
CREATE FUNCTION Security.fn_securitypredicate_region(@storeid INT)
    RETURNS TABLE
WITH SCHEMABINDING
AS
    RETURN SELECT 1 AS fn_securitypredicate_result
    FROM dbo.dimstore s
    WHERE s.storeid = @storeid
      AND (s.region = USER_NAME() OR USER_NAME() = 'dbo');
GO

CREATE SECURITY POLICY Security.StoreRegionPolicy
    ADD FILTER PREDICATE Security.fn_securitypredicate_region(storeid) ON dbo.factsales,
    ADD FILTER PREDICATE Security.fn_securitypredicate_region(storeid) ON dbo.dimstore
    WITH (STATE = ON);
GO
```

---

## ⚡ Semantic Model Optimization & Self-Service BI

To ensure enterprise-grade performance and business adoption, the final semantic model was optimized and integrated for self-service reporting:

- **VertiPaq Engine Optimization:** Using **DAX Studio** and **VertiPaq Analyzer**, column cardinalities, relationships, and dictionary sizes were audited. Highly-precise datatypes (such as fractions for `_pct` columns and targeted decimals) were enforced in the silver/gold layers to achieve maximum columnar compression in memory.
- **Analyze in Excel Integration:** Designed and secured the semantic model to support native AD-Hoc reporting. Business and finance stakeholders can connect directly to the centralized, single-source-of-truth Fabric model using Excel Pivot Tables, preventing local file fragmentation and data security breaches.

---

## 🗄️ Table Definitions

### 1. `dim_date`
*Includes one technical dummy record (`datekey = -1`) representing an Unknown or Invalid Date.*

| Column | Type | Nullability | Business Alias | Business Purpose |
|--------|------|-------------|----------------|------------------|
| **datekey** | INT | NOT NULL | Date Key | YYYYMMDD surrogate key (PK) connecting the Fact Table to Date dimension. |
| fulldate | DATE | NOT NULL | Calendar Date | Calendar date representing the actual day, used for standard date filters. |
| year | SMALLINT | NOT NULL | Year | Calendar Year (e.g. 2026), crucial for Year-over-Year (YoY) aggregations. |
| quarternumber | TINYINT | NOT NULL | Quarter Number | Numeric representation of the quarter (1 to 4). |
| quartername | NCHAR(2) | NOT NULL | Quarter | Business representation of the quarter (Q1 to Q4). |
| monthnumber | TINYINT | NOT NULL | Month Number | Calendar month index (1 to 12). |
| monthname | NVARCHAR(20) | NOT NULL | Month Name | Full string month name (e.g. January), used in bar charts and visual axes. |
| weekdaynumber | TINYINT | NOT NULL | Weekday Number | Day index (1=Monday to 7=Sunday) for weekly distribution profiling. |
| weekdayname | NVARCHAR(20) | NOT NULL | Weekday | Full day name (e.g. Monday), used for weekly sales analysis. |
| isweekend | TINYINT | NOT NULL | Is Weekend | Binary flag (1/0) to quickly evaluate weekend shopping behaviors. |
| yearmonth | NCHAR(7) | NOT NULL | Year-Month | Formatted YYYY-MM string, optimal for chronological trend charts. |
| yearmonthnumber | INT | NOT NULL | Year-Month ID | YYYYMM integer, highly optimal for sorting chronological fields. |
| yearquarter | NVARCHAR(7) | NOT NULL | Year-Quarter | Formatted YYYY-QX string for quarterly analytical trends. |
| yearquarternumber | INT | NOT NULL | Year-Quarter ID | YYYYQ integer used for sequential sorting of quarters. |
| yearweek | NVARCHAR(8) | NOT NULL | Year-Week | Formatted YYYY-Www string for weekly operational audits. |
| yearweeknumber | INT | NOT NULL | Year-Week ID | Sequential integer representing the calendar week for ordering. |
| isholiday | TINYINT | NOT NULL | Is Holiday | Flag indicating major holiday periods (December/January/July). |

### 2. `dim_customer`
*Includes one technical dummy record (`customerid = -1`) representing an Unknown Customer.*

| Column | Type | Nullability | Business Alias | Business Purpose |
|--------|------|-------------|----------------|------------------|
| **customerid** | INT | NOT NULL | Customer ID | Surrogate primary key (PK) to uniquely identify retail customers. |
| fullname | NVARCHAR(100) | NOT NULL | Customer Name | Combined first and last name, anonymized for CRM-ready modeling. |
| email | NVARCHAR(100) | NOT NULL | Email Address | Unique contact email. |
| age | TINYINT | NOT NULL | Age | Customer age at registration, used for demographic cohorting. |
| gender | NVARCHAR(20) | NOT NULL | Gender | Restricted strictly to Male/Female values. |
| city | NVARCHAR(50) | NOT NULL | Customer City | City of residence, utilized for regional customer split. |
| tier | NVARCHAR(20) | NOT NULL | Loyalty Tier | Predefined loyalty levels (Bronze, Silver, Gold, Platinum). |
| points | INT | NOT NULL | Loyalty Points | Accrued active loyalty points from purchase amounts. |
| isactive | TINYINT | NOT NULL | Is Active | Flag indicating whether the customer profile is active or churned. |
| lang | NVARCHAR(10) | NOT NULL | Language | Preferred contact language code (e.g., 'en', 'pl'). |
| totalspend | DECIMAL(18,2) | NOT NULL | Total Lifetime Spend | Sum of lifetime net expenditures, crucial for customer LTV. |
| regdate | DATE | NOT NULL | Registration Date | Date when the customer joined the loyalty program. |
| annualincome | DECIMAL(18,2) | NOT NULL | Annual Income | Customer salary estimate, used to evaluate purchase power. |
| incomebracket | NVARCHAR(20) | NOT NULL | Income Bracket | Categorical income ranges (Low to Ultra High) for segmentation. |
| education | NVARCHAR(50) | NOT NULL | Education Level | Academic background of the consumer. |
| maritalstatus | NVARCHAR(20) | NOT NULL | Marital Status | Single, Married, Divorced, or Widowed classification. |
| childrencount | TINYINT | NOT NULL | Children Count | Number of dependents, used for household size clustering. |
| loyaltysegment | NVARCHAR(20) | NOT NULL | Loyalty Segment | Redundant/denormalized tier mapping for direct slicing. |
| satisfactionscore | DECIMAL(5,1) | NOT NULL | Satisfaction Score | NPS/CSAT metric on a 1.0 to 5.0 scale. |
| dayssincelastpurchase | INT | NOT NULL | Recency Days | Days since last transaction, core input for RFM modeling. |
| hassubscription | TINYINT | NOT NULL | Has Newsletter | Flag indicating active marketing communication opt-in. |
| preferredcontact | NVARCHAR(20) | NOT NULL | Preferred Channel | Choice of Email, SMS, Phone, or physical Mail for campaigns. |
| spendmultiplier | DECIMAL(10,3) | NOT NULL | Spend Multiplier | Behavior multiplier based on income and loyalty history. |

### 3. `dim_product`
*Includes one technical dummy record (`productid = -1`) representing an Unknown Product.*

| Column | Type | Nullability | Business Alias | Business Purpose |
|--------|------|-------------|----------------|------------------|
| **productid** | INT | NOT NULL | Product ID | Unique surrogate primary key (PK) for product catalog management. |
| name | NVARCHAR(150) | NOT NULL | Product Name | Fully descriptive brand name and product variant. |
| category | NVARCHAR(50) | NOT NULL | Category | Primary business category (Electronics, Home, Sports, Kids, Garden). |
| brand | NVARCHAR(50) | NOT NULL | Brand | Product brand name. |
| unitcost | DECIMAL(18,2) | NOT NULL | Unit Cost | Internal supply acquisition cost, used for COGS evaluation. |
| unitprice | DECIMAL(18,2) | NOT NULL | Regular Price | Standard shelf selling price, used for gross revenue. |
| margin_pct | DECIMAL(5,4) | NOT NULL | Target Margin % | Intrinsic product profit margin, stored as decimal fraction (e.g. `0.1196`). |
| weight | DECIMAL(10,2) | NOT NULL | Weight (kg) | Package weight in kilograms, used to compute shipping rates. |
| color | NVARCHAR(20) | NOT NULL | Color | Visual aesthetic attribute of the product. |
| material | NVARCHAR(50) | NOT NULL | Material | Primary composition material. |
| supplierid | INT | NOT NULL | Supplier ID | Identifier of the supplying partner (1 to 50). |
| isactive | TINYINT | NOT NULL | Is Active Product | Flag representing if the item is currently active in catalogs. |
| minstock | INT | NOT NULL | Safety Stock Level | Minimum inventory threshold before trigger reorder. |
| tax_rate | DECIMAL(5,4) | NOT NULL | Tax Rate % | VAT / Sales tax percentage (stored as fraction, e.g., 0.21). |
| haswarranty | TINYINT | NOT NULL | Has Warranty | Flag indicating whether the item includes product warranty. |
| ecofriendly | TINYINT | NOT NULL | Is Eco-Friendly | Flag indicating if product has sustainable score above threshold. |
| seasonalityfactor | DECIMAL(5,2) | NOT NULL | Seasonality Factor | Demand multiplier (0.7–1.3) |
| warrantymonths | TINYINT | NOT NULL | Warranty Months | Duration of warranty in months (12, 24, 36). |
| ecoscore | TINYINT | NOT NULL | Eco Score | Numeric index of environmental impact (20 to 200). |
| releaseyear | SMALLINT | NOT NULL | Release Year | Year the product model was introduced. |
| skucount | INT | NOT NULL | SKU Count | Number of variants available for this product. |
| isdiscontinued | TINYINT | NOT NULL | Is Discontinued | Flag representing obsolete inventory. |
| productrating | DECIMAL(3,1) | NOT NULL | Rating | Average consumer rating (1.0 to 5.0). |
| stockstatus | NVARCHAR(20) | NOT NULL | Inventory Status | In Stock, Low Stock, or Out of Stock classification. |

### 4. `dim_store`
*Includes one technical dummy record (`storeid = -1`) representing an Unknown Store.*

| Column | Type | Nullability | Business Alias | Business Purpose |
|--------|------|-------------|----------------|------------------|
| **storeid** | INT | NOT NULL | Store ID | Unique primary key (PK) for brick-and-mortar retail stores. |
| storename | NVARCHAR(150) | NOT NULL | Store Name | Full descriptive name combining brand name, city, and location. |
| city | NVARCHAR(50) | NOT NULL | Store City | Physical city location of the store. |
| type | NVARCHAR(50) | NOT NULL | Store Type | Format category (Supermarket, Hypermarket, Convenience, Department). |
| staff | SMALLINT | NOT NULL | Employee Count | Active staff head-count, used to compute labor efficiency. |
| sizem2 | INT | NOT NULL | Size (sqm) | Floor size in square meters, crucial for sales-per-sqm metrics. |
| hascafe | TINYINT | NOT NULL | Has Cafe | Flag indicating presence of store-in-store cafe facilities. |
| openingyear | SMALLINT | NOT NULL | Opening Year | Year the store was opened. |
| region | NVARCHAR(50) | NOT NULL | Store Region | Regional group (North, South, East, West, Central). |
| renovationyear | SMALLINT | NOT NULL | Last Renovation | Year of last store refresh (0 = never). |
| parkingspots | SMALLINT | NOT NULL | Parking Spots | Available customer parking spaces. |
| storerating | DECIMAL(3,1) | NOT NULL | Store Rating | Customer satisfaction rating for the store (2.0 to 5.0). |
| hasdeliveryservice | TINYINT | NOT NULL | Has Local Delivery | Flag indicating store-to-home delivery services. |
| floornumber | TINYINT | NOT NULL | Floor Count | Multi-level store vertical count. |
| distancetocitycenterkm | DECIMAL(8,1) | NOT NULL | Distance to City Center | km distance to evaluated downtown zones. |
| annualrentcost | DECIMAL(18,2) | NOT NULL | Annual Rent Cost | Yearly property rent in USD. |
| storesizemultiplier | DECIMAL(10,4) | NOT NULL | Size Multiplier | Store scaling factor relative to the average size. |

### 5. `dim_promotion`
*Includes `promoid = 0` (No Promotion) and `promoid = -1` (Unknown Promotion) technical dummy rows.*

| Column | Type | Nullability | Business Alias | Business Purpose |
|--------|------|-------------|----------------|------------------|
| **promoid** | INT | NOT NULL | Promotion ID | Unique primary key (PK) to track marketing promotions. |
| promoname | NVARCHAR(150) | NOT NULL | Campaign Name | Business campaign name. |
| discount_pct | DECIMAL(5,4) | NOT NULL | Campaign Discount % | Discount rate stored as decimal fraction (e.g. `0.2500` = 25% OFF). |
| discount_fixed | DECIMAL(10,2) | NOT NULL | Fixed Discount | Cash-back or voucher discount in USD. |
| type | NVARCHAR(50) | NOT NULL | Promo Type | Mechanics (Percentage, Fixed Amount, BOGO, Free Shipping). |
| isactive | TINYINT | NOT NULL | Is Active Campaign | Flag indicating active marketing campaigns. |
| minspend | INT | NOT NULL | Minimum Spend | Minimum purchase threshold required to activate promotion. |
| channel | NVARCHAR(50) | NOT NULL | Marketing Channel | Campaign delivery medium (Email, SMS, App, InStore, etc.). |
| budget | DECIMAL(18,2) | NOT NULL | Campaign Budget | Total allocated marketing expenditure. |
| startdate | DATE | NOT NULL | Start Date | Launch date of the promotion. |
| enddate | DATE | NOT NULL | End Date | Conclusion date of the promotion. |
| targetaudience | NVARCHAR(50) | NOT NULL | Target Segment | Targeted group (All, New, Loyal, HighSpend). |
| maxdiscountcap | DECIMAL(18,2) | NOT NULL | Discount Cap | Maximum discount limit per transaction. |
| isstackable | TINYINT | NOT NULL | Is Stackable | Flag representing if campaign can combine with other discounts. |
| redemption_rate | DECIMAL(5,3) | NOT NULL | Redemption Rate % | Target coupon redemption rate, stored as fraction. |
| coderequired | TINYINT | NOT NULL | Requires Promo Code | Flag indicating if manual code entry is needed. |
| promoupliftfactor | DECIMAL(6,3) | NOT NULL | Promo Uplift | Expected sales volume multiplier under promotion. |

### 6. `fact_sales`
*The core transactional table containing 10,000,000 sales and return line items.*

| Column | Type | Nullability | Business Alias | Business Purpose |
|--------|------|-------------|----------------|------------------|
| **salesid** | BIGINT | NOT NULL | Transaction ID | Unique primary key (PK) representing a line-item transaction. |
| datekey | INT | NOT NULL | Date Key | FK pointing to the Date Dimension, resolving transaction dates. |
| productid | INT | NOT NULL | Product ID | FK pointing to the Product Catalog. |
| customerid | INT | NOT NULL | Customer ID | FK pointing to the Customer CRM. |
| storeid | INT | NOT NULL | Store ID | FK pointing to the Retail Store. |
| promoid | INT | NOT NULL | Promotion ID | FK pointing to the Campaign Dimension (0 = no promotion). |
| qty | INT | NOT NULL | Sales Quantity | Items purchased. Negative if it's a return. |
| unitprice | DECIMAL(18,2) | NOT NULL | Unit Price | Actual selling price per unit at the time of purchase. |
| tax_rate | DECIMAL(5,4) | NOT NULL | Tax Rate % | Tax rate applied to this sale (stored as fraction). |
| net | DECIMAL(18,2) | NOT NULL | Net Sales (Revenue) | Net revenue generated, calculated as: `grossvalue - discount + tax`. |
| payment | NVARCHAR(20) | NOT NULL | Payment Method | Customer choice (Card, Cash, PayPal, Digital Wallet, Bank Transfer). |
| channel | NVARCHAR(20) | NOT NULL | Sales Channel | Point of purchase (Online, In-Store, Mobile App, Phone Order). |
| grossvalue | DECIMAL(18,2) | NOT NULL | Gross Sales Value | Pre-discount sales total: `qty * unitprice`. |
| discountamount | DECIMAL(18,2) | NOT NULL | Discount Amount | Total monetary value of discount applied. |
| taxamount | DECIMAL(18,2) | NOT NULL | Tax Amount | Total VAT/sales tax paid by consumer. |
| shipcost | DECIMAL(18,2) | NOT NULL | Shipping Cost | Shipping fee charged (0 for In-Store transactions). |
| isreturn | TINYINT | NOT NULL | Is Return | Binary flag (1 = Return, 0 = Sale). Returns negate monetary values. |
| shipweight | DECIMAL(10,2) | NOT NULL | Shipping Weight | Transaction package weight: `qty * product weight`. |
| discountapplied | TINYINT | NOT NULL | Is Discounted | Flag indicating whether any discount was applied. |
| returnreason | NVARCHAR(50) | NOT NULL | Return Reason | Defective, Wrong item, Changed mind, etc. (No return if `isreturn = 0`). |
| deliverydays | TINYINT | NOT NULL | Delivery Days | Logistical delivery duration (0 for In-Store transactions). |
| hour | TINYINT | NOT NULL | Purchase Hour | Hour of transaction (0-23) used for time-of-day analytics. |

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
SELECT p.category, FORMAT(SUM(sa.revenue), 'N0') AS revenue
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

## 🚀 Advanced Analytical Scenarios

These advanced scenarios provide enterprise-grade analytics covering YoY growth, customer cohorts, and basket analysis.

### 11. Year-over-Year (YoY) Monthly Sales Growth
*Calculates monthly revenue growth compared to the same month of the previous year, showing the growth percentage.*

**T-SQL (Optimized):**
```sql
WITH MonthlySales AS (
    SELECT d.[year] AS SalesYear,
           d.monthnumber AS SalesMonth,
           SUM(f.net) AS MonthlyRevenue
    FROM dbo.factsales f
    INNER JOIN dbo.dimdate d ON f.datekey = d.datekey
    WHERE f.isreturn = 0
    GROUP BY d.[year], d.monthnumber
)
SELECT cur.SalesYear, 
       cur.SalesMonth,
       FORMAT(cur.MonthlyRevenue, 'N0') AS CurrentRevenue,
       FORMAT(prev.MonthlyRevenue, 'N0') AS PriorYearRevenue,
       FORMAT((cur.MonthlyRevenue - prev.MonthlyRevenue) / NULLIF(prev.MonthlyRevenue, 0) * 100, 'N2') + '%' AS YoYGrowthPct
FROM MonthlySales cur
LEFT JOIN MonthlySales prev ON cur.SalesYear = prev.SalesYear + 1 AND cur.SalesMonth = prev.SalesMonth
ORDER BY cur.SalesYear, cur.SalesMonth;
```

**DAX:**
```dax
YoY Revenue Growth % = 
VAR CurrentRevenue = [Total Revenue]
VAR PriorYearRevenue = CALCULATE([Total Revenue], SAMEPERIODLASTYEAR(dimdate[fulldate]))
RETURN DIVIDE(CurrentRevenue - PriorYearRevenue, PriorYearRevenue, 0)
```

**Python (Pandas):**
```python
monthly = nonret_date.groupby(['year', 'monthnumber'])['net'].sum().reset_index()
monthly['prior_year_net'] = monthly.groupby('monthnumber')['net'].shift(1)
monthly['yoy_growth_pct'] = (monthly['net'] - monthly['prior_year_net']) / monthly['prior_year_net'] * 100
```

### 12. Advanced Customer RFM Segmentation
*Generates customer-level RFM metrics (Recency, Frequency, Monetary) and aggregates them into strategic cohorts.*

**T-SQL (Optimized):**
```sql
WITH CustomerMetrics AS (
    SELECT f.customerid,
           DATEDIFF(day, MAX(d.fulldate), CAST(GETDATE() AS DATE)) AS Recency,
           COUNT(DISTINCT f.salesid) AS Frequency,
           SUM(f.net) AS Monetary
    FROM dbo.factsales f
    INNER JOIN dbo.dimdate d ON f.datekey = d.datekey
    WHERE f.isreturn = 0
    GROUP BY f.customerid
),
ScoredMetrics AS (
    SELECT customerid, Recency, Frequency, Monetary,
           NTILE(5) OVER (ORDER BY Recency DESC) AS R_Score,
           NTILE(5) OVER (ORDER BY Frequency ASC) AS F_Score,
           NTILE(5) OVER (ORDER BY Monetary ASC) AS M_Score
    FROM CustomerMetrics
)
SELECT customerid, Recency, Frequency, Monetary, R_Score, F_Score, M_Score,
       CASE 
           WHEN R_Score >= 4 AND F_Score >= 4 THEN 'Champions'
           WHEN R_Score >= 4 AND F_Score >= 3 THEN 'Loyal'
           WHEN R_Score >= 3 AND M_Score >= 4 THEN 'Big Spenders'
           WHEN R_Score <= 2 AND F_Score <= 2 THEN 'At Risk'
           WHEN R_Score = 1 THEN 'Lost'
           ELSE 'Other'
       END AS Segment
FROM ScoredMetrics;
```

**DAX (Calculated Table):**
```dax
RFM Table = 
SUMMARIZE(
    FILTER(factsales, factsales[isreturn] = 0),
    factsales[customerid],
    "Recency", DATEDIFF(MAX(dimdate[fulldate]), TODAY(), DAY),
    "Frequency", DISTINCTCOUNT(factsales[salesid]),
    "Monetary", SUM(factsales[net])
)
```

**Python (Pandas):**
```python
customer_rfm = nonret_date.groupby('customerid').agg(
    recency=('fulldate', lambda x: (pd.to_datetime('today') - pd.to_datetime(x).max()).days),
    frequency=('salesid', 'nunique'),
    monetary=('net', 'sum')
).reset_index()

customer_rfm['r_score'] = pd.qcut(customer_rfm['recency'].rank(method='first'), 5, labels=[5,4,3,2,1])
customer_rfm['f_score'] = pd.qcut(customer_rfm['frequency'].rank(method='first'), 5, labels=[1,2,3,4,5])
customer_rfm['m_score'] = pd.qcut(customer_rfm['monetary'].rank(method='first'), 5, labels=[1,2,3,4,5])
```

### 13. Market Basket Analysis (Top Product Pairs)
*Finds the Top 100 product combinations bought together in the same basket, indicating cross-sell lift.*

**T-SQL (Optimized):**
```sql
WITH TransactionProducts AS (
    SELECT DISTINCT salesid, productid
    FROM dbo.factsales
    WHERE isreturn = 0
),
ProductPairs AS (
    SELECT p1.productid AS ProductA,
           p2.productid AS ProductB,
           COUNT(*) AS CoOccurrenceCount
    FROM TransactionProducts p1
    INNER JOIN TransactionProducts p2 ON p1.salesid = p2.salesid AND p1.productid < p2.productid
    GROUP BY p1.productid, p2.productid
)
SELECT TOP 100 
       pa.ProductA, pa.ProductB, pa.CoOccurrenceCount,
       prodA.name AS ProductAName, prodB.name AS ProductBName
FROM ProductPairs pa
INNER JOIN dbo.dimproduct prodA ON pa.ProductA = prodA.productid
INNER JOIN dbo.dimproduct prodB ON pa.ProductB = prodB.productid
ORDER BY pa.CoOccurrenceCount DESC;
```

**DAX (Co-Purchase Measure):**
```dax
Co-Purchased Products Count = 
VAR CurrentProduct = SELECTEDVALUE(dimproduct[productid])
RETURN
CALCULATE(
    DISTINCTCOUNT(factsales[salesid]),
    CALCULATETABLE(
        SUMMARIZE(factsales, factsales[salesid]),
        ALL(dimproduct)
    ),
    factsales[isreturn] = 0
)
```

**Python (Pandas):**
```python
tx_prods = nonret_fact[['salesid', 'productid']].drop_duplicates()
pairs = tx_prods.merge(tx_prods, on='salesid')
pairs = pairs[pairs['productid_x'] < pairs['productid_y']]
top_pairs = pairs.groupby(['productid_x', 'productid_y']).size().reset_index(name='co_occurrence').sort_values('co_occurrence', ascending=False).head(100)
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