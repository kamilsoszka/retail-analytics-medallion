-- =====================================================================
-- T-SQL Load Script for retailanalytics database (Python v46 compatible)
-- No dimmanager table, no denormalized columns in factsales.
-- All percent columns have _pct suffix.
-- =====================================================================

USE master;
GO

IF DB_ID('retailanalytics') IS NOT NULL
BEGIN
    ALTER DATABASE retailanalytics SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE retailanalytics;
END
GO

CREATE DATABASE retailanalytics;
GO
ALTER DATABASE retailanalytics SET RECOVERY SIMPLE;
GO
USE retailanalytics;
GO

-- Drop existing objects
IF OBJECT_ID('dbo.vw_sales', 'V') IS NOT NULL DROP VIEW dbo.vw_sales;
IF OBJECT_ID('dbo.vw_customers', 'V') IS NOT NULL DROP VIEW dbo.vw_customers;
IF OBJECT_ID('dbo.vw_dates', 'V') IS NOT NULL DROP VIEW dbo.vw_dates;
IF OBJECT_ID('dbo.vw_products', 'V') IS NOT NULL DROP VIEW dbo.vw_products;
IF OBJECT_ID('dbo.vw_promotions', 'V') IS NOT NULL DROP VIEW dbo.vw_promotions;
IF OBJECT_ID('dbo.vw_stores', 'V') IS NOT NULL DROP VIEW dbo.vw_stores;
GO

IF OBJECT_ID('dbo.factsales', 'U') IS NOT NULL DROP TABLE dbo.factsales;
IF OBJECT_ID('dbo.dimdate', 'U') IS NOT NULL DROP TABLE dbo.dimdate;
IF OBJECT_ID('dbo.dimcustomer', 'U') IS NOT NULL DROP TABLE dbo.dimcustomer;
IF OBJECT_ID('dbo.dimproduct', 'U') IS NOT NULL DROP TABLE dbo.dimproduct;
IF OBJECT_ID('dbo.dimstore', 'U') IS NOT NULL DROP TABLE dbo.dimstore;
IF OBJECT_ID('dbo.dimpromotion', 'U') IS NOT NULL DROP TABLE dbo.dimpromotion;
GO

-- =====================================================================
-- CREATE TABLES
-- =====================================================================
CREATE TABLE dbo.dimdate (
    datekey INT NOT NULL CONSTRAINT pk_dimdate PRIMARY KEY,
    fulldate DATE NOT NULL,
    year SMALLINT NOT NULL,
    quarternumber TINYINT NOT NULL,
    quartername NCHAR(2) NOT NULL,
    monthnumber TINYINT NOT NULL,
    monthname NVARCHAR(20) NOT NULL,
    weekdaynumber TINYINT NOT NULL,
    weekdayname NVARCHAR(20) NOT NULL,
    isweekend BIT NOT NULL,
    yearmonth NCHAR(7) NOT NULL,
    yearmonthnumber INT NOT NULL,
    yearquarter NVARCHAR(7) NOT NULL,
    yearquarternumber INT NOT NULL,
    yearweek NVARCHAR(8) NOT NULL,
    yearweeknumber INT NOT NULL,
    isholiday BIT NOT NULL
);
GO

CREATE TABLE dbo.dimcustomer (
    customerid INT NOT NULL CONSTRAINT pk_dimcustomer PRIMARY KEY,
    fullname NVARCHAR(100) NOT NULL,
    email NVARCHAR(100) NOT NULL,
    age TINYINT NOT NULL,
    gender NVARCHAR(20) NOT NULL,
    city NVARCHAR(50) NOT NULL,
    tier NVARCHAR(20) NOT NULL,
    points INT NOT NULL,
    isactive BIT NOT NULL,
    lang NVARCHAR(10) NOT NULL,
    totalspend DECIMAL(18,2) NOT NULL,
    regdate DATE NOT NULL,
    annualincome DECIMAL(18,2) NOT NULL,
    incomebracket NVARCHAR(20) NOT NULL,
    education NVARCHAR(50) NOT NULL,
    maritalstatus NVARCHAR(20) NOT NULL,
    childrencount TINYINT NOT NULL,
    loyaltysegment NVARCHAR(20) NOT NULL,
    satisfactionscore DECIMAL(5,1) NOT NULL,
    dayssincelastpurchase INT NOT NULL,
    hassubscription BIT NOT NULL,
    preferredcontact NVARCHAR(20) NOT NULL,
    spendmultiplier DECIMAL(10,3) NOT NULL
);
GO

CREATE TABLE dbo.dimproduct (
    productid INT NOT NULL CONSTRAINT pk_dimproduct PRIMARY KEY,
    name NVARCHAR(150) NOT NULL,
    category NVARCHAR(50) NOT NULL,
    brand NVARCHAR(50) NOT NULL,
    unitcost DECIMAL(18,2) NOT NULL,
    unitprice DECIMAL(18,2) NOT NULL,
    margin_pct DECIMAL(5,4) NOT NULL,          -- fraction, 0.15 = 15%
    weight DECIMAL(10,2) NOT NULL,
    color NVARCHAR(20) NOT NULL,
    material NVARCHAR(50) NOT NULL,
    supplierid INT NOT NULL,
    isactive BIT NOT NULL,
    minstock INT NOT NULL,
    taxrate_pct DECIMAL(5,4) NOT NULL,         -- fraction
    haswarranty BIT NOT NULL,
    ecofriendly BIT NOT NULL,
    seasonalityfactor DECIMAL(5,2) NOT NULL,
    warrantymonths TINYINT NOT NULL,
    ecoscore TINYINT NOT NULL,
    releaseyear SMALLINT NOT NULL,
    skucount INT NOT NULL,
    isdiscontinued BIT NOT NULL,
    productrating DECIMAL(3,1) NOT NULL,
    stockstatus NVARCHAR(20) NOT NULL
);
GO

CREATE TABLE dbo.dimstore (
    storeid INT NOT NULL CONSTRAINT pk_dimstore PRIMARY KEY,
    storename NVARCHAR(150) NOT NULL,
    city NVARCHAR(50) NOT NULL,
    type NVARCHAR(50) NOT NULL,
    staff SMALLINT NOT NULL,
    sizem2 INT NOT NULL,
    hascafe BIT NOT NULL,
    openingyear SMALLINT NOT NULL,
    region NVARCHAR(50) NOT NULL,
    renovationyear SMALLINT NOT NULL,
    parkingspots SMALLINT NOT NULL,
    storerating DECIMAL(3,1) NOT NULL,
    hasdeliveryservice BIT NOT NULL,
    floornumber TINYINT NOT NULL,
    distancetocitycenterkm DECIMAL(8,1) NOT NULL,
    annualrentcost DECIMAL(18,2) NOT NULL,
    storesizemultiplier DECIMAL(10,3) NOT NULL
);
GO

CREATE TABLE dbo.dimpromotion (
    promoid INT NOT NULL CONSTRAINT pk_dimpromotion PRIMARY KEY,
    promoname NVARCHAR(150) NOT NULL,
    discount_pct DECIMAL(5,3) NOT NULL,             -- fraction
    discount_fixed DECIMAL(10,2) NOT NULL,
    type NVARCHAR(50) NOT NULL,
    isactive BIT NOT NULL,
    minspend INT NOT NULL,
    channel NVARCHAR(50) NOT NULL,
    budget DECIMAL(18,2) NOT NULL,
    startdate DATE NOT NULL,
    enddate DATE NOT NULL,
    targetaudience NVARCHAR(50) NOT NULL,
    maxdiscountcap DECIMAL(18,2) NOT NULL,
    isstackable BIT NOT NULL,
    redemption_rate_target_pct DECIMAL(5,3) NOT NULL, -- fraction
    coderequired BIT NOT NULL,
    promoupliftfactor DECIMAL(6,3) NOT NULL
);
GO

CREATE TABLE dbo.factsales (
    salesid BIGINT NOT NULL,
    datekey INT NOT NULL,
    productid INT NOT NULL,
    customerid INT NOT NULL,
    storeid INT NOT NULL,
    promoid INT NOT NULL,
    qty TINYINT NOT NULL,
    unitprice DECIMAL(18,2) NOT NULL,
    taxrate_pct DECIMAL(5,4) NOT NULL,
    net DECIMAL(18,2) NOT NULL,
    payment NVARCHAR(20) NOT NULL,
    channel NVARCHAR(20) NOT NULL,
    grossvalue DECIMAL(18,2) NOT NULL,
    discountamount DECIMAL(18,2) NOT NULL,
    taxamount DECIMAL(18,2) NOT NULL,
    shipcost DECIMAL(18,2) NOT NULL,
    isreturn BIT NOT NULL,
    shipweight DECIMAL(10,2) NOT NULL,
    discountapplied BIT NOT NULL,
    returnreason NVARCHAR(50) NULL,
    deliverydays TINYINT NOT NULL
);
GO

-- =====================================================================
-- STAGING FOR DIM_DATE (handles True/False)
-- =====================================================================
CREATE TABLE #dimdate_staging (
    datekey NVARCHAR(50),
    fulldate NVARCHAR(50),
    year NVARCHAR(50),
    quarternumber NVARCHAR(50),
    quartername NVARCHAR(50),
    monthnumber NVARCHAR(50),
    monthname NVARCHAR(50),
    weekdaynumber NVARCHAR(50),
    weekdayname NVARCHAR(50),
    isweekend NVARCHAR(50),
    yearmonth NVARCHAR(50),
    yearmonthnumber NVARCHAR(50),
    yearquarter NVARCHAR(50),
    yearquarternumber NVARCHAR(50),
    yearweek NVARCHAR(50),
    yearweeknumber NVARCHAR(50),
    isholiday NVARCHAR(50)
);
GO

BULK INSERT #dimdate_staging FROM 'c:\data\dim_date.csv' 
WITH (FIRSTROW=2, FIELDTERMINATOR=',', ROWTERMINATOR='0x0A', TABLOCK, CODEPAGE='65001');
GO

INSERT INTO dbo.dimdate (
    datekey, fulldate, year, quarternumber, quartername, monthnumber, monthname,
    weekdaynumber, weekdayname, isweekend, yearmonth, yearmonthnumber, yearquarter,
    yearquarternumber, yearweek, yearweeknumber, isholiday
)
SELECT 
    TRY_CAST(datekey AS INT),
    TRY_CAST(fulldate AS DATE),
    TRY_CAST(year AS SMALLINT),
    TRY_CAST(quarternumber AS TINYINT),
    quartername,
    TRY_CAST(monthnumber AS TINYINT),
    monthname,
    TRY_CAST(weekdaynumber AS TINYINT),
    weekdayname,
    CASE WHEN isweekend IN ('1', 'True', 'true', 'TRUE') THEN 1 ELSE 0 END,
    yearmonth,
    TRY_CAST(yearmonthnumber AS INT),
    yearquarter,
    TRY_CAST(yearquarternumber AS INT),
    yearweek,
    TRY_CAST(yearweeknumber AS INT),
    CASE WHEN isholiday IN ('1', 'True', 'true', 'TRUE') THEN 1 ELSE 0 END
FROM #dimdate_staging;
GO

DROP TABLE #dimdate_staging;
GO

-- =====================================================================
-- BULK INSERT FOR ALL TABLES (no staging needed for others)
-- =====================================================================
PRINT 'Loading dim_customer...';
BULK INSERT dbo.dimcustomer FROM 'c:\data\dim_customer.csv' 
WITH (FIRSTROW=2, FIELDTERMINATOR=',', ROWTERMINATOR='0x0A', TABLOCK, CODEPAGE='65001', BATCHSIZE=50000);
GO

PRINT 'Loading dim_product...';
BULK INSERT dbo.dimproduct FROM 'c:\data\dim_product.csv' 
WITH (FIRSTROW=2, FIELDTERMINATOR=',', ROWTERMINATOR='0x0A', TABLOCK, CODEPAGE='65001', BATCHSIZE=50000);
GO

PRINT 'Loading dim_store...';
BULK INSERT dbo.dimstore FROM 'c:\data\dim_store.csv' 
WITH (FIRSTROW=2, FIELDTERMINATOR=',', ROWTERMINATOR='0x0A', TABLOCK, CODEPAGE='65001', BATCHSIZE=50000);
GO

PRINT 'Loading dim_promotion...';
BULK INSERT dbo.dimpromotion FROM 'c:\data\dim_promotion.csv' 
WITH (FIRSTROW=2, FIELDTERMINATOR=',', ROWTERMINATOR='0x0A', TABLOCK, CODEPAGE='65001', BATCHSIZE=50000);
GO

-- Insert dummy promotion with promoid = 0
IF NOT EXISTS (SELECT 1 FROM dbo.dimpromotion WHERE promoid = 0)
BEGIN
    INSERT INTO dbo.dimpromotion (promoid, promoname, discount_pct, discount_fixed, type, isactive, minspend, channel, budget, startdate, enddate, targetaudience, maxdiscountcap, isstackable, redemption_rate_target_pct, coderequired, promoupliftfactor)
    VALUES (0, 'No Promotion', 0.000, 0.00, 'None', 1, 0, 'None', 0, '2000-01-01', '2099-12-31', 'All', 0, 0, 0.000, 0, 1.000);
END
GO

PRINT 'Loading fact_sales...';
BULK INSERT dbo.factsales FROM 'c:\data\fact_sales.csv' 
WITH (FIRSTROW=2, FIELDTERMINATOR=',', ROWTERMINATOR='0x0A', TABLOCK, CODEPAGE='65001', BATCHSIZE=100000, KEEPNULLS);
GO

-- =====================================================================
-- CONSTRAINTS & INDEXES
-- =====================================================================
ALTER TABLE dbo.factsales ADD CONSTRAINT pk_factsales PRIMARY KEY NONCLUSTERED (salesid);
GO
CREATE CLUSTERED COLUMNSTORE INDEX cci_factsales ON dbo.factsales;
GO

ALTER TABLE dbo.factsales ADD CONSTRAINT fk_fact_date FOREIGN KEY (datekey) REFERENCES dbo.dimdate(datekey);
ALTER TABLE dbo.factsales ADD CONSTRAINT fk_fact_customer FOREIGN KEY (customerid) REFERENCES dbo.dimcustomer(customerid);
ALTER TABLE dbo.factsales ADD CONSTRAINT fk_fact_product FOREIGN KEY (productid) REFERENCES dbo.dimproduct(productid);
ALTER TABLE dbo.factsales ADD CONSTRAINT fk_fact_store FOREIGN KEY (storeid) REFERENCES dbo.dimstore(storeid);
ALTER TABLE dbo.factsales ADD CONSTRAINT fk_fact_promo FOREIGN KEY (promoid) REFERENCES dbo.dimpromotion(promoid);
GO

CREATE NONCLUSTERED INDEX ix_dimdate_year_month ON dbo.dimdate (year, monthnumber) INCLUDE (fulldate, isweekend, isholiday);
CREATE NONCLUSTERED INDEX ix_dimcustomer_tier_city ON dbo.dimcustomer (tier, city) INCLUDE (loyaltysegment, isactive, annualincome);
CREATE NONCLUSTERED INDEX ix_dimproduct_category_brand ON dbo.dimproduct (category, brand) INCLUDE (unitprice, taxrate_pct, isactive, stockstatus);
CREATE NONCLUSTERED INDEX ix_dimstore_region_type ON dbo.dimstore (region, type) INCLUDE (city, storerating, storesizemultiplier);
CREATE NONCLUSTERED INDEX ix_dimpromotion_type_channel ON dbo.dimpromotion (type, channel) INCLUDE (discount_pct, discount_fixed, isactive, promoupliftfactor);
GO

UPDATE STATISTICS dbo.dimdate WITH FULLSCAN;
UPDATE STATISTICS dbo.dimcustomer WITH FULLSCAN;
UPDATE STATISTICS dbo.dimproduct WITH FULLSCAN;
UPDATE STATISTICS dbo.dimstore WITH FULLSCAN;
UPDATE STATISTICS dbo.dimpromotion WITH FULLSCAN;
UPDATE STATISTICS dbo.factsales WITH FULLSCAN;
GO

-- =====================================================================
-- VIEWS FOR REPORTING
-- =====================================================================
CREATE VIEW dbo.vw_dates AS SELECT * FROM dbo.dimdate;
GO
CREATE VIEW dbo.vw_customers AS SELECT * FROM dbo.dimcustomer;
GO
CREATE VIEW dbo.vw_products AS SELECT * FROM dbo.dimproduct;
GO
CREATE VIEW dbo.vw_stores AS SELECT * FROM dbo.dimstore;
GO
CREATE VIEW dbo.vw_promotions AS SELECT * FROM dbo.dimpromotion;
GO
CREATE VIEW dbo.vw_sales AS SELECT * FROM dbo.factsales;
GO

-- =====================================================================
-- VERIFICATION
-- =====================================================================
PRINT 'Row counts after load:';
SELECT 'dimdate' AS table_name, COUNT(*) AS rows FROM dbo.dimdate UNION ALL
SELECT 'dimcustomer', COUNT(*) FROM dbo.dimcustomer UNION ALL
SELECT 'dimproduct', COUNT(*) FROM dbo.dimproduct UNION ALL
SELECT 'dimstore', COUNT(*) FROM dbo.dimstore UNION ALL
SELECT 'dimpromotion', COUNT(*) FROM dbo.dimpromotion UNION ALL
SELECT 'factsales', COUNT(*) FROM dbo.factsales;
GO

PRINT '✅ Database retailanalytics loaded successfully.';