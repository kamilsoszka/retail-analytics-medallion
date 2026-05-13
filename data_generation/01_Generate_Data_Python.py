"""
Retail Data Generator v46 – NO MANAGER TABLE, PROPER PCT/RATE COLUMNS
- Removed dimmanager completely
- No manager_email in factsales
- All percentage columns have _pct suffix (e.g., margin_pct, taxrate_pct, discount_pct)
- Columns with "rate" also use _pct (e.g., redemption_rate_target_pct)
- N_SALES = 5,000,000 rows
- At the end: prints full data dictionary with business column names, descriptions, formats,
  and example base measures in T-SQL and DAX.
"""

import numpy as np
import pandas as pd
from datetime import datetime, timedelta
import os
import re
from decimal import Decimal, getcontext, ROUND_HALF_UP
import random
from collections import defaultdict

getcontext().prec = 28

# =====================================================================
# CONFIGURATION
# =====================================================================
OUTPUT_DIR = "c:/data"
N_SALES      = 5_000_000
N_CUSTOMERS  = 200_000
N_PRODUCTS   = 2_000
N_STORES     = 150
N_PROMOTIONS = 50
RANDOM_SEED  = 42

if RANDOM_SEED is not None:
    np.random.seed(RANDOM_SEED)
    random.seed(RANDOM_SEED)

os.makedirs(OUTPUT_DIR, exist_ok=True)

START_DATE = datetime(2023, 1, 1)
END_DATE   = datetime.now()

CSV_OPTS = dict(index=False, encoding='utf-8', lineterminator='\n')

# =====================================================================
# NAME LISTS
# =====================================================================
STORE_CHAINS = {
    'Supermarket': ['FreshMart', 'CityFood', 'DailyGrocer', 'ValueStore', 'GreenWay', 'FamilyMarket'],
    'Hypermarket': ['MegaMart', 'SuperSaver', 'GlobalHyper', 'EcoBazaar', 'MetroPoint', 'BigBox'],
    'Convenience': ['QuickStop', 'CornerShop', 'EasyBuy', '24Seven', 'NeighborStore', 'ExpressMarts'],
    'Department': ['CityCenter', 'TheGalleria', 'TownSquare', 'MetroPlaza', 'HeritageMall', 'Pavilion']
}
PROMO_TEMPLATES = {
    'Percentage': ['Spring Sale', 'Summer Deal', 'Winter Discount', 'Flash Sale', 'Weekend Special', 'Member Only', 'Clearance', 'Seasonal Offer'],
    'Fixed Amount': ['Cashback', 'Save $', 'Discount Voucher', 'Coupon Deal', 'Instant Rebate', 'Money Off'],
    'BOGO': ['Buy 1 Get 1 Free', '2 for 1', '3 for 2', 'Buy More Save More', 'Buy One Get One'],
    'Free Shipping': ['Free Delivery', 'No Shipping Fee', 'Shipping included', 'Free Express Shipping']
}
PRODUCT_NAMES = {
    'Electronics': ['Smartphone', 'Laptop', 'Headphones', 'Smartwatch', 'Tablet', 'TV', 'Camera', 'Speaker', 'Monitor', 'Keyboard', 'Mouse', 'Charger'],
    'Home': ['Desk', 'Chair', 'Lamp', 'Sofa', 'Table', 'Fridge', 'Vacuum', 'Blender', 'Microwave', 'Toaster', 'Oven', 'Dishwasher'],
    'Sports': ['Shoes', 'Tshirt', 'Backpack', 'Bike', 'Ball', 'Racket', 'Gloves', 'Shorts', 'Towel', 'Bottle', 'Tent', 'Fitness Tracker'],
    'Kids': ['Doll', 'Action Figure', 'Puzzle', 'Blocks', 'Board Game', 'Stuffed Toy', 'Car Set', 'Drawing Kit', 'Playset', 'Book', 'Drone', 'Scooter'],
    'Garden': ['Lawn Mower', 'Hedge Trimmer', 'Hose', 'Shovel', 'Gloves', 'Seeds', 'Fertilizer', 'Pots', 'Furniture', 'Grill', 'Sprinkler', 'Weed Killer']
}
PRODUCT_ADJECTIVES = ['Pro', 'Plus', 'Max', 'Lite', 'Premium', 'Advanced', 'Basic', 'Deluxe', 'Eco', 'Compact', 'Ultra', 'Smart']
FIRST_NAMES_MALE = ['James', 'John', 'Robert', 'Michael', 'William', 'David', 'Richard', 'Joseph', 'Thomas', 'Charles',
                    'Christopher', 'Daniel', 'Matthew', 'Anthony', 'Donald', 'Mark', 'Paul', 'Steven', 'Andrew', 'Kenneth']
FIRST_NAMES_FEMALE = ['Mary', 'Patricia', 'Jennifer', 'Linda', 'Elizabeth', 'Barbara', 'Susan', 'Jessica', 'Sarah', 'Karen',
                      'Nancy', 'Lisa', 'Betty', 'Margaret', 'Sandra', 'Ashley', 'Kimberly', 'Emily', 'Donna', 'Michelle']
LAST_NAMES = ['Smith', 'Johnson', 'Williams', 'Brown', 'Jones', 'Garcia', 'Miller', 'Davis', 'Rodriguez', 'Martinez',
              'Wilson', 'Anderson', 'Thomas', 'Taylor', 'Moore', 'Jackson', 'Martin', 'Lee', 'White', 'Harris']
FIRST_NAMES_MALE_CUST = ['James', 'John', 'Robert', 'Michael', 'William', 'David', 'Richard', 'Joseph', 'Thomas', 'Charles']
FIRST_NAMES_FEMALE_CUST = ['Mary', 'Patricia', 'Jennifer', 'Linda', 'Elizabeth', 'Barbara', 'Susan', 'Jessica', 'Sarah', 'Karen']
LAST_NAMES_CUST = ['Smith', 'Johnson', 'Williams', 'Brown', 'Jones', 'Garcia', 'Miller', 'Davis', 'Rodriguez', 'Martinez']

CAT_NAMES = ['Electronics', 'Home', 'Sports', 'Kids', 'Garden']
CATEGORY_CFG = {
    'Electronics': {'price_lo': 250, 'price_hi': 600, 'weight_lo': 0.3, 'weight_hi': 3.0, 'tax_rate': 0.21, 'warranty_prob': 0.9, 'return_rate_base': 0.03, 'season_weights': [0.5,0.5,0.6,0.7,0.8,0.9,0.9,1.0,1.2,1.5,2.2,2.8]},
    'Home':        {'price_lo': 80, 'price_hi': 200, 'weight_lo': 1.0, 'weight_hi': 15.0, 'tax_rate': 0.21, 'warranty_prob': 0.5, 'return_rate_base': 0.06, 'season_weights': [0.8,0.8,0.9,1.0,1.0,1.0,0.9,0.9,1.0,1.2,1.4,1.6]},
    'Sports':      {'price_lo': 40, 'price_hi': 150, 'weight_lo': 0.2, 'weight_hi': 5.0, 'tax_rate': 0.21, 'warranty_prob': 0.3, 'return_rate_base': 0.09, 'season_weights': [0.6,0.7,0.8,1.0,1.2,1.4,1.6,1.4,1.2,1.0,0.7,0.5]},
    'Kids':        {'price_lo': 15, 'price_hi': 60, 'weight_lo': 0.1, 'weight_hi': 2.0, 'tax_rate': 0.10, 'warranty_prob': 0.2, 'return_rate_base': 0.15, 'season_weights': [0.8,0.8,0.9,0.9,1.0,1.0,0.9,0.9,1.2,1.4,2.0,2.5]},
    'Garden':      {'price_lo': 30, 'price_hi': 120, 'weight_lo': 0.5, 'weight_hi': 12.0, 'tax_rate': 0.21, 'warranty_prob': 0.6, 'return_rate_base': 0.07, 'season_weights': [0.2,0.3,0.5,0.8,1.2,1.5,1.6,1.3,0.9,0.5,0.3,0.2]},
}
BRANDS = {
    'Electronics': ['Sony','Samsung','Apple','Philips','LG','Bose','Dell','HP','Canon','Panasonic'],
    'Home':        ['IKEA','Tefal','Bosch','Electrolux','KitchenAid','Dyson','Philips','Rowenta','Zyliss','Le Creuset'],
    'Sports':      ['Nike','Adidas','Puma','Reebok','Under Armour','Decathlon','Wilson','Spalding','The North Face','Columbia'],
    'Kids':        ['LEGO','Fisher-Price','Mattel','Hasbro','Barbie','Hot Wheels','Playmobil','VTech','Crayola','Nerf'],
    'Garden':      ['Husqvarna','Bosch','Black and Decker','Gardena','Fiskars','Stihl','Wolf-Garten','Einhell','Flymo','Worx'],
}
CITIES = ['New York', 'Los Angeles', 'Chicago', 'Houston', 'Phoenix', 'Philadelphia', 'San Antonio', 'San Diego', 'Dallas', 'Austin']
GENDERS = ['Male','Female','Non-binary']
EDUCATION = ['High School','Bachelor','Master','PhD']
MARITAL = ['Single','Married','Divorced','Widowed']
CONTACT_PREF = ['Email','SMS','Phone','Mail']
PAYMENT = ['Card','Cash','Bank Transfer','Digital Wallet','PayPal']
CHANNELS = ['Online','In-Store','Mobile App','Phone Order']
STORE_TYPES = ['Supermarket','Hypermarket','Convenience','Department']
REGIONS = ['North','South','East','West','Central']
RETURN_REASONS = ['Defective','Wrong item','Not as described','Changed mind','Late delivery','Other']

def d2(value):
    return Decimal(str(value)).quantize(Decimal('0.01'), rounding=ROUND_HALF_UP)

print("Generating dimensions...")

# =====================================================================
# DIMENSION: STORES (unchanged)
# =====================================================================
store_type_list = []
for t in STORE_TYPES:
    for chain in STORE_CHAINS[t]:
        for city in CITIES:
            for suffix in ['Center','Park','Plaza','Mall','Point','Market','Square']:
                store_type_list.append((t, chain, city, suffix))
random.shuffle(store_type_list)
selected_stores = store_type_list[:N_STORES]

store_ids = np.arange(1, N_STORES + 1)
store_types = [s[0] for s in selected_stores]
store_chain = [s[1] for s in selected_stores]
store_cities = [s[2] for s in selected_stores]
store_suffix = [s[3] for s in selected_stores]
store_name = [f"{chain} {city} {suffix}" for chain, city, suffix in zip(store_chain, store_cities, store_suffix)]

store_size_mult = np.random.lognormal(mean=0.2, sigma=0.9, size=N_STORES).clip(0.3, 4.0)
store_regions = np.random.choice(REGIONS, N_STORES)
city_rent_mult = {c: 1.0 + np.random.uniform(0.0, 0.8) for c in CITIES}
store_sizem2 = np.where(np.array(store_types) == 'Hypermarket', np.random.randint(2500, 5000, N_STORES),
                np.where(np.array(store_types) == 'Supermarket', np.random.randint(800, 2500, N_STORES),
                np.where(np.array(store_types) == 'Department', np.random.randint(1200, 3500, N_STORES),
                np.random.randint(150, 800, N_STORES))))
store_staff = np.clip((store_sizem2 / 45 + np.random.normal(0, 5, N_STORES)).astype(int), 3, 120)
store_parking = np.clip((store_sizem2 / 25 + np.random.normal(0, 10, N_STORES)).astype(int), 0, 300)
store_annualrent = (store_sizem2 * 12 * np.array([city_rent_mult[c] for c in store_cities]) *
                    np.where(np.array(store_types) == 'Hypermarket', 0.8, np.where(np.array(store_types) == 'Convenience', 1.4, 1.0))).round(0)
store_rating = np.clip(2.0 + (store_staff/120)*0.8 + (store_parking/300)*0.5 + np.random.uniform(0, 1.2, N_STORES), 2.0, 5.0).round(1)

# =====================================================================
# DIMENSION: PRODUCTS (with margin_pct and taxrate_pct)
# =====================================================================
product_pool = []
for cat in CAT_NAMES:
    for brand in BRANDS[cat]:
        for adj in PRODUCT_ADJECTIVES:
            for noun in PRODUCT_NAMES[cat]:
                product_pool.append(f"{brand} {adj} {noun}")
product_pool = list(set(product_pool))
random.shuffle(product_pool)
unique_product_names = product_pool[:N_PRODUCTS]

product_ids = np.arange(1, N_PRODUCTS + 1)
product_categories = np.random.choice(CAT_NAMES, N_PRODUCTS, p=[0.25, 0.25, 0.20, 0.15, 0.15])
product_brands = [np.random.choice(BRANDS[cat]) for cat in product_categories]
product_brand_premium = np.random.uniform(0.9, 1.5, N_PRODUCTS)
product_weights = []
product_unitprice = []
product_unitcost = []
product_taxrate_pct = []
product_warranty = []
product_ecoscore = []
product_material = []
product_margin_pct = []
for i, cat in enumerate(product_categories):
    cfg = CATEGORY_CFG[cat]
    w = round(np.random.uniform(cfg['weight_lo'], cfg['weight_hi']), 2)
    p_base = round(np.random.uniform(cfg['price_lo'], cfg['price_hi']), 2)
    p_final = round(p_base * product_brand_premium[i], 2)
    margin = np.random.uniform(0.01, 0.30)
    cost = round(p_final * (1 - margin), 2)
    product_weights.append(w)
    product_unitprice.append(p_final)
    product_unitcost.append(cost)
    product_taxrate_pct.append(cfg['tax_rate'])
    product_warranty.append(int(np.random.random() < cfg['warranty_prob']))
    e_score = int(np.random.uniform(20, 200))
    product_ecoscore.append(e_score)
    product_material.append(np.random.choice(['Plastic','Metal','Wood','Glass','Fabric']))
    product_margin_pct.append(margin)

product_unitprice = np.array(product_unitprice)
product_unitcost = np.array(product_unitcost)
product_taxrate_pct = np.array(product_taxrate_pct)
product_weights = np.array(product_weights)
product_margin_pct = np.array(product_margin_pct)
product_categories = np.array(product_categories)
product_ecoscore = np.array(product_ecoscore)

product_isactive = np.random.choice([0,1], N_PRODUCTS, p=[0.05, 0.95]).astype(int)
product_stockstatus = np.where(product_isactive == 0, 'Out of Stock', np.random.choice(['In Stock','Low Stock','Out of Stock'], N_PRODUCTS, p=[0.78, 0.17, 0.05]))
product_releaseyear = np.random.choice([2018,2019,2020,2021,2022,2023,2024,2025], N_PRODUCTS, p=[0.05,0.08,0.12,0.18,0.25,0.20,0.10,0.02])
product_skucount = np.random.poisson(2.5, N_PRODUCTS) + 1
product_isdiscontinued = np.where(product_releaseyear < 2021, np.random.choice([0,1], N_PRODUCTS, p=[0.6, 0.4]), np.random.choice([0,1], N_PRODUCTS, p=[0.95, 0.05])).astype(int)
product_rating = np.clip(2.0 + np.random.normal(0, 0.8, N_PRODUCTS), 1.0, 5.0).round(1)
product_name = unique_product_names

# =====================================================================
# DIMENSION: PROMOTIONS (with discount_pct and redemption_rate_target_pct)
# =====================================================================
promo_ids = np.arange(1, N_PROMOTIONS + 1)
promo_types = np.random.choice(['Percentage','Fixed Amount','BOGO','Free Shipping'], N_PROMOTIONS, p=[0.35,0.25,0.25,0.15])
promo_channels = np.where(promo_types == 'Free Shipping', 'Online', np.random.choice(['Email','SMS','App','InStore','All'], N_PROMOTIONS))
promo_discount_pct = np.where(promo_types == 'Percentage', np.random.uniform(0.10, 0.45, N_PROMOTIONS), 0.0)
promo_discount_fixed = np.where(promo_types == 'Fixed Amount', np.random.uniform(3, 30, N_PROMOTIONS), 0.0)
promo_budgets = (np.where(promo_types == 'Percentage', promo_discount_pct, promo_discount_fixed/100) * N_SALES * 0.002 * np.random.uniform(0.8, 1.5, N_PROMOTIONS)).round(0)
promo_uplift_map = {
    'BOGO': np.random.uniform(1.8, 2.2, N_PROMOTIONS),
    'Percentage': np.random.uniform(1.2, 1.4, N_PROMOTIONS),
    'Fixed Amount': np.random.uniform(1.05, 1.15, N_PROMOTIONS),
    'Free Shipping': np.random.uniform(1.0, 1.02, N_PROMOTIONS)
}
promo_uplift = np.zeros(N_PROMOTIONS)
for i, pt in enumerate(promo_types):
    promo_uplift[i] = promo_uplift_map[pt][i]

promo_start = (START_DATE + pd.to_timedelta(np.random.randint(0, 900, N_PROMOTIONS), unit='D')).to_pydatetime()
promo_end = (START_DATE + pd.to_timedelta(np.random.randint(15, 950, N_PROMOTIONS), unit='D')).to_pydatetime()
for i in range(N_PROMOTIONS):
    if promo_start[i] > promo_end[i]:
        promo_start[i], promo_end[i] = promo_end[i], promo_start[i]
promo_isactive = np.where(promo_end >= END_DATE, 1, 0).astype(int)
promo_start_str = [d.strftime('%Y-%m-%d') for d in promo_start]
promo_end_str = [d.strftime('%Y-%m-%d') for d in promo_end]

promo_name = []
used_names = set()
for i, ptype in enumerate(promo_types):
    template = np.random.choice(PROMO_TEMPLATES[ptype])
    if ptype == 'Percentage':
        disc = int(promo_discount_pct[i] * 100)
        base = f"{template} {disc}% OFF"
    elif ptype == 'Fixed Amount':
        amount = int(promo_discount_fixed[i])
        base = f"{template} ${amount}"
    else:
        base = template
    final_name = base
    suffix = 2
    while final_name in used_names:
        final_name = f"{base} {suffix}"
        suffix += 1
    used_names.add(final_name)
    promo_name.append(final_name)

# =====================================================================
# DIMENSION: CUSTOMERS (unchanged)
# =====================================================================
customer_ids = np.arange(1, N_CUSTOMERS + 1)
gender_choice = np.random.choice(['Male','Female'], N_CUSTOMERS, p=[0.5, 0.5])
raw_first = []
raw_last = []
for i in range(N_CUSTOMERS):
    if gender_choice[i] == 'Male':
        first = np.random.choice(FIRST_NAMES_MALE_CUST)
    else:
        first = np.random.choice(FIRST_NAMES_FEMALE_CUST)
    last = np.random.choice(LAST_NAMES_CUST)
    raw_first.append(first)
    raw_last.append(last)

pair_counts = defaultdict(int)
pairs = list(zip(raw_first, raw_last))
for p in pairs:
    pair_counts[p] += 1

current_counter = defaultdict(int)
fullname_list = []
email_list = []
for (first, last) in pairs:
    cnt = current_counter[(first, last)]
    current_counter[(first, last)] += 1
    total = pair_counts[(first, last)]
    if total == 1:
        fullname = f"{first} {last}"
        email_local = f"{first.lower()}.{last.lower()}".replace(" ", ".")
        email_local = re.sub(r'[^a-z0-9.]', '', email_local)
        email = f"{email_local}@example.com"
    else:
        if cnt == 0:
            fullname = f"{first} {last}"
            email_suffix = ""
        else:
            fullname = f"{first} {last} {cnt+1}"
            email_suffix = str(cnt+1)
        email_local = f"{first.lower()}.{last.lower()}{email_suffix}".replace(" ", ".")
        email_local = re.sub(r'[^a-z0-9.]', '', email_local)
        email = f"{email_local}@example.com"
    fullname_list.append(fullname)
    email_list.append(email)

age_range = np.arange(18, 75)
age_probs = np.where(age_range < 25, 0.02, np.where(age_range < 40, 0.035, np.where(age_range < 60, 0.025, 0.015)))
age_probs = age_probs / age_probs.sum()
customer_age = np.random.choice(age_range, N_CUSTOMERS, p=age_probs)

customer_income = np.random.lognormal(mean=9.8, sigma=0.6, size=N_CUSTOMERS).clip(8000, 100000)
customer_tier = np.where(customer_income > 70000, 'Platinum', 
                np.where(customer_income > 45000, 'Gold',
                np.where(customer_income > 25000, 'Silver', 'Bronze')))
customer_spend_mult = np.where(customer_tier == 'Platinum', np.random.uniform(3.0, 6.0, N_CUSTOMERS),
                        np.where(customer_tier == 'Gold', np.random.uniform(1.8, 3.0, N_CUSTOMERS),
                        np.where(customer_tier == 'Silver', np.random.uniform(0.8, 1.5, N_CUSTOMERS), np.random.uniform(0.2, 0.6, N_CUSTOMERS))))
customer_points = np.clip((customer_spend_mult * 45 + np.random.poisson(20, N_CUSTOMERS)).astype(int), 0, 800)
regdate_days = np.random.exponential(600, N_CUSTOMERS).astype(int)
max_days = (END_DATE - START_DATE).days
regdate_days_clipped = np.minimum(regdate_days, max_days)
customer_regdate = [(START_DATE + timedelta(days=int(d))).strftime('%Y-%m-%d') for d in regdate_days_clipped]
customer_totalSpend = (customer_spend_mult * np.random.exponential(180, N_CUSTOMERS)).round(2)
customer_loyaltysegment = customer_tier
customer_satisfactionscore = np.clip(2.5 + (customer_tier == 'Platinum')*1.0 + (customer_tier == 'Gold')*0.6 + np.random.normal(0, 0.8, N_CUSTOMERS), 1.0, 5.0).round(1)
customer_dayssincelast = np.where(customer_tier == 'Platinum', np.random.exponential(5, N_CUSTOMERS), 
                           np.where(customer_tier == 'Gold', np.random.exponential(12, N_CUSTOMERS), 
                           np.random.exponential(35, N_CUSTOMERS))).astype(int)
customer_hassubscription = np.random.choice([0,1], N_CUSTOMERS, p=[0.65, 0.35]).astype(int)
customer_childrencount = np.random.poisson(np.where(customer_age < 30, 0.3, np.where(customer_age < 45, 0.9, 0.4)), N_CUSTOMERS).astype(int)

contact_probs = np.zeros((N_CUSTOMERS, 4))
contact_probs[:, 0] = np.where(customer_age < 35, 0.6, 0.3)
contact_probs[:, 1] = np.where(customer_age < 30, 0.25, 0.4)
contact_probs[:, 2] = np.where(customer_age > 50, 0.35, 0.15)
contact_probs[:, 3] = 1.0 - contact_probs.sum(axis=1)
contact_probs = np.maximum(contact_probs, 0.05)
contact_probs = contact_probs / contact_probs.sum(axis=1, keepdims=True)
customer_contact = np.array([np.random.choice(CONTACT_PREF, p=p) for p in contact_probs])

# =====================================================================
# DIMENSION: DATE
# =====================================================================
dates = pd.date_range(START_DATE, END_DATE, freq='D')
isholiday_arr = (np.isin(dates.month, [12, 1]) | (dates.month == 7)).astype(int)
isholiday_int = isholiday_arr.astype(int)

date_df = pd.DataFrame({
    'datekey': dates.strftime("%Y%m%d").astype(int),
    'fulldate': dates.strftime("%Y-%m-%d"),
    'year': dates.year.astype(int),
    'quarternumber': dates.quarter.astype(int),
    'quartername': 'Q' + dates.quarter.astype(str),
    'monthnumber': dates.month.astype(int),
    'monthname': dates.month_name(),
    'weekdaynumber': (dates.dayofweek + 1).astype(int),
    'weekdayname': dates.day_name(),
    'isweekend': (dates.dayofweek >= 5).astype(int),
    'yearmonth': dates.strftime("%Y-%m"),
    'yearmonthnumber': (dates.year * 100 + dates.month).astype(int),
    'yearquarter': dates.year.astype(str) + '-Q' + dates.quarter.astype(str),
    'yearquarternumber': (dates.year * 10 + dates.quarter).astype(int),
    'yearweek': dates.strftime("%Y-W%W"),
    'yearweeknumber': (dates.isocalendar().week.astype(int) + dates.year * 100),
    'isholiday': isholiday_int
})
date_df.to_csv(f"{OUTPUT_DIR}/dim_date.csv", index=False, encoding='utf-8')

# =====================================================================
# EXPORT OTHER DIMENSIONS
# =====================================================================
customer_df = pd.DataFrame({
    'customerid': customer_ids, 'fullname': fullname_list, 'email': email_list,
    'age': customer_age, 'gender': np.random.choice(GENDERS, N_CUSTOMERS, p=[0.48, 0.48, 0.04]),
    'city': np.random.choice(CITIES, N_CUSTOMERS), 'tier': customer_tier,
    'points': customer_points, 'isactive': np.random.choice([0,1], N_CUSTOMERS, p=[0.06, 0.94]).astype(int),
    'lang': np.random.choice(['en','de','fr','es','pl','it'], N_CUSTOMERS, p=[0.35,0.20,0.15,0.15,0.10,0.05]),
    'totalspend': customer_totalSpend, 'regdate': customer_regdate,
    'annualincome': customer_income.round(2),
    'incomebracket': pd.cut(customer_income, bins=[0,25000,50000,75000,100000,1e9], labels=['Low','Medium','High','Very High','Ultra High']).astype(str),
    'education': np.random.choice(EDUCATION, N_CUSTOMERS, p=[0.30,0.40,0.25,0.05]),
    'maritalstatus': np.random.choice(MARITAL, N_CUSTOMERS),
    'childrencount': customer_childrencount, 'loyaltysegment': customer_loyaltysegment,
    'satisfactionscore': customer_satisfactionscore,
    'dayssincelastpurchase': customer_dayssincelast, 'hassubscription': customer_hassubscription,
    'preferredcontact': customer_contact, 'spendmultiplier': customer_spend_mult.round(3)
})
customer_df.to_csv(f"{OUTPUT_DIR}/dim_customer.csv", index=False, encoding='utf-8')

product_df = pd.DataFrame({
    'productid': product_ids, 'name': product_name,
    'category': product_categories, 'brand': product_brands,
    'unitcost': product_unitcost, 'unitprice': product_unitprice,
    'margin_pct': product_margin_pct,
    'weight': product_weights, 'color': np.random.choice(['Red','Blue','Green','Black','White','Gray'], N_PRODUCTS),
    'material': product_material, 'supplierid': np.random.randint(1, 51, N_PRODUCTS),
    'isactive': product_isactive, 'minstock': np.random.randint(2, 100, N_PRODUCTS),
    'taxrate_pct': product_taxrate_pct,
    'haswarranty': product_warranty,
    'ecofriendly': (product_ecoscore > 100).astype(int),
    'seasonalityfactor': np.random.uniform(0.7, 1.3, N_PRODUCTS).round(2),
    'warrantymonths': np.where(product_warranty==1, np.random.choice([12,24,36], N_PRODUCTS), 0),
    'ecoscore': product_ecoscore, 'releaseyear': product_releaseyear,
    'skucount': product_skucount, 'isdiscontinued': product_isdiscontinued,
    'productrating': product_rating, 'stockstatus': product_stockstatus
})
assert product_df['name'].is_unique
product_df.to_csv(f"{OUTPUT_DIR}/dim_product.csv", index=False, encoding='utf-8')

store_df = pd.DataFrame({
    'storeid': store_ids, 'storename': store_name,
    'city': store_cities, 'type': store_types, 'staff': store_staff, 'sizem2': store_sizem2,
    'hascafe': np.random.choice([0,1], N_STORES, p=[0.6,0.4]).astype(int),
    'openingyear': np.random.randint(1985, 2023, N_STORES), 'region': store_regions,
    'renovationyear': np.random.choice([0]+list(range(2010,2024)), N_STORES, p=[0.35]+[0.65/14]*14),
    'parkingspots': store_parking, 'storerating': store_rating,
    'hasdeliveryservice': np.random.choice([0,1], N_STORES, p=[0.4,0.6]).astype(int),
    'floornumber': np.random.randint(1, 6, N_STORES),
    'distancetocitycenterkm': np.random.uniform(0.5, 25.0, N_STORES).round(1),
    'annualrentcost': store_annualrent,
    'storesizemultiplier': store_size_mult
})
renov = store_df['renovationyear'].values
op = store_df['openingyear'].values
renov = np.where((renov != 0) & (renov < op), op, renov)
store_df['renovationyear'] = renov
store_df.to_csv(f"{OUTPUT_DIR}/dim_store.csv", index=False, encoding='utf-8')

promo_df = pd.DataFrame({
    'promoid': promo_ids, 'promoname': promo_name,
    'discount_pct': promo_discount_pct.round(3),
    'discount_fixed': promo_discount_fixed.round(2),
    'type': promo_types, 'isactive': promo_isactive,
    'minspend': np.random.choice([0,10,25,50,100], N_PROMOTIONS, p=[0.25,0.30,0.20,0.15,0.10]),
    'channel': promo_channels, 'budget': promo_budgets,
    'startdate': promo_start_str, 'enddate': promo_end_str,
    'targetaudience': np.random.choice(['All','New','Loyal','HighSpend'], N_PROMOTIONS, p=[0.40,0.15,0.25,0.20]),
    'maxdiscountcap': np.random.uniform(5, 120, N_PROMOTIONS).round(2),
    'isstackable': np.random.choice([0,1], N_PROMOTIONS, p=[0.85,0.15]).astype(int),
    'redemption_rate_target_pct': np.random.uniform(0.02, 0.35, N_PROMOTIONS).round(3),
    'coderequired': np.random.choice([0,1], N_PROMOTIONS, p=[0.60,0.40]).astype(int),
    'promoupliftfactor': promo_uplift.round(3)
})
assert promo_df['promoname'].is_unique
promo_df.to_csv(f"{OUTPUT_DIR}/dim_promotion.csv", index=False, encoding='utf-8')

print("Dimensions exported successfully ✓")

# =====================================================================
# FACT TABLE (no manager_email, no manager columns)
# =====================================================================
print(f"Generating fact_sales with {N_SALES:,} rows...")
customer_tier_arr = np.array(customer_tier)
customer_spend_mult_arr = np.array(customer_spend_mult)

cat_season_matrix = np.array([CATEGORY_CFG[cat]['season_weights'] for cat in CAT_NAMES])
cat_to_idx = {cat: i for i, cat in enumerate(CAT_NAMES)}
dow_weights = np.array([0.75, 0.70, 0.72, 0.78, 0.95, 1.30, 1.20])
month_idx = dates.month.values - 1
holiday_boost = np.where(isholiday_arr, 1.25, 1.0)
date_weights = dow_weights[dates.dayofweek.values] * cat_season_matrix[:, month_idx].mean(axis=0) * holiday_boost
date_weights = date_weights / date_weights.sum()
datekeys = date_df['datekey'].values

datekey_to_month = np.zeros(int(datekeys.max()) + 1, dtype=np.int8)
for dk, m in zip(datekeys, dates.month):
    datekey_to_month[dk] = m

tier_bonus = np.array([1.0, 1.5, 2.2, 3.0])[np.array([{'Bronze':0,'Silver':1,'Gold':2,'Platinum':3}[t] for t in customer_tier_arr])]
cust_weights = customer_spend_mult_arr * tier_bonus
cust_weights = cust_weights / cust_weights.sum()
store_weights = store_size_mult / store_size_mult.sum()

channel_cum_probs = np.array([0.50, 0.70, 0.85, 1.0])
channel_list = ['Online', 'Mobile App', 'In-Store', 'Phone Order']
channel_payment_probs = {
    'Online': [0.45,0.05,0.25,0.20,0.05],
    'Mobile App': [0.35,0.02,0.20,0.38,0.05],
    'In-Store': [0.30,0.45,0.15,0.05,0.05],
    'Phone Order': [0.25,0.10,0.40,0.15,0.10]
}
channel_pay_matrix = np.array([channel_payment_probs[c] for c in channel_list])
return_reason_probs = {
    'Online': [0.25,0.15,0.20,0.15,0.15,0.10],
    'Mobile App': [0.30,0.10,0.25,0.10,0.15,0.10],
    'In-Store': [0.45,0.20,0.10,0.15,0.05,0.05],
    'Phone Order': [0.20,0.25,0.15,0.10,0.20,0.10]
}
promo_discount_pct_arr = np.concatenate([[0.0], promo_discount_pct])
promo_discount_fixed_arr = np.concatenate([[0.0], promo_discount_fixed])
promo_uplift_arr = np.concatenate([[1.0], promo_uplift])

FACT_COLUMNS = ['salesid','datekey','productid','customerid','storeid','promoid',
                'qty','unitprice','taxrate_pct','net','payment','channel',
                'grossvalue','discountamount','taxamount','shipcost','isreturn',
                'shipweight','discountapplied','returnreason','deliverydays']
fact_file = f"{OUTPUT_DIR}/fact_sales.csv"
pd.DataFrame(columns=FACT_COLUMNS).to_csv(fact_file, index=False, encoding='utf-8')

total_errors = 0
BATCH_SIZE = 500_000
num_batches = N_SALES // BATCH_SIZE + (1 if N_SALES % BATCH_SIZE else 0)
sales_id = 1

for batch_num in range(num_batches):
    bsz = BATCH_SIZE if batch_num < num_batches - 1 else N_SALES - batch_num * BATCH_SIZE

    chosen_dates = np.random.choice(datekeys, bsz, p=date_weights)
    chosen_stores = np.random.choice(store_ids, bsz, p=store_weights)
    chosen_customers = np.random.choice(customer_ids, bsz, p=cust_weights)
    chosen_products = np.random.choice(product_ids, bsz)
    prod_cats = product_categories[chosen_products - 1]
    cat_idx = np.array([cat_to_idx[c] for c in prod_cats])
    
    has_promo = np.random.choice([0,1], bsz, p=[0.6, 0.4])
    chosen_promos = np.where(has_promo == 1, np.random.choice(promo_ids, bsz), 0)
    month_arr = datekey_to_month[chosen_dates] - 1
    
    base_qty = np.array([1.5, 1.8, 2.2, 2.8, 2.0])[cat_idx]
    tier_factor = np.array([1.0, 1.3, 1.8, 2.5])[np.array([{'Bronze':0,'Silver':1,'Gold':2,'Platinum':3}[t] for t in customer_tier_arr[chosen_customers - 1]])]
    promo_uplift_values = promo_uplift_arr[chosen_promos]
    qty = np.clip(np.random.gamma(shape=2.0, scale=(base_qty * tier_factor * promo_uplift_values)/2.0), 1, 10).astype(int)
    
    base_price = product_unitprice[chosen_products - 1]
    cat_seasonal = cat_season_matrix[cat_idx, month_arr]
    price_noise = np.random.uniform(0.85, 1.20, bsz)
    unit_price = (base_price * cat_seasonal * price_noise).round(2)
    unit_price = np.clip(unit_price, 10, 800)
    gross = (qty * unit_price).round(2)
    
    promo_perc = promo_discount_pct_arr[chosen_promos]
    promo_fixed = promo_discount_fixed_arr[chosen_promos]
    loyalty_disc = np.where(customer_tier_arr[chosen_customers - 1] == 'Platinum', 0.08, 
                     np.where(customer_tier_arr[chosen_customers - 1] == 'Gold', 0.05, 0.0))
    disc_amount_perc = (gross * (promo_perc + loyalty_disc)).round(2)
    disc_amount_fixed = promo_fixed * qty
    disc_amount = (disc_amount_perc + disc_amount_fixed).round(2)
    disc_amount = np.minimum(disc_amount, gross * 0.99)
    tax_rate = product_taxrate_pct[chosen_products - 1]

    gross_dec = [d2(g) for g in gross]
    disc_dec = [d2(d) for d in disc_amount]
    taxrate_dec = [d2(tr) for tr in tax_rate]
    net_before_tax_dec = [g - d for g, d in zip(gross_dec, disc_dec)]
    tax_amount_dec = [(nbt * tr).quantize(Decimal('0.01')) for nbt, tr in zip(net_before_tax_dec, taxrate_dec)]
    net_dec = [(nbt + tax).quantize(Decimal('0.01')) for nbt, tax in zip(net_before_tax_dec, tax_amount_dec)]

    channel_idx = np.searchsorted(channel_cum_probs, np.random.random(bsz))
    channel = np.array(channel_list)[channel_idx]
    
    is_online = np.isin(channel, ['Online', 'Mobile App'])
    delivery_days = np.zeros(bsz, dtype=int)
    delivery_days[is_online] = np.clip(np.random.negative_binomial(2, 0.4, size=np.sum(is_online)) + 1, 1, 12)
    
    base_return_probs = np.array([CATEGORY_CFG[cat]['return_rate_base'] for cat in prod_cats])
    channel_multiplier = np.ones(bsz)
    channel_multiplier[channel == 'Online'] = 2.5
    channel_multiplier[channel == 'Mobile App'] = 2.2
    channel_multiplier[channel == 'In-Store'] = 0.4
    channel_multiplier[channel == 'Phone Order'] = 1.0
    
    delivery_multiplier = np.ones(bsz)
    online_mask = is_online
    delivery_multiplier[online_mask & (delivery_days <= 2)] = 0.5
    delivery_multiplier[online_mask & (delivery_days > 5)] = 2.5
    
    final_return_prob = base_return_probs * channel_multiplier * delivery_multiplier
    final_return_prob = np.clip(final_return_prob, 0.01, 0.35)
    is_return = np.random.random(bsz) < final_return_prob

    gross_final = []
    disc_final = []
    tax_final = []
    net_final = []
    for i in range(bsz):
        if is_return[i]:
            gross_final.append(float(-gross_dec[i]))
            disc_final.append(float(-disc_dec[i]))
            tax_final.append(float(-tax_amount_dec[i]))
            net_final.append(float(-net_dec[i]))
        else:
            gross_final.append(float(gross_dec[i]))
            disc_final.append(float(disc_dec[i]))
            tax_final.append(float(tax_amount_dec[i]))
            net_final.append(float(net_dec[i]))

    pay_probs = channel_pay_matrix[channel_idx]
    payment = np.array([np.random.choice(PAYMENT, p=p) for p in pay_probs])
    weight = product_weights[chosen_products - 1]
    shipping = np.where(is_online, np.clip((weight * 1.0 + np.random.uniform(0.5, 4.0, bsz)), 0.0, 15.0), 0.0).round(2)
    
    ret_reason = []
    for i in range(bsz):
        if is_return[i]:
            probs = list(return_reason_probs[channel[i]])
            if channel[i] in ['Online', 'Mobile App'] and delivery_days[i] > 5:
                probs[4] += 0.15
                probs = np.array(probs) / sum(probs)
            ret_reason.append(np.random.choice(RETURN_REASONS, p=probs))
        else:
            ret_reason.append(None)

    batch_df = pd.DataFrame({
        'salesid': np.arange(sales_id, sales_id + bsz),
        'datekey': chosen_dates,
        'productid': chosen_products,
        'customerid': chosen_customers,
        'storeid': chosen_stores,
        'promoid': chosen_promos,
        'qty': qty,
        'unitprice': unit_price,
        'taxrate_pct': tax_rate,
        'net': net_final,
        'payment': payment,
        'channel': channel,
        'grossvalue': gross_final,
        'discountamount': disc_final,
        'taxamount': tax_final,
        'shipcost': shipping,
        'isreturn': is_return.astype(int),
        'shipweight': (weight * qty).round(2),
        'discountapplied': ((promo_perc + promo_fixed + loyalty_disc) > 0).astype(int),
        'returnreason': ret_reason,
        'deliverydays': delivery_days
    })
    batch_df.to_csv(fact_file, mode='a', header=False, index=False, encoding='utf-8', lineterminator='\n')
    sales_id += bsz
    if batch_num % 4 == 0:
        print(f"Batch {batch_num+1}/{num_batches} ✓")

print(f"{N_SALES:,} fact rows generated.")
print("✅ All files created successfully.")

# =============================================================================
# DOCUMENTATION: DATA DICTIONARY, BUSINESS NAMES, FORMATS, AND MEASURES
# =============================================================================
print("\n" + "="*80)
print("DATA DICTIONARY & MEASURE CALCULATION GUIDE")
print("="*80)

def print_table_dict(table_name, columns):
    print(f"\n--- {table_name} ---")
    for col, desc, fmt in columns:
        print(f"{col:<30} : {desc} (Format: {fmt})")

# dimdate
dimdate_cols = [
    ("datekey", "Integer surrogate key (YYYYMMDD)", "INT"),
    ("fulldate", "Actual date", "DATE"),
    ("year", "Year (e.g., 2023)", "SMALLINT"),
    ("quarternumber", "Quarter number (1-4)", "TINYINT"),
    ("quartername", "Quarter name (Q1-Q4)", "NCHAR(2)"),
    ("monthnumber", "Month number (1-12)", "TINYINT"),
    ("monthname", "Month name", "NVARCHAR(20)"),
    ("weekdaynumber", "Day of week (1=Monday, 7=Sunday)", "TINYINT"),
    ("weekdayname", "Day name", "NVARCHAR(20)"),
    ("isweekend", "1 if weekend, else 0", "BIT"),
    ("yearmonth", "Year-month (YYYY-MM)", "NCHAR(7)"),
    ("yearmonthnumber", "Year-month integer (YYYYMM)", "INT"),
    ("yearquarter", "Year-quarter (YYYY-QX)", "NVARCHAR(7)"),
    ("yearquarternumber", "Year-quarter integer (YYYY*10+Q)", "INT"),
    ("yearweek", "Year-week (YYYY-Www)", "NVARCHAR(8)"),
    ("yearweeknumber", "Year-week integer (YYYY*100+week)", "INT"),
    ("isholiday", "1 if holiday (Dec/Jan/July), else 0", "BIT")
]
print_table_dict("dim_date", dimdate_cols)

# dimcustomer
dimcustomer_cols = [
    ("customerid", "Unique customer identifier", "INT"),
    ("fullname", "Full name (first + last), with numeric suffix if duplicate", "NVARCHAR(100)"),
    ("email", "Customer email (unique)", "NVARCHAR(100)"),
    ("age", "Age in years (18-75)", "TINYINT"),
    ("gender", "Male / Female / Non-binary", "NVARCHAR(20)"),
    ("city", "City of residence", "NVARCHAR(50)"),
    ("tier", "Bronze / Silver / Gold / Platinum", "NVARCHAR(20)"),
    ("points", "Loyalty points", "INT"),
    ("isactive", "1 if active, else 0", "BIT"),
    ("lang", "Language preference (en,de,fr,es,pl,it)", "NVARCHAR(10)"),
    ("totalspend", "Total lifetime spend (USD)", "DECIMAL(18,2)"),
    ("regdate", "Registration date", "DATE"),
    ("annualincome", "Estimated annual income (USD)", "DECIMAL(18,2)"),
    ("incomebracket", "Low / Medium / High / Very High / Ultra High", "NVARCHAR(20)"),
    ("education", "Education level", "NVARCHAR(50)"),
    ("maritalstatus", "Single / Married / Divorced / Widowed", "NVARCHAR(20)"),
    ("childrencount", "Number of children", "TINYINT"),
    ("loyaltysegment", "Same as tier", "NVARCHAR(20)"),
    ("satisfactionscore", "Customer satisfaction (1.0-5.0)", "DECIMAL(5,1)"),
    ("dayssincelastpurchase", "Days since last purchase", "INT"),
    ("hassubscription", "1 if subscribed to newsletter", "BIT"),
    ("preferredcontact", "Email / SMS / Phone / Mail", "NVARCHAR(20)"),
    ("spendmultiplier", "Multiplier for spending behavior", "DECIMAL(10,3)")
]
print_table_dict("dim_customer", dimcustomer_cols)

# dimproduct
dimproduct_cols = [
    ("productid", "Unique product identifier", "INT"),
    ("name", "Product name (brand + adjective + noun)", "NVARCHAR(150)"),
    ("category", "Electronics / Home / Sports / Kids / Garden", "NVARCHAR(50)"),
    ("brand", "Brand name", "NVARCHAR(50)"),
    ("unitcost", "Cost per unit (USD)", "DECIMAL(18,2)"),
    ("unitprice", "Selling price per unit (USD)", "DECIMAL(18,2)"),
    ("margin_pct", "Margin percentage (unitprice - unitcost)/unitprice as fraction (0.01-0.30)", "DECIMAL(5,4)"),
    ("weight", "Weight in kg", "DECIMAL(10,2)"),
    ("color", "Primary color", "NVARCHAR(20)"),
    ("material", "Plastic / Metal / Wood / Glass / Fabric", "NVARCHAR(50)"),
    ("supplierid", "Supplier identifier (1-50)", "INT"),
    ("isactive", "1 if product still sold", "BIT"),
    ("minstock", "Minimum stock level", "INT"),
    ("taxrate_pct", "Tax rate as fraction (0.10 or 0.21)", "DECIMAL(5,4)"),
    ("haswarranty", "1 if warranty offered", "BIT"),
    ("ecofriendly", "1 if eco-score >100", "BIT"),
    ("seasonalityfactor", "Seasonal demand multiplier (0.7-1.3)", "DECIMAL(5,2)"),
    ("warrantymonths", "Warranty duration in months (0,12,24,36)", "TINYINT"),
    ("ecoscore", "Environmental score (20-200)", "TINYINT"),
    ("releaseyear", "Year of release", "SMALLINT"),
    ("skucount", "Number of SKUs/variants", "INT"),
    ("isdiscontinued", "1 if discontinued", "BIT"),
    ("productrating", "Customer rating (1.0-5.0)", "DECIMAL(3,1)"),
    ("stockstatus", "In Stock / Low Stock / Out of Stock", "NVARCHAR(20)")
]
print_table_dict("dim_product", dimproduct_cols)

# dimstore
dimstore_cols = [
    ("storeid", "Unique store identifier", "INT"),
    ("storename", "Store name (chain + city + suffix)", "NVARCHAR(150)"),
    ("city", "City where store is located", "NVARCHAR(50)"),
    ("type", "Supermarket / Hypermarket / Convenience / Department", "NVARCHAR(50)"),
    ("staff", "Number of employees", "SMALLINT"),
    ("sizem2", "Store size in square meters", "INT"),
    ("hascafe", "1 if store has a café", "BIT"),
    ("openingyear", "Year store opened", "SMALLINT"),
    ("region", "North / South / East / West / Central", "NVARCHAR(50)"),
    ("renovationyear", "Year of last renovation (0 if never)", "SMALLINT"),
    ("parkingspots", "Number of parking spots", "SMALLINT"),
    ("storerating", "Store rating (2.0-5.0)", "DECIMAL(3,1)"),
    ("hasdeliveryservice", "1 if delivery service available", "BIT"),
    ("floornumber", "Number of floors (1-5)", "TINYINT"),
    ("distancetocitycenterkm", "Distance to city center (km)", "DECIMAL(8,1)"),
    ("annualrentcost", "Annual rent cost (USD)", "DECIMAL(18,2)"),
    ("storesizemultiplier", "Relative size multiplier (0.3-4.0)", "DECIMAL(10,3)")
]
print_table_dict("dim_store", dimstore_cols)

# dimpromotion
dimpromotion_cols = [
    ("promoid", "Unique promotion identifier", "INT"),
    ("promoname", "Promotion name (unique)", "NVARCHAR(150)"),
    ("discount_pct", "Percentage discount as fraction (0.10-0.45)", "DECIMAL(5,3)"),
    ("discount_fixed", "Fixed discount in USD", "DECIMAL(10,2)"),
    ("type", "Percentage / Fixed Amount / BOGO / Free Shipping", "NVARCHAR(50)"),
    ("isactive", "1 if promotion is currently active", "BIT"),
    ("minspend", "Minimum spend required to qualify (USD)", "INT"),
    ("channel", "Email / SMS / App / InStore / All / Online", "NVARCHAR(50)"),
    ("budget", "Promotion budget (USD)", "DECIMAL(18,2)"),
    ("startdate", "Start date", "DATE"),
    ("enddate", "End date", "DATE"),
    ("targetaudience", "All / New / Loyal / HighSpend", "NVARCHAR(50)"),
    ("maxdiscountcap", "Maximum discount cap (USD)", "DECIMAL(18,2)"),
    ("isstackable", "1 if can combine with other promotions", "BIT"),
    ("redemption_rate_target_pct", "Target redemption rate as fraction (0.02-0.35)", "DECIMAL(5,3)"),
    ("coderequired", "1 if promo code required", "BIT"),
    ("promoupliftfactor", "Sales uplift multiplier (1.0-2.2)", "DECIMAL(6,3)")
]
print_table_dict("dim_promotion", dimpromotion_cols)

# factsales
factsales_cols = [
    ("salesid", "Unique transaction line identifier", "BIGINT"),
    ("datekey", "Foreign key to dim_date", "INT"),
    ("productid", "Foreign key to dim_product", "INT"),
    ("customerid", "Foreign key to dim_customer", "INT"),
    ("storeid", "Foreign key to dim_store", "INT"),
    ("promoid", "Foreign key to dim_promotion (0 = no promotion)", "INT"),
    ("qty", "Quantity sold (1-10)", "TINYINT"),
    ("unitprice", "Selling price per unit at time of sale (USD)", "DECIMAL(18,2)"),
    ("taxrate_pct", "Tax rate applied as fraction (0.10 or 0.21)", "DECIMAL(5,4)"),
    ("net", "Net amount after discount and tax (gross - discount + tax)", "DECIMAL(18,2)"),
    ("payment", "Card / Cash / Bank Transfer / Digital Wallet / PayPal", "NVARCHAR(20)"),
    ("channel", "Online / In-Store / Mobile App / Phone Order", "NVARCHAR(20)"),
    ("grossvalue", "Gross value before discount and tax (qty * unitprice)", "DECIMAL(18,2)"),
    ("discountamount", "Total discount applied (USD)", "DECIMAL(18,2)"),
    ("taxamount", "Tax amount (USD)", "DECIMAL(18,2)"),
    ("shipcost", "Shipping cost (USD, 0 for in-store)", "DECIMAL(18,2)"),
    ("isreturn", "1 if transaction is a return", "BIT"),
    ("shipweight", "Total weight of items shipped (kg)", "DECIMAL(10,2)"),
    ("discountapplied", "1 if any discount was applied", "BIT"),
    ("returnreason", "Reason for return (NULL if not a return)", "NVARCHAR(50)"),
    ("deliverydays", "Delivery days (0 for in-store, 1-12 for online)", "TINYINT")
]
print_table_dict("fact_sales", factsales_cols)

# =============================================================================
# MEASURE EXAMPLES IN T-SQL AND DAX
# =============================================================================
print("\n" + "="*80)
print("BASE MEASURES IN T-SQL (SQL SERVER)")
print("="*80)
print("-- 1. Total Revenue (net sales after discount and tax)")
print("SELECT SUM(net) AS total_revenue FROM dbo.factsales WHERE isreturn = 0;")
print("\n-- 2. Total Cost")
print("SELECT SUM(f.qty * p.unitcost) AS total_cost")
print("FROM dbo.factsales f")
print("INNER JOIN dbo.dimproduct p ON f.productid = p.productid")
print("WHERE f.isreturn = 0;")
print("\n-- 3. Total Margin")
print("SELECT SUM(f.net - (f.qty * p.unitcost)) AS total_margin")
print("FROM dbo.factsales f")
print("INNER JOIN dbo.dimproduct p ON f.productid = p.productid")
print("WHERE f.isreturn = 0;")
print("\n-- 4. Margin % (fraction)")
print("SELECT (SUM(f.net - (f.qty * p.unitcost)) / NULLIF(SUM(f.net),0)) AS margin_pct")
print("FROM dbo.factsales f")
print("INNER JOIN dbo.dimproduct p ON f.productid = p.productid")
print("WHERE f.isreturn = 0;")
print("\n-- 5. Average Basket Value")
print("SELECT SUM(net) / COUNT(DISTINCT salesid) AS avg_basket")
print("FROM dbo.factsales WHERE isreturn = 0;")
print("\n-- 6. Return Rate (fraction)")
print("SELECT 1.0 * SUM(CASE WHEN isreturn = 1 THEN 1 ELSE 0 END) / COUNT(*) AS return_rate")
print("FROM dbo.factsales;")
print("\n-- 7. Top 10 Products by Revenue")
print("SELECT TOP 10 p.name, SUM(f.net) AS revenue")
print("FROM dbo.factsales f")
print("INNER JOIN dbo.dimproduct p ON f.productid = p.productid")
print("WHERE f.isreturn = 0")
print("GROUP BY p.name")
print("ORDER BY revenue DESC;")

print("\n" + "="*80)
print("BASE MEASURES IN DAX (POWER BI)")
print("="*80)
print("-- Assumes relationships: factsales[productid] -> dimproduct[productid], etc.")
print("Total Revenue = SUMX(FILTER(factsales, factsales[isreturn] = 0), factsales[net])")
print("\nTotal Cost = SUMX(")
print("    FILTER(factsales, factsales[isreturn] = 0),")
print("    factsales[qty] * RELATED(dimproduct[unitcost])")
print(")")
print("\nTotal Margin = [Total Revenue] - [Total Cost]")
print("\nMargin % = DIVIDE([Total Margin], [Total Revenue], 0)")
print("\nAverage Basket = DIVIDE([Total Revenue], DISTINCTCOUNT(factsales[salesid]))")
print("\nReturn Rate = DIVIDE(COUNTROWS(FILTER(factsales, factsales[isreturn]=1)), COUNTROWS(factsales), 0)")
print("\n-- Note: All percentage columns (margin_pct, taxrate_pct, discount_pct, redemption_rate_target_pct)")
print("-- are stored as fractions (0.15 = 15%). Set column format to 'Percentage' in Power BI.")

print("\n✅ Script finished successfully.")