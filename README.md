# 🛒 Retail Analytics – Medallion Architecture Pipeline

[![Python 3.9+](https://img.shields.io/badge/Python-3.9+-blue.svg)](https://www.python.org/)
[![SQL Server](https://img.shields.io/badge/SQL%20Server-2019-red.svg)](https://www.microsoft.com/en-us/sql-server)
[![Power BI](https://img.shields.io/badge/Power%20BI-Desktop-yellow.svg)](https://powerbi.microsoft.com/)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

## Overview

This project delivers an **end‑to‑end retail analytics solution** based on the Medallion Architecture (Bronze → Silver → Gold). It generates **5 million synthetic sales records**, loads them into a star‑schema SQL Server database, validates data quality, and provides **10 analytical views** for Power BI.

## Repository Structure

## How to Run (Local SQL Server)

1. **Generate CSV files**  
   `python generator.py` → all CSVs to `c:/data/`.

2. **Create and load database**  
   In SSMS, run `sql/01_create_database.sql`.  
   This creates `retailanalytics`, loads all data, adds keys/indexes, and forces `deliverydays = 0` for in‑store transactions.

3. **Validate model**  
   Run `sql/02_model_validation.sql` – all checks return `OK`.

4. **Data quality checks**  
   Run `sql/03_data_quality_checks.sql` – all tests pass.

5. **Build analytical views**  
   Run `sql/04_analytical_views.sql` – creates 10 gold views.

6. **Connect Power BI**  
   Use DirectQuery to `retailanalytics`. DAX measures are in `docs/DOCUMENTATION.md`.

## Key Business Insights (from Gold Views)

| Insight | Finding |
|---------|---------|
| Product margin | Kids products >30% margin; BOGO promotions are the only consistently profitable type. |
| Customer RFM | Champions (53k) and Big Spenders (16k) generate 85% of total LTV. |
| Returns | Online accounts for 65% of returns (defective 24%, late delivery 20%). Fast delivery cuts returns by 80%. |
| Channel performance | In‑Store is the only profitable channel (+$32 margin/transaction). |
| Seasonality | December drives Electronics ($269M), Home ($98M), Kids ($32M). |
| Pareto margin | 483 products (24%) contribute 80% of total margin. |
| Delivery speed | Long delivery (>5 days) increases return rates to 33‑35%. |
| Warranty impact | Products with warranty generate twice the revenue and have 30% lower return rates. |

## Full Documentation

For complete table definitions, all T‑SQL queries, all DAX measures, and the Python verification script, see [`docs/DOCUMENTATION.md`](docs/DOCUMENTATION.md).

## Quality & Integrity

- No orphan rows (foreign keys fully satisfied).
- Financial equation holds: `net = grossvalue - discountamount + taxamount`.
- `deliverydays = 0` for all `In-Store` transactions.
- All percentages stored as fractions (e.g., `0.15` = 15%).
- Clustered columnstore index on `factsales` for fast aggregations.

## License

MIT © 2025 Kamil Soszka

**Last update: 2025-05-19**