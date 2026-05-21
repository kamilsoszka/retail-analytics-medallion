# 🛒 Retail Analytics – Medallion Architecture Pipeline

[![Python 3.9+](https://img.shields.io/badge/Python-3.9+-blue.svg)](https://www.python.org/)
[![SQL Server](https://img.shields.io/badge/SQL%20Server-2019-red.svg)](https://www.microsoft.com/en-us/sql-server)
[![Microsoft Fabric](https://img.shields.io/badge/Microsoft%20Fabric-Lakehouse-orange.svg)](https://microsoft.com/fabric)
[![Power BI](https://img.shields.io/badge/Power%20BI-Desktop-yellow.svg)](https://powerbi.microsoft.com/)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

## 📌 Overview

This project delivers an end-to-end retail analytics solution based on the Medallion Architecture (Bronze -> Silver -> Gold). It generates 5 million synthetic sales records, processes them through a star-schema database, validates data quality, and presents interactive dashboards in Power BI. The entire pipeline is implemented both in SQL Server (on-premise) and Microsoft Fabric (cloud lakehouse), demonstrating cross-platform proficiency.

Why this project stands out:
- Realistic retail data generation (customers, products, stores, promotions, returns)
- Rigorous data quality & model validation (automated checks)
- Advanced analytical views (RFM segmentation, Pareto, promotion uplift, seasonality, delivery impact)
- Row-level security (RLS) ready for production
- Fully documented with T-SQL, DAX, and PySpark examples
- Reproducible and cloud-ready (Fabric notebooks)

Latest improvements (2026-05-21):
- ✅ hour column (0-23) in fact table – never NULL, realistic distribution per channel
- ✅ promoid = 0 instead of NULL – dedicated "No Promotion" row in dimpromotion
- ✅ returnreason = 'No return' for non-return transactions (no NULLs)
- ✅ Unique store names enforced (no duplicates)
- ✅ Trend: slight decline (60k->50k) -> flat -> strong rise (50k->95k) at the end
- ✅ All data quality checks pass (including new tests for hour and returnreason)

## 🧱 Architecture & Technologies

| Layer | Technology (On-Prem) | Technology (Fabric) | Purpose |
|-------|----------------------|---------------------|---------|
| Data Generation | Python (pandas, numpy) | Same CSV files | Creates 5M fact rows + dimension CSVs |
| Bronze (Raw) | SQL Server (heap) | Fabric Delta Lake | Stores raw CSV data with audit columns |
| Silver (Cleaned) | SQL Server (indexed) | PySpark / Delta | Deduplicates, casts types, adds timestamps |
| Gold (Aggregated) | SQL Server (views) | Spark SQL | 10 business-ready analytical tables |
| Reporting | Power BI (DirectQuery) | Power BI (DirectLake) | Interactive dashboards with RLS |
| Validation | T-SQL | Spark SQL | Data quality, foreign keys, range checks |
| Orchestration | SQL Agent | Fabric Pipeline | Automated notebook execution |

## 📁 Repository Structure

retail-analytics-medallion/
├── generator.py                     # Python data generator (5M rows + dimensions)
├── sql/
│   ├── 01_create_database.sql       # Creates DB, loads CSVs, keys, indexes, columnstore
│   ├── 02_model_validation.sql      # Validates star schema, foreign keys, columnstore
│   ├── 03_data_quality_checks.sql   # 30+ value-based tests (all pass)
│   └── 04_analytical_views.sql      # 10 gold views for business insights
├── fabric_notebooks/
│   ├── 01_bronze_ingestion.py       # Load CSV -> Bronze Delta tables
│   ├── 02_silver_transformation.py  # Clean, dedupe, add audit -> Silver
│   ├── 03_gold_analytics_tables.sql # Create 10 gold tables (Spark SQL)
│   ├── 04_optimization_adapted.py   # Delta optimization (Z-order, compaction)
│   └── 05_silver_gold_validation.sql # Data quality checks (Spark SQL)
├── docs/
│   └── DOCUMENTATION.md             # Full documentation (tables, T-SQL, DAX, Python)
└── README.md                        # This file

## 🚀 How to Run (Local SQL Server)

1. Generate CSV files – Run python generator.py. All CSVs written to c:/data/.
2. Create and load database – In SSMS, execute sql/01_create_database.sql. This script drops/recreates retailanalytics, loads all CSVs, adds primary/foreign keys, indexes, and a clustered columnstore index on factsales. It also forces deliverydays = 0 for In-Store transactions and inserts dummy promoid=0 if missing.
3. Validate the model – Run sql/02_model_validation.sql. All checks should return OK.
4. Run data quality checks – Execute sql/03_data_quality_checks.sql. All tests must pass (no FAIL). Includes new checks for hour and returnreason.
5. Build analytical views – Execute sql/04_analytical_views.sql. Creates 10 gold views.
6. Connect Power BI – Use DirectQuery mode. All DAX measures are in docs/DOCUMENTATION.md.

## 🚀 How to Run (Microsoft Fabric)

1. Upload CSV files to a Fabric Lakehouse (Files/raw/ folder).
2. Import notebooks from fabric_notebooks/ into a Fabric workspace.
3. Run notebooks in order:
   - 01_bronze_ingestion.py – loads CSVs into Bronze Delta tables with audit columns.
   - 02_silver_transformation.py – cleans, casts types, adds timestamps, inserts dummy promoid=0.
   - 03_gold_analytics_tables.sql – creates 10 gold tables using Spark SQL.
   - 04_optimization_adapted.py – optimises Delta tables (compaction, Z-order).
   - 05_silver_gold_validation.sql – runs data quality checks on Silver/Gold layers.
4. Connect Power BI to the Lakehouse SQL endpoint (DirectLake mode).

## 📊 Key Business Insights (from Gold Views)

| Insight | Finding |
|---------|---------|
| Product margin | Kids products >30% margin; BOGO promotions are the only consistently profitable type. |
| Customer RFM | Champions and Big Spenders generate 85% of total LTV. At-Risk segment needs retention. |
| Returns | Online accounts for 65% of returns (defective 24%, late delivery 20%). Fast delivery cuts returns by 80%. |
| Channel performance | In-Store is the only profitable channel (+$32 margin/transaction). Online and Mobile App lose money. |
| Seasonality | December drives Electronics ($269M), Home ($98M), Kids ($32M). July peaks for Sports and Garden. |
| Pareto margin | ~24% of products contribute 80% of total margin. |
| Delivery speed | Long delivery (>5 days) increases return rates to 33-35% (5-10x higher than fast delivery). |
| Warranty impact | Products with warranty generate twice the revenue and have 30% lower return rates. |
| Hourly patterns | Evening peak for online, afternoon peak for in-store – used for staffing optimisation. |

## ✅ Quality & Integrity

- No orphan rows (foreign keys fully satisfied).
- Financial equation holds: net = grossvalue - discountamount + taxamount (tolerance 0.01).
- deliverydays = 0 for all In-Store transactions (enforced in both generator and loader).
- promoid = 0 exists in dimpromotion (dummy "No Promotion" row) – factsales.promoid never NULL.
- returnreason is 'No return' for non-returns – no NULLs.
- hour column (0-23) always populated, realistic distribution.
- All percentages stored as fractions (e.g., 0.15 = 15%) – easy to format in Power BI.
- Clustered columnstore index on factsales for fast aggregations.

## 📄 Full Documentation

For complete table definitions, all T-SQL queries (basic and advanced), all DAX measures (basic and extended), and the Python verification script, see docs/DOCUMENTATION.md.

## 🤝 Contributing

This project is part of a portfolio. Issues and pull requests are welcome.

## 📜 License

MIT © 2025 Kamil Soszka

Last update: 2026-05-21 (final generator & loader – hour, promoid=0, returnreason, unique store names)

<img width="1301" height="731" alt="Revenue Trend" src="https://github.com/user-attachments/assets/4ab352b5-4801-4fb4-a08e-2905f7f279bb" />
<img width="1297" height="727" alt="Payment Matrix" src="https://github.com/user-attachments/assets/8bae82f3-e982-4793-9c14-3d6484bb174d" />
<img width="1301" height="731" alt="Monthly Revenue" src="https://github.com/user-attachments/assets/95bd5066-87cd-4758-9dcc-979de7d2f131" />


