# 🛒 Retail Analytics – Medallion Architecture Pipeline

[![Python 3.9+](https://img.shields.io/badge/Python-3.9+-blue.svg)](https://www.python.org/)
[![SQL Server](https://img.shields.io/badge/SQL%20Server-2019-red.svg)](https://www.microsoft.com/en-us/sql-server)
[![Power BI](https://img.shields.io/badge/Power%20BI-Desktop-yellow.svg)](https://powerbi.microsoft.com/)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

## 📌 Overview

This project delivers an **end‑to‑end retail analytics solution** based on the **Medallion Architecture** (Bronze → Silver → Gold). It generates **5 million synthetic sales records**, processes them through a star‑schema database, validates data quality, and presents interactive dashboards in Power BI. The entire pipeline is implemented both in **SQL Server** (on‑premise) and **Microsoft Fabric** (cloud lakehouse), demonstrating cross‑platform proficiency.

**Why this project stands out:**
- Realistic retail data generation (customers, products, stores, promotions, returns)
- Rigorous data quality & model validation (automated checks)
- Advanced analytical views (RFM segmentation, Pareto, promotion uplift, seasonality, delivery impact)
- Row‑level security (RLS) ready for production
- Fully documented with T‑SQL and DAX measure examples
- Reproducible and cloud‑ready (Fabric notebooks)

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

## 📁 Repository Structure

    retail-analytics-medallion/
    ├── generator.py                # Python data generator (5M rows + dimensions)
    ├── sql/
    │   ├── 01_create_database.sql   # Creates DB, loads CSVs, keys, indexes, columnstore
    │   ├── 02_model_validation.sql  # Validates star schema, foreign keys, columnstore
    │   ├── 03_data_quality_checks.sql # 30+ value‑based tests (all pass)
    │   └── 04_analytical_views.sql   # 10 gold views for business insights
    ├── docs/
    │   └── DOCUMENTATION.md         # Full documentation (tables, all T‑SQL, DAX, Python)
    └── README.md                    # This file

## 🚀 How to Run (Local SQL Server)

### Prerequisites
- Python 3.9+ with `pandas`, `numpy`, `matplotlib`, `seaborn`, `scikit-learn`, `scipy`
- SQL Server 2019+ (or Azure SQL Database)
- SSMS (SQL Server Management Studio)
- (Optional) Power BI Desktop

### Step‑by‑Step

1. **Generate CSV files**  
   `python generator.py` → all CSVs to `c:/data/` (the generator automatically deletes old files).

2. **Create and load the database**  
   In SSMS, execute `sql/01_create_database.sql`.  
   This script:
   - Drops/recreates `retailanalytics`
   - Loads all CSV files via `BULK INSERT`
   - Adds primary/foreign keys, indexes, and a clustered columnstore index on `factsales`
   - Forces `deliverydays = 0` for `In-Store` transactions (even if the CSV is wrong)

3. **Validate the model**  
   Run `sql/02_model_validation.sql`. All checks should return `OK`.

4. **Run data quality checks**  
   Execute `sql/03_data_quality_checks.sql`. All tests must pass (no `FAIL`).  
   *We have verified that all tests pass with the final generator and loader.*

5. **Build analytical views**  
   Execute `sql/04_analytical_views.sql`. This creates 10 gold views in the `retailanalytics` database.

6. **Connect Power BI**  
   Use DirectQuery mode to `retailanalytics`.  
   The full set of DAX measures is provided in `docs/DOCUMENTATION.md`.

## 📊 Key Business Insights (from Gold Views)

| Insight | Finding |
|---------|---------|
| **Product margin** | Kids products >30% margin; BOGO promotions are the only consistently profitable type. |
| **Customer RFM** | Champions (53k) and Big Spenders (16k) generate 85% of total LTV. At‑Risk segment (55k) needs retention. |
| **Returns** | Online accounts for 65% of returns (defective 24%, late delivery 20%). Fast delivery cuts returns by 80%. |
| **Channel performance** | In‑Store is the only profitable channel (+$32 margin/transaction). Online and Mobile App lose money. |
| **Seasonality** | December drives Electronics ($269M), Home ($98M), Kids ($32M). July peaks for Sports and Garden. |
| **Pareto margin** | 483 products (24%) contribute 80% of total margin. |
| **Delivery speed** | Long delivery (>5 days) increases return rates to 33‑35% (5‑10x higher than fast delivery). |
| **Warranty impact** | Products with warranty generate twice the revenue and have 30% lower return rates. |

## 📄 Full Documentation

For complete table definitions, all T‑SQL queries (basic and advanced), all DAX measures (basic and extended), and the Python verification script, see [`docs/DOCUMENTATION.md`](docs/DOCUMENTATION.md).

## ✅ Quality & Integrity

- No orphan rows (foreign keys fully satisfied).
- Financial equation holds: `net = grossvalue - discountamount + taxamount` (tolerance 0.01).
- `deliverydays = 0` for all `In-Store` transactions (enforced in both generator and loader).
- All percentages stored as fractions (e.g., `0.15` = 15%) – easy to format in Power BI.
- Clustered columnstore index on `factsales` for fast aggregations.

## 🤝 Contributing

This project is part of a portfolio. Issues and pull requests are welcome.

## 📜 License

MIT © 2025 Kamil Soszka

**Last update: 2025-05-19**