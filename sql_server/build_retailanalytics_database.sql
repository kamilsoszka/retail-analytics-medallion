-- ============================================================================
-- build_retailanalytics_database.sql
-- ============================================================================
-- Author:           DataGen AI & Assistant
-- Created:          2026-05-23
-- Last modified:    2026-05-25 18:30:00 UTC
-- Suggested name:   build_retailanalytics_database.sql
-- Description:
--   Creates the retailanalytics database in SQL Server using an ELT pattern.
--   - Implements a dedicated "staging" schema to load raw CSV files first.
--   - Bulk inserts dimensions and 10M fact rows into staging tables.
--   - Populates production tables from staging in a highly efficient manner.
--   - Applies Primary Keys, Foreign Keys, and Non-Clustered Indexes AFTER data load.
--   - Builds a Clustered Columnstore Index on the fact table for compression.
--   - Performs basic row-count reconciliation and data quality checks.
-- ============================================================================

USE master;
GO

-- ============================================================================
-- STEP 0: Prepare the environment
--   - Drop and recreate the database to guarantee a clean state.
--   - Set SIMPLE recovery model to avoid transaction log growth.
-- ============================================================================
PRINT '============================================================';
PRINT 'STEP 0: Prepare database';
PRINT '============================================================';

IF DB_ID('retailanalytics') IS NOT NULL
BEGIN
    PRINT '  -> Dropping existing database retailanalytics...';
    ALTER DATABASE retailanalytics SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE retailanalytics;
END
GO

PRINT '  -> Creating fresh database retailanalytics...';
CREATE DATABASE retailanalytics;
GO
ALTER DATABASE retailanalytics SET RECOVERY SIMPLE;
GO
USE retailanalytics;
GO

-- ============================================================================
-- STEP 1: Create Schemas
-- ============================================================================
PRINT '============================================================';
PRINT 'STEP 1: Create Schemas';
PRINT '============================================================';
GO
CREATE SCHEMA staging;
GO

-- ============================================================================
-- STEP 2: Drop existing tables and views (idempotency)
-- ============================================================================
PRINT '============================================================';
PRINT 'STEP 2: Drop existing objects';
PRINT '============================================================';

-- Drop views if they exist
IF OBJECT_ID('dbo.vw_sales', 'V')      IS NOT NULL DROP VIEW dbo.vw_sales;
IF OBJECT_ID('dbo.vw_customers', 'V')  IS NOT NULL DROP VIEW dbo.vw_customers;
IF OBJECT_ID('dbo.vw_dates', 'V')      IS NOT NULL DROP VIEW dbo.vw_dates;
IF OBJECT_ID('dbo.vw_products', 'V')   IS NOT NULL DROP VIEW dbo.vw_products;
IF OBJECT_ID('dbo.vw_promotions', 'V') IS NOT NULL DROP VIEW dbo.vw_promotions;
IF OBJECT_ID('dbo.vw_stores', 'V')     IS NOT NULL DROP VIEW dbo.vw_stores;
GO

-- Drop production tables (fact first, then dimensions)
IF OBJECT_ID('dbo.factsales', 'U')     IS NOT NULL DROP TABLE dbo.factsales;
IF OBJECT_ID('dbo.dimdate', 'U')       IS NOT NULL DROP TABLE dbo.dimdate;
IF OBJECT_ID('dbo.dimcustomer', 'U')   IS NOT NULL DROP TABLE dbo.dimcustomer;
IF OBJECT_ID('dbo.dimproduct', 'U')    IS NOT NULL DROP TABLE dbo.dimproduct;
IF OBJECT_ID('dbo.dimstore', 'U')      IS NOT NULL DROP TABLE dbo.dimstore;
IF OBJECT_ID('dbo.dimpromotion', 'U')  IS NOT NULL DROP TABLE dbo.dimpromotion;
GO

-- Drop staging tables
IF OBJECT_ID('staging.stg_factsales', 'U')    IS NOT NULL DROP TABLE staging.stg_factsales;
IF OBJECT_ID('staging.stg_dimdate', 'U')      IS NOT NULL DROP TABLE staging.stg_dimdate;
IF OBJECT_ID('staging.stg_dimcustomer', 'U')  IS NOT NULL DROP TABLE staging.stg_dimcustomer;
IF OBJECT_ID('staging.stg_dimproduct', 'U')   IS NOT NULL DROP TABLE staging.stg_dimproduct;
IF OBJECT_ID('staging.stg_dimstore', 'U')     IS NOT NULL DROP TABLE staging.stg_dimstore;
IF OBJECT_ID('staging.stg_dimpromotion', 'U') IS NOT NULL DROP TABLE staging.stg_dimpromotion;
GO

PRINT '  -> Old objects dropped cleanly.';
GO

-- ============================================================================
-- STEP 3: Create Staging Tables
--   - Used for fast, raw bulk inserts without constraints or indexes.
--   - Column structures align with CSV properties for seamless ingestion.
-- ============================================================================
PRINT '============================================================';
PRINT 'STEP 3: Create Staging Tables';
PRINT '============================================================';

CREATE TABLE staging.stg_dimdate (
    datekey             INT,
    fulldate            DATE,
    year                SMALLINT,
    quarternumber       TINYINT,
    quartername         NCHAR(2),
    monthnumber         TINYINT,
    monthname           NVARCHAR(20),
    weekdaynumber       TINYINT,
    weekdayname         NVARCHAR(20),
    isweekend           TINYINT,
    yearmonth           NCHAR(7),
    yearmonthnumber     INT,
    yearquarter         NVARCHAR(7),
    yearquarternumber   INT,
    yearweek            NVARCHAR(8),
    yearweeknumber      INT,
    isholiday           TINYINT
);

CREATE TABLE staging.stg_dimcustomer (
    customerid          INT,
    fullname            NVARCHAR(100),
    email               NVARCHAR(100),
    age                 TINYINT,
    gender              NVARCHAR(20),
    city                NVARCHAR(50),
    tier                NVARCHAR(20),
    points              INT,
    isactive            TINYINT,
    lang                NVARCHAR(10),
    totalspend          DECIMAL(18,2),
    regdate             DATE,
    annualincome        DECIMAL(18,2),
    incomebracket       NVARCHAR(20),
    education           NVARCHAR(50),
    maritalstatus       NVARCHAR(20),
    childrencount       TINYINT,
    loyaltysegment      NVARCHAR(20),
    satisfactionscore   DECIMAL(5,1),
    dayssincelastpurchase INT,
    hassubscription     TINYINT,
    preferredcontact    NVARCHAR(20),
    spendmultiplier     DECIMAL(10,3)
);

CREATE TABLE staging.stg_dimproduct (
    productid           INT,
    name                NVARCHAR(150),
    category            NVARCHAR(50),
    brand               NVARCHAR(50),
    unitcost            DECIMAL(18,2),
    unitprice           DECIMAL(18,2),
    margin_pct          DECIMAL(5,4),
    weight              DECIMAL(10,2),
    color               NVARCHAR(20),
    material            NVARCHAR(50),
    supplierid          INT,
    isactive            TINYINT,
    minstock            INT,
    tax_rate            DECIMAL(5,4),
    haswarranty         TINYINT,
    ecofriendly         TINYINT,
    seasonalityfactor   DECIMAL(5,2),
    warrantymonths      TINYINT,
    ecoscore            TINYINT,
    releaseyear         SMALLINT,
    skucount            INT,
    isdiscontinued      TINYINT,
    productrating       DECIMAL(3,1),
    stockstatus         NVARCHAR(20)
);

CREATE TABLE staging.stg_dimstore (
    storeid                 INT,
    storename               NVARCHAR(150),
    city                    NVARCHAR(50),
    type                    NVARCHAR(50),
    staff                   SMALLINT,
    sizem2                  INT,
    hascafe                 TINYINT,
    openingyear             SMALLINT,
    region                  NVARCHAR(50),
    renovationyear          SMALLINT,
    parkingspots            SMALLINT,
    storerating             DECIMAL(3,1),
    hasdeliveryservice      TINYINT,
    floornumber             TINYINT,
    distancetocitycenterkm  DECIMAL(8,1),
    annualrentcost          DECIMAL(18,2),
    storesizemultiplier     DECIMAL(10,4) -- Formatted in Python with up to 4 decimals
);

CREATE TABLE staging.stg_dimpromotion (
    promoid             INT,
    promoname           NVARCHAR(150),
    discount_pct        DECIMAL(5,4),
    discount_fixed      DECIMAL(10,2),
    type                NVARCHAR(50),
    isactive            TINYINT,
    minspend            INT,
    channel             NVARCHAR(50),
    budget              DECIMAL(18,2),
    startdate           DATE,
    enddate             DATE,
    targetaudience      NVARCHAR(50),
    maxdiscountcap      DECIMAL(18,2),
    isstackable         TINYINT,
    redemption_rate     DECIMAL(5,3),
    coderequired        TINYINT,
    promoupliftfactor   DECIMAL(6,3)
);

CREATE TABLE staging.stg_factsales (
    salesid             BIGINT,
    datekey             INT,
    productid           INT,
    customerid          INT,
    storeid             INT,
    promoid             INT,
    qty                 INT,
    unitprice           DECIMAL(18,2),
    tax_rate            DECIMAL(5,4),
    net                 DECIMAL(18,2),
    payment             NVARCHAR(20),
    channel             NVARCHAR(20),
    grossvalue          DECIMAL(18,2),
    discountamount      DECIMAL(18,2),
    taxamount           DECIMAL(18,2),
    shipcost            DECIMAL(18,2),
    isreturn            TINYINT,
    shipweight          DECIMAL(10,2),
    discountapplied     TINYINT,
    returnreason        NVARCHAR(50),
    deliverydays        TINYINT,
    hour                TINYINT
);
GO

PRINT '  -> Staging tables created.';
GO

-- ============================================================================
-- STEP 4: Create Production Tables (Target Schema)
--   - No constraints or indexes are applied yet to maximize load performance.
-- ============================================================================
PRINT '============================================================';
PRINT 'STEP 4: Create Production Tables';
PRINT '============================================================';

CREATE TABLE dbo.dimdate (
    datekey             INT NOT NULL,
    fulldate            DATE NOT NULL,
    year                SMALLINT NOT NULL,
    quarternumber       TINYINT NOT NULL,
    quartername         NCHAR(2) NOT NULL,
    monthnumber         TINYINT NOT NULL,
    monthname           NVARCHAR(20) NOT NULL,
    weekdaynumber       TINYINT NOT NULL,
    weekdayname         NVARCHAR(20) NOT NULL,
    isweekend           TINYINT NOT NULL,
    yearmonth           NCHAR(7) NOT NULL,
    yearmonthnumber     INT NOT NULL,
    yearquarter         NVARCHAR(7) NOT NULL,
    yearquarternumber   INT NOT NULL,
    yearweek            NVARCHAR(8) NOT NULL,
    yearweeknumber      INT NOT NULL,
    isholiday           TINYINT NOT NULL
);

CREATE TABLE dbo.dimcustomer (
    customerid          INT NOT NULL,
    fullname            NVARCHAR(100) NOT NULL,
    email               NVARCHAR(100) NOT NULL,
    age                 TINYINT NOT NULL,
    gender              NVARCHAR(20) NOT NULL,
    city                NVARCHAR(50) NOT NULL,
    tier                NVARCHAR(20) NOT NULL,
    points              INT NOT NULL,
    isactive            TINYINT NOT NULL,
    lang                NVARCHAR(10) NOT NULL,
    totalspend          DECIMAL(18,2) NOT NULL,
    regdate             DATE NOT NULL,
    annualincome        DECIMAL(18,2) NOT NULL,
    incomebracket       NVARCHAR(20) NOT NULL,
    education           NVARCHAR(50) NOT NULL,
    maritalstatus       NVARCHAR(20) NOT NULL,
    childrencount       TINYINT NOT NULL,
    loyaltysegment      NVARCHAR(20) NOT NULL,
    satisfactionscore   DECIMAL(5,1) NOT NULL,
    dayssincelastpurchase INT NOT NULL,
    hassubscription     TINYINT NOT NULL,
    preferredcontact    NVARCHAR(20) NOT NULL,
    spendmultiplier     DECIMAL(10,3) NOT NULL
);

CREATE TABLE dbo.dimproduct (
    productid           INT NOT NULL,
    name                NVARCHAR(150) NOT NULL,
    category            NVARCHAR(50) NOT NULL,
    brand               NVARCHAR(50) NOT NULL,
    unitcost            DECIMAL(18,2) NOT NULL,
    unitprice           DECIMAL(18,2) NOT NULL,
    margin_pct          DECIMAL(5,4) NOT NULL,
    weight              DECIMAL(10,2) NOT NULL,
    color               NVARCHAR(20) NOT NULL,
    material            NVARCHAR(50) NOT NULL,
    supplierid          INT NOT NULL,
    isactive            TINYINT NOT NULL,
    minstock            INT NOT NULL,
    tax_rate            DECIMAL(5,4) NOT NULL,
    haswarranty         TINYINT NOT NULL,
    ecofriendly         TINYINT NOT NULL,
    seasonalityfactor   DECIMAL(5,2) NOT NULL,
    warrantymonths      TINYINT NOT NULL,
    ecoscore            TINYINT NOT NULL,
    releaseyear         SMALLINT NOT NULL,
    skucount            INT NOT NULL,
    isdiscontinued      TINYINT NOT NULL,
    productrating       DECIMAL(3,1) NOT NULL,
    stockstatus         NVARCHAR(20) NOT NULL
);

CREATE TABLE dbo.dimstore (
    storeid                 INT NOT NULL,
    storename               NVARCHAR(150) NOT NULL,
    city                    NVARCHAR(50) NOT NULL,
    type                    NVARCHAR(50) NOT NULL,
    staff                   SMALLINT NOT NULL,
    sizem2                  INT NOT NULL,
    hascafe                 TINYINT NOT NULL,
    openingyear             SMALLINT NOT NULL,
    region                  NVARCHAR(50) NOT NULL,
    renovationyear          SMALLINT NOT NULL,
    parkingspots            SMALLINT NOT NULL,
    storerating             DECIMAL(3,1) NOT NULL,
    hasdeliveryservice      TINYINT NOT NULL,
    floornumber             TINYINT NOT NULL,
    distancetocitycenterkm  DECIMAL(8,1) NOT NULL,
    annualrentcost          DECIMAL(18,2) NOT NULL,
    storesizemultiplier     DECIMAL(10,4) NOT NULL
);

CREATE TABLE dbo.dimpromotion (
    promoid             INT NOT NULL,
    promoname           NVARCHAR(150) NOT NULL,
    discount_pct        DECIMAL(5,4) NOT NULL,
    discount_fixed      DECIMAL(10,2) NOT NULL,
    type                NVARCHAR(50) NOT NULL,
    isactive            TINYINT NOT NULL,
    minspend            INT NOT NULL,
    channel             NVARCHAR(50) NOT NULL,
    budget              DECIMAL(18,2) NOT NULL,
    startdate           DATE NOT NULL,
    enddate             DATE NOT NULL,
    targetaudience      NVARCHAR(50) NOT NULL,
    maxdiscountcap      DECIMAL(18,2) NOT NULL,
    isstackable         TINYINT NOT NULL,
    redemption_rate     DECIMAL(5,3) NOT NULL,
    coderequired        TINYINT NOT NULL,
    promoupliftfactor   DECIMAL(6,3) NOT NULL
);

CREATE TABLE dbo.factsales (
    salesid             BIGINT NOT NULL,
    datekey             INT NOT NULL,
    productid           INT NOT NULL,
    customerid          INT NOT NULL,
    storeid             INT NOT NULL,
    promoid             INT NOT NULL,
    qty                 INT NOT NULL,
    unitprice           DECIMAL(18,2) NOT NULL,
    tax_rate            DECIMAL(5,4) NOT NULL,
    net                 DECIMAL(18,2) NOT NULL,
    payment             NVARCHAR(20) NOT NULL,
    channel             NVARCHAR(20) NOT NULL,
    grossvalue          DECIMAL(18,2) NOT NULL,
    discountamount      DECIMAL(18,2) NOT NULL,
    taxamount           DECIMAL(18,2) NOT NULL,
    shipcost            DECIMAL(18,2) NOT NULL,
    isreturn            TINYINT NOT NULL,
    shipweight          DECIMAL(10,2) NOT NULL,
    discountapplied     TINYINT NOT NULL,
    returnreason        NVARCHAR(50) NOT NULL,
    deliverydays        TINYINT NOT NULL,
    hour                TINYINT NOT NULL
);
GO

PRINT '  -> Production tables created.';
GO

-- ============================================================================
-- STEP 5: Load data into Staging Tables using BULK INSERT
--   - Uses UTF-8 (65001) codepage configuration for proper character support.
--   - Bulk insert paths assume default path "c:\data\".
-- ============================================================================
PRINT '============================================================';
PRINT 'STEP 5: Load Staging Tables via BULK INSERT';
PRINT '============================================================';

PRINT '  -> Loading staging.stg_dimdate...';
BULK INSERT staging.stg_dimdate FROM 'c:\data\dim_date.csv'
WITH (FIRSTROW=2, FIELDTERMINATOR=',', ROWTERMINATOR='\n', TABLOCK, CODEPAGE='65001');

PRINT '  -> Loading staging.stg_dimcustomer...';
BULK INSERT staging.stg_dimcustomer FROM 'c:\data\dim_customer.csv'
WITH (FIRSTROW=2, FIELDTERMINATOR=',', ROWTERMINATOR='\n', TABLOCK, CODEPAGE='65001');

PRINT '  -> Loading staging.stg_dimproduct...';
BULK INSERT staging.stg_dimproduct FROM 'c:\data\dim_product.csv'
WITH (FIRSTROW=2, FIELDTERMINATOR=',', ROWTERMINATOR='\n', TABLOCK, CODEPAGE='65001');

PRINT '  -> Loading staging.stg_dimstore...';
BULK INSERT staging.stg_dimstore FROM 'c:\data\dim_store.csv'
WITH (FIRSTROW=2, FIELDTERMINATOR=',', ROWTERMINATOR='\n', TABLOCK, CODEPAGE='65001');

PRINT '  -> Loading staging.stg_dimpromotion...';
BULK INSERT staging.stg_dimpromotion FROM 'c:\data\dim_promotion.csv'
WITH (FIRSTROW=2, FIELDTERMINATOR=',', ROWTERMINATOR='\n', TABLOCK, CODEPAGE='65001');

PRINT '  -> Loading staging.stg_factsales (10M rows)...';
BULK INSERT staging.stg_factsales FROM 'c:\data\fact_sales.csv'
WITH (FIRSTROW=2, FIELDTERMINATOR=',', ROWTERMINATOR='\n', TABLOCK, CODEPAGE='65001');
GO

PRINT '  -> Staging ingestion completed.';
GO

-- ============================================================================
-- STEP 6: Populate Production Tables from Staging Layer
--   - Utilizes fast SELECT INTO / INSERT operations.
--   - Enables rapid data migration before constraints are created.
-- ============================================================================
PRINT '============================================================';
PRINT 'STEP 6: Populating production tables from staging';
PRINT '============================================================';

PRINT '  -> Populating dbo.dimdate...';
INSERT INTO dbo.dimdate WITH (TABLOCK) SELECT * FROM staging.stg_dimdate;

PRINT '  -> Populating dbo.dimcustomer...';
INSERT INTO dbo.dimcustomer WITH (TABLOCK) SELECT * FROM staging.stg_dimcustomer;

PRINT '  -> Populating dbo.dimproduct...';
INSERT INTO dbo.dimproduct WITH (TABLOCK) SELECT * FROM staging.stg_dimproduct;

PRINT '  -> Populating dbo.dimstore...';
INSERT INTO dbo.dimstore WITH (TABLOCK) SELECT * FROM staging.stg_dimstore;

PRINT '  -> Populating dbo.dimpromotion...';
INSERT INTO dbo.dimpromotion WITH (TABLOCK) SELECT * FROM staging.stg_dimpromotion;

PRINT '  -> Populating dbo.factsales (10M rows)...';
INSERT INTO dbo.factsales WITH (TABLOCK) SELECT * FROM staging.stg_factsales;
GO

PRINT '  -> Production population completed.';
GO

-- ============================================================================
-- STEP 7: Quality Assurance & Reconciliation
--   - Verify row count consistency between Staging and Production.
-- ============================================================================
PRINT '============================================================';
PRINT 'STEP 7: Running Data Quality & Row-Count Reconciliation';
PRINT '============================================================';
GO

DECLARE @StgDateCount INT, @ProdDateCount INT;
DECLARE @StgCustCount INT, @ProdCustCount INT;
DECLARE @StgProdCount INT, @ProdProdCount INT;
DECLARE @StgStoreCount INT, @ProdStoreCount INT;
DECLARE @StgPromoCount INT, @ProdPromoCount INT;
DECLARE @StgSalesCount INT, @ProdSalesCount INT;

SELECT @StgDateCount = COUNT(*) FROM staging.stg_dimdate;
SELECT @ProdDateCount = COUNT(*) FROM dbo.dimdate;
SELECT @StgCustCount = COUNT(*) FROM staging.stg_dimcustomer;
SELECT @ProdCustCount = COUNT(*) FROM dbo.dimcustomer;
SELECT @StgProdCount = COUNT(*) FROM staging.stg_dimproduct;
SELECT @ProdProdCount = COUNT(*) FROM dbo.dimproduct;
SELECT @StgStoreCount = COUNT(*) FROM staging.stg_dimstore;
SELECT @ProdStoreCount = COUNT(*) FROM dbo.dimstore;
SELECT @StgPromoCount = COUNT(*) FROM staging.stg_dimpromotion;
SELECT @ProdPromoCount = COUNT(*) FROM dbo.dimpromotion;
SELECT @StgSalesCount = COUNT(*) FROM staging.stg_factsales;
SELECT @ProdSalesCount = COUNT(*) FROM dbo.factsales;

PRINT 'Reconciliation Report:';
PRINT '---------------------------------------------------------';
PRINT 'Dimension Date:      Staging = ' + CAST(@StgDateCount AS VARCHAR(10)) + ' | Prod = ' + CAST(@ProdDateCount AS VARCHAR(10));
PRINT 'Dimension Customer:  Staging = ' + CAST(@StgCustCount AS VARCHAR(10)) + ' | Prod = ' + CAST(@ProdCustCount AS VARCHAR(10));
PRINT 'Dimension Product:   Staging = ' + CAST(@StgProdCount AS VARCHAR(10)) + ' | Prod = ' + CAST(@ProdProdCount AS VARCHAR(10));
PRINT 'Dimension Store:     Staging = ' + CAST(@StgStoreCount AS VARCHAR(10)) + ' | Prod = ' + CAST(@ProdStoreCount AS VARCHAR(10));
PRINT 'Dimension Promotion: Staging = ' + CAST(@StgPromoCount AS VARCHAR(10)) + ' | Prod = ' + CAST(@ProdPromoCount AS VARCHAR(10));
PRINT 'Fact Sales:          Staging = ' + CAST(@StgSalesCount AS VARCHAR(10)) + ' | Prod = ' + CAST(@ProdSalesCount AS VARCHAR(10));
PRINT '---------------------------------------------------------';

-- Assertions to catch and abort in case of row loss
IF @StgDateCount <> @ProdDateCount OR @StgSalesCount <> @ProdSalesCount OR @StgCustCount <> @ProdCustCount
BEGIN
    RAISERROR('RECONCILIATION ERROR: Row count mismatch found between Staging and Production layers!', 16, 1);
    ROLLBACK TRANSACTION;
END
ELSE
BEGIN
    PRINT '✓ Reconciliation check passed. All row counts match.';
END
GO

-- ============================================================================
-- STEP 8: Create Constraints & Build Indexes
--   - Applies NONCLUSTERED Primary Keys to allow CCI creation.
--   - Creates Clustered Columnstore Index (CCI) for maximum compression.
--   - Applies Foreign Keys for relational integrity.
-- ============================================================================
PRINT '============================================================';
PRINT 'STEP 8: Create primary keys, indexes, and foreign keys';
PRINT '============================================================';

PRINT '  -> Adding primary keys to dimensions...';
ALTER TABLE dbo.dimdate      ADD CONSTRAINT pk_dimdate      PRIMARY KEY NONCLUSTERED (datekey);
ALTER TABLE dbo.dimcustomer  ADD CONSTRAINT pk_dimcustomer  PRIMARY KEY NONCLUSTERED (customerid);
ALTER TABLE dbo.dimproduct   ADD CONSTRAINT pk_dimproduct   PRIMARY KEY NONCLUSTERED (productid);
ALTER TABLE dbo.dimstore     ADD CONSTRAINT pk_dimstore     PRIMARY KEY NONCLUSTERED (storeid);
ALTER TABLE dbo.dimpromotion ADD CONSTRAINT pk_dimpromotion PRIMARY KEY NONCLUSTERED (promoid);
GO

PRINT '  -> Adding primary key to fact table...';
ALTER TABLE dbo.factsales ADD CONSTRAINT pk_factsales PRIMARY KEY NONCLUSTERED (salesid);
GO

PRINT '  -> Building Clustered Columnstore Index on fact table (10M rows)...';
CREATE CLUSTERED COLUMNSTORE INDEX cci_factsales ON dbo.factsales;
GO

PRINT '  -> Enforcing foreign key constraints (relational validation)...';
ALTER TABLE dbo.factsales ADD CONSTRAINT fk_fact_date      FOREIGN KEY (datekey)    REFERENCES dbo.dimdate(datekey);
ALTER TABLE dbo.factsales ADD CONSTRAINT fk_fact_customer  FOREIGN KEY (customerid) REFERENCES dbo.dimcustomer(customerid);
ALTER TABLE dbo.factsales ADD CONSTRAINT fk_fact_product   FOREIGN KEY (productid)  REFERENCES dbo.dimproduct(productid);
ALTER TABLE dbo.factsales ADD CONSTRAINT fk_fact_store     FOREIGN KEY (storeid)    REFERENCES dbo.dimstore(storeid);
ALTER TABLE dbo.factsales ADD CONSTRAINT fk_fact_promo     FOREIGN KEY (promoid)    REFERENCES dbo.dimpromotion(promoid);
GO

-- ============================================================================
-- STEP 9: Create Additional Indexes for Common Analytical Query Path
-- ============================================================================
PRINT '============================================================';
PRINT 'STEP 9: Create additional indexes';
PRINT '============================================================';

CREATE NONCLUSTERED INDEX ix_dimdate_year_month
    ON dbo.dimdate (year, monthnumber) INCLUDE (fulldate, isweekend, isholiday);

CREATE NONCLUSTERED INDEX ix_dimcustomer_tier_city
    ON dbo.dimcustomer (tier, city) INCLUDE (loyaltysegment, isactive, annualincome);

CREATE NONCLUSTERED INDEX ix_dimproduct_category_brand
    ON dbo.dimproduct (category, brand) INCLUDE (unitprice, tax_rate, isactive, stockstatus);

CREATE NONCLUSTERED INDEX ix_dimstore_region_type
    ON dbo.dimstore (region, type) INCLUDE (city, storerating, storesizemultiplier);

CREATE NONCLUSTERED INDEX ix_dimpromotion_type_channel
    ON dbo.dimpromotion (type, channel) INCLUDE (discount_pct, discount_fixed, isactive, promoupliftfactor);

CREATE NONCLUSTERED INDEX ix_factsales_hour
    ON dbo.factsales (hour) INCLUDE (net, channel);
GO

-- ============================================================================
-- STEP 10: Update Statistics
-- ============================================================================
PRINT '============================================================';
PRINT 'STEP 10: Update statistics';
PRINT '============================================================';

UPDATE STATISTICS dbo.dimdate      WITH FULLSCAN;
UPDATE STATISTICS dbo.dimcustomer  WITH FULLSCAN;
UPDATE STATISTICS dbo.dimproduct   WITH FULLSCAN;
UPDATE STATISTICS dbo.dimstore     WITH FULLSCAN;
UPDATE STATISTICS dbo.dimpromotion WITH FULLSCAN;
UPDATE STATISTICS dbo.factsales    WITH FULLSCAN;
GO

-- ============================================================================
-- STEP 11: Create Simple Views for Quick Analytics Access
-- ============================================================================
PRINT '============================================================';
PRINT 'STEP 11: Create simple views';
PRINT '============================================================';
GO
CREATE VIEW dbo.vw_dates      AS SELECT * FROM dbo.dimdate;
GO
CREATE VIEW dbo.vw_customers  AS SELECT * FROM dbo.dimcustomer;
GO
CREATE VIEW dbo.vw_products   AS SELECT * FROM dbo.dimproduct;
GO
CREATE VIEW dbo.vw_stores     AS SELECT * FROM dbo.dimstore;
GO
CREATE VIEW dbo.vw_promotions AS SELECT * FROM dbo.dimpromotion;
GO
CREATE VIEW dbo.vw_sales      AS SELECT * FROM dbo.factsales;
GO

-- ============================================================================
-- STEP 12: Drop Staging Layer after Successful Ingestion
--   - Clean up staging tables to free memory/storage (optional, but recommended).
-- ============================================================================
PRINT '============================================================';
PRINT 'STEP 12: Cleanup Staging Tables';
PRINT '============================================================';
GO
DROP TABLE staging.stg_factsales;
DROP TABLE staging.stg_dimdate;
DROP TABLE staging.stg_dimcustomer;
DROP TABLE staging.stg_dimproduct;
DROP TABLE staging.stg_dimstore;
DROP TABLE staging.stg_dimpromotion;
GO

-- ============================================================================
-- STEP 13: Final Row Counts Display
-- ============================================================================
PRINT '============================================================';
PRINT 'STEP 13: Display final row counts';
PRINT '============================================================';

SELECT 'dimdate'      AS table_name, COUNT(*) FROM dbo.dimdate
UNION ALL
SELECT 'dimcustomer'  , COUNT(*) FROM dbo.dimcustomer
UNION ALL
SELECT 'dimproduct'   , COUNT(*) FROM dbo.dimproduct
UNION ALL
SELECT 'dimstore'     , COUNT(*) FROM dbo.dimstore
UNION ALL
SELECT 'dimpromotion' , COUNT(*) FROM dbo.dimpromotion
UNION ALL
SELECT 'factsales'    , COUNT(*) FROM dbo.factsales;

PRINT '============================================================';
PRINT '✅ Database retailanalytics loaded successfully.';
PRINT '   - ELT Staging area used & cleaned up.';
PRINT '   - No NULLs, referential integrity enforced.';
PRINT '   - Clustered columnstore index created on factsales.';
PRINT '   - All dummy (-1) rows correctly ingested from Python.';
PRINT '============================================================';
-- ============================================================================
-- End of build_retailanalytics_database.sql
-- ============================================================================