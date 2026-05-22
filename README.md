# Retail Analytics – End-to-End Data Pipeline

## Project Goal
The goal of this project is to build a complete, reproducible data pipeline for retail transaction analytics. It generates 10 million sales rows plus dimension tables (customers, products, stores, promotions, date), enforces business rules (margin <=20%, no NULLs, deliverydays=0 for In-Store, hour column, promoid=0 as dummy promotion), processes data in a medallion architecture (bronze to silver to gold) using Microsoft Fabric, and provides ready-to-use analytical tables and validation scripts.

## What has been done

1. Data generation (Python 3.8+, pandas, numpy) – script final_retail_gen.py creates six CSV files:
   - dim_date.csv – date dimension (2023-01-01 to today)
   - dim_customer.csv – 200k customers with demographics, RFM attributes
   - dim_product.csv – 2k products, margin capped at 20%
   - dim_store.csv – 200 stores, unique names, region, type, size, rating
   - dim_promotion.csv – 100 promotions plus dummy promoid=0
   - fact_sales.csv – 10 million sales rows with hour, deliverydays, returnreason, grossvalue, discountamount, net, etc.

2. Data loading into SQL Server – script final_retail_loader.sql creates database retailanalytics, tables, inserts all CSVs, adds primary/foreign keys and a clustered columnstore index on factsales.

3. Microsoft Fabric notebooks (PySpark) – five notebooks:
   - 01_bronze_ingestion.py – reads CSVs, adds audit columns, writes Delta tables to 01_bronze_db
   - 02_silver_transformation.py – cleans, casts types, deduplicates, adds dummy promotion, writes to 02_silver_db
   - 03_gold_views.py – creates 17 materialized Delta tables (named vw_001_* to vw_017_*) in 03_gold_db with analytical aggregates (product margin, promo performance, RFM, returns, channel performance, seasonal revenue, store performance, Pareto, delivery impact, warranty, hourly sales, basket analysis, margin by price tier, recency, promo margin efficiency)
   - 04_optimization.py – compacts and Z-orders Delta tables
   - 05_silver_gold_validation.sql – data quality checks (row counts, PK uniqueness, orphan checks, hour validation, returnreason, deliverydays, margin ranges)

4. Validation scripts for SQL Server:
   - check_product_margins.sql – verifies that all product margins are between 0% and 20%
   - model_validation.sql – checks star schema integrity, foreign keys, clustered columnstore index

5. Power BI integration – DAX measures for total revenue, total COGS, gross margin percentage. Example measures are provided in the power_bi folder.

## Technologies used
- Python for data generation (pandas, numpy)
- Microsoft Fabric for Lakehouse and PySpark
- SQL Server / T-SQL for loading and validation
- Power BI for reporting

## How to reproduce the pipeline step by step

A. Generate CSV files
- Install Python 3.8+ with pandas and numpy.
- Run final_retail_gen.py. It will create six CSV files in c:/data/ (adjust OUTPUT_DIR if needed).

B. Load into SQL Server
- In SSMS or Azure Data Studio, execute final_retail_loader.sql. It creates database retailanalytics, all tables, loads data, adds indexes.
- Run check_product_margins.sql and model_validation.sql to verify data quality.

C. Run in Microsoft Fabric
- Upload the six CSV files to your Lakehouse Files/raw/ folder.
- Open a Fabric notebook and run the five notebooks in order:
   01_bronze_ingestion.py
   02_silver_transformation.py
   03_gold_views.py
   04_optimization.py
   05_silver_gold_validation.sql (run this cell as SQL)
- Query gold tables from SQL endpoint, for example:
   SELECT * FROM 03_gold_db.vw_001_product_category_margin LIMIT 10;

D. Power BI reporting
- Connect to the SQL endpoint of your Fabric Lakehouse (or to SQL Server).
- Create measures: Total Revenue, Total COGS, Gross Margin percentage.
- Build dashboards (examples: Revenue Trend, Payment Matrix, Monthly Revenue).

## File reference
- final_retail_gen.py – generates 10M rows + dimensions, margin <=20%
- final_retail_loader.sql – creates SQL Server database, tables, loads CSVs
- check_product_margins.sql – validates product margins (0%-20%)
- model_validation.sql – star schema integrity, foreign keys, CCI
- 01_bronze_ingestion.py – reads CSVs into bronze Delta tables
- 02_silver_transformation.py – cleans, casts, deduplicates, adds dummy promo
- 03_gold_views.py – creates 17 materialized gold tables in 03_gold_db
- 04_optimization.py – compaction and Z-order for Delta tables
- 05_silver_gold_validation.sql – data quality checks (SQL cell)

## License
MIT – free to use, modify, and distribute.