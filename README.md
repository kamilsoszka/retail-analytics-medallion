# 🛒 Retail Analytics – Medallion Architecture Pipeline

[![Python 3.9+](https://img.shields.io/badge/Python-3.9+-blue.svg)](https://www.python.org/)
[![SQL Server](https://img.shields.io/badge/SQL%20Server-2019-red.svg)](https://www.microsoft.com/en-us/sql-server)
[![Power BI](https://img.shields.io/badge/Power%20BI-Desktop-yellow.svg)](https://powerbi.microsoft.com/)
[![Fabric](https://img.shields.io/badge/Microsoft-Fabric-purple.svg)](https://microsoft.com/fabric)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

## 📌 Project Overview

This project delivers an **end‑to‑end retail data analytics solution** based on the **Medallion Architecture** (Bronze → Silver → Gold). It generates **5 million synthetic sales records**, processes them through a star‑schema database, validates data quality, and finally presents interactive dashboards in Power BI. The entire pipeline is implemented both in **SQL Server** (on‑premise) and **Microsoft Fabric** (cloud lakehouse), demonstrating cross‑platform proficiency.

**Why this project stands out:**
- Realistic retail data generation (customers, products, stores, promotions, returns)
- Rigorous data quality & model validation (automated checks)
- Advanced analytical views (RFM segmentation, Pareto, promotion uplift, seasonality, delivery impact)
- Row‑level security (RLS) ready for production
- Fully documented with T‑SQL and DAX measure examples
- Reproducible and cloud‑ready (Fabric notebooks)

---

## 🧱 Architecture & Technologies

| Layer | Technology | Purpose |
|-------|------------|---------|
| **Data Generation** | Python (pandas, numpy) | Creates 5M fact rows + dimension CSVs |
| **Bronze (Raw)** | SQL Server / Fabric Delta | Stores raw CSV data with audit columns |
| **Silver (Cleaned)** | SQL / PySpark | Deduplicates, casts types, adds timestamps |
| **Gold (Aggregated)** | SQL / Spark SQL | 10 business‑ready analytical tables |
| **Reporting** | Power BI (DirectQuery) | Interactive dashboards with RLS |
| **Validation** | T‑SQL, Spark SQL | Data quality, foreign keys, range checks |
| **Orchestration** | Fabric Pipeline | Automated notebook execution |

---

## 📁 Repository Structure


---

## 📊 Business Insights at a Glance (from Gold Views)

| View | Key Finding |
|------|--------------|
| **Product Margin** | Kids products >30% margin; Garden & many Sports products lose money. |
| **Promotion Performance** | BOGO promotions are the only consistently profitable type. Percentage discounts >30% destroy value (negative margin). |
| **Customer RFM** | Champions (53k customers) and Big Spenders (16k) generate 85% of total LTV. At‑Risk segment (55k) needs retention. |
| **Returns Analysis** | Online accounts for 65% of returns (defective 24%, late delivery 20%). Fast delivery (1‑2 days) cuts returns by 80%. |
| **Channel Performance** | In‑Store is the only profitable channel (+$32 margin/transaction). Online and Mobile App lose money. |
| **Seasonality** | December drives Electronics ($269M), Home ($98M), Kids ($32M). July peaks for Sports ($48.7M) and Garden ($25.3M). |
| **Pareto Margin** | 483 products (24% of total) contribute 80% of total margin. |
| **Delivery Speed** | Long delivery (>5 days) increases return rates to 33‑35% (5‑10x higher than fast delivery). |
| **Warranty Impact** | Products with warranty generate twice the revenue and have 30% lower return rates. |

---

## 🚀 How to Run the Project (Local SQL Server)

### Prerequisites
- Python 3.9+ with `pandas`, `numpy`
- SQL Server 2019+ (or Azure SQL Database)
- Power BI Desktop (October 2023 or later)

### Step‑by‑step

1. **Generate data**
   ```bash
   cd data_generation
   python 01_Generate_Data_Python.py

   -- Total Revenue (net after discount, tax included)
SELECT SUM(net) FROM dbo.factsales WHERE isreturn = 0;

-- Total Cost
SELECT SUM(f.qty * p.unitcost) FROM dbo.factsales f
JOIN dbo.dimproduct p ON f.productid = p.productid
WHERE f.isreturn = 0;

-- Margin %
SELECT (SUM(f.net - (f.qty * p.unitcost)) / NULLIF(SUM(f.net), 0)) AS margin_pct
FROM dbo.factsales f JOIN dbo.dimproduct p ON f.productid = p.productid
WHERE f.isreturn = 0;

-- Return Rate
SELECT 1.0 * SUM(CASE WHEN isreturn = 1 THEN 1 ELSE 0 END) / COUNT(*) FROM dbo.factsales;

Total Revenue = SUMX(FILTER(factsales, factsales[isreturn] = 0), factsales[net])

Total Cost = SUMX(FILTER(factsales, factsales[isreturn] = 0), factsales[qty] * RELATED(dimproduct[unitcost]))

Total Margin = [Total Revenue] - [Total Cost]

Margin % = DIVIDE([Total Margin], [Total Revenue], 0)

Return Rate = DIVIDE(COUNTROWS(FILTER(factsales, factsales[isreturn]=1)), COUNTROWS(factsales), 0)
