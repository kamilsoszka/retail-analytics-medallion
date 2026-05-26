# ============================================================================
# run_pipeline.py
# ============================================================================
# Author:           DataGen AI & Assistant
# Modified for:     Kamil Soszka (Clean Local Environment - Configured Instance)
# Last modified:    2026-05-26 09:30:00 UTC
# Description:
#   Main orchestrator for the Retail Analytics data pipeline.
#   - Automated end-to-end data pipeline management.
#   - Paths completely migrated to local directory C:\retail-analytics-project
#   - Configured dynamically with environment variables for database instance.
#   - Executes data generation and bulk loading via pyodbc to MS SQL Server.
#   - Handles multi-batch SQL script parsing based on the 'GO' delimiter.
# ============================================================================

import os
import sys
import subprocess
import time
import re
import pyodbc
from datetime import datetime

# ============================================================================
# 1. PIPELINE CONFIGURATION (Configured for Kamil's Named Instance)
# ============================================================================

# Database connection profiles for local named MS SQL Server instance
# Reads from environment variable 'SQL_SERVER_NAME' with a safe default of 'localhost'
SQL_SERVER_NAME   = os.environ.get("SQL_SERVER_NAME", "localhost")
DB_DRIVER         = "{ODBC Driver 17 for SQL Server}"   # Required Windows ODBC driver
TRUSTED_CONN      = "yes"                               # Use Windows Integrated Security

# Clean local base project directory (Completely isolated from OneDrive sync loops)
BASE_PROJECT_DIR  = r"C:\retail-analytics-project"

# Deterministic mapping of internal directory structures
PYTHON_SCRIPTS_DIR = os.path.join(BASE_PROJECT_DIR, "data_generation")
SQL_SCRIPTS_DIR    = os.path.join(BASE_PROJECT_DIR, "sql_server")

# Fully qualified paths to production execution assets
GEN_DATA_SCRIPT   = os.path.join(PYTHON_SCRIPTS_DIR, "generate_retail_data.py")
BUILD_DB_SQL      = os.path.join(SQL_SCRIPTS_DIR, "build_retailanalytics_database.sql")
CREATE_VIEWS_SQL  = os.path.join(SQL_SCRIPTS_DIR, "create_analytical_views.sql")
VALIDATE_DQ_SQL   = os.path.join(SQL_SCRIPTS_DIR, "validate_retail_data_quality.sql")
VALIDATE_MD_SQL   = os.path.join(SQL_SCRIPTS_DIR, "validate_star_schema_model.sql")
ANALYZE_MARGIN_SQL= os.path.join(SQL_SCRIPTS_DIR, "analyze_product_margins.sql")
QUICK_CHECKS_SQL  = os.path.join(SQL_SCRIPTS_DIR, "quick_data_quality_checks.sql")


# ---------------------------------------------------------------------------
# 2. CORE UTILITY FUNCTIONS (PARSERS & EXECUTORS)
# ---------------------------------------------------------------------------

def parse_sql_batches(file_path):
    """
    Reads a SQL file and splits it into logical batches using the 'GO' token.
    Prevents pyodbc driver failures when parsing native SQL Server scripts.
    """
    if not os.path.exists(file_path):
        raise FileNotFoundError(f"SQL file target not found at: {file_path}")
        
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    # Split using case-insensitive regex matching 'GO' isolated on its own line
    raw_batches = re.split(r'^\s*GO\s*$', content, flags=re.MULTILINE | re.IGNORECASE)
    
    clean_batches = []
    for batch in raw_batches:
        cleaned = batch.strip()
        if cleaned: # Filter out empty evaluation blocks
            clean_batches.append(cleaned)
            
    return clean_batches


def execute_sql_file(connection, file_path, print_info=True):
    """
    Executes a multi-batch SQL script sequentially on an active pyodbc connection.
    Forwards internal database PRINT commands directly to the python stdout stream.
    """
    if print_info:
        print(f"Executing script block: {os.path.basename(file_path)}...")
    
    batches = parse_sql_batches(file_path)
    cursor = connection.cursor()
    
    for idx, batch in enumerate(batches, 1):
        try:
            cursor.execute(batch)
            while cursor.nextset():
                pass
        except pyodbc.Error as err:
            print(f"\n[CRITICAL ERROR] Failed at execution block {idx} inside {os.path.basename(file_path)}:")
            print("-" * 80)
            print(batch[:400] + "..." if len(batch) > 400 else batch)
            print("-" * 80)
            print(f"Driver Details: {err}")
            raise err
            
    cursor.close()
    if print_info:
        print(f"✓ Script {os.path.basename(file_path)} deployed successfully.")


def print_section_header(title):
    """Generates structured visual delimiters for the tracking console."""
    print("\n" + "=" * 80)
    print(f" {title.upper()} ".center(80, "#"))
    print("=" * 80)


# ============================================================================
# 3. PIPELINE MAIN ORCHESTRATION LAYER
# ============================================================================
def main():
    pipeline_start_time = time.time()
    print_section_header("RETAIL ANALYTICS LOCAL PIPELINE INITIALIZATION")
    print(f"Execution Timestamp: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"Python Environment Base: {PYTHON_SCRIPTS_DIR}")
    print(f"SQL Server Engine Base:  {SQL_SCRIPTS_DIR}")
    
    # Pre-flight safety check: assert the absolute presence of all local files
    for label, path in [
        ("Python Data Generator", GEN_DATA_SCRIPT),
        ("DB Build Script", BUILD_DB_SQL),
        ("Analytical Views Spec", CREATE_VIEWS_SQL),
        ("Data Quality Auditing", VALIDATE_DQ_SQL),
        ("Star Schema Validation", VALIDATE_MD_SQL),
        ("Margin Performance Tuning", ANALYZE_MARGIN_SQL),
        ("Fast Sanity Testing", QUICK_CHECKS_SQL)
    ]:
        if not os.path.exists(path):
            print(f"[FATAL ERROR] Missing critical system file ({label}) at path: {path}")
            print("Action Required: Validate directory contents of C:\\retail-analytics-project")
            sys.exit(1)
            
    # ---------------------------------------------------------------------------
    # Step 1: Run Local Python Generation (Inline Data Quality Checks)
    # ---------------------------------------------------------------------------
    print_section_header("STEP 1: Generating Synthetic Dataset (Python)")
    gen_start = time.time()
    try:
        # Run generator as an isolated subprocess to enforce aggressive RAM flushing
        result = subprocess.run([sys.executable, GEN_DATA_SCRIPT], check=True)
        if result.returncode == 0:
            print(f"✓ Data generation layer executed successfully in {time.time() - gen_start:.2f} seconds.")
    except subprocess.CalledProcessError as err:
        print(f"[FATAL ERROR] Python generator failed with exit status {err.returncode}. Aborting pipeline execution.")
        sys.exit(1)

    # ---------------------------------------------------------------------------
    # Establish Connection to Local RDBMS (SSMS)
    # ---------------------------------------------------------------------------
    print_section_header("Establishing Relational Database Context")
    conn_str = f"DRIVER={DB_DRIVER};SERVER={SQL_SERVER_NAME};DATABASE=master;Trusted_Connection={TRUSTED_CONN};"
    print(f"Target Connection String: {conn_str}")
    
    try:
        # autocommit=True is explicitly required for database level DDL statements (e.g. CREATE DATABASE)
        conn = pyodbc.connect(conn_str, autocommit=True)
        print("✓ Session established with local Microsoft SQL Server engine.")
    except pyodbc.Error as err:
        print(f"[FATAL ERROR] Database driver communication failure: {err}")
        print("Action Required: Ensure SQL Server service (MSSQLSERVER01) status is set to RUNNING.")
        sys.exit(1)

    try:
        # ---------------------------------------------------------------------------
        # Step 2: Build Database Schema & Bulk Insert to SSMS
        # ---------------------------------------------------------------------------
        print_section_header("STEP 2: Deploying Relational Schema & Executing Bulk Ingestion")
        db_build_start = time.time()
        execute_sql_file(conn, BUILD_DB_SQL)
        print(f"✓ Database entities initialized and storage constraints enforced in {time.time() - db_build_start:.2f} seconds.")
        
        # ---------------------------------------------------------------------------
        # Step 3: Deploy Analytical Views
        # ---------------------------------------------------------------------------
        print_section_header("STEP 3: Deploying 17 Analytical Views")
        execute_sql_file(conn, CREATE_VIEWS_SQL)
        
        # ---------------------------------------------------------------------------
        # Step 4: Execute Data Quality Audits & Validations
        # ---------------------------------------------------------------------------
        print_section_header("STEP 4: Executing Data Quality Audits")
        execute_sql_file(conn, VALIDATE_DQ_SQL)
        execute_sql_file(conn, VALIDATE_MD_SQL)
        execute_sql_file(conn, ANALYZE_MARGIN_SQL)
        execute_sql_file(conn, QUICK_CHECKS_SQL)
        
        print_section_header("PIPELINE EXECUTION COMPLETED SUCCESSFULLY")
        print(f"Total processing latency: {time.time() - pipeline_start_time:.2f} seconds.")

    except Exception as pipeline_error:
        print(f"\n[FATAL RUNTIME EXCEPTION] Pipeline aborted due to SQL Engine failure: {pipeline_error}")
    finally:
        if 'conn' in locals():
            conn.close()
            print("\nRelational database connection context dropped safely.")

if __name__ == "__main__":
    main()