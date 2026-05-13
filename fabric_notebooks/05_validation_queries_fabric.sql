SELECT 'bronze_dimdate' AS table_name, COUNT(*) FROM `01_bronze_db`.`bronze_dimdate`
UNION ALL SELECT 'bronze_dimcustomer', COUNT(*) FROM `01_bronze_db`.`bronze_dimcustomer`
UNION ALL SELECT 'bronze_dimproduct', COUNT(*) FROM `01_bronze_db`.`bronze_dimproduct`
UNION ALL SELECT 'bronze_dimstore', COUNT(*) FROM `01_bronze_db`.`bronze_dimstore`
UNION ALL SELECT 'bronze_dimpromotion', COUNT(*) FROM `01_bronze_db`.`bronze_dimpromotion`
UNION ALL SELECT 'bronze_factsales', COUNT(*) FROM `01_bronze_db`.`bronze_factsales`;

SELECT 'silver_dimdate' AS table_name, COUNT(*) FROM `02_silver_db`.`silver_dimdate`
UNION ALL SELECT 'silver_dimcustomer', COUNT(*) FROM `02_silver_db`.`silver_dimcustomer`
UNION ALL SELECT 'silver_dimproduct', COUNT(*) FROM `02_silver_db`.`silver_dimproduct`
UNION ALL SELECT 'silver_dimstore', COUNT(*) FROM `02_silver_db`.`silver_dimstore`
UNION ALL SELECT 'silver_dimpromotion', COUNT(*) FROM `02_silver_db`.`silver_dimpromotion`
UNION ALL SELECT 'silver_factsales', COUNT(*) FROM `02_silver_db`.`silver_factsales`;

SELECT 'vw_001_product_category_margin' AS view_name, COUNT(*) FROM `03_gold_db`.`vw_001_product_category_margin`
UNION ALL SELECT 'vw_002_promo_performance', COUNT(*) FROM `03_gold_db`.`vw_002_promo_performance`
UNION ALL SELECT 'vw_003_customer_rfm_segments', COUNT(*) FROM `03_gold_db`.`vw_003_customer_rfm_segments`
UNION ALL SELECT 'vw_004_returns_analysis', COUNT(*) FROM `03_gold_db`.`vw_004_returns_analysis`
UNION ALL SELECT 'vw_005_channel_performance', COUNT(*) FROM `03_gold_db`.`vw_005_channel_performance`
UNION ALL SELECT 'vw_006_seasonal_category_revenue', COUNT(*) FROM `03_gold_db`.`vw_006_seasonal_category_revenue`
UNION ALL SELECT 'vw_007_store_performance_by_region_type', COUNT(*) FROM `03_gold_db`.`vw_007_store_performance_by_region_type`
UNION ALL SELECT 'vw_008_pareto_margin_analysis', COUNT(*) FROM `03_gold_db`.`vw_008_pareto_margin_analysis`
UNION ALL SELECT 'vw_009_delivery_speed_impact', COUNT(*) FROM `03_gold_db`.`vw_009_delivery_speed_impact`
UNION ALL SELECT 'vw_010_warranty_eco_impact', COUNT(*) FROM `03_gold_db`.`vw_010_warranty_eco_impact`;

SELECT 'bronze_dimdate', COUNT(*) - COUNT(DISTINCT datekey) FROM `01_bronze_db`.`bronze_dimdate`
UNION ALL SELECT 'bronze_dimcustomer', COUNT(*) - COUNT(DISTINCT customerid) FROM `01_bronze_db`.`bronze_dimcustomer`
UNION ALL SELECT 'bronze_dimproduct', COUNT(*) - COUNT(DISTINCT productid) FROM `01_bronze_db`.`bronze_dimproduct`
UNION ALL SELECT 'bronze_dimstore', COUNT(*) - COUNT(DISTINCT storeid) FROM `01_bronze_db`.`bronze_dimstore`
UNION ALL SELECT 'bronze_dimpromotion', COUNT(*) - COUNT(DISTINCT promoid) FROM `01_bronze_db`.`bronze_dimpromotion`
UNION ALL SELECT 'bronze_factsales', COUNT(*) - COUNT(DISTINCT salesid) FROM `01_bronze_db`.`bronze_factsales`;

SELECT 
    COUNT(*) AS transactions,
    SUM(qty) AS total_quantity,
    SUM(grossvalue - discountamount) AS net_revenue_before_tax,
    SUM(net) AS net_revenue_including_tax,
    SUM(taxamount) AS total_tax,
    SUM(discountamount) AS total_discount
FROM `01_bronze_db`.`bronze_factsales`
WHERE isreturn = 0;

SELECT salesid, datekey, productid, customerid, storeid, promoid, qty, unitprice, net, grossvalue, discountamount, taxamount, isreturn
FROM `01_bronze_db`.`bronze_factsales`
ORDER BY salesid
LIMIT 10;

SELECT 'missing datekey', COUNT(*) FROM `02_silver_db`.`silver_factsales` f LEFT JOIN `02_silver_db`.`silver_dimdate` d ON f.datekey = d.datekey WHERE d.datekey IS NULL
UNION ALL SELECT 'missing productid', COUNT(*) FROM `02_silver_db`.`silver_factsales` f LEFT JOIN `02_silver_db`.`silver_dimproduct` p ON f.productid = p.productid WHERE p.productid IS NULL
UNION ALL SELECT 'missing customerid', COUNT(*) FROM `02_silver_db`.`silver_factsales` f LEFT JOIN `02_silver_db`.`silver_dimcustomer` c ON f.customerid = c.customerid WHERE c.customerid IS NULL
UNION ALL SELECT 'missing storeid', COUNT(*) FROM `02_silver_db`.`silver_factsales` f LEFT JOIN `02_silver_db`.`silver_dimstore` s ON f.storeid = s.storeid WHERE s.storeid IS NULL
UNION ALL SELECT 'missing promoid', COUNT(*) FROM `02_silver_db`.`silver_factsales` f LEFT JOIN `02_silver_db`.`silver_dimpromotion` p ON f.promoid = p.promoid WHERE p.promoid IS NULL;

SELECT 'margin_pct', COUNT(*) FROM `01_bronze_db`.`bronze_dimproduct` WHERE margin_pct < 0 OR margin_pct > 1
UNION ALL SELECT 'taxrate_pct', COUNT(*) FROM `01_bronze_db`.`bronze_dimproduct` WHERE taxrate_pct < 0 OR taxrate_pct > 1
UNION ALL SELECT 'discount_pct', COUNT(*) FROM `01_bronze_db`.`bronze_dimpromotion` WHERE discount_pct < 0 OR discount_pct > 1;

SELECT COUNT(*) AS rows, SUM(total_revenue) AS total_revenue, AVG(margin_pct) AS avg_margin_pct
FROM `03_gold_db`.`vw_001_product_category_margin`;

