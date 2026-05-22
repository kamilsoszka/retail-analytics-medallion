T-SQL – Total revenue (excl. returns)
SELECT SUM(net) AS total_revenue FROM dbo.factsales WHERE isreturn = 0;

DAX – Total revenue
Total Revenue = SUMX(FILTER(factsales, factsales[isreturn]=0), factsales[net])

Python – Total revenue
total_revenue = df[df['isreturn']==0]['net'].sum()

----------------------------------------------------------------------

T-SQL – Total COGS
SELECT SUM(f.qty * p.unitcost) AS total_cogs FROM dbo.factsales f JOIN dbo.dimproduct p ON f.productid = p.productid WHERE f.isreturn = 0;

DAX – Total COGS
Total COGS = SUMX(FILTER(factsales, factsales[isreturn]=0), factsales[qty] * RELATED(dimproduct[unitcost]))

Python – Total COGS
merged = fact.merge(product, on='productid')
total_cogs = merged[merged['isreturn']==0]['qty' * 'unitcost'].sum()

----------------------------------------------------------------------

T-SQL – Gross profit
SELECT SUM(f.net - f.qty * p.unitcost) AS gross_profit FROM dbo.factsales f JOIN dbo.dimproduct p ON f.productid = p.productid WHERE f.isreturn = 0;

DAX – Gross profit
Gross Profit = [Total Revenue] - [Total COGS]

Python – Gross profit
gross_profit = total_revenue - total_cogs

----------------------------------------------------------------------

T-SQL – Gross margin %
SELECT (SUM(f.net - f.qty * p.unitcost) / NULLIF(SUM(f.net), 0)) AS gross_margin_pct FROM dbo.factsales f JOIN dbo.dimproduct p ON f.productid = p.productid WHERE f.isreturn = 0;

DAX – Gross margin %
Gross Margin % = DIVIDE([Gross Profit], [Total Revenue], 0)

Python – Gross margin %
gross_margin_pct = gross_profit / total_revenue if total_revenue != 0 else 0

----------------------------------------------------------------------

T-SQL – Average basket value
SELECT SUM(net) / COUNT(DISTINCT salesid) AS avg_basket_value FROM dbo.factsales WHERE isreturn = 0;

DAX – Average basket value
Average Basket Value = DIVIDE([Total Revenue], DISTINCTCOUNT(FILTER(factsales, factsales[isreturn]=0), factsales[salesid]))

Python – Average basket value
avg_basket_value = df[df['isreturn']==0]['net'].sum() / df[df['isreturn']==0]['salesid'].nunique()

----------------------------------------------------------------------

T-SQL – Return rate
SELECT 1.0 * SUM(CASE WHEN isreturn = 1 THEN 1 ELSE 0 END) / COUNT(*) AS return_rate FROM dbo.factsales;

DAX – Return rate
Return Rate = DIVIDE(COUNTROWS(FILTER(factsales, factsales[isreturn]=1)), COUNTROWS(factsales), 0)

Python – Return rate
return_rate = df['isreturn'].mean()

----------------------------------------------------------------------

T-SQL – Discount penetration
SELECT 1.0 * SUM(CASE WHEN discountapplied = 1 THEN 1 ELSE 0 END) / COUNT(*) AS discount_penetration FROM dbo.factsales WHERE isreturn = 0;

DAX – Discount penetration
Discount Penetration = DIVIDE(COUNTROWS(FILTER(factsales, factsales[discountapplied]=1 && factsales[isreturn]=0)), COUNTROWS(FILTER(factsales, factsales[isreturn]=0)), 0)

Python – Discount penetration
discount_penetration = df[(df['isreturn']==0) & (df['discountapplied']==1)].shape[0] / df[df['isreturn']==0].shape[0]

----------------------------------------------------------------------

T-SQL – Unique customers
SELECT COUNT(DISTINCT customerid) AS unique_customers FROM dbo.factsales WHERE isreturn = 0;

DAX – Unique customers
Unique Customers = DISTINCTCOUNT(FILTER(factsales, factsales[isreturn]=0), factsales[customerid])

Python – Unique customers
unique_customers = df[df['isreturn']==0]['customerid'].nunique()

----------------------------------------------------------------------

T-SQL – Revenue by channel
SELECT channel, SUM(net) AS revenue FROM dbo.factsales WHERE isreturn = 0 GROUP BY channel ORDER BY revenue DESC;

DAX – Revenue by channel (add to table visual with channel)
Channel Revenue = SUMMARIZE(FILTER(factsales, factsales[isreturn]=0), factsales[channel], "Revenue", SUM(factsales[net]))

Python – Revenue by channel
channel_revenue = df[df['isreturn']==0].groupby('channel')['net'].sum().sort_values(ascending=False).reset_index()

----------------------------------------------------------------------

T-SQL – Revenue by product category
SELECT p.category, SUM(f.net) AS revenue FROM dbo.factsales f JOIN dbo.dimproduct p ON f.productid = p.productid WHERE f.isreturn = 0 GROUP BY p.category ORDER BY revenue DESC;

DAX – Revenue by category (add to table visual with category)
Category Revenue = SUMMARIZE(FILTER(factsales, factsales[isreturn]=0), dimproduct[category], "Revenue", SUM(factsales[net]))

Python – Revenue by category
merged = fact.merge(product, on='productid')
cat_rev = merged[merged['isreturn']==0].groupby('category')['net'].sum().sort_values(ascending=False)

----------------------------------------------------------------------

T-SQL – 7-day moving average of daily sales
WITH daily AS (
  SELECT d.fulldate, SUM(f.net) AS daily_total
  FROM dbo.factsales f JOIN dbo.dimdate d ON f.datekey = d.datekey
  WHERE f.isreturn = 0
  GROUP BY d.fulldate
)
SELECT fulldate, daily_total,
       AVG(daily_total) OVER (ORDER BY fulldate ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS ma_7days
FROM daily ORDER BY fulldate;

DAX – 7-day moving average (measure in a visual with dates)
7D Moving Avg = CALCULATE(AVERAGEX(DATESINPERIOD(dimdate[fulldate], LASTDATE(dimdate[fulldate]), -7, DAY), [Total Revenue]), ALL(dimdate))

Python – 7-day moving average
daily = df[df['isreturn']==0].groupby('fulldate')['net'].sum().reset_index()
daily['ma_7days'] = daily['net'].rolling(7).mean()

----------------------------------------------------------------------

T-SQL – Promotion effect (average daily revenue with vs without promo)
WITH promo_days AS (
  SELECT d.fulldate,
         MAX(CASE WHEN f.promoid > 0 THEN 1 ELSE 0 END) AS has_promo,
         SUM(f.net) AS daily_revenue
  FROM dbo.factsales f JOIN dbo.dimdate d ON f.datekey = d.datekey
  WHERE f.isreturn = 0
  GROUP BY d.fulldate
)
SELECT has_promo, AVG(daily_revenue) AS avg_revenue FROM promo_days GROUP BY has_promo;

DAX – Promotion uplift
Promo Uplift = VAR Promo = CALCULATE([Total Revenue], factsales[promoid] > 0) VAR NonPromo = CALCULATE([Total Revenue], factsales[promoid] = 0) RETURN DIVIDE(Promo - NonPromo, NonPromo, 0)

Python – Promotion effect
daily_promo = df[df['isreturn']==0].groupby(['fulldate', df['promoid']>0])['net'].sum().unstack().fillna(0)
daily_promo.columns = ['non_promo', 'promo']
avg_promo = daily_promo['promo'].mean()
avg_non = daily_promo['non_promo'].mean()
uplift = (avg_promo - avg_non) / avg_non