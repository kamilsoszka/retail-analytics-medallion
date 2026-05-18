# 🛒 Retail Analytics – Medallion Architecture Pipeline

[![Python 3.9+](https://img.shields.io/badge/Python-3.9+-blue.svg)](https://www.python.org/)
[![SQL Server](https://img.shields.io/badge/SQL%20Server-2019-red.svg)](https://www.microsoft.com/en-us/sql-server)
[![Power BI](https://img.shields.io/badge/Power%20BI-Desktop-yellow.svg)](https://powerbi.microsoft.com/)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

This project delivers an end‑to‑end retail data analytics solution based on the Medallion Architecture (Bronze → Silver → Gold). We generated **5 million synthetic sales records** with a realistic soft‑landing trend (Jan‑Mar 2023 linear decay, stabilisation, moderate bull run, correction, final rally) using a Python script. The script creates all dimension tables (`dim_date`, `dim_customer`, `dim_product`, `dim_store`, `dim_promotion`) and a fact table (`fact_sales`). Key fixes: `deliverydays = 0` for all in‑store transactions (forced after clipping), discontinued products set to inactive, `discountapplied` flag based on actual rounded discount, and `END_DATE` dynamic (today). The output CSV files are saved to `c:/data`.

We then wrote a T‑SQL script that creates the `retailanalytics` database, loads all CSVs via `BULK INSERT`, adds primary/foreign keys, non‑clustered indexes, and a clustered columnstore index on `factsales` for performance. The loader also forces `deliverydays = 0` for `channel = 'In-Store'` even if the CSV is wrong. After loading, we run two validation scripts: **model validation** (checks star schema, foreign keys, columnstore, orphan rows) and **data quality checks** (over 30 tests – nulls, ranges, financial equation, returns logic, etc.). Both scripts produce clear `OK`/`FAIL` reports.

We built **10 analytical views** (`001` to `010`) that answer key business questions: product margin, promotion uplift, customer RFM segmentation, returns by channel, channel performance, seasonal category revenue, store performance by region and type, Pareto margin analysis, delivery speed impact, and warranty/eco‑friendly impact. For Power BI, we provided a complete set of DAX measures (total revenue, COGS, margin, basket value, return rate, YoY, moving averages, RFM score, customer segment, CLV, churn rate, product margin $, revenue per m², promo uplift, price‑quantity correlation, etc.). We also included a Python verification script that loads all CSVs, runs statistical checks (daily sales with moving averages, YoY growth, RFM clustering, market basket analysis, promotion uplift, price elasticity), creates a multi‑plot visualisation, and exports monthly summaries and top product pairs.

**How to run the pipeline:**  
1. Run `python generator.py` → CSV files in `c:/data`.  
2. In SSMS, execute `sql/01_create_database.sql` → creates `retailanalytics`, loads data, adds keys/indexes.  
3. Execute `sql/02_model_validation.sql` (should return OK).  
4. Execute `sql/03_data_quality_checks.sql` (all tests pass).  
5. Execute `sql/04_analytical_views.sql` to build 10 gold views.  
6. Connect Power BI using DirectQuery and use the provided DAX measures.  

**Business insights from the gold views** (short version): Kids products have >30% margin; BOGO promotions are the only consistently profitable type; Champions (53k) and Big Spenders (16k) generate 85% of LTV; online accounts for 65% of returns (defective 24%, late delivery 20%); fast delivery cuts returns by 80%; in‑store is the only profitable channel (+$32 margin/transaction); December drives Electronics ($269M) and Home ($98M); 483 products (24%) contribute 80% of total margin; products with warranty generate twice the revenue and have 30% lower return rates. All scripts are in the `sql/` folder, the generator is in `generator.py`, and the Python verification script can be run after data generation. Enjoy! 🛒📊