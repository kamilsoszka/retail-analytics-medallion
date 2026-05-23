# Retail Analytics – End-to-End Data Pipeline

A complete, reproducible data pipeline for retail transaction analytics built on **10 million sales rows** with a full medallion architecture (Bronze → Silver → Gold) in Microsoft Fabric.

---

## Features

- **10M fact rows** with realistic revenue trend (decline → flat → strong rise)
- **Star schema**: 5 dimension tables + 1 fact table, no NULLs, full referential integrity
- **17 analytical views / gold tables** covering margins, promotions, RFM, returns, basket analysis, and more
- **Microsoft Fabric Lakehouse** notebooks (PySpark Delta) + SQL Server scripts
- **Power BI ready**: all percentages stored as decimal fractions (e.g. `0.1196` = 11.96 %)

---

## Dashboard Previews

| Revenue Trend | Payment Matrix | Monthly Revenue |
|:---:|:---:|:---:|
| ![Revenue Trend](images/revenue_trend.jpg) | ![Payment Matrix](images/payment_matrix.jpg) | ![Monthly Revenue](images/monthly_revenue.jpg) |
| Daily net-sales pattern (decline → flat → rise) | Payment methods by channel | Seasonal peaks in December |

---

## Architecture Overview

```
CSV Files (generated)
      │
      ▼
01_bronze_ingestion.py   ──►  01_bronze_db  (raw Delta tables + audit columns)
      │
      ▼
02_silver_transformation.py  ──►  02_silver_db  (cleaned, typed, deduplicated)
      │
      ▼
03_gold_views.py  ──►  03_gold_db  (17 materialized analytical tables)
      │
      ▼
Power BI / SQL Endpoint
```

---

## Generated Files

| File | Description |
|------|-------------|
| `dim_date.csv` | Date dimension (2023-01-01 to today) |
| `dim_customer.csv` | 200k customers with demographics, RFM attributes |
| `dim_product.csv` | 2k products, margin capped at 30 % (stored as fraction) |
| `dim_store.csv` | 200 stores – region, type, size, rating |
| `dim_promotion.csv` | 100 promotions + dummy `promoid=0` (no promotion) |
| `fact_sales.csv` | 10M sales rows with `hour`, `deliverydays`, returns, discounts |

---

## Scripts Reference

| Script | Description |
|--------|-------------|
| `final_retail_gen.py` | Generates all CSV files |
| `final_retail_loader.sql` | Creates SQL Server DB, tables, loads CSVs, adds indexes |
| `deploy_all_analytical_views.sql` | Creates 17 analytical views |
| `03_data_quality_checks.sql` | Comprehensive data quality checks |
| `check_product_margins.sql` | Validates margin distribution (−10 % to 30 %) |
| `model_validation.sql` | Star schema integrity, FK checks, columnstore index |
| `01_bronze_ingestion.py` | PySpark: CSV → Bronze Delta |
| `02_silver_transformation.py` | PySpark: Bronze → Silver (clean, cast, deduplicate) |
| `03_gold_views.py` | PySpark: Silver → 17 Gold analytical tables |
| `04_optimization.py` | Delta compaction + Z-ordering |
| `05_silver_gold_validation.sql` | Data quality checks for Silver/Gold layers |
| `06_analysis_queries.py` | Analytical queries on Silver data |
| `comprehensive_tsql_queries.sql` | Ready-to-run T-SQL analytical queries |

---

## How to Reproduce

### A. Generate CSV files

```bash
pip install pandas numpy
python final_retail_gen.py          # outputs to c:/data/ by default
```

> Adjust `OUTPUT_DIR` inside the script if needed.

### B. Load into SQL Server

```sql
-- In SSMS or Azure Data Studio, run in order:
-- 1. final_retail_loader.sql          (creates DB, tables, loads data)
-- 2. deploy_all_analytical_views.sql  (17 views)
-- 3. 03_data_quality_checks.sql       (validation)
-- 4. model_validation.sql             (schema integrity)
```

### C. Run in Microsoft Fabric

1. Upload the six CSV files to your Lakehouse `Files/raw/` folder.
2. Run notebooks in order:
   - `01_bronze_ingestion.py`
   - `02_silver_transformation.py`
   - `03_gold_views.py`
   - `04_optimization.py`
   - `05_silver_gold_validation.sql` (run as SQL cell)
3. Query Gold tables from the SQL endpoint:

```sql
SELECT * FROM 03_gold_db.vw_001_product_category_margin LIMIT 10;
```

### D. Power BI reporting

- Connect to the Fabric Lakehouse SQL endpoint (or SQL Server).
- Create core measures: `Total Revenue`, `Total COGS`, `Gross Margin %`.
- Format `margin_pct` and `discount_pct` columns as **Percentage** — Power BI will display fractions correctly.

---

## Data Rules & Business Logic

| Rule | Detail |
|------|--------|
| Margins | Stored as fractions (e.g. `0.1196`). Range: −10 % to 30 %. |
| Promotions | `promoid = 0` = "No Promotion" (dedicated row in `dim_promotion`) |
| Returns | `returnreason = 'No return'` for non-return rows, never NULL |
| In-Store delivery | `deliverydays = 0` for all In-Store transactions |
| Hour | `hour` (0–23) always populated, never NULL |
| Gender | Only `Male` / `Female` values |
| Percentages | All stored as decimal fractions, ready for Power BI % formatting |

### Product margin distribution

| Margin range | Share |
|---|---|
| Exactly 30 % | 5 % of products |
| 20 %–29 % | 5 % of products |
| Exactly 15 % | 5 % of products |
| 5 %–10 % | 50 % of products |
| 0 %–5 % | 30 % of products |
| −10 %–0 % | 5 % of products (negative margin allowed) |

---

## 17 Analytical Views / Gold Tables

| # | Name | Topic |
|---|------|-------|
| 001 | `vw_001_product_category_margin` | Product category margin |
| 002 | `vw_002_promotion_performance` | Promotion performance vs baseline |
| 003 | `vw_003_customer_rfm` | Customer RFM segments |
| 004 | `vw_004_returns_analysis` | Returns analysis |
| 005 | `vw_005_channel_performance` | Channel performance |
| 006 | `vw_006_seasonal_revenue` | Seasonal category revenue |
| 007 | `vw_007_store_performance` | Store performance by region & type |
| 008 | `vw_008_pareto_margin` | Pareto margin analysis |
| 009 | `vw_009_delivery_returns` | Delivery speed impact on returns |
| 010 | `vw_010_warranty_eco` | Warranty & eco-friendly impact |
| 011 | `vw_011_hourly_sales` | Hourly sales & margin analysis |
| 012 | `vw_012_pareto_combined` | Pareto revenue & margin combined |
| 013 | `vw_013_basket_analysis` | Basket analysis – frequently bought together |
| 014 | `vw_014_delivery_margin` | Delivery speed impact on margin |
| 015 | `vw_015_margin_price_tier` | Margin by price tier & category |
| 016 | `vw_016_recency_spend` | Recency impact on spend |
| 017 | `vw_017_promo_efficiency` | Promotion margin efficiency |

---

## Technologies

- **Python 3.8+** · pandas, numpy — data generation
- **Microsoft Fabric** · PySpark, Delta Lake — Lakehouse medallion architecture
- **SQL Server / T-SQL** — loading, views, validation
- **Power BI** — reporting and dashboards

---

## License

MIT – free to use, modify, and distribute.