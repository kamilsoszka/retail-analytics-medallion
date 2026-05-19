# =====================================================================
# generator.py
# Retail Data Generator – 5M rows
# Last updated: 2026-05-19
# =====================================================================

"""
Realistic Retail Data Generator - 5M Rows Edition (FINAL WORKING)
- END_DATE = today
- In-Store deliverydays = 0 (guaranteed using np.where after clipping)
- Overwrites existing CSV (deletes old file before writing)
- No dummy promotion (NULL = no promotion)
- Self-verifies generated CSV
"""

import numpy as np
import pandas as pd
from datetime import datetime, timedelta
import os
import re
import random
from collections import defaultdict

# =====================================================================
# CONFIGURATION
# =====================================================================
OUTPUT_DIR = "c:/data"
N_SALES = 5_000_000
N_CUSTOMERS = 200_000
N_PRODUCTS = 2_000
N_STORES = 200
N_PROMOTIONS = 100
RANDOM_SEED = 42

if RANDOM_SEED is not None:
    np.random.seed(RANDOM_SEED)
    random.seed(RANDOM_SEED)

os.makedirs(OUTPUT_DIR, exist_ok=True)

START_DATE = datetime(2023, 1, 1)
END_DATE = datetime.now().replace(hour=0, minute=0, second=0, microsecond=0)

print(f"Generating data from {START_DATE.date()} to {END_DATE.date()}")

# =====================================================================
# NAME LISTS (full)
# =====================================================================
STORE_CHAINS = {
    'Supermarket': ['FreshMart', 'CityFood', 'DailyGrocer', 'MarketPlace', 'ValueSave', 'GoodMart'],
    'Hypermarket': ['MegaMart', 'SuperSaver', 'GlobalHyper', 'BigBox', 'GiantStore', 'PriceCutter'],
    'Convenience': ['QuickStop', 'CornerShop', 'EasyBuy', 'OnTheRun', 'MiniMarket', 'FastShop'],
    'Department': ['CityCenter', 'TheGalleria', 'TownSquare', 'UrbanMall', 'GrandPlaza', 'MetroStore']
}
STORE_SUFFIXES = ['Center', 'Plaza', 'Market', 'Point', 'Hub', 'Square', 'Mart']

PROMO_TEMPLATES = {
    'Percentage': ['Spring Sale', 'Summer Deal', 'Winter Discount', 'Flash Sale', 'Clearance', 'Happy Hour', 'Member Special'],
    'Fixed Amount': ['Cashback', 'Save $', 'Discount Voucher', 'Price Drop', 'Instant Save', 'Coupon Special'],
    'BOGO': ['Buy 1 Get 1 Free', '2 for 1', '3 for 2', 'Multi-buy', 'Double Up'],
    'Free Shipping': ['Free Delivery', 'No Shipping Fee', 'Shipping included', 'Free Post']
}

PRODUCT_NAMES = {
    'Electronics': ['Smartphone', 'Laptop', 'Headphones', 'Smartwatch', 'Tablet', 'Monitor', 'Speaker', 'Camera', 'Console', 'Router'],
    'Home': ['Desk', 'Chair', 'Lamp', 'Sofa', 'Table', 'Bed', 'Cabinet', 'Vacuum', 'Blender', 'Toaster'],
    'Sports': ['Shoes', 'Tshirt', 'Backpack', 'Bike', 'Ball', 'Racket', 'Dumbbells', 'Mat', 'Gloves', 'Helmet'],
    'Kids': ['Doll', 'Action Figure', 'Puzzle', 'Blocks', 'Board Game', 'Plushie', 'Lego Set', 'Cart', 'Book', 'Costume'],
    'Garden': ['Lawn Mower', 'Hedge Trimmer', 'Hose', 'Shovel', 'Rake', 'Faucet', 'Seeds', 'Pot', 'Fertilizer', 'Gnome']
}
PRODUCT_ADJECTIVES = ['Pro', 'Plus', 'Max', 'Lite', 'Ultra', 'Mini', 'Elite', 'Core', 'Prime', 'Select', 'Air', 'Studio']
BRANDS = {
    'Electronics': ['Sony','Samsung','Apple','Philips','LG','Dell','HP','Asus','Bose','Logitech'],
    'Home': ['IKEA','Tefal','Bosch','Electrolux','Dyson','Nespresso','Kenwood','Braun','Rowenta','DeLonghi'],
    'Sports': ['Nike','Adidas','Puma','Reebok','UnderArmour','NewBalance','Asics','Jordan','Mizuno','Salomon'],
    'Kids': ['LEGO','Fisher-Price','Mattel','Hasbro','Playmobil','Barbie','HotWheels','Nerf','Cocomelon','PawPatrol'],
    'Garden': ['Husqvarna','Bosch','Black and Decker','Gardena','Makita','Stihl','Fiskars','Wolf','Karcher','Bosch'],
}
FIRST_NAMES_MALE = ['James', 'John', 'Robert', 'Michael', 'William', 'David', 'Richard', 'Joseph', 'Thomas', 'Charles', 'Daniel', 'Matthew']
FIRST_NAMES_FEMALE = ['Mary', 'Patricia', 'Jennifer', 'Linda', 'Elizabeth', 'Barbara', 'Susan', 'Jessica', 'Sarah', 'Karen', 'Lisa', 'Nancy']
LAST_NAMES = ['Smith', 'Johnson', 'Williams', 'Brown', 'Jones', 'Garcia', 'Miller', 'Davis', 'Rodriguez', 'Martinez', 'Hernandez', 'Lopez']
CITIES = ['New York', 'Los Angeles', 'Chicago', 'Houston', 'Phoenix', 'Philadelphia', 'San Antonio', 'San Diego', 'Dallas', 'San Jose']
GENDERS = ['Male','Female','Non-binary']
EDUCATION = ['High School','Bachelor','Master','PhD']
MARITAL = ['Single','Married','Divorced','Widowed']
CONTACT_PREF = ['Email','SMS','Phone','Mail']
PAYMENT = ['Card','Cash','Bank Transfer','Digital Wallet','PayPal']
CHANNELS = ['Online','In-Store','Mobile App','Phone Order']
STORE_TYPES = ['Supermarket','Hypermarket','Convenience','Department']
REGIONS = ['North','South','East','West','Central']
RETURN_REASONS = ['Defective','Wrong item','Not as described','Changed mind','Late delivery','Other']

CAT_NAMES = ['Electronics', 'Home', 'Sports', 'Kids', 'Garden']
CATEGORY_CFG = {
    'Electronics': {'price_lo': 250, 'price_hi': 600, 'weight_lo': 0.3, 'weight_hi': 3.0, 'tax_rate': 0.21, 'warranty_prob': 0.9, 'return_rate_base': 0.03},
    'Home':        {'price_lo': 80, 'price_hi': 200, 'weight_lo': 1.0, 'weight_hi': 15.0, 'tax_rate': 0.21, 'warranty_prob': 0.5, 'return_rate_base': 0.06},
    'Sports':      {'price_lo': 40, 'price_hi': 150, 'weight_lo': 0.2, 'weight_hi': 5.0, 'tax_rate': 0.21, 'warranty_prob': 0.3, 'return_rate_base': 0.09},
    'Kids':        {'price_lo': 15, 'price_hi': 60, 'weight_lo': 0.1, 'weight_hi': 2.0, 'tax_rate': 0.10, 'warranty_prob': 0.2, 'return_rate_base': 0.15},
    'Garden':      {'price_lo': 30, 'price_hi': 120, 'weight_lo': 0.5, 'weight_hi': 12.0, 'tax_rate': 0.21, 'warranty_prob': 0.6, 'return_rate_base': 0.07},
}

print("Generating dimensions...")

# =====================================================================
# DIMENSION: STORES (unchanged)
# =====================================================================
store_type_list = []
while len(store_type_list) < N_STORES:
    for t in STORE_TYPES:
        for chain in STORE_CHAINS.get(t, STORE_CHAINS['Supermarket']):
            for city in CITIES:
                for suffix in STORE_SUFFIXES:
                    store_type_list.append((t, chain, city, suffix))
                    if len(store_type_list) >= N_STORES * 2:
                        break
                if len(store_type_list) >= N_STORES * 2:
                    break
            if len(store_type_list) >= N_STORES * 2:
                break
        if len(store_type_list) >= N_STORES * 2:
            break

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
                    np.where(np.array(store_types) == 'Hypermarket', 0.8,
                    np.where(np.array(store_types) == 'Convenience', 1.4, 1.0))).round(0)
store_rating = np.clip(2.0 + (store_staff/120)*0.8 + (store_parking/300)*0.5 + np.random.uniform(0, 1.2, N_STORES), 2.0, 5.0).round(1)

store_df = pd.DataFrame({
    'storeid': store_ids,
    'storename': store_name,
    'city': store_cities,
    'type': store_types,
    'staff': store_staff,
    'sizem2': store_sizem2,
    'hascafe': np.random.choice([0,1], N_STORES, p=[0.6,0.4]),
    'openingyear': np.random.randint(1985, 2023, N_STORES),
    'region': store_regions,
    'renovationyear': np.random.choice([0]+list(range(2010,2024)), N_STORES, p=[0.35]+[0.65/14]*14),
    'parkingspots': store_parking,
    'storerating': store_rating,
    'hasdeliveryservice': np.random.choice([0,1], N_STORES, p=[0.4,0.6]),
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

# =====================================================================
# DIMENSION: PRODUCTS (with isactive fix)
# =====================================================================
product_pool = []
while len(product_pool) < N_PRODUCTS * 1.5:
    for cat in CAT_NAMES:
        for brand in BRANDS[cat]:
            for adj in PRODUCT_ADJECTIVES:
                for noun in PRODUCT_NAMES[cat]:
                    variant = np.random.choice(['', 'V2', 'X', 'Series 5', 'Mk1', '2024', 'Ltd', 'Gen3'], p=[0.4, 0.1, 0.1, 0.1, 0.1, 0.1, 0.05, 0.05])
                    name = f"{brand} {adj} {noun} {variant}".strip()
                    if name not in product_pool:
                        product_pool.append(name)
    if len(product_pool) > N_PRODUCTS * 1.2:
        break

random.shuffle(product_pool)
unique_product_names = product_pool[:N_PRODUCTS]

product_ids = np.arange(1, N_PRODUCTS + 1)
product_categories = np.random.choice(CAT_NAMES, N_PRODUCTS, p=[0.25, 0.25, 0.20, 0.15, 0.15])
product_brands = [np.random.choice(BRANDS[cat]) for cat in product_categories]
product_brand_premium = np.random.uniform(0.9, 1.5, N_PRODUCTS)
product_weights = []
product_unitprice = []
product_unitcost = []
product_tax_rate = []
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
    product_tax_rate.append(cfg['tax_rate'])
    product_warranty.append(int(np.random.random() < cfg['warranty_prob']))
    e_score = int(np.random.uniform(20, 200))
    product_ecoscore.append(e_score)
    product_material.append(np.random.choice(['Plastic','Metal','Wood','Glass','Fabric']))
    product_margin_pct.append(margin)

product_unitprice = np.array(product_unitprice)
product_unitcost = np.array(product_unitcost)
product_tax_rate = np.array(product_tax_rate)
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

product_isactive = np.where(product_isdiscontinued == 1, 0, product_isactive)

product_df = pd.DataFrame({
    'productid': product_ids,
    'name': product_name,
    'category': product_categories,
    'brand': product_brands,
    'unitcost': product_unitcost,
    'unitprice': product_unitprice,
    'margin_pct': product_margin_pct,
    'weight': product_weights,
    'color': np.random.choice(['Red','Blue','Green','Black','White','Gray','Silver','Gold'], N_PRODUCTS),
    'material': product_material,
    'supplierid': np.random.randint(1, 51, N_PRODUCTS),
    'isactive': product_isactive,
    'minstock': np.random.randint(2, 100, N_PRODUCTS),
    'tax_rate': product_tax_rate,
    'haswarranty': product_warranty,
    'ecofriendly': (product_ecoscore > 100).astype(int),
    'seasonalityfactor': np.random.uniform(0.7, 1.3, N_PRODUCTS).round(2),
    'warrantymonths': np.where(product_warranty==1, np.random.choice([12,24,36], N_PRODUCTS), 0),
    'ecoscore': product_ecoscore,
    'releaseyear': product_releaseyear,
    'skucount': product_skucount,
    'isdiscontinued': product_isdiscontinued,
    'productrating': product_rating,
    'stockstatus': product_stockstatus
})
if not product_df['name'].is_unique:
    product_df['name'] = product_df['name'] + ' - ' + product_df['productid'].astype(str)
product_df.to_csv(f"{OUTPUT_DIR}/dim_product.csv", index=False, encoding='utf-8')

# =====================================================================
# DIMENSION: PROMOTIONS – NO DUMMY ROW (only real promos 1..N_PROMOTIONS)
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

max_days = max(1, (END_DATE - START_DATE).days)
promo_start = (START_DATE + pd.to_timedelta(np.random.randint(0, min(900, max_days), N_PROMOTIONS), unit='D')).to_pydatetime()
promo_end = (START_DATE + pd.to_timedelta(np.random.randint(15, min(950, max_days), N_PROMOTIONS), unit='D')).to_pydatetime()
for i in range(N_PROMOTIONS):
    if promo_start[i] > promo_end[i]:
        promo_start[i], promo_end[i] = promo_end[i], promo_start[i]
    if promo_end[i] > END_DATE:
        promo_end[i] = END_DATE
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

promo_df = pd.DataFrame({
    'promoid': promo_ids,
    'promoname': promo_name,
    'discount_pct': promo_discount_pct.round(3),
    'discount_fixed': promo_discount_fixed.round(2),
    'type': promo_types,
    'isactive': promo_isactive,
    'minspend': np.random.choice([0,10,25,50,100], N_PROMOTIONS, p=[0.25,0.30,0.20,0.15,0.10]),
    'channel': promo_channels,
    'budget': promo_budgets,
    'startdate': promo_start_str,
    'enddate': promo_end_str,
    'targetaudience': np.random.choice(['All','New','Loyal','HighSpend'], N_PROMOTIONS, p=[0.40,0.15,0.25,0.20]),
    'maxdiscountcap': np.random.uniform(5, 120, N_PROMOTIONS).round(2),
    'isstackable': np.random.choice([0,1], N_PROMOTIONS, p=[0.85,0.15]),
    'redemption_rate': np.random.uniform(0.02, 0.35, N_PROMOTIONS).round(3),
    'coderequired': np.random.choice([0,1], N_PROMOTIONS, p=[0.60,0.40]),
    'promoupliftfactor': promo_uplift.round(3)
})
promo_df.to_csv(f"{OUTPUT_DIR}/dim_promotion.csv", index=False, encoding='utf-8')

# =====================================================================
# DIMENSION: CUSTOMERS (unchanged)
# =====================================================================
customer_ids = np.arange(1, N_CUSTOMERS + 1)
gender_choice = np.random.choice(['Male','Female'], N_CUSTOMERS, p=[0.5, 0.5])
raw_first = []
raw_last = []
for i in range(N_CUSTOMERS):
    if gender_choice[i] == 'Male':
        first = np.random.choice(FIRST_NAMES_MALE)
    else:
        first = np.random.choice(FIRST_NAMES_FEMALE)
    last = np.random.choice(LAST_NAMES)
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
customer_hassubscription = np.random.choice([0,1], N_CUSTOMERS, p=[0.65, 0.35])
customer_childrencount = np.random.poisson(np.where(customer_age < 30, 0.3, np.where(customer_age < 45, 0.9, 0.4)), N_CUSTOMERS).astype(int)

contact_probs = np.zeros((N_CUSTOMERS, 4))
contact_probs[:, 0] = np.where(customer_age < 35, 0.6, 0.3)
contact_probs[:, 1] = np.where(customer_age < 30, 0.25, 0.4)
contact_probs[:, 2] = np.where(customer_age > 50, 0.35, 0.15)
contact_probs[:, 3] = 1.0 - contact_probs.sum(axis=1)
contact_probs = np.maximum(contact_probs, 0.05)
contact_probs = contact_probs / contact_probs.sum(axis=1, keepdims=True)
customer_contact = np.array([np.random.choice(CONTACT_PREF, p=p) for p in contact_probs])

customer_df = pd.DataFrame({
    'customerid': customer_ids,
    'fullname': fullname_list,
    'email': email_list,
    'age': customer_age,
    'gender': np.random.choice(GENDERS, N_CUSTOMERS, p=[0.48, 0.48, 0.04]),
    'city': np.random.choice(CITIES, N_CUSTOMERS),
    'tier': customer_tier,
    'points': customer_points,
    'isactive': np.random.choice([0,1], N_CUSTOMERS, p=[0.06, 0.94]),
    'lang': np.random.choice(['en','de','fr','es','pl','it'], N_CUSTOMERS, p=[0.35,0.20,0.15,0.15,0.10,0.05]),
    'totalspend': customer_totalSpend,
    'regdate': customer_regdate,
    'annualincome': customer_income.round(2),
    'incomebracket': pd.cut(customer_income, bins=[0,25000,50000,75000,100000,1e9], labels=['Low','Medium','High','Very High','Ultra High']).astype(str),
    'education': np.random.choice(EDUCATION, N_CUSTOMERS, p=[0.30,0.40,0.25,0.05]),
    'maritalstatus': np.random.choice(MARITAL, N_CUSTOMERS),
    'childrencount': customer_childrencount,
    'loyaltysegment': customer_loyaltysegment,
    'satisfactionscore': customer_satisfactionscore,
    'dayssincelastpurchase': customer_dayssincelast,
    'hassubscription': customer_hassubscription,
    'preferredcontact': customer_contact,
    'spendmultiplier': customer_spend_mult.round(3)
})
customer_df.to_csv(f"{OUTPUT_DIR}/dim_customer.csv", index=False, encoding='utf-8')

# =====================================================================
# DIMENSION: DATE (dynamic)
# =====================================================================
dates = pd.date_range(START_DATE, END_DATE, freq='D')
isholiday_arr = (np.isin(dates.month, [12, 1]) | (dates.month == 7)).astype(int)

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
    'isholiday': isholiday_arr
})
date_df.to_csv(f"{OUTPUT_DIR}/dim_date.csv", index=False, encoding='utf-8')

print("Dimensions exported successfully ✓")

# ============================================================================
# MODERATE TREND GENERATION (unchanged)
# ============================================================================
print("Generating Moderate Trend Data...")
n = len(dates)

phase1_end_idx = min((datetime(2023, 3, 31) - START_DATE).days, n - 1)
phase2_end_idx = min((datetime(2023, 12, 31) - START_DATE).days, n - 1)
phase3_end_idx = min((datetime(2025, 12, 31) - START_DATE).days, n - 1)
phase4_mid_idx = min((datetime(2026, 6, 30) - START_DATE).days, n - 1)

start_val = 50000
soft_land_val = 20000
stable_val = 22000
moderate_peak_val = 45000
correction_val = 35000
final_rally_val = 42000

trend = np.zeros(n)

len1 = phase1_end_idx + 1
if len1 > 0:
    trend[:len1] = np.linspace(start_val, soft_land_val, len1)

if phase2_end_idx > phase1_end_idx:
    len2 = phase2_end_idx - phase1_end_idx
    trend[phase1_end_idx+1:phase2_end_idx+1] = np.linspace(soft_land_val, stable_val, len2)

if phase3_end_idx > phase2_end_idx:
    len3 = phase3_end_idx - phase2_end_idx
    trend[phase2_end_idx+1:phase3_end_idx+1] = np.linspace(stable_val, moderate_peak_val, len3)

if phase4_mid_idx > phase3_end_idx:
    len4 = phase4_mid_idx - phase3_end_idx
    trend[phase3_end_idx+1:phase4_mid_idx+1] = np.linspace(moderate_peak_val, correction_val, len4)

if n - 1 > phase4_mid_idx:
    len5 = n - (phase4_mid_idx + 1)
    trend[phase4_mid_idx+1:] = np.linspace(correction_val, final_rally_val, len5)

window = 7
ma = np.convolve(trend, np.ones(window)/window, mode='same')
ma[:window//2] = trend[:window//2]
ma[-window//2:] = trend[-window//2:]
smooth_trend = ma

drift_rates = np.zeros(n)
drift_rates[0] = 0
for i in range(1, n):
    if smooth_trend[i-1] != 0:
        drift_rates[i] = (smooth_trend[i] - smooth_trend[i-1]) / smooth_trend[i-1]

volatility = 0.02
noise = np.random.normal(0, 1, n)
smoothed_noise = np.convolve(noise, np.ones(3)/3, mode='same')

final_values = np.zeros(n)
final_values[0] = smooth_trend[0]
for i in range(1, n):
    daily_change = drift_rates[i] + volatility * smoothed_noise[i]
    final_values[i] = final_values[i-1] * (1 + daily_change)

daily_net_sales_target = np.round(final_values).astype(int)
daily_net_sales_target = np.maximum(daily_net_sales_target, 1000)

print("\n" + "="*60)
print("MODERATE TREND Statistics")
print("="*60)
print(f"Start ({dates[0].date()}): {daily_net_sales_target[0]}")
print(f"After Soft Landing (approx {dates[min(phase1_end_idx, n-1)].date()}): {daily_net_sales_target[min(phase1_end_idx, n-1)]}")
print(f"End 2023 (approx {dates[min(phase2_end_idx, n-1)].date()}): {daily_net_sales_target[min(phase2_end_idx, n-1)]}")
print(f"Peak (approx {dates[min(phase3_end_idx, n-1)].date()}): {daily_net_sales_target[min(phase3_end_idx, n-1)]}")
print(f"Correction low (approx {dates[min(phase4_mid_idx, n-1)].date()}): {daily_net_sales_target[min(phase4_mid_idx, n-1)]}")
print(f"End ({dates[-1].date()}): {daily_net_sales_target[-1]}")
print("="*60)

# ============================================================================
# GENERATE FACT SALES – WITH DELIVERYDAYS FIX (np.where)
# ============================================================================
print("\nGenerating fact_sales rows (5M) in chunks...")

datekeys = date_df['datekey'].values
product_ids_arr = product_df['productid'].values
customer_ids_arr = customer_df['customerid'].values
store_ids_arr = store_df['storeid'].values
promo_ids_arr = promo_df['promoid'].values
product_unitprice_arr = product_df['unitprice'].values
product_tax_rate_arr = product_df['tax_rate'].values
product_weight_arr = product_df['weight'].values
customer_tier_arr = customer_df['tier'].values
customer_spend_mult_arr = customer_df['spendmultiplier'].values
store_size_mult_arr = store_df['storesizemultiplier'].values

cust_weights = customer_spend_mult_arr * np.where(customer_tier_arr == 'Platinum', 3.0,
                                           np.where(customer_tier_arr == 'Gold', 1.8,
                                           np.where(customer_tier_arr == 'Silver', 1.0, 0.5)))
cust_weights = cust_weights / cust_weights.sum()
store_weights = store_size_mult_arr / store_size_mult_arr.sum()
promo_weights = np.ones(len(promo_ids_arr)) / len(promo_ids_arr)

avg_transaction_value = 125.0
expected_n_transactions = daily_net_sales_target / avg_transaction_value
total_expected = expected_n_transactions.sum()
daily_n_trans = np.floor(N_SALES * expected_n_transactions / total_expected).astype(int)
diff = N_SALES - daily_n_trans.sum()

if diff > 0:
    idx_sorted = np.argsort(daily_net_sales_target)[::-1]
    for i in idx_sorted[:diff]:
        daily_n_trans[i] += 1
elif diff < 0:
    idx_sorted = np.argsort(daily_n_trans)[::-1]
    to_remove = abs(diff)
    for i in idx_sorted:
        if to_remove == 0:
            break
        if daily_n_trans[i] > 0:
            daily_n_trans[i] -= 1
            to_remove -= 1
    if to_remove > 0 and daily_n_trans[0] > to_remove:
        daily_n_trans[0] -= to_remove
    elif to_remove > 0:
        daily_n_trans[0] = 0

daily_n_trans = np.maximum(daily_n_trans, 0)

chunk_size = 100_000
current_buffer = []
sales_id = 1

f_path = f"{OUTPUT_DIR}/fact_sales.csv"
if os.path.exists(f_path):
    os.remove(f_path)

pd.DataFrame(columns=['salesid', 'datekey', 'productid', 'customerid', 'storeid', 'promoid', 
                      'qty', 'unitprice', 'tax_rate', 'net', 'payment', 'channel', 
                      'grossvalue', 'discountamount', 'taxamount', 'shipcost', 'isreturn', 
                      'shipweight', 'discountapplied', 'returnreason', 'deliverydays']).to_csv(f_path, index=False)

print(f"Writing to {f_path} in chunks of {chunk_size}...")

for day_idx in range(n):
    target = daily_net_sales_target[day_idx]
    n_tr = daily_n_trans[day_idx]
    if n_tr == 0:
        continue
    datekey = datekeys[day_idx]

    prod_choices = np.random.choice(product_ids_arr, n_tr)
    cust_choices = np.random.choice(customer_ids_arr, n_tr, p=cust_weights)
    store_choices = np.random.choice(store_ids_arr, n_tr, p=store_weights)
    
    promo_has = np.random.choice([0,1], n_tr, p=[0.65, 0.35])
    promo_choices = np.where(promo_has == 1, np.random.choice(promo_ids_arr, n_tr, p=promo_weights), None)

    daily_price_mult = 1.0 + 0.02 * np.sin(2 * np.pi * day_idx / 365)
    unit_prices = product_unitprice_arr[prod_choices - 1] * daily_price_mult
    tax_rates = product_tax_rate_arr[prod_choices - 1]
    weights = product_weight_arr[prod_choices - 1]

    raw_qty = np.random.poisson(2, n_tr) + 1
    gross = raw_qty * unit_prices
    disc_factor = np.random.uniform(0, 0.3, n_tr)
    net_before_tax = gross * (1 - disc_factor)
    tax = net_before_tax * tax_rates
    net_sales = net_before_tax + tax

    total_raw = net_sales.sum()
    if total_raw != 0:
        scale = target / total_raw
    else:
        scale = 1.0

    gross = (gross * scale).round(2)
    net_sales = (net_sales * scale).round(2)
    tax = (tax * scale).round(2)
    disc_amount = (gross - (net_before_tax * scale)).round(2)

    gross = gross.astype(float)
    net_sales = net_sales.astype(float)
    tax = tax.astype(float)
    disc_amount = disc_amount.astype(float)

    discountapplied = (disc_amount != 0).astype(int)

    channel = np.random.choice(CHANNELS, n_tr, p=[0.5, 0.3, 0.15, 0.05])
    payment = np.random.choice(PAYMENT, n_tr)
    is_online = np.isin(channel, ['Online', 'Mobile App'])

    delivery_days = np.ones(n_tr, dtype=int)
    if is_online.sum() > 0:
        delivery_days[is_online] = np.random.negative_binomial(2, 0.4, size=is_online.sum()) + 1
    delivery_days = np.where(channel == 'In-Store', 0, np.clip(delivery_days, 1, 10))

    return_prob = np.where(channel == 'Online', 0.08,
                  np.where(channel == 'Mobile App', 0.07,
                  np.where(channel == 'In-Store', 0.02, 0.04)))
    return_prob = return_prob * (1 + 0.2 * (delivery_days > 5))
    is_return = np.random.random(n_tr) < return_prob

    shipcost = np.where(is_online, (weights * raw_qty * 0.5).round(2), 0.0)

    return_reason = np.array([None] * n_tr, dtype=object)
    mask_ret = is_return.astype(bool)
    if mask_ret.any():
        return_reason[mask_ret] = np.random.choice(RETURN_REASONS, mask_ret.sum())

    gross = np.where(is_return, -gross, gross)
    net_sales = np.where(is_return, -net_sales, net_sales)
    disc_amount = np.where(is_return, -disc_amount, disc_amount)
    tax = np.where(is_return, -tax, tax)
    shipcost = np.where(is_return, 0.0, shipcost)

    batch_df = pd.DataFrame({
        'salesid': np.arange(sales_id, sales_id + n_tr),
        'datekey': datekey,
        'productid': prod_choices,
        'customerid': cust_choices,
        'storeid': store_choices,
        'promoid': promo_choices,
        'qty': raw_qty,
        'unitprice': unit_prices.round(2),
        'tax_rate': tax_rates,
        'net': net_sales,
        'payment': payment,
        'channel': channel,
        'grossvalue': gross,
        'discountamount': disc_amount,
        'taxamount': tax,
        'shipcost': shipcost,
        'isreturn': is_return.astype(int),
        'shipweight': (weights * raw_qty).round(2),
        'discountapplied': discountapplied,
        'returnreason': return_reason,
        'deliverydays': delivery_days
    })

    current_buffer.append(batch_df)
    sales_id += n_tr

    total_buffered = sum(len(df) for df in current_buffer)
    if total_buffered >= chunk_size:
        pd.concat(current_buffer).to_csv(f_path, mode='a', header=False, index=False)
        current_buffer = []
        print(f"Progress: {sales_id:,} / {N_SALES:,} rows generated...")

if current_buffer:
    pd.concat(current_buffer).to_csv(f_path, mode='a', header=False, index=False)

print("\nVerifying generated CSV...")
df_verify = pd.read_csv(f_path, nrows=5000)
instore = df_verify[df_verify['channel'] == 'In-Store']
if not instore.empty:
    if (instore['deliverydays'] == 0).all():
        print("✅ In-Store deliverydays = 0 – OK")
    else:
        print("❌ ERROR: Some In-Store rows have deliverydays != 0")
        print(instore[['channel', 'deliverydays']].head(10))
        raise SystemExit("Generator produced wrong deliverydays – fix the code!")
else:
    print("No In-Store rows in sample – check data")

print(f"\n✅ All files created successfully. Total rows: {N_SALES:,}")
print(f"Data generated from {START_DATE.date()} to {END_DATE.date()}")
print("In-Store deliverydays = 0. No promotion = NULL.")
# Last updated: 2026-05-19