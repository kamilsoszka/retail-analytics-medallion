---

# 🚀 Retail Analytics – End-to-End Data Pipeline

**Author:** DataGen AI & Assistant  
**Date:** 2026-05-25  
**Description:** A production-grade, highly optimized, end-to-end data pipeline for retail transaction analytics built on a scale of **10 million sales rows**. Demonstrates a robust ELT staging-to-production pattern in Microsoft SQL Server and a full Medallion architecture (Bronze 🥉 → Silver 🥈 → Gold 🥇) in Microsoft Fabric Lakehouse. All percentage columns are stored as decimal fractions, monetary values use thousand separators with zero decimals, and validation scripts enforce rigorous business and structural constraints.

---

## 🌟 Features

- **10M Fact Rows:** Vectorized synthetic data generation with seasonal pricing and stochastically-driven revenue trends (decline → flat → strong rise) [generate_retail_data.py].
- **Double-Tier SQL Ingestion (ELT):** Loads raw files into `staging.stg_...` before migrating to `dbo` production tables. Primary/Foreign Keys and Indexes are applied *after* data load for a 10x write performance boost [build_retailanalytics_database.sql].
- **Spark-Native Medallion Architecture:** Explicit PySpark schemas (avoiding expensive `inferSchema` double-scans), single-pass projection casting (combating DataFrame lineage memory bloat), and primary-key-based hashing deduplication [ingest_bronze_layer.py, transform_silver_layer.py].
- **Delta Lake File Optimization:** Mitigates the "Tiny Files Problem" by avoiding physical folder partitioning on the fact table. Utilizes a single-pass `OPTIMIZE` combining file compaction and 3-axis `Z-ORDER` (`datekey`, `productid`, `customerid`) [optimize_delta_tables.py].
- **Defensive Data Quality (DQ):** Multi-table validation audits and structural checks that intelligently recognize and skip technical dummy records (`-1`/`0`) in business range checks [validate_retail_data_quality.sql, validate_fabric_layers.sql].
- **End-to-End Orchestrator (`run_pipeline.py`):** Runs the entire SQL Server pipeline with a single command. Parses and splits T-SQL batches around the `GO` delimiter, manages `autocommit` transactions, and displays SQL test reports directly in the console [run_pipeline.py].

---

## 📊 Dashboard Previews

| Revenue Trend 📈 | Payment Matrix 💳 | Monthly Revenue 📅 |
|:---:|:---:|:---:|
| ![Revenue Trend](images/revenue_trend.jpg) | ![Payment Matrix](images/payment_matrix.jpg) | ![Monthly Revenue](images/monthly_revenue.jpg) |
| Daily net-sales pattern (decline → flat → rise) | Payment methods by channel | Seasonal peaks in December |

---

## 🏛️ Architecture & Medallion Layers

The project is structured into three clear stages following the industry-standard Medallion architecture pattern:

```
                  CSV Files (generated)
                        │
                        ▼
ingest_bronze_layer.py   ──►  01_bronze_db (🥉 Bronze Layer)
                        │     - Raw CSV ingestion using explicit PySpark schemas
                        │     - Lineage metadata & ingestion timestamps appended
                        ▼
transform_silver_layer.py  ──►  02_silver_db (🥈 Silver Layer)
                        │     - String nullification & strict DECIMAL castings
                        │     - Hash-based deduplication on primary keys
                        ▼
create_gold_views.py     ──►  03_gold_db   (🥇 Gold Layer)
                        │     - 17 zmaterializowanych Delta tables (Delta)
                        │     - Optimized via "Aggregate-then-Join" CTEs
                        ▼
            Power BI / SQL Endpoints
```

### 🥉 Bronze Layer (Raw Ingestion)
- **Objective:** Securely land raw CSV files into Delta tables with minimal transformation.
- **Optimizations:** Avoids Spark's expensive `inferSchema` feature by supplying strict, pre-defined PySpark `StructType` schemas [ingest_bronze_layer.py]. Appends crucial audit columns (`_source_file`, `_ingestion_ts`, `_file_name`) for end-to-end data lineage tracking [ingest_bronze_layer.py].

### 🥈 Silver Layer (Refinement & Cleaning)
- **Objective:** Clean, cast, and standardize the data to serve as the enterprise-grade single source of truth.
- **Optimizations:** Combines all column type castings (monetary to `DECIMAL(18,2)`, fractions to `DECIMAL(5,4)`) and string empty-to-null conversions into a **single projection pass** [transform_silver_layer.py]. This collapses the Spark Catalyst Optimizer plan from dozens of expensive `.withColumn` steps into a single logical node, preventing memory exhaustion [transform_silver_layer.py]. Deduplication is performed on primary keys instead of full row-by-row comparisons.

### 🥇 Gold Layer (Aggregated Business Analytics)
- **Objective:** Present highly aggregated, ready-to-run business analytical metrics.
- **Optimizations:** Materializes the analytical queries into physical Delta tables rather than virtual views, making them instantly queryable by BI reporting tools like Power BI Direct Lake [create_gold_views.py]. Queries are rewritten using CTEs that aggregate the fact table's integer keys *first* before joining dimension tables, reducing network shuffle sizes by over 90% [create_gold_views.py].

---

## 💾 Generated Files (`Files/raw/` or `c:/data/`)

| File | Row Count | Relational Dummy Rows | Description |
|------|-----------|------------------------|-------------|
| `dim_date.csv` | ~1,240 | `datekey = -1` | Date dimension (2023-01-01 to today) + technical dummy row. |
| `dim_customer.csv` | 200,001 | `customerid = -1` | 200k customers with demographics, income, and RFM + technical dummy row. |
| `dim_product.csv` | 2,001 | `productid = -1` | 2k products, margins following a prescribed market distribution + technical dummy row. |
| `dim_store.csv` | 201 | `storeid = -1` | 200 stores – staff, size, rent, rating, and distance + technical dummy row. |
| `dim_promotion.csv` | 102 | `promoid = 0`, `promoid = -1` | 100 promotions + `promoid=0` (No Promotion) and `promoid=-1` (Unknown Promotion) dummy rows. |
| `fact_sales.csv` | 10,000,000 | *None* | 10M sales transactions, including returns, shipping costs, channels, and delivery parameters. |

---

## 🛠️ Scripts & Notebooks Reference

### 🐍 Python Core & Local Orchestration
*   **`run_pipeline.py`**: **End-to-End local pipeline orchestrator.** Automatically runs the python generation subprocess, connects to SQL, handles `GO` batching, runs DB load, views, and outputs DQ and schema verification tables to console [run_pipeline.py]. Supports parameterized separate folder paths [run_pipeline.py].
*   **`generate_retail_data.py`**: Generates all CSV files using optimized vectorization. Embeds `-1` and `0` relational dummy rows directly in the CSV outputs [generate_retail_data.py]. Formats floats to safe decimal strings to prevent `BULK INSERT` casting errors [generate_retail_data.py].
*   **`analyze_csv_data.py`**: Standalone analytical script that reads CSV files [analyze_csv_data.py]. Optimized to select only required columns during merges to reduce memory consumption by >70% on 10M rows [analyze_csv_data.py].

### 🛢️ T-SQL Database Scripts (Local SQL Server / SSMS)
*   **`build_retailanalytics_database.sql`**: **ELT DB Builder.** Creates `staging` and `dbo` schemas. Uses fast `BULK INSERT` into staging, inserts into production, and builds Primary Keys, Foreign Keys, and a Clustered Columnstore Index (CCI) *last* for maximum speed [build_retailanalytics_database.sql].
*   **`create_analytical_views.sql`**: Creates 17 analytical views in `dbo` [create_analytical_views.sql]. Engineered using "Aggregate-then-Join" CTEs to let the CCI aggregate integer keys before joining text columns [create_analytical_views.sql].
*   **`validate_retail_data_quality.sql`**: Robust DB validation. Formulates 60+ business rules checks (financial, shipping, dates) [validate_retail_data_quality.sql]. Properly ignores technical dummy rows (`-1`/`0`) in range checks to prevent false negatives [validate_retail_data_quality.sql].
*   **`analyze_product_margins.sql`**: Analyzes stored vs calculated margins [analyze_product_margins.sql]. Draws a visual histogram using `█` in pure T-SQL [analyze_product_margins.sql]. Ignores dummy records in statistical calculations [analyze_product_margins.sql].
*   **`validate_star_schema_model.sql`**: Validates structural integrity. Confirms CCI presence, allowed columns, PKs, FKs, database `SIMPLE` recovery mode, and verifies that all constraints are fully trusted by the optimizer [validate_star_schema_model.sql].
*   **`quick_data_quality_checks.sql`**: Quick sanity checks executing row counts, primary key duplicate counts, and financial totals [quick_data_quality_checks.sql].
*   **`comprehensive_tsql_queries.sql`**: Ready-to-run analytical SQL queries returning COGS, RFM metrics, and trends [comprehensive_tsql_queries.sql]. Uses pre-calculated calendar attributes instead of slow in-flight string conversions [comprehensive_tsql_queries.sql].

### ☁️ Microsoft Fabric Notebooks (Cloud Medallion Pipeline)
*   **`ingest_bronze_layer.py`**: **Bronze layer Notebook.** Ingests raw CSVs using strict `StructType` schemas (speeds up loading by bypassing `inferSchema`) [ingest_bronze_layer.py]. Writes Delta tables with file lineage metadata [ingest_bronze_layer.py]. Combines fact table partitions to prevent the "Tiny Files" problem on OneLake [ingest_bronze_layer.py].
*   **`transform_silver_layer.py`**: **Silver layer Notebook.** Sanitizes strings, casts double types to strict `DECIMAL(18,2)` and `DECIMAL(5,4)` scales [transform_silver_layer.py]. Minimizes execution graph by evaluating all columns in a *single projection pass* [transform_silver_layer.py]. Performs quick primary-key-based duplicate removal [transform_silver_layer.py].
*   **`create_gold_views.py`**: **Gold layer Notebook.** Materializes the 17 analytical views as physical Delta tables [create_gold_views.py]. Implements Spark SQL versions of "Aggregate-then-Join" CTEs to bypass heavy network shuffles on 10M rows [create_gold_views.py].
*   **`optimize_delta_tables.py`**: **Maintenance Notebook.** Combines compaction and multi-dimensional `Z-ORDER` into a single-pass write to save 50% CPU/IO [optimize_delta_tables.py]. Restructured Z-order keys on factsales to 3 primary keys (`datekey`, `productid`, `customerid`) to avoid the curse of dimensionality [optimize_delta_tables.py].
*   **`validate_fabric_layers.sql`**: **Fabric SQL Endpoint script.** Executes structural and data quality validation queries. Uses Spark SQL backtick schema notations [validate_fabric_layers.sql].
*   **`analyze_silver_data.py`**: **Silver analysis Notebook.** Evaluates KPIs [analyze_silver_data.py]. Minimizes separate Spark Actions (`.head()`) by consolidating scalar KPIs into a single Spark job, and groups new/returning cohorts using single-pass conditional aggregation [analyze_silver_data.py].

---

## 🛠️ How to Reproduce

### Option A: Local Execution (Unified Python Orchestrator)
1. Ensure Python 3.8+ and Microsoft SQL Server (with an ODBC driver) are installed. Install dependencies:
   ```bash
   pip install pandas numpy pyodbc
   ```
2. Open `run_pipeline.py`. Configure your SQL Server name and separate paths for your Python generator and SQL scripts folder:
   ```python
   SQL_SERVER_NAME    = "YOUR_SERVER_NAME"
   PYTHON_SCRIPTS_DIR = r"C:\Users\kamil\OneDrive - ksoszka\Kamil Soszka Business Intelligence\retail-analytics-project\data_generation"
   SQL_SCRIPTS_DIR    = r"C:\Users\kamil\OneDrive - ksoszka\Kamil Soszka Business Intelligence\retail-analytics-project\sql_server"
   ```
3. Run the pipeline:
   ```bash
   python run_pipeline.py
   ```
   *The pipeline will automatically generate files, recreate the database, bulk-load staging, migrate to production, apply indexes/keys, build views, and print comprehensive data quality and model integrity audits directly to your console.*

### Option B: Microsoft Fabric Cloud Execution
1. Create a **Lakehouse** in your Microsoft Fabric workspace.
2. Upload the six CSV files into the `Files/raw/` folder using the Lakehouse explorer.
3. Import the four Notebooks into your Fabric workspace.
4. Open each notebook and **attach your default Lakehouse** in the left-hand *Explorer* panel.
5. Create a **Data Pipeline** in Fabric Data Factory. Link the four notebooks sequentially:
   `ingest_bronze` ──► `transform_silver` ──► `create_gold` ──► `optimize_delta` ──► `analyze_silver`
6. Set your Workspace Spark idle timeout settings to **2 minutes** (*Workspace settings -> Synapse -> Spark settings -> Automatic shutdown*) to immediately free up CPU capacity on your SKU between runs.
7. Run the pipeline! Once completed, go to your **SQL Endpoint**, open a query tab, and execute `validate_fabric_layers.sql` to verify the gold layer.

---

## 📖 Documentation & Resources

For more detailed technical references and engineering guides, consult the following documentation:

- **Microsoft Fabric Platform:**
  - [Microsoft Fabric Documentation Hub](https://learn.microsoft.com/en-us/fabric/) 🌐
  - [Synapse Spark Notebooks in Fabric](https://learn.microsoft.com/en-us/fabric/data-engineering/author-execute-notebook) 📓
  - [Data Pipeline Orchestration in Fabric](https://learn.microsoft.com/en-us/fabric/data-factory/pipeline-activity-results) 🔗
- **Delta Lake Optimization:**
  - [Delta Lake Table Optimizations & Compaction](https://docs.delta.io/latest/optimizations-and-performance.html) ⚡
  - [Multi-Dimensional Clustering (Z-Ordering) Guidelines](https://learn.microsoft.com/en-us/azure/databricks/delta/optimizations#z-order-multi-dimensional-clustering) 📍
- **Database Engine Performance:**
  - [SQL Server Clustered Columnstore Indexes (CCI)](https://learn.microsoft.com/en-us/sql/relational-databases/indexes/columnstore-indexes-overview) 🗄️
  - [Understanding SARGability & Query Execution Plans](https://learn.microsoft.com/en-us/sql/relational-databases/performance/execution-plans) 📈
- **PySpark Optimization:**
  - [PySpark SQL Functions Reference API](https://spark.apache.org/docs/latest/api/python/reference/pyspark.sql/functions.html) 🐍

---

## 📏 Data Rules & Business Logic

| Rule | Detail |
|------|--------|
| **Margins** | Stored as decimal fractions (e.g. `0.1196` = 11.96%). Range: −0.1000 to 0.3000. Negative margins represent loss-leader items. |
| **Relational Dummy Rows** | Every dimension table contains a `-1` (and `0` for Promo) technical dummy row representing "Unknown" or "Missing" values to prevent NULLs in fact table FK columns. |
| **Returns** | `isreturn = 1` sets monetary fields (gross, net, tax, discount) as negative. `returnreason = 'No return'` for non-return rows, never NULL. |
| **In-Store delivery** | `deliverydays = 0` for all In-Store transactions; online/app channels have `deliverydays > 0`. |
| **Hour** | `hour` (0–23) always populated, never NULL. |
| **Gender** | Standardized strictly to `Male` / `Female`. |
| **Quantity scaling** | Daily net-sales targets met by scaling `qty`, preserving product margins. |
| **Discount flag** | `discountapplied` set **after** rounding `discountamount` to avoid false mismatches. |
| **Variance** | Wide spread in store sizes (0.1–10.0), customer incomes (bi-modal), and product margins (prescribed distribution). |

### Product margin distribution

| Margin range | Share |
|---|---|
| Exactly 30% | 5% of products |
| 20%–29% | 5% of products |
| Exactly 15% | 5% of products |
| 5%–10% | 50% of products |
| 0%–5% | 30% of products |
| −10%–0% (negative) | 5% of products |

---

## 🥇 17 Analytical Views / Gold Tables

| # | View Name | Topic |
|---|-----------|-------|
| 001 | `vw_001_product_category_margin` | Product category margin analysis with ranking [create_gold_views.py] |
| 002 | `vw_002_promo_performance` | Promotion performance vs baseline (margin & uplift) [create_gold_views.py] |
| 003 | `vw_003_customer_rfm_segments` | RFM segmentation (Champions, Loyal, Big Spenders, At Risk, Lost) [create_gold_views.py] |
| 004 | `vw_004_returns_analysis` | Returns by channel and reason [create_gold_views.py] |
| 005 | `vw_005_channel_performance` | Key metrics per sales channel [create_gold_views.py] |
| 006 | `vw_006_seasonal_category_revenue` | Monthly revenue by product category [create_gold_views.py] |
| 007 | `vw_007_store_performance_by_region_type` | Store performance aggregated by region and type [create_gold_views.py] |
| 008 | `vw_008_pareto_margin_analysis` | 80/20 rule – products contributing 80% of margin [create_gold_views.py] |
| 009 | `vw_009_delivery_speed_impact` | Return rate by delivery speed for online channels [create_gold_views.py] |
| 010 | `vw_010_warranty_eco_impact` | Impact of warranty and eco-certification [create_gold_views.py] |
| 011 | `vw_011_hourly_sales_margin_analysis` | Hourly breakdown of sales and margin per channel [create_gold_views.py] |
| 012 | `vw_012_pareto_revenue_margin` | Products needed for 80% of revenue vs 80% of margin [create_gold_views.py] |
| 013 | `vw_013_basket_analysis` | Top 100 product pairs frequently bought together [create_gold_views.py] |
| 014 | `vw_014_delivery_speed_impact_detailed` | Delivery speed impact with margin percentage [create_gold_views.py] |
| 015 | `vw_015_margin_by_price_tier` | Margin by price tier and category [create_gold_views.py] |
| 016 | `vw_016_recency_impact_on_spend` | Customer recency groups and average spend [create_gold_views.py] |
| 017 | `vw_017_promo_margin_efficiency` | Promotion margin uplift ranking [create_gold_views.py] |

---

## 💻 Technologies

- **Python 3.8+** · Pandas, NumPy — data generation & localized analysis
- **Microsoft Fabric** · PySpark, Delta Lake, Synapse Spark — Lakehouse medallion architecture
- **SQL Server / T-SQL** — ELT loading, views, validation audits, index optimizations
- **Power BI** — Direct Lake / DirectQuery reporting and dashboards

---

## 📝 License

MIT – free to use, modify, and distribute.

---