# ============================================================================
# final_retail_gen.py
# ============================================================================
# Author:       DataGen AI
# Date:         2026-05-23
# Description:  Generates 10M retail sales rows + dimension CSVs.
#               Margins follow a realistic distribution (see product_margin_dist).
#               All _pct columns stored as fractions (0.0–1.0).
#               Gender limited to Male/Female.
#               Higher variance in store size, customer spend, and product prices.
#               margin_pct is rounded to 4 decimal places to fit DECIMAL(5,4).
# ============================================================================

import numpy as np
import pandas as pd
from datetime import datetime, timedelta
import os, random

# ============================================================================
# Configuration
# ============================================================================
OUTPUT_DIR = "c:/data"
N_SALES = 10_000_000
N_CUSTOMERS = 200_000
N_PRODUCTS = 2_000
N_STORES = 200
N_PROMOTIONS = 100
RANDOM_SEED = 42
CHUNK_SIZE = 200_000

if RANDOM_SEED is not None:
    np.random.seed(RANDOM_SEED)
    random.seed(RANDOM_SEED)

os.makedirs(OUTPUT_DIR, exist_ok=True)
START_DATE = datetime(2023, 1, 1)
END_DATE = datetime.now().replace(hour=0, minute=0, second=0, microsecond=0)
print(f"Generating data from {START_DATE.date()} to {END_DATE.date()}")

# ============================================================================
# Static reference data
# ============================================================================
STORE_CHAINS = {
    'Supermarket': ['FreshMart','CityFood','DailyGrocer','MarketPlace','ValueSave','GoodMart'],
    'Hypermarket': ['MegaMart','SuperSaver','GlobalHyper','BigBox','GiantStore','PriceCutter'],
    'Convenience': ['QuickStop','CornerShop','EasyBuy','OnTheRun','MiniMarket','FastShop'],
    'Department': ['CityCenter','TheGalleria','TownSquare','UrbanMall','GrandPlaza','MetroStore']
}
STORE_SUFFIXES = ['Center','Plaza','Market','Point','Hub','Square','Mart']
REGION_CITY_MAP = {
    'North': ['New York','Chicago','Boston','Seattle','Detroit','Minneapolis','Buffalo','Pittsburgh'],
    'South': ['Houston','Dallas','Miami','Atlanta','Austin','Nashville','Orlando','San Antonio'],
    'East': ['Philadelphia','Baltimore','Charlotte','Jacksonville','Washington DC','Tampa','Richmond'],
    'West': ['Los Angeles','San Francisco','Phoenix','San Diego','Portland','Las Vegas','Sacramento'],
    'Central': ['Kansas City','St. Louis','Omaha','Denver','Cleveland','Columbus','Indianapolis','Milwaukee']
}
REGIONS = list(REGION_CITY_MAP.keys())
PROMO_TEMPLATES = {
    'Percentage': ['Spring Sale','Summer Deal','Winter Discount','Flash Sale','Clearance','Happy Hour','Member Special'],
    'Fixed Amount': ['Cashback','Save $','Discount Voucher','Price Drop','Instant Save','Coupon Special'],
    'BOGO': ['Buy 1 Get 1 Free','2 for 1','3 for 2','Multi‑buy','Double Up'],
    'Free Shipping': ['Free Delivery','No Shipping Fee','Shipping included','Free Post']
}
PRODUCT_NAMES = {
    'Electronics': ['Smartphone','Laptop','Headphones','Smartwatch','Tablet','Monitor','Speaker','Camera','Console','Router'],
    'Home': ['Desk','Chair','Lamp','Sofa','Table','Bed','Cabinet','Vacuum','Blender','Toaster'],
    'Sports': ['Shoes','Tshirt','Backpack','Bike','Ball','Racket','Dumbbells','Mat','Gloves','Helmet'],
    'Kids': ['Doll','Action Figure','Puzzle','Blocks','Board Game','Plushie','Lego Set','Cart','Book','Costume'],
    'Garden': ['Lawn Mower','Hedge Trimmer','Hose','Shovel','Rake','Faucet','Seeds','Pot','Fertilizer','Gnome']
}
PRODUCT_ADJECTIVES = ['Pro','Plus','Max','Lite','Ultra','Mini','Elite','Core','Prime','Select','Air','Studio']
BRANDS = {
    'Electronics': ['Sony','Samsung','Apple','Philips','LG','Dell','HP','Asus','Bose','Logitech'],
    'Home': ['IKEA','Tefal','Bosch','Electrolux','Dyson','Nespresso','Kenwood','Braun','Rowenta','DeLonghi'],
    'Sports': ['Nike','Adidas','Puma','Reebok','UnderArmour','NewBalance','Asics','Jordan','Mizuno','Salomon'],
    'Kids': ['LEGO','Fisher‑Price','Mattel','Hasbro','Playmobil','Barbie','HotWheels','Nerf','Cocomelon','PawPatrol'],
    'Garden': ['Husqvarna','Bosch','Black and Decker','Gardena','Makita','Stihl','Fiskars','Wolf','Karcher','Bosch']
}
FIRST_NAMES_MALE = ['James','John','Robert','Michael','William','David','Richard','Joseph','Thomas','Charles','Daniel','Matthew']
FIRST_NAMES_FEMALE = ['Mary','Patricia','Jennifer','Linda','Elizabeth','Barbara','Susan','Jessica','Sarah','Karen','Lisa','Nancy']
LAST_NAMES = ['Smith','Johnson','Williams','Brown','Jones','Garcia','Miller','Davis','Rodriguez','Martinez','Hernandez','Lopez']
GENDERS = ['Male','Female']                    # only two genders
EDUCATION = ['High School','Bachelor','Master','PhD']
MARITAL = ['Single','Married','Divorced','Widowed']
CONTACT_PREF = ['Email','SMS','Phone','Mail']
PAYMENT = ['Card','Cash','Bank Transfer','Digital Wallet','PayPal']
CHANNELS = ['Online','In‑Store','Mobile App','Phone Order']
STORE_TYPES = ['Supermarket','Hypermarket','Convenience','Department']
RETURN_REASONS = ['Defective','Wrong item','Not as described','Changed mind','Late delivery','Other']
CAT_NAMES = ['Electronics','Home','Sports','Kids','Garden']
CATEGORY_CFG = {
    'Electronics': {'price_lo':250, 'price_hi':600, 'weight_lo':0.3, 'weight_hi':3.0, 'tax_rate':0.21, 'warranty_prob':0.9, 'return_rate_base':0.03},
    'Home':        {'price_lo':80, 'price_hi':200, 'weight_lo':1.0, 'weight_hi':15.0, 'tax_rate':0.21, 'warranty_prob':0.5, 'return_rate_base':0.06},
    'Sports':      {'price_lo':40, 'price_hi':150, 'weight_lo':0.2, 'weight_hi':5.0, 'tax_rate':0.21, 'warranty_prob':0.3, 'return_rate_base':0.09},
    'Kids':        {'price_lo':15, 'price_hi':60, 'weight_lo':0.1, 'weight_hi':2.0, 'tax_rate':0.10, 'warranty_prob':0.2, 'return_rate_base':0.15},
    'Garden':      {'price_lo':30, 'price_hi':120, 'weight_lo':0.5, 'weight_hi':12.0, 'tax_rate':0.21, 'warranty_prob':0.6, 'return_rate_base':0.07},
}

# ---------------------------------------------------------------------------
# Helper functions
# ---------------------------------------------------------------------------
def clean_df(df, string_default='Unknown', int_default=0, float_default=0.0):
    for col in df.select_dtypes(include=['object']).columns:
        df[col] = df[col].fillna(string_default).replace('', string_default).astype(str)
    for col in df.select_dtypes(include=['int64','int32']).columns:
        df[col] = df[col].fillna(int_default).astype(int)
    for col in df.select_dtypes(include=['float64','float32']).columns:
        df[col] = df[col].fillna(float_default)
    return df

def check_primary_key(df, key_col, table_name):
    if df[key_col].is_unique:
        print(f"✓ {table_name}: Primary key '{key_col}' is unique.")
    else:
        dup_count = df[key_col].duplicated().sum()
        raise ValueError(f"✗ {table_name}: {dup_count} duplicate values found in '{key_col}'!")

def check_no_nulls(df, table_name):
    null_counts = df.isnull().sum()
    null_cols = null_counts[null_counts > 0]
    if null_cols.empty:
        print(f"✓ {table_name}: No NULL values.")
    else:
        raise ValueError(f"✗ {table_name}: NULLs found in columns: {null_cols.to_dict()}")

# ============================================================================
# DIMENSION: STORES (higher variance in size and revenue potential)
# ============================================================================
print("Generating dim_store with unique names and realistic spread...")
store_ids = np.arange(1, N_STORES + 1)
unique_names = set()
store_data = []
while len(unique_names) < N_STORES:
    stype = np.random.choice(STORE_TYPES)
    reg = random.choice(REGIONS)
    city = random.choice(REGION_CITY_MAP[reg])
    chain = random.choice(STORE_CHAINS[stype])
    suffix = random.choice(STORE_SUFFIXES)
    name = f"{chain} {city} {suffix}"
    if name not in unique_names:
        unique_names.add(name)
        store_data.append((name, city, stype, reg, chain, suffix))
for i in range(len(store_data), N_STORES):
    name = f"Store_{i+1}"
    store_data.append((name, "Unknown", "Supermarket", "Central", "Store", "Mart"))

store_name = [d[0] for d in store_data]
store_cities = [d[1] for d in store_data]
store_types = [d[2] for d in store_data]
store_regions = [d[3] for d in store_data]
store_chains = [d[4] for d in store_data]
store_suffixes = [d[5] for d in store_data]

# Much wider spread for store size multiplier (0.1 to 10.0)
store_size_mult = np.random.lognormal(mean=0.5, sigma=1.2, size=N_STORES).clip(0.1, 10.0)
city_rent_mult = {city: 1.0 + np.random.uniform(0.0, 1.5) for city in store_cities}   # wider rent variation
store_sizem2 = np.where(np.array(store_types) == 'Hypermarket', np.random.randint(2500, 5000, N_STORES),
                np.where(np.array(store_types) == 'Supermarket', np.random.randint(800, 2500, N_STORES),
                np.where(np.array(store_types) == 'Department', np.random.randint(1200, 3500, N_STORES),
                np.random.randint(150, 800, N_STORES))))
store_staff = np.clip((store_sizem2 / 45 + np.random.normal(0, 8, N_STORES)).astype(int), 3, 200)
store_parking = np.clip((store_sizem2 / 25 + np.random.normal(0, 15, N_STORES)).astype(int), 0, 500)
store_annualrent = (store_sizem2 * 12 * np.array([city_rent_mult.get(c, 1.0) for c in store_cities]) *
                    np.where(np.array(store_types) == 'Hypermarket', 0.8,
                    np.where(np.array(store_types) == 'Convenience', 1.4, 1.0))).round(0)
store_rating = np.clip(2.0 + (store_staff/200)*0.8 + (store_parking/500)*0.5 + np.random.uniform(0, 1.2, N_STORES), 2.0, 5.0).round(1)

store_df = pd.DataFrame({
    'storeid': store_ids,
    'storename': store_name,
    'city': store_cities,
    'type': store_types,
    'staff': store_staff,
    'sizem2': store_sizem2,
    'hascafe': np.random.choice([0, 1], N_STORES, p=[0.6, 0.4]),
    'openingyear': np.random.randint(1985, 2023, N_STORES),
    'region': store_regions,
    'renovationyear': np.random.choice([0] + list(range(2010, 2024)), N_STORES, p=[0.35] + [0.65/14]*14),
    'parkingspots': store_parking,
    'storerating': store_rating,
    'hasdeliveryservice': np.random.choice([0, 1], N_STORES, p=[0.4, 0.6]),
    'floornumber': np.random.randint(1, 6, N_STORES),
    'distancetocitycenterkm': np.random.uniform(0.5, 25.0, N_STORES).round(1),
    'annualrentcost': store_annualrent,
    'storesizemultiplier': store_size_mult
})
renov = store_df['renovationyear'].values
op = store_df['openingyear'].values
store_df['renovationyear'] = np.where((renov != 0) & (renov < op), op, renov)
store_df = clean_df(store_df)

check_primary_key(store_df, 'storeid', 'dim_store')
check_no_nulls(store_df, 'dim_store')
assert store_df['storename'].is_unique, "Duplicate store names found!"
store_df.to_csv(f"{OUTPUT_DIR}/dim_store.csv", index=False, encoding='utf-8')

# ============================================================================
# DIMENSION: PRODUCTS (margin distribution as requested)
# ============================================================================
print("Generating dim_product with specified margin distribution...")

# product name pool (unchanged)
product_pool = []
product_names_set = set()
while len(product_pool) < N_PRODUCTS * 1.5:
    cat = random.choice(CAT_NAMES)
    brand = random.choice(BRANDS[cat])
    adj = random.choice(PRODUCT_ADJECTIVES)
    noun = random.choice(PRODUCT_NAMES[cat])
    variant = np.random.choice(['','V2','X','Series 5','Mk1','2024','Ltd','Gen3'], p=[0.4,0.1,0.1,0.1,0.1,0.1,0.05,0.05])
    name = f"{brand} {adj} {noun} {variant}".strip()
    if name not in product_names_set:
        product_names_set.add(name)
        product_pool.append((name, cat, brand))
random.shuffle(product_pool)
selected_products = product_pool[:N_PRODUCTS]

product_ids = np.arange(1, N_PRODUCTS + 1)
product_name = [p[0] for p in selected_products]
product_categories = np.array([p[1] for p in selected_products])
product_brands = [p[2] for p in selected_products]
product_brand_premium = np.random.uniform(0.9, 1.5, N_PRODUCTS)

# Assign margin according to distribution
margins = np.zeros(N_PRODUCTS)
# 5% exactly 30%
margins[:int(N_PRODUCTS*0.05)] = 0.30
# 5% between 29% and 20% (uniform)
idx2 = int(N_PRODUCTS*0.05)
idx3 = int(N_PRODUCTS*0.10)
margins[idx2:idx3] = np.random.uniform(0.20, 0.29, idx3-idx2)
# 5% exactly 15%
idx4 = int(N_PRODUCTS*0.15)
margins[idx3:idx4] = 0.15
# 50% between 10% and 5%
idx5 = int(N_PRODUCTS*0.65)
margins[idx4:idx5] = np.random.uniform(0.05, 0.10, idx5-idx4)
# 30% between 5% and 0%
idx6 = int(N_PRODUCTS*0.95)
margins[idx5:idx6] = np.random.uniform(0.00, 0.05, idx6-idx5)
# remaining 5% between -10% and 0%
margins[idx6:] = np.random.uniform(-0.10, 0.00, N_PRODUCTS-idx6)
np.random.shuffle(margins)   # mix the order

# FIX: round margins to 4 decimal places to fit DECIMAL(5,4)
margins = np.round(margins, 4)

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
    margin = margins[i]
    cost = round(p_final * (1 - margin), 2)
    # ensure cost positive
    if cost <= 0:
        cost = round(p_final * 0.75, 2)
        margin = round((p_final - cost) / p_final, 4)
    product_weights.append(w)
    product_unitprice.append(p_final)
    product_unitcost.append(cost)
    product_tax_rate.append(cfg['tax_rate'])
    product_warranty.append(int(np.random.random() < cfg['warranty_prob']))
    product_ecoscore.append(int(np.random.uniform(20, 200)))
    product_material.append(np.random.choice(['Plastic','Metal','Wood','Glass','Fabric']))
    product_margin_pct.append(margin)

product_isactive = np.random.choice([0, 1], N_PRODUCTS, p=[0.05, 0.95]).astype(int)
product_stockstatus = np.where(product_isactive == 0, 'Out of Stock',
                               np.random.choice(['In Stock','Low Stock','Out of Stock'], N_PRODUCTS, p=[0.78,0.17,0.05]))
product_releaseyear = np.random.choice([2018,2019,2020,2021,2022,2023,2024,2025], N_PRODUCTS, p=[0.05,0.08,0.12,0.18,0.25,0.20,0.10,0.02])
product_skucount = np.random.poisson(2.5, N_PRODUCTS) + 1
product_isdiscontinued = np.where(product_releaseyear < 2021,
                                  np.random.choice([0,1], N_PRODUCTS, p=[0.6,0.4]),
                                  np.random.choice([0,1], N_PRODUCTS, p=[0.95,0.05])).astype(int)
product_rating = np.clip(2.0 + np.random.normal(0, 0.8, N_PRODUCTS), 1.0, 5.0).round(1)
product_isactive = np.where(product_isdiscontinued == 1, 0, product_isactive)

product_df = pd.DataFrame({
    'productid': product_ids,
    'name': product_name,
    'category': product_categories,
    'brand': product_brands,
    'unitcost': product_unitcost,
    'unitprice': product_unitprice,
    'margin_pct': product_margin_pct,   # fraction, already rounded to 4 decimal places
    'weight': product_weights,
    'color': np.random.choice(['Red','Blue','Green','Black','White','Gray','Silver','Gold'], N_PRODUCTS),
    'material': product_material,
    'supplierid': np.random.randint(1, 51, N_PRODUCTS),
    'isactive': product_isactive,
    'minstock': np.random.randint(2, 100, N_PRODUCTS),
    'tax_rate': product_tax_rate,
    'haswarranty': product_warranty,
    'ecofriendly': (np.array(product_ecoscore) > 100).astype(int),
    'seasonalityfactor': np.random.uniform(0.7, 1.3, N_PRODUCTS).round(2),
    'warrantymonths': np.where(np.array(product_warranty) == 1, np.random.choice([12,24,36], N_PRODUCTS), 0),
    'ecoscore': product_ecoscore,
    'releaseyear': product_releaseyear,
    'skucount': product_skucount,
    'isdiscontinued': product_isdiscontinued,
    'productrating': product_rating,
    'stockstatus': product_stockstatus
})
product_df = clean_df(product_df, string_default='Unknown Product')
check_primary_key(product_df, 'productid', 'dim_product')
check_no_nulls(product_df, 'dim_product')

# Quick check margin cap
max_margin = product_df['margin_pct'].max()
min_margin = product_df['margin_pct'].min()
print(f"Product margins: min={min_margin:.4f}, max={max_margin:.4f}")
if max_margin > 0.30:
    print("WARNING: Margin exceeds 30%!")
product_df.to_csv(f"{OUTPUT_DIR}/dim_product.csv", index=False, encoding='utf-8')

# ============================================================================
# DIMENSION: PROMOTIONS (discount_pct as fraction)
# ============================================================================
print("Generating dim_promotion...")
dummy_promo = pd.DataFrame([{
    'promoid': 0,
    'promoname': 'No Promotion',
    'discount_pct': 0.0,
    'discount_fixed': 0.0,
    'type': 'None',
    'isactive': 1,
    'minspend': 0,
    'channel': 'All',
    'budget': 0,
    'startdate': START_DATE.strftime('%Y-%m-%d'),
    'enddate': END_DATE.strftime('%Y-%m-%d'),
    'targetaudience': 'All',
    'maxdiscountcap': 0,
    'isstackable': 0,
    'redemption_rate': 0,
    'coderequired': 0,
    'promoupliftfactor': 1.0
}])

promo_ids = np.arange(1, N_PROMOTIONS + 1)
promo_types = np.random.choice(['Percentage','Fixed Amount','BOGO','Free Shipping'], N_PROMOTIONS, p=[0.35,0.25,0.25,0.15])
promo_channels = np.where(promo_types == 'Free Shipping', 'Online', np.random.choice(['Email','SMS','App','InStore','All'], N_PROMOTIONS))
# discount_pct as fraction (0.10–0.45)
promo_discount_pct = np.where(promo_types == 'Percentage', np.random.uniform(0.10,0.45,N_PROMOTIONS).round(4), 0.0)
promo_discount_fixed = np.where(promo_types == 'Fixed Amount', np.random.uniform(3,30,N_PROMOTIONS).round(2), 0.0)

promo_budgets = (np.where(promo_types == 'Percentage', promo_discount_pct, promo_discount_fixed/100) * N_SALES * 0.002 * np.random.uniform(0.8,1.5,N_PROMOTIONS)).round(0)

promo_uplift = np.zeros(N_PROMOTIONS)
for i, pt in enumerate(promo_types):
    if pt == 'BOGO': promo_uplift[i] = np.random.uniform(1.8,2.2)
    elif pt == 'Percentage': promo_uplift[i] = np.random.uniform(1.2,1.4)
    elif pt == 'Fixed Amount': promo_uplift[i] = np.random.uniform(1.05,1.15)
    else: promo_uplift[i] = np.random.uniform(1.0,1.02)

max_days = (END_DATE - START_DATE).days
promo_start = (START_DATE + pd.to_timedelta(np.random.randint(0, min(900,max_days), N_PROMOTIONS), unit='D')).to_pydatetime()
promo_end = (START_DATE + pd.to_timedelta(np.random.randint(15, min(950,max_days), N_PROMOTIONS), unit='D')).to_pydatetime()
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
        disc = int(promo_discount_pct[i]*100)
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
    'discount_pct': promo_discount_pct,
    'discount_fixed': promo_discount_fixed,
    'type': promo_types,
    'isactive': promo_isactive,
    'minspend': np.random.choice([0,10,25,50,100], N_PROMOTIONS, p=[0.25,0.30,0.20,0.15,0.10]),
    'channel': promo_channels,
    'budget': promo_budgets,
    'startdate': promo_start_str,
    'enddate': promo_end_str,
    'targetaudience': np.random.choice(['All','New','Loyal','HighSpend'], N_PROMOTIONS, p=[0.40,0.15,0.25,0.20]),
    'maxdiscountcap': np.random.uniform(5,120,N_PROMOTIONS).round(2),
    'isstackable': np.random.choice([0,1], N_PROMOTIONS, p=[0.85,0.15]),
    'redemption_rate': np.random.uniform(0.02,0.35,N_PROMOTIONS).round(3),
    'coderequired': np.random.choice([0,1], N_PROMOTIONS, p=[0.60,0.40]),
    'promoupliftfactor': promo_uplift.round(3)
})
promo_df = pd.concat([dummy_promo, promo_df], ignore_index=True)
promo_df = clean_df(promo_df)
check_primary_key(promo_df, 'promoid', 'dim_promotion')
check_no_nulls(promo_df, 'dim_promotion')
promo_df.to_csv(f"{OUTPUT_DIR}/dim_promotion.csv", index=False, encoding='utf-8')

# ============================================================================
# DIMENSION: CUSTOMERS (higher variance in income and spend)
# ============================================================================
print("Generating dim_customer with realistic income spread...")
customer_ids = np.arange(1, N_CUSTOMERS + 1)
gender_choice = np.random.choice(['Male','Female'], N_CUSTOMERS, p=[0.5,0.5])
first_names = np.where(gender_choice == 'Male',
                       np.random.choice(FIRST_NAMES_MALE, N_CUSTOMERS),
                       np.random.choice(FIRST_NAMES_FEMALE, N_CUSTOMERS))
last_names = np.random.choice(LAST_NAMES, N_CUSTOMERS)

temp_names = pd.DataFrame({'first': first_names, 'last': last_names})
temp_names['occurrence'] = temp_names.groupby(['first','last']).cumcount()
temp_names['is_dup'] = temp_names.groupby(['first','last']).transform('size') > 1
suffix_num = np.where(temp_names['is_dup'] & (temp_names['occurrence'] > 0), temp_names['occurrence'], 0)
suffix_str = np.where(suffix_num > 0, ' ' + suffix_num.astype(str), '')
email_suffix_str = np.where(suffix_num > 0, suffix_num.astype(str), '')

fullname = temp_names['first'] + ' ' + temp_names['last'] + suffix_str
email_local = (temp_names['first'].str.lower() + '.' + temp_names['last'].str.lower() + email_suffix_str) \
                .str.replace(' ', '.').str.replace('[^a-z0-9.]', '', regex=True)
email = email_local + '@example.com'

age_range = np.arange(18, 75)
age_probs = np.where(age_range < 25, 0.02, np.where(age_range < 40, 0.035, np.where(age_range < 60, 0.025, 0.015)))
age_probs /= age_probs.sum()
customer_age = np.random.choice(age_range, N_CUSTOMERS, p=age_probs)

# Income – use a mixture of two lognormals for a more realistic spread
low_income = np.random.lognormal(mean=9.5, sigma=0.8, size=N_CUSTOMERS//2).clip(5000, 60000)
high_income = np.random.lognormal(mean=10.5, sigma=0.6, size=N_CUSTOMERS - N_CUSTOMERS//2).clip(30000, 200000)
customer_income = np.concatenate([low_income, high_income])
np.random.shuffle(customer_income)
customer_income = customer_income[:N_CUSTOMERS]

customer_tier = np.where(customer_income > 80000, 'Platinum',
                np.where(customer_income > 50000, 'Gold',
                np.where(customer_income > 30000, 'Silver', 'Bronze')))
customer_spend_mult = np.where(customer_tier == 'Platinum', np.random.uniform(3.0,8.0,N_CUSTOMERS),
                        np.where(customer_tier == 'Gold', np.random.uniform(1.8,3.5,N_CUSTOMERS),
                        np.where(customer_tier == 'Silver', np.random.uniform(0.8,1.8,N_CUSTOMERS), np.random.uniform(0.2,0.8,N_CUSTOMERS))))
customer_points = np.clip((customer_spend_mult * 45 + np.random.poisson(20,N_CUSTOMERS)).astype(int), 0, 1200)
regdate_days = np.random.exponential(600, N_CUSTOMERS).astype(int)
max_days_date = (END_DATE - START_DATE).days
regdate_days_clipped = np.minimum(regdate_days, max_days_date)
customer_regdate = [(START_DATE + timedelta(days=int(d))).strftime('%Y-%m-%d') for d in regdate_days_clipped]
customer_totalSpend = (customer_spend_mult * np.random.exponential(250,N_CUSTOMERS)).round(2)
customer_satisfactionscore = np.clip(2.5 + (customer_tier == 'Platinum')*1.0 + (customer_tier == 'Gold')*0.6 + np.random.normal(0,0.8,N_CUSTOMERS), 1.0,5.0).round(1)
customer_dayssincelast = np.where(customer_tier == 'Platinum', np.random.exponential(5,N_CUSTOMERS),
                           np.where(customer_tier == 'Gold', np.random.exponential(12,N_CUSTOMERS),
                           np.random.exponential(35,N_CUSTOMERS))).astype(int)
customer_hassubscription = np.random.choice([0,1], N_CUSTOMERS, p=[0.65,0.35])
customer_childrencount = np.random.poisson(np.where(customer_age < 30, 0.3, np.where(customer_age < 45, 0.9, 0.4)), N_CUSTOMERS).astype(int)

contact_probs = np.zeros((N_CUSTOMERS, 4))
contact_probs[:,0] = np.where(customer_age < 35, 0.6, 0.3)
contact_probs[:,1] = np.where(customer_age < 30, 0.25, 0.4)
contact_probs[:,2] = np.where(customer_age > 50, 0.35, 0.15)
contact_probs[:,3] = 1.0 - contact_probs.sum(axis=1)
contact_probs = np.maximum(contact_probs, 0.05)
contact_probs = contact_probs / contact_probs.sum(axis=1, keepdims=True)
customer_contact = np.array([np.random.choice(CONTACT_PREF, p=p) for p in contact_probs])

all_cities = sum(REGION_CITY_MAP.values(), [])
customer_cities = np.random.choice(all_cities, N_CUSTOMERS)

customer_df = pd.DataFrame({
    'customerid': customer_ids,
    'fullname': fullname.values,
    'email': email.values,
    'age': customer_age,
    'gender': gender_choice,
    'city': customer_cities,
    'tier': customer_tier,
    'points': customer_points,
    'isactive': np.random.choice([0,1], N_CUSTOMERS, p=[0.06,0.94]),
    'lang': np.random.choice(['en','de','fr','es','pl','it'], N_CUSTOMERS, p=[0.35,0.20,0.15,0.15,0.10,0.05]),
    'totalspend': customer_totalSpend,
    'regdate': customer_regdate,
    'annualincome': customer_income.round(2),
    'incomebracket': pd.cut(customer_income, bins=[0,25000,50000,75000,100000,1e9], labels=['Low','Medium','High','Very High','Ultra High']).astype(str),
    'education': np.random.choice(EDUCATION, N_CUSTOMERS, p=[0.30,0.40,0.25,0.05]),
    'maritalstatus': np.random.choice(MARITAL, N_CUSTOMERS),
    'childrencount': customer_childrencount,
    'loyaltysegment': customer_tier,
    'satisfactionscore': customer_satisfactionscore,
    'dayssincelastpurchase': customer_dayssincelast,
    'hassubscription': customer_hassubscription,
    'preferredcontact': customer_contact,
    'spendmultiplier': customer_spend_mult.round(3)
})
customer_df = clean_df(customer_df)
check_primary_key(customer_df, 'customerid', 'dim_customer')
check_no_nulls(customer_df, 'dim_customer')
customer_df.to_csv(f"{OUTPUT_DIR}/dim_customer.csv", index=False, encoding='utf-8')

# ============================================================================
# DIMENSION: DATE
# ============================================================================
print("Generating dim_date...")
dates = pd.date_range(START_DATE, END_DATE, freq='D')
isholiday_arr = np.isin(dates.month, [12,1]) | (dates.month == 7)
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
    'isholiday': isholiday_arr.astype(int)
})
date_df = clean_df(date_df)
check_primary_key(date_df, 'datekey', 'dim_date')
check_no_nulls(date_df, 'dim_date')
date_df.to_csv(f"{OUTPUT_DIR}/dim_date.csv", index=False, encoding='utf-8')
print("All dimension files exported successfully ✓")

# ============================================================================
# TREND: DECLINE → FLAT → STRONG RISE AT THE END (unchanged)
# ============================================================================
print("Generating trend: decline (60k→50k) then flat, then strong rise to 95k at end...")
n_dates = len(dates)
decline_end = int(n_dates * 0.5)
flat_end = int(n_dates * 0.7)

start_val, decline_val, flat_val, rise_start, final_peak = 60000, 50000, 50000, 50000, 95000

trend = np.zeros(n_dates)
trend[:decline_end] = np.linspace(start_val, decline_val, decline_end)
trend[decline_end:flat_end] = flat_val
trend[flat_end:] = np.linspace(rise_start, final_peak, n_dates - flat_end)

window = 7
ma = np.convolve(trend, np.ones(window)/window, mode='same')
ma[:window//2] = trend[:window//2]
ma[-window//2:] = trend[-window//2:]
smooth_trend = ma

drift_rates = np.zeros(n_dates)
for i in range(1, n_dates):
    if smooth_trend[i-1] != 0:
        drift_rates[i] = (smooth_trend[i] - smooth_trend[i-1]) / smooth_trend[i-1]

volatility = 0.02
noise = np.random.normal(0, 1, n_dates)
smoothed_noise = np.convolve(noise, np.ones(3)/3, mode='same')
final_values = np.zeros(n_dates)
final_values[0] = smooth_trend[0]
for i in range(1, n_dates):
    daily_change = drift_rates[i] + volatility * smoothed_noise[i]
    final_values[i] = final_values[i-1] * (1 + daily_change)

daily_net_sales_target = np.maximum(np.round(final_values).astype(int), 1000)
print(f"Trend: start={daily_net_sales_target[0]}, min={daily_net_sales_target.min()}, end={daily_net_sales_target[-1]}")

# ============================================================================
# FACT SALES GENERATION (10M rows, quantity scaling, no NULLs)
# ============================================================================
print(f"\nGenerating fact_sales ({N_SALES:,} rows) in chunks...")
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
product_unitcost_arr = product_df['unitcost'].values

# Weights for probabilistic selection
cust_weights = customer_spend_mult_arr * np.where(customer_tier_arr == 'Platinum', 3.0,
                                           np.where(customer_tier_arr == 'Gold', 1.8,
                                           np.where(customer_tier_arr == 'Silver', 1.0, 0.5)))
cust_weights /= cust_weights.sum()
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
        if to_remove == 0: break
        if daily_n_trans[i] > 0:
            daily_n_trans[i] -= 1
            to_remove -= 1
    if to_remove > 0 and daily_n_trans[0] > to_remove:
        daily_n_trans[0] -= to_remove
    elif to_remove > 0:
        daily_n_trans[0] = 0
daily_n_trans = np.maximum(daily_n_trans, 0)

def generate_hours_vectorized(channels, store_types=None):
    n = len(channels)
    hours = np.zeros(n, dtype=np.uint8)
    online_probs = np.array([0.01,0.01,0.01,0.01,0.01,0.01,0.02,0.03,0.04,0.05,0.05,0.05,0.05,0.05,0.06,0.07,0.08,0.09,0.09,0.07,0.05,0.03,0.02,0.01])
    online_probs /= online_probs.sum()
    mobile_probs = np.array([0.01,0.01,0.01,0.01,0.02,0.03,0.05,0.06,0.07,0.08,0.08,0.07,0.07,0.06,0.06,0.06,0.05,0.04,0.03,0.02,0.02,0.01,0.01,0.01])
    mobile_probs /= mobile_probs.sum()
    phone_probs = np.zeros(24)
    phone_probs[9:21] = 1/12
    phone_probs /= phone_probs.sum()
    instore_default_probs = np.zeros(24)
    instore_default_probs[8:21] = 1/13
    instore_default_probs /= instore_default_probs.sum()
    instore_broad_probs = np.zeros(24)
    instore_broad_probs[6:23] = 1/17
    instore_broad_probs /= instore_broad_probs.sum()

    mask_online = (channels == 'Online')
    if mask_online.any():
        hours[mask_online] = np.random.choice(24, size=mask_online.sum(), p=online_probs)
    mask_mobile = (channels == 'Mobile App')
    if mask_mobile.any():
        hours[mask_mobile] = np.random.choice(24, size=mask_mobile.sum(), p=mobile_probs)
    mask_phone = (channels == 'Phone Order')
    if mask_phone.any():
        hours[mask_phone] = np.random.choice(24, size=mask_phone.sum(), p=phone_probs)
    mask_instore = (channels == 'In-Store')
    if mask_instore.any():
        if store_types is not None:
            broad_mask = np.isin(store_types[mask_instore], ['Convenience', 'Hypermarket'])
            broad_idx = np.where(mask_instore)[0][broad_mask]
            if len(broad_idx) > 0:
                hours[broad_idx] = np.random.choice(24, size=len(broad_idx), p=instore_broad_probs)
            default_idx = np.where(mask_instore)[0][~broad_mask]
            if len(default_idx) > 0:
                hours[default_idx] = np.random.choice(24, size=len(default_idx), p=instore_default_probs)
        else:
            hours[mask_instore] = np.random.choice(24, size=mask_instore.sum(), p=instore_default_probs)
    return np.clip(hours, 0, 23).astype(np.uint8)

# Write CSV in chunks
f_path = f"{OUTPUT_DIR}/fact_sales.csv"
if os.path.exists(f_path):
    os.remove(f_path)

pd.DataFrame(columns=['salesid','datekey','productid','customerid','storeid','promoid',
                      'qty','unitprice','tax_rate','net','payment','channel',
                      'grossvalue','discountamount','taxamount','shipcost','isreturn',
                      'shipweight','discountapplied','returnreason','deliverydays','hour']
            ).to_csv(f_path, index=False)

store_type_map = store_df.set_index('storeid')['type'].to_dict()
current_buffer = []
sales_id = 1

for day_idx in range(n_dates):
    target = daily_net_sales_target[day_idx]
    n_tr = daily_n_trans[day_idx]
    if n_tr == 0:
        continue
    datekey = datekeys[day_idx]

    prod_choices = np.random.choice(product_ids_arr, n_tr)
    cust_choices = np.random.choice(customer_ids_arr, n_tr, p=cust_weights)
    store_choices = np.random.choice(store_ids_arr, n_tr, p=store_weights)
    promo_has = np.random.choice([0, 1], n_tr, p=[0.65, 0.35])
    promo_choices = np.where(promo_has == 1, np.random.choice(promo_ids_arr, n_tr, p=promo_weights), 0)

    daily_price_mult = 1.0 + 0.02 * np.sin(2 * np.pi * day_idx / 365)
    unit_prices = product_unitprice_arr[prod_choices - 1] * daily_price_mult
    tax_rates = product_tax_rate_arr[prod_choices - 1]
    weights = product_weight_arr[prod_choices - 1]
    unit_costs = product_unitcost_arr[prod_choices - 1]

    raw_qty = np.random.poisson(2, n_tr) + 1
    disc_factor = np.random.uniform(0, 0.3, n_tr)

    gross_temp = raw_qty * unit_prices
    net_temp = gross_temp * (1 - disc_factor) + (gross_temp * (1 - disc_factor) * tax_rates)
    total_net = net_temp.sum()
    if total_net > 0:
        scale_factor = target / total_net
    else:
        scale_factor = 1.0

    scaled_qty = np.maximum(np.round(raw_qty * scale_factor).astype(int), 1)

    gross = scaled_qty * unit_prices
    net_before_tax = gross * (1 - disc_factor)
    tax = net_before_tax * tax_rates
    net_sales = net_before_tax + tax
    disc_amount = gross - net_before_tax

    disc_amount_rounded = disc_amount.round(2)
    discountapplied = (disc_amount_rounded != 0).astype(int)

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
    is_return = (np.random.random(n_tr) < return_prob).astype(int)

    shipcost = np.where(is_online, (weights * scaled_qty * 0.5).round(2), 0.0)
    return_reason_arr = np.full(n_tr, "No return", dtype=object)
    mask_ret = is_return == 1
    if mask_ret.any():
        return_reason_arr[mask_ret] = np.random.choice(RETURN_REASONS, mask_ret.sum())

    gross = np.where(is_return == 1, -gross, gross)
    net_sales = np.where(is_return == 1, -net_sales, net_sales)
    disc_amount_rounded = np.where(is_return == 1, -disc_amount_rounded, disc_amount_rounded)
    tax = np.where(is_return == 1, -tax, tax)
    shipcost = np.where(is_return == 1, 0.0, shipcost)

    store_types_for_rows = np.array([store_type_map.get(s, 'Supermarket') for s in store_choices])
    hour_arr = generate_hours_vectorized(channel, store_types_for_rows)

    batch_df = pd.DataFrame({
        'salesid': np.arange(sales_id, sales_id + n_tr),
        'datekey': datekey,
        'productid': prod_choices,
        'customerid': cust_choices,
        'storeid': store_choices,
        'promoid': promo_choices,
        'qty': scaled_qty,
        'unitprice': unit_prices.round(2),
        'tax_rate': tax_rates,
        'net': net_sales.round(2),
        'payment': payment,
        'channel': channel,
        'grossvalue': gross.round(2),
        'discountamount': disc_amount_rounded,
        'taxamount': tax.round(2),
        'shipcost': shipcost,
        'isreturn': is_return,
        'shipweight': (weights * scaled_qty).round(2),
        'discountapplied': discountapplied,
        'returnreason': return_reason_arr,
        'deliverydays': delivery_days,
        'hour': hour_arr
    })
    current_buffer.append(batch_df)
    sales_id += n_tr
    if sum(len(df) for df in current_buffer) >= CHUNK_SIZE:
        pd.concat(current_buffer).to_csv(f_path, mode='a', header=False, index=False)
        current_buffer.clear()
        print(f"Progress: {sales_id-1:,} / {N_SALES:,} rows generated...")

if current_buffer:
    pd.concat(current_buffer).to_csv(f_path, mode='a', header=False, index=False)

print("\nFact table generation completed.")

# ============================================================================
# FINAL DATA QUALITY CHECKS
# ============================================================================
print("\nRunning final data quality checks...")
df_check = pd.read_csv(f_path, nrows=5000)
assert df_check['promoid'].isna().sum() == 0
assert df_check['returnreason'].isna().sum() == 0
assert df_check['hour'].isna().sum() == 0
instore_check = df_check[df_check['channel'] == 'In-Store']
if not instore_check.empty:
    assert (instore_check['deliverydays'] == 0).all(), "In-Store deliverydays not zero!"
print("✓ Sample fact table: No NULLs, In-Store deliverydays=0.")

def check_fact_references(fact_path, dim_set, fact_col, dim_name):
    missing = set()
    chunk_iter = pd.read_csv(fact_path, chunksize=500000, usecols=[fact_col])
    for chunk in chunk_iter:
        fact_vals = set(chunk[fact_col].unique())
        missing.update(fact_vals - dim_set)
        if missing:
            break
    if missing:
        print(f"⚠ {dim_name}: Missing foreign keys {list(missing)[:10]}...")
    else:
        print(f"✓ {dim_name}: All {fact_col} values reference existing dimension keys.")

check_fact_references(f_path, set(product_df['productid']), 'productid', 'dim_product')
check_fact_references(f_path, set(customer_df['customerid']), 'customerid', 'dim_customer')
check_fact_references(f_path, set(store_df['storeid']), 'storeid', 'dim_store')
check_fact_references(f_path, set(promo_df['promoid']), 'promoid', 'dim_promotion')

total_rows = sum(1 for _ in open(f_path)) - 1
assert total_rows == N_SALES, f"Row count mismatch: expected {N_SALES}, got {total_rows}"
print(f"✓ Fact table contains exactly {N_SALES:,} rows.")
print("\n✅ All data quality checks passed.")
print(f"\nAll files created. Data range: {START_DATE.date()} to {END_DATE.date()}")
print(f"Script finished at {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
# ============================================================================
# End of final_retail_gen.py
# ============================================================================