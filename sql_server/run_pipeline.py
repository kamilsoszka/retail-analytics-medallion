# ============================================================================
# run_pipeline.py
# ============================================================================
# Author:           DataGen AI & Assistant
# Created:          2026-05-25
# Last modified:    2026-05-25 19:15:00 UTC
# Suggested name:   run_pipeline.py
# Description:
#   Main orchestrator for the Retail Analytics data pipeline.
#   - Automated end-to-end data pipeline management.
#   - Runs Python data generation as an isolated subprocess.
#   - Establishes pyodbc connection to Microsoft SQL Server.
#   - Parses and executes multi-batch T-SQL scripts (handles 'GO' delimiter).
#   - Executes database creation, bulk loading, view deployment, and QA audits.
#   - Formats and displays validation reports directly in the console.
# ============================================================================

import os
import sys
import subprocess
import time
import re
import pyodbc
from datetime import datetime

# ============================================================================
# 1. PIPELINE CONFIGURATION
#    Custom-tailored folder paths for Kamil's local environment.
# ============================================================================

# Database connection settings
SQL_SERVER_NAME   = "localhost"                         # Change to your SQL Server instance (e.g. localhost\SQLEXPRESS)
DB_DRIVER         = "{ODBC Driver 17 for SQL Server}"   # Ensure this driver is installed on your Windows system
TRUSTED_CONN      = "yes"                               # Use Windows Integrated Security

# Local directory paths (using raw strings r"..." to handle spaces and backslashes)
PYTHON_SCRIPTS_DIR = r"C:\Users\kamil\OneDrive - ksoszka\Kamil Soszka Business Intelligence\retail-analytics-project\data_generation"
SQL_SCRIPTS_DIR    = r"C:\Users\kamil\OneDrive - ksoszka\Kamil Soszka Business Intelligence\retail-analytics-project\sql_server"

# Fully qualified file paths constructed from the directories above
GEN_DATA_SCRIPT   = os.path.join(PYTHON_SCRIPTS_DIR, "generate_retail_data.py")
BUILD_DB_SQL      = os.path.join(SQL_SCRIPTS_DIR, "build_retailanalytics_database.sql")
CREATE_VIEWS_SQL  = os.path.join(SQL_SCRIPTS_DIR, "create_analytical_views.sql")
VALIDATE_DQ_SQL   = os.path.join(SQL_SCRIPTS_DIR, "validate_retail_data_quality.sql")
VALIDATE_MD_SQL   = os.path.join(SQL_SCRIPTS_DIR, "validate_star_schema_model.sql")
ANALYZE_MARGIN_SQL= os.path.join(SQL_SCRIPTS_DIR, "analyze_product_margins.sql")
QUICK_CHECKS_SQL  = os.path.join(SQL_SCRIPTS_DIR, "quick_data_quality_checks.sql")


# ---------------------------------------------------------------------------
# 2. HELPER FUNCTIONS
# ---------------------------------------------------------------------------

def parse_sql_batches(file_path):
    """
    Reads a SQL file and splits it into logical batches based on the 'GO' separator.
    Required because pyodbc cannot execute scripts containing 'GO' directly.
    """
    if not os.path.exists(file_path):
        raise FileNotFoundError(f"SQL file not found at: {file_path}")
        
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    # Split using a regex that identifies 'GO' on its own line (case-insensitive)
    raw_batches = re.split(r'^\s*GO\s*$', content, flags=re.MULTILINE | re.IGNORECASE)
    
    clean_batches = []
    for batch in raw_batches:
        cleaned = batch.strip()
        if cleaned: # Skip empty batches
            clean_batches.append(cleaned)
            
    return clean_batches


def execute_sql_file(connection, file_path, print_info=True):
    """
    Parses and executes a SQL script batch by batch on an active connection.
    Captures print statements sent from SQL Server and outputs them to Python console.
    """
    if print_info:
        print(f"Executing: {os.path.basename(file_path)}...")
    
    batches = parse_sql_batches(file_path)
    cursor = connection.cursor()
    
    for idx, batch in enumerate(batches, 1):
        try:
            cursor.execute(batch)
            while cursor.nextset():
                pass
        except pyodbc.Error as err:
            print(f"\n[ERROR] Failed at batch {idx} in {os.path.basename(file_path)}:")
            print("-" * 80)
            print(batch[:400] + "..." if len(batch) > 400 else batch)
            print("-" * 80)
            print(f"Error Details: {err}")
            raise err
            
    cursor.close()
    if print_info:
        print(f"✓ {os.path.basename(file_path)} executed successfully.")


def print_section_header(title):
    """Prints a styled visual section header in the console."""
    print("\n" + "=" * 80)
    print(f" {title.upper()} ".center(80, "#"))
    print("=" * 80)


# ============================================================================
# 3. PIPELINE ORCHESTRATION EXECUTION
# ============================================================================
def main():
    pipeline_start_time = time.time()
    print_section_header("RETAIL ANALYTICS PIPELINE START")
    print(f"Time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"Python folder: {PYTHON_SCRIPTS_DIR}")
    print(f"SQL folder:    {SQL_SCRIPTS_DIR}")
    
    # Pre-execution safety check: verify all files exist before starting heavy generation
    for label, path in [
        ("Python generator", GEN_DATA_SCRIPT),
        ("DB build script", BUILD_DB_SQL),
        ("Analytical views", CREATE_VIEWS_SQL),
        ("Data quality validation", VALIDATE_DQ_SQL),
        ("Model validation", VALIDATE_MD_SQL),
        ("Margin analysis", ANALYZE_MARGIN_SQL),
        ("Quick sanity checks", QUICK_CHECKS_SQL)
    ]:
        if not os.path.exists(path):
            print(f"[FATAL] Missing required file ({label}) at path: {path}")
            print("Please check your folder paths configuration on top of the script.")
            sys.exit(1)
            
    # ---------------------------------------------------------------------------
    # Step 1: Run Python Data Generation
    # ---------------------------------------------------------------------------
    print_section_header("STEP 1: Generating Synthetic Data (10M Rows)")
    gen_start = time.time()
    try:
        # Run generator as an isolated subprocess to manage memory cleanups
        result = subprocess.run([sys.executable, GEN_DATA_SCRIPT], check=True)
        if result.returncode == 0:
            print(f"✓ Data generation finished successfully in {time.time() - gen_start:.2f} seconds.")
    except subprocess.CalledProcessError as err:
        print(f"[FATAL] Data generation failed with exit code {err.returncode}. Aborting pipeline.")
        sys.exit(1)

    # ---------------------------------------------------------------------------
    # Connect to MS SQL Server
    # ---------------------------------------------------------------------------
    print_section_header("Connecting to SQL Server")
    conn_str = f"DRIVER={DB_DRIVER};SERVER={SQL_SERVER_NAME};DATABASE=master;Trusted_Connection={TRUSTED_CONN};"
    print(f"Connection String: {conn_str}")
    
    try:
        # autocommit = True is required to run database creation DDL scripts (Step 0 in SQL)
        conn = pyodbc.connect(conn_str, autocommit=True)
        print("✓ Connected to SQL Server successfully.")
    except pyodbc.Error as err:
        print(f"[FATAL] Database connection failed: {err}")
        print("Please check your SQL_SERVER_NAME and ensure MS SQL Server is running.")
        sys.exit(1)

    try:
        # ---------------------------------------------------------------------------
        # Step 2: Build Database Schema & Load Data (Bulk Insert)
        # ---------------------------------------------------------------------------
        print_section_header("STEP 2: Deploying Schema & Bulk Inserting Data")
        db_build_start = time.time()
        execute_sql_file(conn, BUILD_DB_SQL)
        print(f"✓ Database loaded and constraints applied in {time.time() - db_build_start:.2f} seconds.")

        # ---------------------------------------------------------------------------
        # Step 3: Deploy Analytical Views
        # ---------------------------------------------------------------------------
        print_section_header("STEP 3: Deploying Analytical Views (Gold Layer)")
        execute_sql_file(conn, CREATE_VIEWS_SQL)

        # ---------------------------------------------------------------------------
        # Step 4: Run Structural Model Checks
        # ---------------------------------------------------------------------------
        print_section_header("STEP 4: Structural Star-Schema Model Verification")
        cursor = conn.cursor()
        batches = parse_sql_batches(VALIDATE_MD_SQL)
        for batch in batches:
            cursor.execute(batch)
            if cursor.description: # If batch returns rows
                rows = cursor.fetchall()
                print("\nModel Checks Results:")
                print(f"{'Category':<25} | {'Description':<50} | {'Result':<10} | {'Details':<10}")
                print("-" * 105)
                for r in rows:
                    print(f"{r[0]:<25} | {r[1][:50]:<50} | {r[2]:<10} | {r[3]:<10}")
                print("-" * 105)
        cursor.close()

        # ---------------------------------------------------------------------------
        # Step 5: Run Detailed Data Quality Validation Audit
        # ---------------------------------------------------------------------------
        print_section_header("STEP 5: Running Complete Data Quality Validation Audit")
        cursor = conn.cursor()
        batches = parse_sql_batches(VALIDATE_DQ_SQL)
        for batch in batches:
            cursor.execute(batch)
            if cursor.description and len(cursor.description) == 5:
                rows = cursor.fetchall()
                print("\nData Quality Summary per Table:")
                print(f"{'Table Name':<20} | {'Total Checks':<15} | {'Passed':<10} | {'Warnings':<10} | {'Failures':<10}")
                print("-" * 75)
                for r in rows:
                    print(f"{r[0]:<20} | {r[1]:<15} | {r[2]:<10} | {r[3]:<10} | {r[4]:<10}")
                print("-" * 75)
        cursor.close()

        # ---------------------------------------------------------------------------
        # Step 6: Product Margin Distribution Audit
        # ---------------------------------------------------------------------------
        print_section_header("STEP 6: Product Margin Distribution Analysis")
        cursor = conn.cursor()
        batches = parse_sql_batches(ANALYZE_MARGIN_SQL)
        for batch in batches:
            cursor.execute(batch)
            if cursor.description and len(cursor.description) == 4:
                rows = cursor.fetchall()
                print("\nStored Product Margin Distribution Histogram:")
                print(f"{'Bucket':<20} | {'Count':<15} | {'Percentage':<12} | {'Bar Chart'}")
                print("-" * 80)
                for r in rows:
                    print(f"{r[0]:<20} | {r[1]:<15} | {r[2]:<12} | {r[3]}")
                print("-" * 80)
        cursor.close()

        # ---------------------------------------------------------------------------
        # Step 7: Run Quick Checks (Sanity Checks)
        # ---------------------------------------------------------------------------
        print_section_header("STEP 7: Running Quick Sanity Checks")
        execute_sql_file(conn, QUICK_CHECKS_SQL)

    except Exception as ex:
        print(f"\n[FATAL] Pipeline stopped due to an unhandled SQL error: {ex}")
        sys.exit(1)
    finally:
        conn.close()
        print("\nDatabase connection closed safely.")

    # ---------------------------------------------------------------------------
    # Complete Reporting
    # ---------------------------------------------------------------------------
    total_time = time.time() - pipeline_start_time
    print_section_header("PIPELINE COMPLETED SUCCESSFULLY")
    print(f"Total Pipeline Duration: {total_time / 60:.2f} minutes ({total_time:.2f} seconds)")
    print("Database is fully synchronized, validated, and optimized for analytics.")
    print("=" * 80)


if __name__ == "__main__":
    try:
        import pyodbc
    except ImportError:
        print("[ERROR] pyodbc library not found. Please install it with 'pip install pyodbc' to run the pipeline.")
        sys.exit(1)
        
    main()
```

---