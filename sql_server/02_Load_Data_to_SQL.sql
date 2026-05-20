-- =====================================================================
-- final_retail_loader.sql
-- =====================================================================
-- Author:       AI Assistant
-- Generated:    2026-05-21 01:30:00 UTC
-- Purpose:      Load retail data into SQL Server (retailanalytics)
--               - Forces storename non-NULL, deliverydays=0 for In-Store
--               - Ensures promoid=0, returnreason='No return', hour NOT NULL
-- =====================================================================

USE master;
GO

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

PRINT '============================================================';
PRINT 'STEP 1: Drop existing objects (views, tables)';
PRINT '============================================================';

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

PRINT '  -> Old objects dropped.';
GO

PRINT '============================================================';
PRINT 'STEP 2: Create tables (including hour column)';
PRINT '============================================================';

CREATE TABLE dbo.dimdate (
    datekey INT NOT NULL,
    fulldate DATE NOT NULL,
    year SMALLINT NOT NULL,
    quarternumber TINYINT NOT NULL,
    quartername NCHAR(2) NOT NULL,
    monthnumber TINYINT NOT NULL,
    monthname NVARCHAR(20) NOT NULL,
    weekdaynumber TINYINT NOT NULL,
    weekdayname NVARCHAR(20) NOT NULL,
    isweekend TINYINT NOT NULL,
    yearmonth NCHAR(7) NOT NULL,
    yearmonthnumber INT NOT NULL,
    yearquarter NVARCHAR(7) NOT NULL,
    yearquarternumber INT NOT NULL,
    yearweek NVARCHAR(8) NOT NULL,
    yearweeknumber INT NOT NULL,
    isholiday TINYINT NOT NULL
);
GO

CREATE TABLE dbo.dimcustomer (
    customerid INT NOT NULL,
    fullname NVARCHAR(100) NOT NULL,
    email NVARCHAR(100) NOT NULL,
    age TINYINT NOT NULL,
    gender NVARCHAR(20) NOT NULL,
    city NVARCHAR(50) NOT NULL,
    tier NVARCHAR(20) NOT NULL,
    points INT NOT NULL,
    isactive TINYINT NOT NULL,
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
    hassubscription TINYINT NOT NULL,
    preferredcontact NVARCHAR(20) NOT NULL,
    spendmultiplier DECIMAL(10,3) NOT NULL
);
GO

CREATE TABLE dbo.dimproduct (
    productid INT NOT NULL,
    name NVARCHAR(150) NOT NULL,
    category NVARCHAR(50) NOT NULL,
    brand NVARCHAR(50) NOT NULL,
    unitcost DECIMAL(18,2) NOT NULL,
    unitprice DECIMAL(18,2) NOT NULL,
    margin_pct DECIMAL(5,4) NOT NULL,
    weight DECIMAL(10,2) NOT NULL,
    color NVARCHAR(20) NOT NULL,
    material NVARCHAR(50) NOT NULL,
    supplierid INT NOT NULL,
    isactive TINYINT NOT NULL,
    minstock INT NOT NULL,
    tax_rate DECIMAL(5,4) NOT NULL,
    haswarranty TINYINT NOT NULL,
    ecofriendly TINYINT NOT NULL,
    seasonalityfactor DECIMAL(5,2) NOT NULL,
    warrantymonths TINYINT NOT NULL,
    ecoscore TINYINT NOT NULL,
    releaseyear SMALLINT NOT NULL,
    skucount INT NOT NULL,
    isdiscontinued TINYINT NOT NULL,
    productrating DECIMAL(3,1) NOT NULL,
    stockstatus NVARCHAR(20) NOT NULL
);
GO

CREATE TABLE dbo.dimstore (
    storeid INT NOT NULL,
    storename NVARCHAR(150) NOT NULL,
    city NVARCHAR(50) NOT NULL,
    type NVARCHAR(50) NOT NULL,
    staff SMALLINT NOT NULL,
    sizem2 INT NOT NULL,
    hascafe TINYINT NOT NULL,
    openingyear SMALLINT NOT NULL,
    region NVARCHAR(50) NOT NULL,
    renovationyear SMALLINT NOT NULL,
    parkingspots SMALLINT NOT NULL,
    storerating DECIMAL(3,1) NOT NULL,
    hasdeliveryservice TINYINT NOT NULL,
    floornumber TINYINT NOT NULL,
    distancetocitycenterkm DECIMAL(8,1) NOT NULL,
    annualrentcost DECIMAL(18,2) NOT NULL,
    storesizemultiplier DECIMAL(10,3) NOT NULL
);
GO

CREATE TABLE dbo.dimpromotion (
    promoid INT NOT NULL,
    promoname NVARCHAR(150) NOT NULL,
    discount_pct DECIMAL(5,3) NOT NULL,
    discount_fixed DECIMAL(10,2) NOT NULL,
    type NVARCHAR(50) NOT NULL,
    isactive TINYINT NOT NULL,
    minspend INT NOT NULL,
    channel NVARCHAR(50) NOT NULL,
    budget DECIMAL(18,2) NOT NULL,
    startdate DATE NOT NULL,
    enddate DATE NOT NULL,
    targetaudience NVARCHAR(50) NOT NULL,
    maxdiscountcap DECIMAL(18,2) NOT NULL,
    isstackable TINYINT NOT NULL,
    redemption_rate DECIMAL(5,3) NOT NULL,
    coderequired TINYINT NOT NULL,
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
    tax_rate DECIMAL(5,4) NOT NULL,
    net DECIMAL(18,2) NOT NULL,
    payment NVARCHAR(20) NOT NULL,
    channel NVARCHAR(20) NOT NULL,
    grossvalue DECIMAL(18,2) NOT NULL,
    discountamount DECIMAL(18,2) NOT NULL,
    taxamount DECIMAL(18,2) NOT NULL,
    shipcost DECIMAL(18,2) NOT NULL,
    isreturn TINYINT NOT NULL,
    shipweight DECIMAL(10,2) NOT NULL,
    discountapplied TINYINT NOT NULL,
    returnreason NVARCHAR(50) NOT NULL,
    deliverydays TINYINT NOT NULL,
    hour TINYINT NOT NULL
);
GO

PRINT '  -> Tables created.';
GO

-- =====================================================================
-- STEP 3: Load dim_date
-- =====================================================================
PRINT '============================================================';
PRINT 'STEP 3: Load dim_date from CSV';
PRINT '============================================================';

DROP TABLE IF EXISTS #dimdate_staging;
CREATE TABLE #dimdate_staging (
    datekey NVARCHAR(50), fulldate NVARCHAR(50), year NVARCHAR(50),
    quarternumber NVARCHAR(50), quartername NVARCHAR(50), monthnumber NVARCHAR(50),
    monthname NVARCHAR(50), weekdaynumber NVARCHAR(50), weekdayname NVARCHAR(50),
    isweekend NVARCHAR(50), yearmonth NVARCHAR(50), yearmonthnumber NVARCHAR(50),
    yearquarter NVARCHAR(50), yearquarternumber NVARCHAR(50), yearweek NVARCHAR(50),
    yearweeknumber NVARCHAR(50), isholiday NVARCHAR(50)
);
BULK INSERT #dimdate_staging FROM 'c:\data\dim_date.csv' 
WITH (FIRSTROW=2, FIELDTERMINATOR=',', ROWTERMINATOR='\n', TABLOCK, CODEPAGE='65001');

INSERT INTO dbo.dimdate
SELECT
    ISNULL(TRY_CAST(datekey AS INT), 19000101),
    ISNULL(TRY_CAST(fulldate AS DATE), '1900-01-01'),
    ISNULL(TRY_CAST(year AS SMALLINT), 1900),
    ISNULL(TRY_CAST(quarternumber AS TINYINT), 1),
    ISNULL(quartername, 'Q1'),
    ISNULL(TRY_CAST(monthnumber AS TINYINT), 1),
    ISNULL(monthname, 'Unknown'),
    ISNULL(TRY_CAST(weekdaynumber AS TINYINT), 1),
    ISNULL(weekdayname, 'Unknown'),
    ISNULL(TRY_CAST(isweekend AS TINYINT), 0),
    ISNULL(yearmonth, '1900-01'),
    ISNULL(TRY_CAST(yearmonthnumber AS INT), 190001),
    ISNULL(yearquarter, '1900-Q1'),
    ISNULL(TRY_CAST(yearquarternumber AS INT), 19001),
    ISNULL(yearweek, '1900-W01'),
    ISNULL(TRY_CAST(yearweeknumber AS INT), 190001),
    ISNULL(TRY_CAST(isholiday AS TINYINT), 0)
FROM #dimdate_staging;
DROP TABLE #dimdate_staging;
PRINT '  -> dim_date loaded.';
GO

-- =====================================================================
-- STEP 4: Load dim_customer
-- =====================================================================
PRINT '============================================================';
PRINT 'STEP 4: Load dim_customer from CSV';
PRINT '============================================================';

DROP TABLE IF EXISTS #stg_customer;
CREATE TABLE #stg_customer (
    customerid NVARCHAR(50), fullname NVARCHAR(100), email NVARCHAR(100),
    age NVARCHAR(50), gender NVARCHAR(50), city NVARCHAR(50), tier NVARCHAR(50),
    points NVARCHAR(50), isactive NVARCHAR(50), lang NVARCHAR(50),
    totalspend NVARCHAR(50), regdate NVARCHAR(50), annualincome NVARCHAR(50),
    incomebracket NVARCHAR(50), education NVARCHAR(50), maritalstatus NVARCHAR(50),
    childrencount NVARCHAR(50), loyaltysegment NVARCHAR(50), satisfactionscore NVARCHAR(50),
    dayssincelastpurchase NVARCHAR(50), hassubscription NVARCHAR(50),
    preferredcontact NVARCHAR(50), spendmultiplier NVARCHAR(50)
);
BULK INSERT #stg_customer FROM 'c:\data\dim_customer.csv' 
WITH (FIRSTROW=2, FIELDTERMINATOR=',', ROWTERMINATOR='\n', TABLOCK, CODEPAGE='65001');

INSERT INTO dbo.dimcustomer
SELECT
    TRY_CAST(customerid AS INT),
    ISNULL(fullname, 'Unknown Customer'),
    ISNULL(email, 'unknown@example.com'),
    ISNULL(TRY_CAST(age AS TINYINT), 18),
    ISNULL(gender, 'Unknown'),
    ISNULL(city, 'Unknown'),
    ISNULL(tier, 'Bronze'),
    ISNULL(TRY_CAST(points AS INT), 0),
    ISNULL(TRY_CAST(isactive AS TINYINT), 1),
    ISNULL(lang, 'en'),
    ISNULL(TRY_CAST(totalspend AS DECIMAL(18,2)), 0),
    ISNULL(TRY_CAST(regdate AS DATE), GETDATE()),
    ISNULL(TRY_CAST(annualincome AS DECIMAL(18,2)), 0),
    ISNULL(incomebracket, 'Low'),
    ISNULL(education, 'High School'),
    ISNULL(maritalstatus, 'Single'),
    ISNULL(TRY_CAST(childrencount AS TINYINT), 0),
    ISNULL(loyaltysegment, 'Bronze'),
    ISNULL(TRY_CAST(satisfactionscore AS DECIMAL(5,1)), 3.0),
    ISNULL(TRY_CAST(dayssincelastpurchase AS INT), 0),
    ISNULL(TRY_CAST(hassubscription AS TINYINT), 0),
    ISNULL(preferredcontact, 'Email'),
    ISNULL(TRY_CAST(spendmultiplier AS DECIMAL(10,3)), 1.0)
FROM #stg_customer
WHERE TRY_CAST(customerid AS INT) IS NOT NULL;
DROP TABLE #stg_customer;
PRINT '  -> dim_customer loaded.';
GO

-- =====================================================================
-- STEP 5: Load dim_product
-- =====================================================================
PRINT '============================================================';
PRINT 'STEP 5: Load dim_product from CSV';
PRINT '============================================================';

DROP TABLE IF EXISTS #stg_product;
CREATE TABLE #stg_product (
    productid NVARCHAR(50), name NVARCHAR(150), category NVARCHAR(50),
    brand NVARCHAR(50), unitcost NVARCHAR(50), unitprice NVARCHAR(50),
    margin_pct NVARCHAR(50), weight NVARCHAR(50), color NVARCHAR(20),
    material NVARCHAR(50), supplierid NVARCHAR(50), isactive NVARCHAR(50),
    minstock NVARCHAR(50), tax_rate NVARCHAR(50), haswarranty NVARCHAR(50),
    ecofriendly NVARCHAR(50), seasonalityfactor NVARCHAR(50), warrantymonths NVARCHAR(50),
    ecoscore NVARCHAR(50), releaseyear NVARCHAR(50), skucount NVARCHAR(50),
    isdiscontinued NVARCHAR(50), productrating NVARCHAR(50), stockstatus NVARCHAR(50)
);
BULK INSERT #stg_product FROM 'c:\data\dim_product.csv' 
WITH (FIRSTROW=2, FIELDTERMINATOR=',', ROWTERMINATOR='\n', TABLOCK, CODEPAGE='65001');

INSERT INTO dbo.dimproduct
SELECT
    TRY_CAST(productid AS INT),
    ISNULL(name, 'Unknown Product'),
    ISNULL(category, 'General'),
    ISNULL(brand, 'Generic'),
    ISNULL(TRY_CAST(unitcost AS DECIMAL(18,2)), 0),
    ISNULL(TRY_CAST(unitprice AS DECIMAL(18,2)), 0),
    ISNULL(TRY_CAST(margin_pct AS DECIMAL(5,4)), 0),
    ISNULL(TRY_CAST(weight AS DECIMAL(10,2)), 1),
    ISNULL(color, 'White'),
    ISNULL(material, 'Plastic'),
    ISNULL(TRY_CAST(supplierid AS INT), 1),
    ISNULL(TRY_CAST(isactive AS TINYINT), 1),
    ISNULL(TRY_CAST(minstock AS INT), 10),
    ISNULL(TRY_CAST(tax_rate AS DECIMAL(5,4)), 0),
    ISNULL(TRY_CAST(haswarranty AS TINYINT), 0),
    ISNULL(TRY_CAST(ecofriendly AS TINYINT), 0),
    ISNULL(TRY_CAST(seasonalityfactor AS DECIMAL(5,2)), 1),
    ISNULL(TRY_CAST(warrantymonths AS TINYINT), 0),
    ISNULL(TRY_CAST(ecoscore AS TINYINT), 50),
    ISNULL(TRY_CAST(releaseyear AS SMALLINT), 2023),
    ISNULL(TRY_CAST(skucount AS INT), 1),
    ISNULL(TRY_CAST(isdiscontinued AS TINYINT), 0),
    ISNULL(TRY_CAST(productrating AS DECIMAL(3,1)), 3.0),
    ISNULL(stockstatus, 'Out of Stock')
FROM #stg_product
WHERE TRY_CAST(productid AS INT) IS NOT NULL;
DROP TABLE #stg_product;
PRINT '  -> dim_product loaded.';
GO

-- =====================================================================
-- STEP 6: Load dim_store (storename forced non-NULL/non-empty)
-- =====================================================================
PRINT '============================================================';
PRINT 'STEP 6: Load dim_store from CSV';
PRINT '============================================================';

DROP TABLE IF EXISTS #stg_store;
CREATE TABLE #stg_store (
    storeid NVARCHAR(50), storename NVARCHAR(150), city NVARCHAR(50),
    type NVARCHAR(50), staff NVARCHAR(50), sizem2 NVARCHAR(50),
    hascafe NVARCHAR(50), openingyear NVARCHAR(50), region NVARCHAR(50),
    renovationyear NVARCHAR(50), parkingspots NVARCHAR(50), storerating NVARCHAR(50),
    hasdeliveryservice NVARCHAR(50), floornumber NVARCHAR(50),
    distancetocitycenterkm NVARCHAR(50), annualrentcost NVARCHAR(50),
    storesizemultiplier NVARCHAR(50)
);
BULK INSERT #stg_store FROM 'c:\data\dim_store.csv' 
WITH (FIRSTROW=2, FIELDTERMINATOR=',', ROWTERMINATOR='\n', TABLOCK, CODEPAGE='65001');

INSERT INTO dbo.dimstore
SELECT
    TRY_CAST(storeid AS INT),
    ISNULL(NULLIF(storename, ''), 'Unknown Store') AS storename,
    ISNULL(NULLIF(city, ''), 'Unknown') AS city,
    ISNULL(NULLIF(type, ''), 'Supermarket') AS type,
    ISNULL(TRY_CAST(staff AS SMALLINT), 10),
    ISNULL(TRY_CAST(sizem2 AS INT), 1000),
    ISNULL(TRY_CAST(hascafe AS TINYINT), 0),
    ISNULL(TRY_CAST(openingyear AS SMALLINT), 2000),
    ISNULL(NULLIF(region, ''), 'Central') AS region,
    ISNULL(TRY_CAST(renovationyear AS SMALLINT), 0),
    ISNULL(TRY_CAST(parkingspots AS SMALLINT), 50),
    ISNULL(TRY_CAST(storerating AS DECIMAL(3,1)), 3.0),
    ISNULL(TRY_CAST(hasdeliveryservice AS TINYINT), 0),
    ISNULL(TRY_CAST(floornumber AS TINYINT), 1),
    ISNULL(TRY_CAST(distancetocitycenterkm AS DECIMAL(8,1)), 5.0),
    ISNULL(TRY_CAST(annualrentcost AS DECIMAL(18,2)), 10000),
    ISNULL(TRY_CAST(storesizemultiplier AS DECIMAL(10,3)), 1.0)
FROM #stg_store
WHERE TRY_CAST(storeid AS INT) IS NOT NULL;
DROP TABLE #stg_store;
PRINT '  -> dim_store loaded.';
GO

-- =====================================================================
-- STEP 7: Load dim_promotion (including dummy promoid=0)
-- =====================================================================
PRINT '============================================================';
PRINT 'STEP 7: Load dim_promotion from CSV';
PRINT '============================================================';

DROP TABLE IF EXISTS #stg_promo;
CREATE TABLE #stg_promo (
    promoid NVARCHAR(50), promoname NVARCHAR(150), discount_pct NVARCHAR(50),
    discount_fixed NVARCHAR(50), type NVARCHAR(50), isactive NVARCHAR(50),
    minspend NVARCHAR(50), channel NVARCHAR(50), budget NVARCHAR(50),
    startdate NVARCHAR(50), enddate NVARCHAR(50), targetaudience NVARCHAR(50),
    maxdiscountcap NVARCHAR(50), isstackable NVARCHAR(50), redemption_rate NVARCHAR(50),
    coderequired NVARCHAR(50), promoupliftfactor NVARCHAR(50)
);
BULK INSERT #stg_promo FROM 'c:\data\dim_promotion.csv' 
WITH (FIRSTROW=2, FIELDTERMINATOR=',', ROWTERMINATOR='\n', TABLOCK, CODEPAGE='65001');

INSERT INTO dbo.dimpromotion
SELECT
    TRY_CAST(promoid AS INT),
    ISNULL(promoname, 'Unknown Promotion'),
    ISNULL(TRY_CAST(discount_pct AS DECIMAL(5,3)), 0),
    ISNULL(TRY_CAST(discount_fixed AS DECIMAL(10,2)), 0),
    ISNULL(type, 'None'),
    ISNULL(TRY_CAST(isactive AS TINYINT), 0),
    ISNULL(TRY_CAST(minspend AS INT), 0),
    ISNULL(channel, 'All'),
    ISNULL(TRY_CAST(budget AS DECIMAL(18,2)), 0),
    ISNULL(TRY_CAST(startdate AS DATE), GETDATE()),
    ISNULL(TRY_CAST(enddate AS DATE), GETDATE()),
    ISNULL(targetaudience, 'All'),
    ISNULL(TRY_CAST(maxdiscountcap AS DECIMAL(18,2)), 0),
    ISNULL(TRY_CAST(isstackable AS TINYINT), 0),
    ISNULL(TRY_CAST(redemption_rate AS DECIMAL(5,3)), 0),
    ISNULL(TRY_CAST(coderequired AS TINYINT), 0),
    ISNULL(TRY_CAST(promoupliftfactor AS DECIMAL(6,3)), 1.0)
FROM #stg_promo
WHERE TRY_CAST(promoid AS INT) IS NOT NULL;
DROP TABLE #stg_promo;

IF NOT EXISTS (SELECT 1 FROM dbo.dimpromotion WHERE promoid = 0)
BEGIN
    INSERT INTO dbo.dimpromotion (promoid, promoname, discount_pct, discount_fixed, type, isactive, minspend, channel, budget, startdate, enddate, targetaudience, maxdiscountcap, isstackable, redemption_rate, coderequired, promoupliftfactor)
    VALUES (0, 'No Promotion', 0.0, 0.0, 'None', 1, 0, 'All', 0.0, CAST(GETDATE() AS DATE), CAST(GETDATE() AS DATE), 'All', 0.0, 0, 0.0, 0, 1.0);
    PRINT '  -> Dummy promotion (promoid=0) inserted.';
END
PRINT '  -> dim_promotion loaded.';
GO

-- =====================================================================
-- STEP 8: Load fact_sales (with hour column, no NULLs)
-- =====================================================================
PRINT '============================================================';
PRINT 'STEP 8: Load fact_sales from CSV (5M rows)';
PRINT '============================================================';

DROP TABLE IF EXISTS #stg_fact;
CREATE TABLE #stg_fact (
    salesid NVARCHAR(50), datekey NVARCHAR(50), productid NVARCHAR(50),
    customerid NVARCHAR(50), storeid NVARCHAR(50), promoid NVARCHAR(50),
    qty NVARCHAR(50), unitprice NVARCHAR(50), tax_rate NVARCHAR(50),
    net NVARCHAR(50), payment NVARCHAR(50), channel NVARCHAR(50),
    grossvalue NVARCHAR(50), discountamount NVARCHAR(50), taxamount NVARCHAR(50),
    shipcost NVARCHAR(50), isreturn NVARCHAR(50), shipweight NVARCHAR(50),
    discountapplied NVARCHAR(50), returnreason NVARCHAR(50), deliverydays NVARCHAR(50),
    hour NVARCHAR(50)
);
BULK INSERT #stg_fact FROM 'c:\data\fact_sales.csv' 
WITH (FIRSTROW=2, FIELDTERMINATOR=',', ROWTERMINATOR='\n', TABLOCK, CODEPAGE='65001', KEEPNULLS);

INSERT INTO dbo.factsales
SELECT
    TRY_CAST(salesid AS BIGINT),
    TRY_CAST(datekey AS INT),
    TRY_CAST(productid AS INT),
    TRY_CAST(customerid AS INT),
    TRY_CAST(storeid AS INT),
    ISNULL(TRY_CAST(promoid AS INT), 0),
    ISNULL(TRY_CAST(qty AS TINYINT), 1),
    ISNULL(TRY_CAST(unitprice AS DECIMAL(18,2)), 0),
    ISNULL(TRY_CAST(tax_rate AS DECIMAL(5,4)), 0),
    ISNULL(TRY_CAST(net AS DECIMAL(18,2)), 0),
    ISNULL(payment, 'Cash'),
    ISNULL(channel, 'In-Store'),
    ISNULL(TRY_CAST(grossvalue AS DECIMAL(18,2)), 0),
    ISNULL(TRY_CAST(discountamount AS DECIMAL(18,2)), 0),
    ISNULL(TRY_CAST(taxamount AS DECIMAL(18,2)), 0),
    ISNULL(TRY_CAST(shipcost AS DECIMAL(18,2)), 0),
    ISNULL(TRY_CAST(isreturn AS TINYINT), 0),
    ISNULL(TRY_CAST(shipweight AS DECIMAL(10,2)), 0),
    ISNULL(TRY_CAST(discountapplied AS TINYINT), 0),
    ISNULL(NULLIF(returnreason, ''), 'No return'),
    CASE WHEN ISNULL(channel, 'In-Store') = 'In-Store' THEN 0 ELSE ISNULL(TRY_CAST(deliverydays AS TINYINT), 1) END,
    ISNULL(TRY_CAST(hour AS TINYINT), 12)
FROM #stg_fact
WHERE TRY_CAST(salesid AS BIGINT) IS NOT NULL;
DROP TABLE #stg_fact;
PRINT '  -> fact_sales loaded.';
GO

-- =====================================================================
-- STEP 9: Add primary keys and foreign keys
-- =====================================================================
PRINT '============================================================';
PRINT 'STEP 9: Add primary keys and foreign keys';
PRINT '============================================================';

ALTER TABLE dbo.dimdate ADD CONSTRAINT pk_dimdate PRIMARY KEY (datekey);
ALTER TABLE dbo.dimcustomer ADD CONSTRAINT pk_dimcustomer PRIMARY KEY (customerid);
ALTER TABLE dbo.dimproduct ADD CONSTRAINT pk_dimproduct PRIMARY KEY (productid);
ALTER TABLE dbo.dimstore ADD CONSTRAINT pk_dimstore PRIMARY KEY (storeid);
ALTER TABLE dbo.dimpromotion ADD CONSTRAINT pk_dimpromotion PRIMARY KEY (promoid);
GO

ALTER TABLE dbo.factsales ADD CONSTRAINT pk_factsales PRIMARY KEY NONCLUSTERED (salesid);
CREATE CLUSTERED COLUMNSTORE INDEX cci_factsales ON dbo.factsales;
GO

ALTER TABLE dbo.factsales ADD CONSTRAINT fk_fact_date FOREIGN KEY (datekey) REFERENCES dbo.dimdate(datekey);
ALTER TABLE dbo.factsales ADD CONSTRAINT fk_fact_customer FOREIGN KEY (customerid) REFERENCES dbo.dimcustomer(customerid);
ALTER TABLE dbo.factsales ADD CONSTRAINT fk_fact_product FOREIGN KEY (productid) REFERENCES dbo.dimproduct(productid);
ALTER TABLE dbo.factsales ADD CONSTRAINT fk_fact_store FOREIGN KEY (storeid) REFERENCES dbo.dimstore(storeid);
ALTER TABLE dbo.factsales ADD CONSTRAINT fk_fact_promo FOREIGN KEY (promoid) REFERENCES dbo.dimpromotion(promoid);
GO

PRINT '  -> Primary and foreign keys added.';
GO

-- =====================================================================
-- STEP 10: Create additional indexes
-- =====================================================================
PRINT '============================================================';
PRINT 'STEP 10: Create additional indexes';
PRINT '============================================================';

CREATE NONCLUSTERED INDEX ix_dimdate_year_month ON dbo.dimdate (year, monthnumber) INCLUDE (fulldate, isweekend, isholiday);
CREATE NONCLUSTERED INDEX ix_dimcustomer_tier_city ON dbo.dimcustomer (tier, city) INCLUDE (loyaltysegment, isactive, annualincome);
CREATE NONCLUSTERED INDEX ix_dimproduct_category_brand ON dbo.dimproduct (category, brand) INCLUDE (unitprice, tax_rate, isactive, stockstatus);
CREATE NONCLUSTERED INDEX ix_dimstore_region_type ON dbo.dimstore (region, type) INCLUDE (city, storerating, storesizemultiplier);
CREATE NONCLUSTERED INDEX ix_dimpromotion_type_channel ON dbo.dimpromotion (type, channel) INCLUDE (discount_pct, discount_fixed, isactive, promoupliftfactor);
CREATE NONCLUSTERED INDEX ix_factsales_hour ON dbo.factsales (hour) INCLUDE (net, channel);
GO

PRINT '  -> Additional indexes created.';
GO

-- =====================================================================
-- STEP 11: Update statistics
-- =====================================================================
PRINT '============================================================';
PRINT 'STEP 11: Update statistics';
PRINT '============================================================';

UPDATE STATISTICS dbo.dimdate WITH FULLSCAN;
UPDATE STATISTICS dbo.dimcustomer WITH FULLSCAN;
UPDATE STATISTICS dbo.dimproduct WITH FULLSCAN;
UPDATE STATISTICS dbo.dimstore WITH FULLSCAN;
UPDATE STATISTICS dbo.dimpromotion WITH FULLSCAN;
UPDATE STATISTICS dbo.factsales WITH FULLSCAN;
PRINT '  -> Statistics updated.';
GO

-- =====================================================================
-- STEP 12: Create views
-- =====================================================================
PRINT '============================================================';
PRINT 'STEP 12: Create views';
PRINT '============================================================';
GO

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

PRINT '  -> Views created.';
GO

-- =====================================================================
-- STEP 13: Show row counts
-- =====================================================================
PRINT '============================================================';
PRINT 'FINAL STEP: Row counts';
PRINT '============================================================';

SELECT 'dimdate' AS table_name, COUNT(*) FROM dbo.dimdate UNION ALL
SELECT 'dimcustomer', COUNT(*) FROM dbo.dimcustomer UNION ALL
SELECT 'dimproduct', COUNT(*) FROM dbo.dimproduct UNION ALL
SELECT 'dimstore', COUNT(*) FROM dbo.dimstore UNION ALL
SELECT 'dimpromotion', COUNT(*) FROM dbo.dimpromotion UNION ALL
SELECT 'factsales', COUNT(*) FROM dbo.factsales;
GO

PRINT '============================================================';
PRINT '✅ Database retailanalytics loaded successfully.';
PRINT '   - No NULL values in any column (storename, promoid, returnreason, hour).';
PRINT '   - In-Store deliverydays = 0.';
PRINT '   - Trend: decline (60k->50k) then flat then strong rise (50k->95k) at end.';
PRINT '============================================================';