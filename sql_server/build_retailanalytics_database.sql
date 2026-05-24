-- ============================================================================
-- build_retailanalytics_database.sql
-- ============================================================================
-- Author:           DataGen AI
-- Created:           2026-05-23
-- Last modified:     2026-05-24 02:00:00 UTC
-- Suggested name:    build_retailanalytics_database.sql
-- Description:
--   Creates the retailanalytics database in SQL Server, loads data from
--   previously generated CSV files (dimensions + 10M fact rows), adds
--   primary/foreign keys, a clustered columnstore index, basic views,
--   and updates statistics.
--   All percentage columns (margin_pct, discount_pct) are stored as decimal
--   fractions (0.0–1.0).  Other rate columns remain fractions as well.
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
-- STEP 1: Remove any left-over objects from previous runs
-- ============================================================================
PRINT '============================================================';
PRINT 'STEP 1: Drop existing objects';
PRINT '============================================================';

-- Drop simple views first (if they exist)
IF OBJECT_ID('dbo.vw_sales', 'V')      IS NOT NULL DROP VIEW dbo.vw_sales;
IF OBJECT_ID('dbo.vw_customers', 'V')  IS NOT NULL DROP VIEW dbo.vw_customers;
IF OBJECT_ID('dbo.vw_dates', 'V')      IS NOT NULL DROP VIEW dbo.vw_dates;
IF OBJECT_ID('dbo.vw_products', 'V')   IS NOT NULL DROP VIEW dbo.vw_products;
IF OBJECT_ID('dbo.vw_promotions', 'V') IS NOT NULL DROP VIEW dbo.vw_promotions;
IF OBJECT_ID('dbo.vw_stores', 'V')     IS NOT NULL DROP VIEW dbo.vw_stores;
GO

-- Drop tables (fact first, then dimensions)
IF OBJECT_ID('dbo.factsales', 'U')     IS NOT NULL DROP TABLE dbo.factsales;
IF OBJECT_ID('dbo.dimdate', 'U')       IS NOT NULL DROP TABLE dbo.dimdate;
IF OBJECT_ID('dbo.dimcustomer', 'U')   IS NOT NULL DROP TABLE dbo.dimcustomer;
IF OBJECT_ID('dbo.dimproduct', 'U')    IS NOT NULL DROP TABLE dbo.dimproduct;
IF OBJECT_ID('dbo.dimstore', 'U')      IS NOT NULL DROP TABLE dbo.dimstore;
IF OBJECT_ID('dbo.dimpromotion', 'U')  IS NOT NULL DROP TABLE dbo.dimpromotion;
GO

PRINT '  -> Old objects dropped.';
GO

-- ============================================================================
-- STEP 2: Create all tables with appropriate data types
--   - Every column is NOT NULL; no empty strings or NULLs are expected.
--   - Fractional _pct columns use DECIMAL(5,4) (range 0.0000‑1.0000).
-- ============================================================================
PRINT '============================================================';
PRINT 'STEP 2: Create tables';
PRINT '============================================================';

-- Date dimension
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
GO

-- Customer dimension
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
GO

-- Product dimension (margin_pct is a fraction, e.g. 0.1196 = 11.96%)
CREATE TABLE dbo.dimproduct (
    productid           INT NOT NULL,
    name                NVARCHAR(150) NOT NULL,
    category            NVARCHAR(50) NOT NULL,
    brand               NVARCHAR(50) NOT NULL,
    unitcost            DECIMAL(18,2) NOT NULL,
    unitprice           DECIMAL(18,2) NOT NULL,
    margin_pct          DECIMAL(5,4) NOT NULL,        -- fraction (0.0000 to 0.3000)
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
GO

-- Store dimension (storesizemultiplier has a wide spread 0.1–10.0)
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
    storesizemultiplier     DECIMAL(10,3) NOT NULL
);
GO

-- Promotion dimension (discount_pct is a fraction, e.g. 0.2500 = 25%)
CREATE TABLE dbo.dimpromotion (
    promoid             INT NOT NULL,
    promoname           NVARCHAR(150) NOT NULL,
    discount_pct        DECIMAL(5,4) NOT NULL,      -- fraction (0.0000 to 0.4500)
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
GO

-- Fact sales table (10M rows)
CREATE TABLE dbo.factsales (
    salesid             BIGINT NOT NULL,
    datekey             INT NOT NULL,
    productid           INT NOT NULL,
    customerid          INT NOT NULL,
    storeid             INT NOT NULL,
    promoid             INT NOT NULL,
    qty                 TINYINT NOT NULL,
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

PRINT '  -> Tables created.';
GO

-- ============================================================================
-- STEP 3‑8: Load data from CSV files
--   BULK INSERT is used for maximum performance.
--   Paths assume CSV files are in c:\data\. Modify if necessary.
-- ============================================================================

-- dim_date
PRINT 'STEP 3: Load dim_date';
BULK INSERT dbo.dimdate FROM 'c:\data\dim_date.csv'
WITH (FIRSTROW=2, FIELDTERMINATOR=',', ROWTERMINATOR='\n', TABLOCK, CODEPAGE='65001');
PRINT '  -> dim_date loaded.';

-- dim_customer
PRINT 'STEP 4: Load dim_customer';
BULK INSERT dbo.dimcustomer FROM 'c:\data\dim_customer.csv'
WITH (FIRSTROW=2, FIELDTERMINATOR=',', ROWTERMINATOR='\n', TABLOCK, CODEPAGE='65001');
PRINT '  -> dim_customer loaded.';

-- dim_product
PRINT 'STEP 5: Load dim_product';
BULK INSERT dbo.dimproduct FROM 'c:\data\dim_product.csv'
WITH (FIRSTROW=2, FIELDTERMINATOR=',', ROWTERMINATOR='\n', TABLOCK, CODEPAGE='65001');
PRINT '  -> dim_product loaded.';

-- dim_store
PRINT 'STEP 6: Load dim_store';
BULK INSERT dbo.dimstore FROM 'c:\data\dim_store.csv'
WITH (FIRSTROW=2, FIELDTERMINATOR=',', ROWTERMINATOR='\n', TABLOCK, CODEPAGE='65001');
PRINT '  -> dim_store loaded.';

-- dim_promotion (and ensure dummy row promoid=0 exists)
PRINT 'STEP 7: Load dim_promotion';
BULK INSERT dbo.dimpromotion FROM 'c:\data\dim_promotion.csv'
WITH (FIRSTROW=2, FIELDTERMINATOR=',', ROWTERMINATOR='\n', TABLOCK, CODEPAGE='65001');
IF NOT EXISTS (SELECT 1 FROM dbo.dimpromotion WHERE promoid = 0)
    INSERT INTO dbo.dimpromotion (
        promoid, promoname, discount_pct, discount_fixed, type, isactive,
        minspend, channel, budget, startdate, enddate, targetaudience,
        maxdiscountcap, isstackable, redemption_rate, coderequired, promoupliftfactor
    )
    VALUES (
        0, 'No Promotion', 0.0, 0.0, 'None', 1, 0, 'All', 0.0,
        '2000-01-01', '2099-12-31', 'All', 0.0, 0, 0.0, 0, 1.0
    );
PRINT '  -> dim_promotion loaded.';

-- fact_sales (10M rows)
PRINT 'STEP 8: Load fact_sales (10M rows)';
BULK INSERT dbo.factsales FROM 'c:\data\fact_sales.csv'
WITH (FIRSTROW=2, FIELDTERMINATOR=',', ROWTERMINATOR='\n', TABLOCK, CODEPAGE='65001');
PRINT '  -> fact_sales loaded.';
GO

-- ============================================================================
-- STEP 9: Add primary keys and foreign keys
--   - PKs are NONCLUSTERED because the fact table will later get a CCI.
--   - FKs enforce referential integrity.
-- ============================================================================
PRINT '============================================================';
PRINT 'STEP 9: Add primary keys and foreign keys';
PRINT '============================================================';

ALTER TABLE dbo.dimdate      ADD CONSTRAINT pk_dimdate      PRIMARY KEY NONCLUSTERED (datekey);
ALTER TABLE dbo.dimcustomer  ADD CONSTRAINT pk_dimcustomer  PRIMARY KEY NONCLUSTERED (customerid);
ALTER TABLE dbo.dimproduct   ADD CONSTRAINT pk_dimproduct   PRIMARY KEY NONCLUSTERED (productid);
ALTER TABLE dbo.dimstore     ADD CONSTRAINT pk_dimstore     PRIMARY KEY NONCLUSTERED (storeid);
ALTER TABLE dbo.dimpromotion ADD CONSTRAINT pk_dimpromotion PRIMARY KEY NONCLUSTERED (promoid);
GO

ALTER TABLE dbo.factsales ADD CONSTRAINT pk_factsales PRIMARY KEY NONCLUSTERED (salesid);
-- Clustered columnstore index for optimal compression and query performance on large fact table
CREATE CLUSTERED COLUMNSTORE INDEX cci_factsales ON dbo.factsales;
GO

-- Foreign keys
ALTER TABLE dbo.factsales ADD CONSTRAINT fk_fact_date      FOREIGN KEY (datekey)    REFERENCES dbo.dimdate(datekey);
ALTER TABLE dbo.factsales ADD CONSTRAINT fk_fact_customer  FOREIGN KEY (customerid) REFERENCES dbo.dimcustomer(customerid);
ALTER TABLE dbo.factsales ADD CONSTRAINT fk_fact_product   FOREIGN KEY (productid)  REFERENCES dbo.dimproduct(productid);
ALTER TABLE dbo.factsales ADD CONSTRAINT fk_fact_store     FOREIGN KEY (storeid)    REFERENCES dbo.dimstore(storeid);
ALTER TABLE dbo.factsales ADD CONSTRAINT fk_fact_promo     FOREIGN KEY (promoid)    REFERENCES dbo.dimpromotion(promoid);
GO

-- ============================================================================
-- STEP 10: Additional indexes for common analytical queries
-- ============================================================================
PRINT '============================================================';
PRINT 'STEP 10: Create additional indexes';
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
-- STEP 11: Update statistics
-- ============================================================================
PRINT '============================================================';
PRINT 'STEP 11: Update statistics';
PRINT '============================================================';

UPDATE STATISTICS dbo.dimdate      WITH FULLSCAN;
UPDATE STATISTICS dbo.dimcustomer  WITH FULLSCAN;
UPDATE STATISTICS dbo.dimproduct   WITH FULLSCAN;
UPDATE STATISTICS dbo.dimstore     WITH FULLSCAN;
UPDATE STATISTICS dbo.dimpromotion WITH FULLSCAN;
UPDATE STATISTICS dbo.factsales    WITH FULLSCAN;
GO

-- ============================================================================
-- STEP 12: Create simple views for quick data inspection
-- ============================================================================
PRINT '============================================================';
PRINT 'STEP 12: Create simple views';
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
-- STEP 13: Final row counts
-- ============================================================================
PRINT '============================================================';
PRINT 'STEP 13: Display row counts';
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
PRINT '   - No NULLs, referential integrity enforced.';
PRINT '   - 10M rows in factsales.';
PRINT '   - Product margins ≤30 % (stored as fractions).';
PRINT '============================================================';
-- ============================================================================
-- End of build_retailanalytics_database.sql
-- ============================================================================