# Retail Analytics – End-to-End Data Pipeline

**Author:** DataGen AI  
**Date:** 2026-05-24  
**Description:** A complete, reproducible data pipeline for retail transaction analytics built on **10 million sales rows** with a full medallion architecture (Bronze → Silver → Gold) in Microsoft Fabric. All percentage columns are stored as decimal fractions, monetary values use thousand separators with zero decimals, and percentage displays show two decimal places.

---

## Features

- **10M fact rows** with realistic revenue trend (decline → flat → strong rise)
- **Star schema**: 5 dimension tables + 1 fact table, no NULLs, full referential integrity
- **17 analytical views / gold tables** covering margins, promotions, RFM, returns, basket analysis, and more
- **Microsoft Fabric Lakehouse** notebooks (PySpark Delta) + SQL Server scripts
- **Power BI ready**: all percentages stored as decimal fractions (e.g. `0.1196` = 11.96 %)

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
ingest_bronze_layer.py   ──►  01_bronze_db  (raw Delta tables + audit columns)
      │
      ▼
transform_silver_layer.py  ──►  02_silver_db  (cleaned, typed, deduplicated)
      │
      ▼
create_gold_views.py  ──►  03_gold_db  (17 materialized analytical tables)
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
| `dim_product.csv` | 2k products, margin capped at 30 % (stored as fraction) |
| `dim_store.csv` | 200 stores – region, type, size, rating |
| `dim_promotion.csv` | 100 promotions + dummy `promoid=0` (no promotion) |
| `fact_sales.csv` | 10M sales rows with `hour`, `deliverydays`, returns, discounts |

---

## Scripts Reference

### Python (Data Generation)
| Script | Description |
|--------|-------------|
| `generate_retail_data.py` | Generates all CSV files with realistic distributions, quantity scaling, and fraction-based percentages |

### SQL Server Scripts (Execution Order)
| # | Script | Description |
|---|--------|-------------|
| 1 | `build_retailanalytics_database.sql` | Creates database, tables, loads all CSV files, adds primary/foreign keys, clustered columnstore index, basic views |
| 2 | `create_analytical_views.sql` | Creates 17 analytical views with fraction-based margin/discount columns |
| 3 | `validate_retail_data_quality.sql` | Comprehensive data quality checks (60+ tests) with formatted output |
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

### Additional Query Files
| Script | Description |
|--------|-------------|
| `comprehensive_tsql_queries.sql` | Ready-to-run T-SQL analytical queries with formatted monetary values and percentages |
| `analysis_queries.py` | Standalone Python/pandas analytical queries on CSV files with formatted output |

---

## How to Reproduce

### A. Generate CSV files

```bash
pip install pandas numpy
python generate_retail_data.py          # outputs to c:/data/ by default
```

> Adjust `OUTPUT_DIR` inside the script if needed.

### B. Load into SQL Server

In SSMS or Azure Data Studio, execute the scripts in order:

```sql
-- 1. build_retailanalytics_database.sql     (creates DB, tables, loads data, adds indexes)
-- 2. create_analytical_views.sql             (17 analytical views)
-- 3. validate_retail_data_quality.sql        (comprehensive validation)
-- 4. analyze_product_margins.sql             (margin distribution analysis)
-- 5. validate_star_schema_model.sql          (schema integrity)
-- 6. quick_data_quality_checks.sql           (quick sanity checks)
```

### C. Run in Microsoft Fabric

1. Upload the six CSV files to your Lakehouse `Files/raw/` folder.
2. Run notebooks in order:
   - `ingest_bronze_layer.py`
   - `transform_silver_layer.py`
   - `create_gold_views.py`
   - `optimize_delta_tables.py`
   - `validate_fabric_layers.sql` (run as SQL cell)
   - `analyze_silver_data.py`
3. Query Gold tables from the SQL endpoint:

```sql
SELECT * FROM 03_gold_db.vw_001_product_category_margin LIMIT 10;
```

### D. Power BI reporting

- Connect to the Fabric Lakehouse SQL endpoint (or SQL Server).
- Create core measures: `Total Revenue`, `Total COGS`, `Gross Margin %`.
- Format `margin_pct` and `discount_pct` columns as **Percentage** — Power BI will display fractions correctly (e.g. `0.1196` → `11.96%`).

---

## Data Rules & Business Logic

| Rule | Detail |
|------|--------|
| **Margins** | Stored as decimal fractions (e.g. `0.1196`). Range: −10 % to 30 %. Negative margins are **allowed**. |
| **Promotions** | `promoid = 0` = "No Promotion" (dedicated row in `dim_promotion`) |
| **Returns** | `returnreason = 'No return'` for non-return rows, never NULL |
| **In-Store delivery** | `deliverydays = 0` for all In-Store transactions |
| **Hour** | `hour` (0–23) always populated, never NULL |
| **Gender** | Only `Male` / `Female` values |
| **Percentages** | All `_pct` columns stored as decimal fractions, ready for Power BI % formatting |
| **Monetary formatting** | Thousand separators, zero decimal places (e.g. `1,234,567`) |
| **Percentage display** | Two decimal places with % sign (e.g. `12.50%`) |
| **Quantity scaling** | Daily net-sales targets met by scaling `qty`, preserving intrinsic product margins |
| **Discount flag** | `discountapplied` set **after** rounding `discountamount` to avoid false mismatches |
| **Variance** | Wide spread in store sizes (0.1–10.0), customer incomes (bi-modal), and product margins (prescribed distribution) |

### Product margin distribution

| Margin range | Share |
|---|---|
| Exactly 30 % | 5 % of products |
| 20 %–29 % | 5 % of products |
| Exactly 15 % | 5 % of products |
| 5 %–10 % | 50 % of products |
| 0 %–5 % | 30 % of products |
| −10 %–0 % (negative) | 5 % of products |

---

## 17 Analytical Views / Gold Tables

| # | View Name | Topic |
|---|-----------|-------|
| 001 | `vw_001_product_category_margin` | Product category margin analysis with ranking |
| 002 | `vw_002_promo_performance` | Promotion performance vs baseline (margin & uplift) |
| 003 | `vw_003_customer_rfm_segments` | RFM segmentation (Champions, Loyal, Big Spenders, At Risk, Lost) |
| 004 | `vw_004_returns_analysis` | Returns by channel and reason |
| 005 | `vw_005_channel_performance` | Key metrics per sales channel |
| 006 | `vw_006_seasonal_category_revenue` | Monthly revenue by product category |
| 007 | `vw_007_store_performance_by_region_type` | Store performance aggregated by region and type |
| 008 | `vw_008_pareto_margin_analysis` | 80/20 rule – products contributing 80% of margin |
| 009 | `vw_009_delivery_speed_impact` | Return rate by delivery speed for online channels |
| 010 | `vw_010_warranty_eco_impact` | Impact of warranty and eco-certification |
| 011 | `vw_011_hourly_sales_margin_analysis` | Hourly breakdown of sales and margin per channel |
| 012 | `vw_012_pareto_revenue_margin` | Products needed for 80% of revenue vs 80% of margin |
| 013 | `vw_013_basket_analysis` | Top 100 product pairs frequently bought together |
| 014 | `vw_014_delivery_speed_impact_detailed` | Delivery speed impact with margin percentage |
| 015 | `vw_015_margin_by_price_tier` | Margin by price tier and category |
| 016 | `vw_016_recency_impact_on_spend` | Customer recency groups and average spend |
| 017 | `vw_017_promo_margin_efficiency` | Promotion margin uplift ranking |

---

## Technologies

- **Python 3.8+** · pandas, numpy — data generation
- **Microsoft Fabric** · PySpark, Delta Lake — Lakehouse medallion architecture
- **SQL Server / T-SQL** — loading, views, validation
- **Power BI** — reporting and dashboards

---

## License

MIT – free to use, modify, and distribute.