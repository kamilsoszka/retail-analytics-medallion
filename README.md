# Retail Analytics – End-to-End Data Pipeline

## Project Goal
Build a complete, reproducible data pipeline for retail transaction analytics.  
It generates **10 million sales rows** plus dimension tables (customers, products, stores, promotions, date), enforces business rules (product margin ≤ 25%, no NULLs, `deliverydays = 0` for In-Store, `hour` column, `promoid = 0` as dummy promotion, all percentages stored as Power‑BI‑ready values e.g. `25.00` for 25%), processes data in a medallion architecture (bronze → silver → gold) using Microsoft Fabric, and provides ready‑to‑use analytical tables and validation scripts.

## What has been done

### 1. Data generation (Python 3.8+, pandas, numpy)
Script `final_retail_gen.py` creates six CSV files:

- `dim_date.csv` – date dimension (2023‑01‑01 to today)
- `dim_customer.csv` – 200k customers with demographics, RFM attributes
- `dim_product.csv` – 2k products, margin capped at **25%** (stored as percentage, e.g. `25.00`)
- `dim_store.csv` – 200 stores, unique names, region, type, size, rating
- `dim_promotion.csv` – 100 promotions plus dummy `promoid=0` (discount percentages stored as percent, e.g. `25.00`)
- `fact_sales.csv` – 10 million sales rows with `hour`, `deliverydays`, `returnreason`, `grossvalue`, `discountamount`, `net`, etc.

**Key improvements in the generator (v2):**
- Daily net‑sales targets are met by **scaling quantities**, not monetary values – this preserves product margins in the fact table and avoids inflated negative margins.
- `discountapplied` flag is now set **after** rounding `discountamount`, eliminating spurious mismatches.
- Gender strings use standard ASCII hyphen (`Non-binary`), ensuring consistency with SQL validation checks.
- All percentages are exported as numbers that can be directly interpreted in Power BI (e.g. `12.50` means 12.50%, **not** 0.125).

### 2. Data loading into SQL Server
Script `final_retail_loader.sql` creates database `retailanalytics`, tables, inserts all CSVs, adds primary/foreign keys and a clustered columnstore index on `factsales`.

### 3. Microsoft Fabric notebooks (PySpark)
Five notebooks implement the medallion architecture:

- `01_bronze_ingestion.py` – reads CSVs, adds audit columns (`_source_file`, `_ingestion_ts`, `_file_name`), writes Delta tables to `01_bronze_db`.
- `02_silver_transformation.py` – cleans data, casts numeric columns to appropriate decimal types, deduplicates, inserts dummy promotion (`promoid=0`), and writes to `02_silver_db`.
- `03_gold_views.py` – creates **17 materialized Delta tables** (named `vw_001_*` to `vw_017_*`) in `03_gold_db` with analytical aggregates:
  - Product category margin (001)
  - Promotion performance vs baseline (002)
  - Customer RFM segments (003)
  - Returns analysis (004)
  - Channel performance (005)
  - Seasonal category revenue (006)
  - Store performance by region & type (007)
  - Pareto margin analysis (008)
  - Delivery speed impact on returns (009)
  - Warranty & eco‑friendly impact (010)
  - Hourly sales & margin analysis (011)
  - Pareto revenue & margin combined (012)
  - Basket analysis – frequently bought together (013)
  - Detailed delivery speed impact on margin (014)
  - Margin by price tier & category (015)
  - Recency impact on spend (016)
  - Promotion margin efficiency (017)

  **All margin percentages in the gold layer are stored as percentages** (e.g. `25.00` for 25%), making them instantly usable in Power BI without further conversion.

- `04_optimization.py` – compacts Delta tables (when >20 files) and applies Z‑ordering on frequently filtered columns (`datekey`, `productid`, `customerid`, `storeid`, etc.) across all three layers.
- `05_silver_gold_validation.sql` – comprehensive data quality checks:
  - Row counts, PK uniqueness
  - Orphan foreign keys
  - Hour column validation (0‑23, not null)
  - Return reason integrity (`No return` when `isreturn=0`)
  - Delivery days logic (In‑Store = 0)
  - Percentage range checks: `margin_pct` 0‑25, `discount_pct` 0‑100

### 4. Validation scripts for SQL Server
- `check_product_margins.sql` – verifies that all product margins are between 0% and 25% (percentage values).
- `model_validation.sql` – checks star schema integrity, foreign keys, clustered columnstore index.

### 5. Power BI integration
DAX measures for total revenue, total COGS, gross margin percentage, etc. are easily created from the gold tables. Example measures are provided in the `power_bi` folder.

### 6. Dashboards built on the generated data
The following reports were built using Power BI connected to the Fabric gold layer (or SQL Server). They demonstrate the quality and analytical readiness of the data.

![Revenue Trend](https://github.com/user-attachments/assets/bb23b6c3-0d5a-4123-8c57-2894939db6c5)
*Revenue Trend – visualising the enforced daily net‑sales pattern (decline → flat → strong rise).*

![Payment Matrix](https://github.com/user-attachments/assets/03127137-b303-4257-80d7-99ae06157587)
*Payment Matrix – breakdown of payment methods by channel.*

![Monthly Revenue](https://github.com/user-attachments/assets/e96770d1-9f3f-481d-9cc6-75898f2ecae4)
*Monthly Revenue – seasonal revenue pattern with clear peaks in December.*

## Technologies used
- **Python** for data generation (pandas, numpy)
- **Microsoft Fabric** for Lakehouse and PySpark
- **SQL Server / T‑SQL** for loading and validation
- **Power BI** for reporting

## How to reproduce the pipeline step by step

### A. Generate CSV files
- Install Python 3.8+ with pandas and numpy.
- Run `final_retail_gen.py`. It will create six CSV files in `c:/data/` (adjust `OUTPUT_DIR` if needed).

### B. Load into SQL Server
- In SSMS or Azure Data Studio, execute `final_retail_loader.sql`. It creates database `retailanalytics`, all tables, loads data, adds indexes.
- Run `check_product_margins.sql` and `model_validation.sql` to verify data quality.

### C. Run in Microsoft Fabric
- Upload the six CSV files to your Lakehouse `Files/raw/` folder.
- Open a Fabric notebook and run the five notebooks in order:
  1. `01_bronze_ingestion.py`
  2. `02_silver_transformation.py`
  3. `03_gold_views.py`
  4. `04_optimization.py`
  5. `05_silver_gold_validation.sql` (run this cell as SQL)
- Query gold tables from SQL endpoint, for example:
  ```sql
  SELECT * FROM 03_gold_db.vw_001_product_category_margin LIMIT 10;