# ============================================================================
# generate_retail_data.py
# ============================================================================
# Author:       DataGen AI & Assistant
# Created:      2026-05-23
# Last modified: 2026-05-26 09:20:00 UTC
# Description:  Generates a complete synthetic retail dataset consisting of
#               5 dimension tables (date, customer, product, store, promotion)
#               and 1 fact table (10 million sales transactions).
#               - Added unknown (-1) dummy rows to all dimension tables.
#               - Optimized referential integrity checks to run in a single pass.
#               - Formatted floating-point decimals to avoid bulk-load issues.
#               - Vectorized mapping lookups inside the generation loop.
#               - Configured to output into the local project folder (csv/).
# ============================================================================

import numpy as np
import pandas as pd
from datetime import datetime, timedelta
import os
import random
import csv

# ============================================================================
# 1. CONFIGURATION
#    All tunable parameters (paths, record counts, random seed, chunk size).
# ============================================================================
# Automatically determine the project directory structure using relative paths
SCRIPT_DIR    = os.path.dirname(os.path.abspath(__file__))
PROJECT_DIR   = os.path.dirname(SCRIPT_DIR)
OUTPUT_DIR    = os.path.join(PROJECT_DIR, "csv") # Outputs directly to the project's csv folder

N_SALES       = 10_000_000               # Target number of fact table rows
N_CUSTOMERS   = 200_000                  # Unique customers
N_PRODUCTS    = 2_000                    # Unique products
N_STORES      = 200                      # Unique stores
N_PROMOTIONS  = 100                      # Promotions (excluding dummy promoid=0)
RANDOM_SEED   = 42                       # Fixed seed for reproducibility
CHUNK_SIZE    = 200_000                  # Rows per CSV write‑chunk (memory control)

# Initialise random generators
if RANDOM_SEED is not None:
    np.random.seed(RANDOM_SEED)
    random.seed(RANDOM_SEED)

# Ensure output directory exists
os.makedirs(OUTPUT_DIR, exist_ok=True)

# Date boundaries for the entire dataset
START_DATE = datetime(2023, 1, 1)
END_DATE   = datetime.now().replace(hour=0, minute=0, second=0, microsecond=0)
print(f"Generating data from {START_DATE.date()} to {END_DATE.date()}")

# ============================================================================
# 2. STATIC REFERENCE DATA
#    Dictionaries and lists used to build realistic‑looking attribute values.
# ============================================================================

STORE_CHAINS = {
    'Supermarket' : ['FreshMart','CityFood','DailyGrocer','MarketPlace','ValueSave','GoodMart'],
    'Hypermarket' : ['MegaMart','SuperSaver','GlobalHyper','BigBox','GiantStore','PriceCutter'],
    'Convenience' : ['QuickStop','CornerShop','EasyBuy','OnTheRun','MiniMarket','FastShop'],
    'Department'  : ['CityCenter','TheGalleria','TownSquare','UrbanMall','GrandPlaza','MetroStore']
}
STORE_SUFFIXES = ['Center','Plaza','Market','Point','Hub','Square','Mart']

REGION_CITY_MAP = {
    'North'   : ['New York','Chicago','Boston','Seattle','Detroit','Minneapolis','Buffalo','Pittsburgh'],
    'South'   : ['Houston','Dallas','Miami','Atlanta','Austin','Nashville','Orlando','San Antonio'],
    'East'    : ['Philadelphia','Baltimore','Charlotte','Jacksonville','Washington DC','Tampa','Richmond'],
    'West'    : ['Los Angeles','San Francisco','Phoenix','San Diego','Portland','Las Vegas','Sacramento'],
    'Central' : ['Kansas City','St. Louis','Omaha','Denver','Cleveland','Columbus','Indianapolis','Milwaukee']
}
REGIONS = list(REGION_CITY_MAP.keys())

PROMO_TEMPLATES = {
    'Percentage'    : ['Spring Sale','Summer Deal','Winter Discount','Flash Sale','Clearance','Happy Hour','Member Special'],
    'Fixed Amount'  : ['Cashback','Save $','Discount Voucher','Price Drop','Instant Save','Coupon Special'],
    'BOGO'          : ['Buy 1 Get 1 Free','2 for 1','3 for 2','Multi‑buy','Double Up'],
    'Free Shipping' : ['Free Delivery','No Shipping Fee','Shipping included','Free Post']
}

PRODUCT_NAMES = {
    'Electronics': ['Smartphone','Laptop','Headphones','Smartwatch','Tablet','Monitor','Speaker','Camera','Console','Router'],
    'Home'       : ['Desk','Chair','Lamp','Sofa','Table','Bed','Cabinet','Vacuum','Blender','Toaster'],
    'Sports'     : ['Shoes','Tshirt','Backpack','Bike','Ball','Racket','Dumbbells','Mat','Gloves','Helmet'],
    'Kids'       : ['Doll','Action Figure','Puzzle','Blocks','Board Game','Plushie','Lego Set','Cart','Book','Costume'],
    'Garden'     : ['Lawn Mower','Hedge Trimmer','Hose','Shovel','Rake','Faucet','Seeds','Pot','Fertilizer','Gnome']
}
PRODUCT_ADJECTIVES = ['Pro','Plus','Max','Lite','Ultra','Mini','Elite','Core','Prime','Select','Air','Studio']

BRANDS = {
    'Electronics': ['Sony','Samsung','Apple','Philips','LG','Dell','HP','Asus','Bose','Logitech'],
    'Home'       : ['IKEA','Tefal','Bosch','Electrolux','Dyson','Nespresso','Kenwood','Braun','Rowenta','DeLonghi'],
    'Sports'     : ['Nike','Adidas','Puma','Reebok','UnderArmour','NewBalance','Asics','Jordan','Mizuno','Salomon'],
    'Kids'       : ['LEGO','Fisher‑Price','Mattel','Hasbro','Playmobil','Barbie','HotWheels','Nerf','Cocomelon','PawPatrol'],
    'Garden'     : ['Husqvarna','Bosch','Black and Decker','Gardena','Makita','Stihl','Fiskars','Wolf','Karcher','Bosch']
}

FIRST_NAMES_MALE   = ['James','John','Robert','Michael','William','David','Richard','Joseph','Thomas','Charles','Daniel','Matthew']
FIRST_NAMES_FEMALE = ['Mary','Patricia','Jennifer','Linda','Elizabeth','Barbara','Susan','Jessica','Sarah','Karen','Lisa','Nancy']
LAST_NAMES         = ['Smith','Johnson','Douglas','Williams','Brown','Jones','Garcia','Miller','Davis','Rodriguez','Martinez','Hernandez','Lopez']

GENDERS      = ['Male','Female']
EDUCATION    = ['High School','Bachelor','Master','PhD']
MARITAL      = ['Single','Married','Divorced','Widowed']
CONTACT_PREF = ['Email','SMS','Phone','Mail']
PAYMENT      = ['Card','Cash','Bank Transfer','Digital Wallet','PayPal']
CHANNELS     = ['Online','In‑Store','Mobile App','Phone Order']
STORE_TYPES  = ['Supermarket','Hypermarket','Convenience','Department']
RETURN_REASONS = ['Defective','Wrong item','Not as described','Changed mind','Late delivery','Other']
CAT_NAMES    = ['Electronics','Home','Sports','Kids','Garden']

CATEGORY_CFG = {
    'Electronics': {'price_lo':250, 'price_hi':600, 'weight_lo':0.3, 'weight_hi':3.0, 'tax_rate':0.21, 'warranty_prob':0.9, 'return_rate_base':0.03},
    'Home':        {'price_lo':80,  'price_hi':200, 'weight_lo':1.0, 'weight_hi':15.0,'tax_rate':0.21, 'warranty_prob':0.5, 'return_rate_base':0.06},
    'Sports':      {'price_lo':40,  'price_hi':150, 'weight_lo':0.2, 'weight_hi':5.0, 'tax_rate':0.21, 'warranty_prob':0.3, 'return_rate_base':0.09},
    'Kids':        {'price_lo':15,  'price_hi':60,  'weight_lo':0.1, 'weight_hi':2.0, 'tax_rate':0.10, 'warranty_prob':0.2, 'return_rate_base':0.15},
    'Garden':      {'price_lo':30,  'price_hi':120, 'weight_lo':0.5, 'weight_hi':12.0,'tax_rate':0.21, 'warranty_prob':0.6, 'return_rate_base':0.07},
}

# ---------------------------------------------------------------------------
# 3. HELPER FUNCTIONS
#    Small utility routines used throughout the script.
# ---------------------------------------------------------------------------

def clean_df(df, string_default='Unknown', int_default=0, float_default=0.0):
    """
    Replace any remaining NULL / empty values with sensible defaults.
    Ensures Power BI compatibility – every field is non‑null.
    """
    for col in df.select_dtypes(include=['object']).columns:
        df[col] = df[col].fillna(string_default).replace('', string_default).astype(str)
    for col in df.select_dtypes(include=['int64','int32']).columns:
        df[col] = df[col].fillna(int_default).astype(int)
    for col in df.select_dtypes(include=['float64','float32']).columns:
        df[col] = df[col].fillna(float_default)
    return df


def check_primary_key(df, key_col, table_name):
    """Raise an error if the primary key column is not unique."""
    if df[key_col].is_unique:
        print(f"✓ {table_name}: Primary key '{key_col}' is unique.")
    else:
        dup_count = df[key_col].duplicated().sum()
        raise ValueError(f"✗ {table_name}: {dup_count} duplicate values found in '{key_col}'!")


def check_no_nulls(df, table_name):
    """Raise an error if any column contains NULL values."""
    null_counts = df.isnull().sum()
    null_cols = null_counts[null_counts > 0]
    if null_cols.empty:
        print(f"✓ {table_name}: No NULL values.")
    else:
        raise ValueError(f"✗ {table_name}: NULLs found in columns: {null_cols.to_dict()}")


def check_all_referential_integrity(fact_path, prod_set, cust_set, store_set, promo_set):
    """
    Verify referential integrity across all dimension keys in a single, efficient pass.
    This replaces multiple file reads with one chunked pass over the 10M-row CSV.
    """
    print("Running single-pass referential integrity check on the entire fact table...")
    missing_prods = set()
    missing_custs = set()
    missing_stores = set()
    missing_promos = set()
    
    chunk_iter = pd.read_csv(fact_path, chunksize=1000000, usecols=['productid', 'customerid', 'storeid', 'promoid'])
    
    for chunk in chunk_iter:
        missing_prods.update(set(chunk['productid'].unique()) - prod_set)
        missing_custs.update(set(chunk['customerid'].unique()) - cust_set)
        missing_stores.update(set(chunk['storeid'].unique()) - store_set)
        missing_promos.update(set(chunk['promoid'].unique()) - promo_set)

    # Report results
    if missing_prods: print(f"✗ Referential Integrity Fail: Missing products in dim: {list(missing_prods)[:10]}")
    else: print("✓ Referential Integrity: All sales 'productid' values exist in dim_product.")
    
    if missing_custs: print(f"✗ Referential Integrity Fail: Missing customers in dim: {list(missing_custs)[:10]}")
    else: print("✓ Referential Integrity: All sales 'customerid' values exist in dim_customer.")
    
    if missing_stores: print(f"✗ Referential Integrity Fail: Missing stores in dim: {list(missing_stores)[:10]}")
    else: print("✓ Referential Integrity: All sales 'storeid' values exist in dim_store.")
    
    if missing_promos: print(f"✗ Referential Integrity Fail: Missing promotions in dim: {list(missing_promos)[:10]}")
    else: print("✓ Referential Integrity: All sales 'promoid' values exist in dim_promotion.")
    
    if missing_prods or missing_custs or missing_stores or missing_promos:
        raise ValueError("Referential integrity check failed for one or more foreign keys!")


def generate_hours_vectorized(channels, store_types=None):
    """
    Assign a realistic hour (0‑23) based on the sales channel.
    Uses pre‑defined probability distributions for each channel.
    Convenience / Hypermarket stores may open slightly longer hours.
    """
    n = len(channels)
    hours = np.zeros(n, dtype=np.uint8)

    online_probs = np.array([
        0.01,0.01,0.01,0.01,0.01,0.01,0.02,0.03,0.04,0.05,0.05,0.05,
        0.05,0.05,0.06,0.07,0.08,0.09,0.09,0.07,0.05,0.03,0.02,0.01
    ])
    online_probs /= online_probs.sum()

    mobile_probs = np.array([
        0.01,0.01,0.01,0.01,0.02,0.03,0.05,0.06,0.07,0.08,0.08,0.07,
        0.07,0.06,0.06,0.06,0.05,0.04,0.03,0.02,0.02,0.01,0.01,0.01
    ])
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

    mask_online  = (channels == 'Online')
    mask_mobile  = (channels == 'Mobile App')
    mask_phone   = (channels == 'Phone Order')
    mask_instore = (channels == 'In-Store')

    if mask_online.any():
        hours[mask_online]  = np.random.choice(24, size=mask_online.sum(),  p=online_probs)
    if mask_mobile.any():
        hours[mask_mobile]  = np.random.choice(24, size=mask_mobile.sum(),  p=mobile_probs)
    if mask_phone.any():
        hours[mask_phone]   = np.random.choice(24, size=mask_phone.sum(),   p=phone_probs)
    if mask_instore.any():
        if store_types is not None:
            broad_mask   = np.isin(store_types[mask_instore], ['Convenience','Hypermarket'])
            broad_idx    = np.where(mask_instore)[0][broad_mask]
            default_idx  = np.where(mask_instore)[0][~broad_mask]
            if len(broad_idx) > 0:
                hours[broad_idx]   = np.random.choice(24, size=len(broad_idx),   p=instore_broad_probs)
            if len(default_idx) > 0:
                hours[default_idx] = np.random.choice(24, size=len(default_idx), p=instore_default_probs)
        else:
            hours[mask_instore] = np.random.choice(24, size=mask_instore.sum(), p=instore_default_probs)

    return np.clip(hours, 0, 23).astype(np.uint8)


# ============================================================================
# 4. DIMENSION TABLE GENERATION
#    Each dimension is built sequentially, validated, and exported as CSV.
# ============================================================================

# ---------------------------------------------------------------------------
# 4.1 DIM_STORE – 200 unique stores + dummy row
# ---------------------------------------------------------------------------
print("Generating dim_store with unique names and realistic spread...")
store_ids = np.arange(1, N_STORES + 1)
unique_names = set()
store_data = []

while len(unique_names) < N_STORES:
    stype  = np.random.choice(STORE_TYPES)
    reg    = random.choice(REGIONS)
    city   = random.choice(REGION_CITY_MAP[reg])
    chain  = random.choice(STORE_CHAINS[stype])
    suffix = random.choice(STORE_SUFFIXES)
    name   = f"{chain} {city} {suffix}"
    if name not in unique_names:
        unique_names.add(name)
        store_data.append((name, city, stype, reg, chain, suffix))

for i in range(len(store_data), N_STORES):
    name = f"Store_{i+1}"
    store_data.append((name, "Unknown", "Supermarket", "Central", "Store", "Mart"))

store_name     = [d[0] for d in store_data]
store_cities   = [d[1] for d in store_data]
store_types    = [d[2] for d in store_data]
store_regions  = [d[3] for d in store_data]
store_chains   = [d[4] for d in store_data]
store_suffixes = [d[5] for d in store_data]

store_size_mult = np.random.lognormal(mean=0.5, sigma=1.2, size=N_STORES).clip(0.1, 10.0)
city_rent_mult  = {city: 1.0 + np.random.uniform(0.0, 1.5) for city in store_cities}

store_sizem2 = np.where(
    np.array(store_types) == 'Hypermarket', np.random.randint(2500, 5000, N_STORES),
    np.where(np.array(store_types) == 'Supermarket', np.random.randint(800, 2500, N_STORES),
    np.where(np.array(store_types) == 'Department',  np.random.randint(1200, 3500, N_STORES),
                                                      np.random.randint(150, 800, N_STORES)))
)

store_staff      = np.clip((store_sizem2 / 45 + np.random.normal(0, 8, N_STORES)).astype(int), 3, 200)
store_parking    = np.clip((store_sizem2 / 25 + np.random.normal(0, 15, N_STORES)).astype(int), 0, 500)
store_annualrent = (store_sizem2 * 12 *
                    np.array([city_rent_mult.get(c, 1.0) for c in store_cities]) *
                    np.where(np.array(store_types) == 'Hypermarket', 0.8,
                    np.where(np.array(store_types) == 'Convenience', 1.4, 1.0))).round(0)
store_rating     = np.clip(2.0 + (store_staff/200)*0.8 + (store_parking/500)*0.5 +
                           np.random.uniform(0, 1.2, N_STORES), 2.0, 5.0).round(1)

store_df = pd.DataFrame({
    'storeid':              store_ids,
    'storename':            store_name,
    'city':                 store_cities,
    'type':                 store_types,
    'staff':                store_staff,
    'sizem2':               store_sizem2,
    'hascafe':              np.random.choice([0,1], N_STORES, p=[0.6,0.4]),
    'openingyear':          np.random.randint(1985, 2023, N_STORES),
    'region':               store_regions,
    'renovationyear':       np.random.choice([0]+list(range(2010,2024)), N_STORES,
                                             p=[0.35]+[0.65/14]*14),
    'parkingspots':         store_parking,
    'storerating':          store_rating,
    'hasdeliveryservice':   np.random.choice([0,1], N_STORES, p=[0.4,0.6]),
    'floornumber':          np.random.randint(1, 6, N_STORES),
    'distancetocitycenterkm': np.random.uniform(0.5, 25.0, N_STORES).round(1),
    'annualrentcost':       store_annualrent,
    'storesizemultiplier':  store_size_mult
})

renov = store_df['renovationyear'].values
op    = store_df['openingyear'].values
store_df['renovationyear'] = np.where((renov != 0) & (renov < op), op, renov)

# Create and prepend the -1 "Unknown Store" dummy row
dummy_store = pd.DataFrame([{
    'storeid': -1, 'storename': 'Unknown Store', 'city': 'Unknown', 'type': 'Unknown',
    'staff': 0, 'sizem2': 0, 'hascafe': 0, 'openingyear': 1900, 'region': 'Unknown',
    'renovationyear': 0, 'parkingspots': 0, 'storerating': 0.0, 'hasdeliveryservice': 0,
    'floornumber': 1, 'distancetocitycenterkm': 0.0, 'annualrentcost': 0.0, 'storesizemultiplier': 1.0
}])
store_df = pd.concat([dummy_store, store_df], ignore_index=True)

store_df = clean_df(store_df)
check_primary_key(store_df, 'storeid', 'dim_store')
check_no_nulls(store_df, 'dim_store')
assert store_df[store_df['storeid'] != -1]['storename'].is_unique, "Duplicate store names found!"

# Force proper float/decimal notation to prevent bulk import errors
store_df['storerating'] = store_df['storerating'].map(lambda x: f"{x:.1f}")
store_df['distancetocitycenterkm'] = store_df['distancetocitycenterkm'].map(lambda x: f"{x:.1f}")
store_df['annualrentcost'] = store_df['annualrentcost'].map(lambda x: f"{x:.2f}")
store_df['storesizemultiplier'] = store_df['storesizemultiplier'].map(lambda x: f"{x:.4f}")

store_df.to_csv(f"{OUTPUT_DIR}/dim_store.csv", index=False, encoding='utf-8', quoting=csv.QUOTE_MINIMAL)


# ---------------------------------------------------------------------------
# 4.2 DIM_PRODUCT – 2 000 products with prescribed margin distribution + dummy row
# ---------------------------------------------------------------------------
print("Generating dim_product with specified margin distribution...")

product_pool = []
product_names_set = set()
while len(product_pool) < N_PRODUCTS * 1.5:
    cat     = random.choice(CAT_NAMES)
    brand   = random.choice(BRANDS[cat])
    adj     = random.choice(PRODUCT_ADJECTIVES)
    noun    = random.choice(PRODUCT_NAMES[cat])
    variant = np.random.choice(['','V2','X','Series 5','Mk1','2024','Ltd','Gen3'],
                               p=[0.4,0.1,0.1,0.1,0.1,0.1,0.05,0.05])
    name = f"{brand} {adj} {noun} {variant}".strip()
    if name not in product_names_set:
        product_names_set.add(name)
        product_pool.append((name, cat, brand))

random.shuffle(product_pool)
selected_products = product_pool[:N_PRODUCTS]

product_ids          = np.arange(1, N_PRODUCTS + 1)
product_name         = [p[0] for p in selected_products]
product_categories   = np.array([p[1] for p in selected_products])
product_brands       = [p[2] for p in selected_products]
product_brand_premium = np.random.uniform(0.9, 1.5, N_PRODUCTS)

margins = np.zeros(N_PRODUCTS)
margins[:int(N_PRODUCTS*0.05)] = 0.30
idx2 = int(N_PRODUCTS*0.05)
idx3 = int(N_PRODUCTS*0.10)
margins[idx2:idx3] = np.random.uniform(0.20, 0.29, idx3-idx2)
idx4 = int(N_PRODUCTS*0.15)
margins[idx3:idx4] = 0.15
idx5 = int(N_PRODUCTS*0.65)
margins[idx4:idx5] = np.random.uniform(0.05, 0.10, idx5-idx4)
idx6 = int(N_PRODUCTS*0.95)
margins[idx5:idx6] = np.random.uniform(0.00, 0.05, idx6-idx5)
margins[idx6:]     = np.random.uniform(-0.10, 0.00, N_PRODUCTS-idx6)
np.random.shuffle(margins)
margins = np.round(margins, 4)

product_weights     = []
product_unitprice   = []
product_unitcost    = []
product_tax_rate    = []
product_warranty    = []
product_ecoscore    = []
product_material    = []
product_margin_pct  = []

for i, cat in enumerate(product_categories):
    cfg      = CATEGORY_CFG[cat]
    w        = round(np.random.uniform(cfg['weight_lo'], cfg['weight_hi']), 2)
    p_base   = round(np.random.uniform(cfg['price_lo'], cfg['price_hi']), 2)
    p_final  = round(p_base * product_brand_premium[i], 2)
    margin   = margins[i]
    cost = round(p_final * (1 - margin), 2)

    if cost <= 0:
        cost   = round(p_final * 0.75, 2)
        margin = round((p_final - cost) / p_final, 4)

    product_weights.append(w)
    product_unitprice.append(p_final)
    product_unitcost.append(cost)
    product_tax_rate.append(cfg['tax_rate'])
    product_warranty.append(int(np.random.random() < cfg['warranty_prob']))
    product_ecoscore.append(int(np.random.uniform(20, 200)))
    product_material.append(np.random.choice(['Plastic','Metal','Wood','Glass','Fabric']))
    product_margin_pct.append(margin)

product_isactive       = np.random.choice([0,1], N_PRODUCTS, p=[0.05,0.95]).astype(int)
product_stockstatus    = np.where(product_isactive == 0, 'Out of Stock',
                                  np.random.choice(['In Stock','Low Stock','Out of Stock'],
                                                   N_PRODUCTS, p=[0.78,0.17,0.05]))
product_releaseyear    = np.random.choice([2018,2019,2020,2021,2022,2023,2024,2025],
                                          N_PRODUCTS,
                                          p=[0.05,0.08,0.12,0.18,0.25,0.20,0.10,0.02])
product_skucount       = np.random.poisson(2.5, N_PRODUCTS) + 1
product_isdiscontinued = np.where(product_releaseyear < 2021,
                                  np.random.choice([0,1], N_PRODUCTS, p=[0.6,0.4]),
                                  np.random.choice([0,1], N_PRODUCTS, p=[0.95,0.05])).astype(int)
product_rating         = np.clip(2.0 + np.random.normal(0, 0.8, N_PRODUCTS), 1.0, 5.0).round(1)
product_isactive       = np.where(product_isdiscontinued == 1, 0, product_isactive)

product_df = pd.DataFrame({
    'productid':          product_ids,
    'name':               product_name,
    'category':           product_categories,
    'brand':              product_brands,
    'unitcost':           product_unitcost,
    'unitprice':          product_unitprice,
    'margin_pct':         product_margin_pct,
    'weight':             product_weights,
    'color':              np.random.choice(['Red','Blue','Green','Black','White','Gray','Silver','Gold'], N_PRODUCTS),
    'material':           product_material,
    'supplierid':         np.random.randint(1, 51, N_PRODUCTS),
    'isactive':           product_isactive,
    'minstock':           np.random.randint(2, 100, N_PRODUCTS),
    'tax_rate':           product_tax_rate,
    'haswarranty':        product_warranty,
    'ecofriendly':        (np.array(product_ecoscore) > 100).astype(int),
    'seasonalityfactor':  np.random.uniform(0.7, 1.3, N_PRODUCTS).round(2),
    'warrantymonths':     np.where(np.array(product_warranty) == 1,
                                   np.random.choice([12,24,36], N_PRODUCTS), 0),
    'ecoscore':           product_ecoscore,
    'releaseyear':        product_releaseyear,
    'skucount':           product_skucount,
    'isdiscontinued':     product_isdiscontinued,
    'productrating':      product_rating,
    'stockstatus':        product_stockstatus
})

# Create and prepend the -1 "Unknown Product" dummy row
dummy_product = pd.DataFrame([{
    'productid': -1, 'name': 'Unknown Product', 'category': 'Unknown', 'brand': 'Unknown',
    'unitcost': 0.0, 'unitprice': 0.0, 'margin_pct': 0.0, 'weight': 0.0, 'color': 'Unknown',
    'material': 'Unknown', 'supplierid': -1, 'isactive': 0, 'minstock': 0, 'tax_rate': 0.0,
    'haswarranty': 0, 'ecofriendly': 0, 'seasonalityfactor': 1.0, 'warrantymonths': 0,
    'ecoscore': 0, 'releaseyear': 1900, 'skucount': 0, 'isdiscontinued': 1, 'productrating': 0.0,
    'stockstatus': 'Unknown'
}])
product_df = pd.concat([dummy_product, product_df], ignore_index=True)

product_df = clean_df(product_df, string_default='Unknown Product')
check_primary_key(product_df, 'productid', 'dim_product')
check_no_nulls(product_df, 'dim_product')

# Format float columns
product_df['unitcost'] = product_df['unitcost'].map(lambda x: f"{x:.2f}")
product_df['unitprice'] = product_df['unitprice'].map(lambda x: f"{x:.2f}")
product_df['margin_pct'] = product_df['margin_pct'].map(lambda x: f"{x:.4f}")
product_df['weight'] = product_df['weight'].map(lambda x: f"{x:.2f}")
product_df['tax_rate'] = product_df['tax_rate'].map(lambda x: f"{x:.2f}")
product_df['seasonalityfactor'] = product_df['seasonalityfactor'].map(lambda x: f"{x:.2f}")
product_df['productrating'] = product_df['productrating'].map(lambda x: f"{x:.1f}")

product_df.to_csv(f"{OUTPUT_DIR}/dim_product.csv", index=False, encoding='utf-8', quoting=csv.QUOTE_MINIMAL)


# ---------------------------------------------------------------------------
# 4.3 DIM_PROMOTION – 100 promotions + dummy row for "No Promotion" & Unknown (-1)
# ---------------------------------------------------------------------------
print("Generating dim_promotion...")

# Dummy row (promoid=0 → no promotion)
dummy_promo_0 = pd.DataFrame([{
    'promoid': 0, 'promoname': 'No Promotion',
    'discount_pct': 0.0, 'discount_fixed': 0.0, 'type': 'None', 'isactive': 1,
    'minspend': 0, 'channel': 'All', 'budget': 0.0,
    'startdate': START_DATE.strftime('%Y-%m-%d'),
    'enddate':   END_DATE.strftime('%Y-%m-%d'),
    'targetaudience': 'All', 'maxdiscountcap': 0.0, 'isstackable': 0,
    'redemption_rate': 0.0, 'coderequired': 0, 'promoupliftfactor': 1.0
}])

# Dummy row (promoid=-1 → Unknown/Invalid promo code)
dummy_promo_minus1 = pd.DataFrame([{
    'promoid': -1, 'promoname': 'Unknown Promotion',
    'discount_pct': 0.0, 'discount_fixed': 0.0, 'type': 'Unknown', 'isactive': 0,
    'minspend': 0, 'channel': 'Unknown', 'budget': 0.0,
    'startdate': '1900-01-01', 'enddate': '1900-01-01',
    'targetaudience': 'Unknown', 'maxdiscountcap': 0.0, 'isstackable': 0,
    'redemption_rate': 0.0, 'coderequired': 0, 'promoupliftfactor': 1.0
}])

promo_ids      = np.arange(1, N_PROMOTIONS + 1)
promo_types    = np.random.choice(['Percentage','Fixed Amount','BOGO','Free Shipping'],
                                  N_PROMOTIONS, p=[0.35,0.25,0.25,0.15])
promo_channels = np.where(promo_types == 'Free Shipping', 'Online',
                          np.random.choice(['Email','SMS','App','InStore','All'], N_PROMOTIONS))

promo_discount_pct   = np.where(promo_types == 'Percentage',
                                np.random.uniform(0.10, 0.45, N_PROMOTIONS).round(4), 0.0)
promo_discount_fixed = np.where(promo_types == 'Fixed Amount',
                                np.random.uniform(3, 30, N_PROMOTIONS).round(2), 0.0)

promo_budgets = (np.where(promo_types == 'Percentage', promo_discount_pct,
                          promo_discount_fixed/100) *
                 N_SALES * 0.002 * np.random.uniform(0.8, 1.5, N_PROMOTIONS)).round(0)

promo_uplift = np.zeros(N_PROMOTIONS)
for i, pt in enumerate(promo_types):
    if pt == 'BOGO':          promo_uplift[i] = np.random.uniform(1.8, 2.2)
    elif pt == 'Percentage':  promo_uplift[i] = np.random.uniform(1.2, 1.4)
    elif pt == 'Fixed Amount':promo_uplift[i] = np.random.uniform(1.05, 1.15)
    else:                     promo_uplift[i] = np.random.uniform(1.0, 1.02)

max_days    = (END_DATE - START_DATE).days
promo_start = (START_DATE + pd.to_timedelta(np.random.randint(0, min(900, max_days),
                                                              N_PROMOTIONS), unit='D')).to_pydatetime()
promo_end   = (START_DATE + pd.to_timedelta(np.random.randint(15, min(950, max_days),
                                                              N_PROMOTIONS), unit='D')).to_pydatetime()
for i in range(N_PROMOTIONS):
    if promo_start[i] > promo_end[i]:
        promo_start[i], promo_end[i] = promo_end[i], promo_start[i]
    if promo_end[i] > END_DATE:
        promo_end[i] = END_DATE

promo_isactive = np.where(promo_end >= END_DATE, 1, 0).astype(int)
promo_start_str = [d.strftime('%Y-%m-%d') for d in promo_start]
promo_end_str   = [d.strftime('%Y-%m-%d') for d in promo_end]

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
    'promoid':            promo_ids,
    'promoname':          promo_name,
    'discount_pct':       promo_discount_pct,
    'discount_fixed':     promo_discount_fixed,
    'type':               promo_types,
    'isactive':           promo_isactive,
    'minspend':           np.random.choice([0,10,25,50,100], N_PROMOTIONS, p=[0.25,0.30,0.20,0.15,0.10]),
    'channel':            promo_channels,
    'budget':             promo_budgets,
    'startdate':          promo_start_str,
    'enddate':            promo_end_str,
    'targetaudience':     np.random.choice(['All','New','Loyal','HighSpend'], N_PROMOTIONS,
                                           p=[0.40,0.15,0.25,0.20]),
    'maxdiscountcap':     np.random.uniform(5, 120, N_PROMOTIONS).round(2),
    'isstackable':        np.random.choice([0,1], N_PROMOTIONS, p=[0.85,0.15]),
    'redemption_rate':    np.random.uniform(0.02, 0.35, N_PROMOTIONS).round(3),
    'coderequired':       np.random.choice([0,1], N_PROMOTIONS, p=[0.60,0.40]),
    'promoupliftfactor':  promo_uplift.round(3)
})

promo_df = pd.concat([dummy_promo_minus1, dummy_promo_0, promo_df], ignore_index=True)
promo_df = clean_df(promo_df)
check_primary_key(promo_df, 'promoid', 'dim_promotion')
check_no_nulls(promo_df, 'dim_promotion')

# Format float columns
promo_df['discount_pct'] = promo_df['discount_pct'].map(lambda x: f"{x:.4f}")
promo_df['discount_fixed'] = promo_df['discount_fixed'].map(lambda x: f"{x:.2f}")
promo_df['budget'] = promo_df['budget'].map(lambda x: f"{x:.2f}")
promo_df['maxdiscountcap'] = promo_df['maxdiscountcap'].map(lambda x: f"{x:.2f}")
promo_df['redemption_rate'] = promo_df['redemption_rate'].map(lambda x: f"{x:.3f}")
promo_df['promoupliftfactor'] = promo_df['promoupliftfactor'].map(lambda x: f"{x:.3f}")

promo_df.to_csv(f"{OUTPUT_DIR}/dim_promotion.csv", index=False, encoding='utf-8', quoting=csv.QUOTE_MINIMAL)


# ---------------------------------------------------------------------------
# 4.4 DIM_CUSTOMER – 200 000 customers with realistic demographics + dummy row
# ---------------------------------------------------------------------------
print("Generating dim_customer with realistic income spread...")

customer_ids  = np.arange(1, N_CUSTOMERS + 1)
gender_choice = np.random.choice(['Male','Female'], N_CUSTOMERS, p=[0.5,0.5])

first_names = np.where(gender_choice == 'Male',
                       np.random.choice(FIRST_NAMES_MALE, N_CUSTOMERS),
                       np.random.choice(FIRST_NAMES_FEMALE, N_CUSTOMERS))
last_names  = np.random.choice(LAST_NAMES, N_CUSTOMERS)

temp_names = pd.DataFrame({'first': first_names, 'last': last_names})
temp_names['occurrence'] = temp_names.groupby(['first','last']).cumcount()
temp_names['is_dup']     = temp_names.groupby(['first','last']).transform('size') > 1
suffix_num       = np.where(temp_names['is_dup'] & (temp_names['occurrence'] > 0),
                            temp_names['occurrence'], 0)
suffix_str       = np.where(suffix_num > 0, ' ' + suffix_num.astype(str), '')
email_suffix_str = np.where(suffix_num > 0, suffix_num.astype(str), '')

fullname    = temp_names['first'] + ' ' + temp_names['last'] + suffix_str
email_local = (temp_names['first'].str.lower() + '.' + temp_names['last'].str.lower() +
               email_suffix_str).str.replace(' ', '.').str.replace('[^a-z0-9.]', '', regex=True)
email       = email_local + '@example.com'

age_range = np.arange(18, 75)
age_probs = np.where(age_range < 25, 0.02,
             np.where(age_range < 40, 0.035,
             np.where(age_range < 60, 0.025, 0.015)))
age_probs /= age_probs.sum()
customer_age = np.random.choice(age_range, N_CUSTOMERS, p=age_probs)

low_income  = np.random.lognormal(mean=9.5, sigma=0.8, size=N_CUSTOMERS//2).clip(5000, 60000)
high_income = np.random.lognormal(mean=10.5, sigma=0.6,
                                  size=N_CUSTOMERS - N_CUSTOMERS//2).clip(30000, 200000)
customer_income = np.concatenate([low_income, high_income])
np.random.shuffle(customer_income)
customer_income = customer_income[:N_CUSTOMERS]

customer_tier       = np.where(customer_income > 80000, 'Platinum',
                       np.where(customer_income > 50000, 'Gold',
                       np.where(customer_income > 30000, 'Silver', 'Bronze')))
customer_spend_mult = np.where(customer_tier == 'Platinum', np.random.uniform(3.0, 8.0, N_CUSTOMERS),
                       np.where(customer_tier == 'Gold',     np.random.uniform(1.8, 3.5, N_CUSTOMERS),
                       np.where(customer_tier == 'Silver',   np.random.uniform(0.8, 1.8, N_CUSTOMERS),
                                                              np.random.uniform(0.2, 0.8, N_CUSTOMERS))))

customer_points             = np.clip((customer_spend_mult * 45 +
                                       np.random.poisson(20, N_CUSTOMERS)).astype(int), 0, 1200)
regdate_days                = np.random.exponential(600, N_CUSTOMERS).astype(int)
max_days_date               = (END_DATE - START_DATE).days
regdate_days_clipped        = np.minimum(regdate_days, max_days_date)
customer_regdate            = [(START_DATE + timedelta(days=int(d))).strftime('%Y-%m-%d')
                               for d in regdate_days_clipped]
customer_totalSpend         = (customer_spend_mult * np.random.exponential(250, N_CUSTOMERS)).round(2)
customer_satisfactionscore  = np.clip(2.5 + (customer_tier == 'Platinum')*1.0 +
                                      (customer_tier == 'Gold')*0.6 +
                                      np.random.normal(0, 0.8, N_CUSTOMERS), 1.0, 5.0).round(1)
customer_dayssincelast      = np.where(customer_tier == 'Platinum',
                                       np.random.exponential(5, N_CUSTOMERS),
                               np.where(customer_tier == 'Gold',
                                        np.random.exponential(12, N_CUSTOMERS),
                                        np.random.exponential(35, N_CUSTOMERS))).astype(int)
customer_hassubscription    = np.random.choice([0,1], N_CUSTOMERS, p=[0.65,0.35])
customer_childrencount      = np.random.poisson(np.where(customer_age < 30, 0.3,
                                                 np.where(customer_age < 45, 0.9, 0.4)),
                                                 N_CUSTOMERS).astype(int)

contact_probs = np.zeros((N_CUSTOMERS, 4))
contact_probs[:,0] = np.where(customer_age < 35, 0.6, 0.3)
contact_probs[:,1] = np.where(customer_age < 30, 0.25, 0.4)
contact_probs[:,2] = np.where(customer_age > 50, 0.35, 0.15)
contact_probs[:,3] = 1.0 - contact_probs.sum(axis=1)
contact_probs = np.maximum(contact_probs, 0.05)
contact_probs = contact_probs / contact_probs.sum(axis=1, keepdims=True)
customer_contact = np.array([np.random.choice(CONTACT_PREF, p=p) for p in contact_probs])

all_cities      = sum(REGION_CITY_MAP.values(), [])
customer_cities = np.random.choice(all_cities, N_CUSTOMERS)

customer_df = pd.DataFrame({
    'customerid':           customer_ids,
    'fullname':             fullname.values,
    'email':                email.values,
    'age':                  customer_age,
    'gender':               gender_choice,
    'city':                 customer_cities,
    'tier':                 customer_tier,
    'points':               customer_points,
    'isactive':             np.random.choice([0,1], N_CUSTOMERS, p=[0.06,0.94]),
    'lang':                 np.random.choice(['en','de','fr','es','pl','it'], N_CUSTOMERS,
                                             p=[0.35,0.20,0.15,0.15,0.10,0.05]),
    'totalspend':           customer_totalSpend,
    'regdate':              customer_regdate,
    'annualincome':         customer_income.round(2),
    'incomebracket':        pd.cut(customer_income,
                                  bins=[0,25000,50000,75000,100000,1e9],
                                  labels=['Low','Medium','High','Very High','Ultra High']).astype(str),
    'education':            np.random.choice(EDUCATION, N_CUSTOMERS, p=[0.30,0.40,0.25,0.05]),
    'maritalstatus':        np.random.choice(MARITAL, N_CUSTOMERS),
    'childrencount':        customer_childrencount,
    'loyaltysegment':       customer_tier,
    'satisfactionscore':    customer_satisfactionscore,
    'dayssincelastpurchase': customer_dayssincelast,
    'hassubscription':      customer_hassubscription,
    'preferredcontact':     customer_contact,
    'spendmultiplier':      customer_spend_mult.round(3)
})

# Create and prepend the -1 "Unknown Customer" dummy row
dummy_customer = pd.DataFrame([{
    'customerid': -1, 'fullname': 'Unknown Customer', 'email': 'unknown@example.com', 'age': 0,
    'gender': 'Unknown', 'city': 'Unknown', 'tier': 'None', 'points': 0, 'isactive': 0, 'lang': 'en',
    'totalspend': 0.0, 'regdate': '1900-01-01', 'annualincome': 0.0, 'incomebracket': 'Low',
    'education': 'Unknown', 'maritalstatus': 'Unknown', 'childrencount': 0, 'loyaltysegment': 'None',
    'satisfactionscore': 0.0, 'dayssincelastpurchase': -1, 'hassubscription': 0, 'preferredcontact': 'Email',
    'spendmultiplier': 1.0
}])
customer_df = pd.concat([dummy_customer, customer_df], ignore_index=True)

customer_df = clean_df(customer_df)
check_primary_key(customer_df, 'customerid', 'dim_customer')
check_no_nulls(customer_df, 'dim_customer')

# Format float columns
customer_df['totalspend'] = customer_df['totalspend'].map(lambda x: f"{x:.2f}")
customer_df['annualincome'] = customer_df['annualincome'].map(lambda x: f"{x:.2f}")
customer_df['satisfactionscore'] = customer_df['satisfactionscore'].map(lambda x: f"{x:.1f}")
customer_df['spendmultiplier'] = customer_df['spendmultiplier'].map(lambda x: f"{x:.3f}")

customer_df.to_csv(f"{OUTPUT_DIR}/dim_customer.csv", index=False, encoding='utf-8', quoting=csv.QUOTE_MINIMAL)


# ---------------------------------------------------------------------------
# 4.5 DIM_DATE – one row per day from START_DATE to today
# ---------------------------------------------------------------------------
print("Generating dim_date...")
dates = pd.date_range(START_DATE, END_DATE, freq='D')
isholiday_arr = np.isin(dates.month, [12,1]) | (dates.month == 7)

date_df = pd.DataFrame({
    'datekey':           dates.strftime("%Y%m%d").astype(int),
    'fulldate':          dates.strftime("%Y-%m-%d"),
    'year':              dates.year.astype(int),
    'quarternumber':     dates.quarter.astype(int),
    'quartername':       'Q' + dates.quarter.astype(str),
    'monthnumber':       dates.month.astype(int),
    'monthname':         dates.month_name(),
    'weekdaynumber':     (dates.dayofweek + 1).astype(int),
    'weekdayname':       dates.day_name(),
    'isweekend':         (dates.dayofweek >= 5).astype(int),
    'yearmonth':         dates.strftime("%Y-%m"),
    'yearmonthnumber':   (dates.year * 100 + dates.month).astype(int),
    'yearquarter':       dates.year.astype(str) + '-Q' + dates.quarter.astype(str),
    'yearquarternumber': (dates.year * 10 + dates.quarter).astype(int),
    'yearweek':          dates.strftime("%Y-W%W"),
    'yearweeknumber':    (dates.isocalendar().week.astype(int) + dates.year * 100),
    'isholiday':         isholiday_arr.astype(int)
})

# Adding datekey -1 representing an Unknown/Missing Date
dummy_date = pd.DataFrame([{
    'datekey': -1, 'fulldate': '1900-01-01', 'year': 1900, 'quarternumber': 1, 'quartername': 'Q1',
    'monthnumber': 1, 'monthname': 'January', 'weekdaynumber': 1, 'weekdayname': 'Monday', 'isweekend': 0,
    'yearmonth': '1900-01', 'yearmonthnumber': 190001, 'yearquarter': '1900-Q1', 'yearquarternumber': 19001,
    'yearweek': '1900-W01', 'yearweeknumber': 190001, 'isholiday': 0
}])
date_df = pd.concat([dummy_date, date_df], ignore_index=True)

date_df = clean_df(date_df)
check_primary_key(date_df, 'datekey', 'dim_date')
check_no_nulls(date_df, 'dim_date')
date_df.to_csv(f"{OUTPUT_DIR}/dim_date.csv", index=False, encoding='utf-8', quoting=csv.QUOTE_MINIMAL)

print("All dimension files exported successfully ✓")


# ============================================================================
# 5. DAILY NET‑SALES TREND
#    Defines the target revenue curve: decline → flat → strong rise
# ============================================================================
print("Generating trend: decline (60k→50k) then flat, then strong rise to 95k at end...")

n_dates     = len(dates)
decline_end = int(n_dates * 0.5)
flat_end    = int(n_dates * 0.7)

start_val, decline_val, flat_val, rise_start, final_peak = 60000, 50000, 50000, 50000, 95000

trend = np.zeros(n_dates)
trend[:decline_end]         = np.linspace(start_val, decline_val, decline_end)
trend[decline_end:flat_end] = flat_val
trend[flat_end:]            = np.linspace(rise_start, final_peak, n_dates - flat_end)

window = 7
ma = np.convolve(trend, np.ones(window)/window, mode='same')
ma[:window//2] = trend[:window//2]
ma[-window//2:] = trend[-window//2:]
smooth_trend = ma

drift_rates = np.zeros(n_dates)
for i in range(1, n_dates):
    if smooth_trend[i-1] != 0:
        drift_rates[i] = (smooth_trend[i] - smooth_trend[i-1]) / smooth_trend[i-1]

volatility      = 0.02
noise           = np.random.normal(0, 1, n_dates)
smoothed_noise  = np.convolve(noise, np.ones(3)/3, mode='same')
final_values    = np.zeros(n_dates)
final_values[0] = smooth_trend[0]

for i in range(1, n_dates):
    daily_change    = drift_rates[i] + volatility * smoothed_noise[i]
    final_values[i] = final_values[i-1] * (1 + daily_change)

daily_net_sales_target = np.maximum(np.round(final_values).astype(int), 1000)
print(f"Trend: start={daily_net_sales_target[0]}, min={daily_net_sales_target.min()}, "
      f"end={daily_net_sales_target[-1]}")


# ============================================================================
# 6. FACT TABLE GENERATION (10M rows, chunked CSV output)
#    Uses quantity‑scaling to hit daily targets while preserving product margins.
# ============================================================================
print(f"\nGenerating fact_sales ({N_SALES:,} rows) in chunks...")

# Filter out dummy (-1) values from the array pools so we don't accidentally select them as normal transactions
product_ids_arr      = product_df[product_df['productid'] > 0]['productid'].values
customer_ids_arr     = customer_df[customer_df['customerid'] > 0]['customerid'].values
store_ids_arr        = store_df[store_df['storeid'] > 0]['storeid'].values
promo_ids_arr        = promo_df[promo_df['promoid'] > 0]['promoid'].values

# Get valid date keys (excluding dummy -1 datekey) matching the sequential timeline loop
datekeys             = date_df[date_df['datekey'] > 0]['datekey'].values

# Keep original dimension indexes mapped for attributes (adjusted for dummy offset mapping)
product_unitprice_arr = product_df.set_index('productid')['unitprice'].astype(float).to_dict()
product_tax_rate_arr  = product_df.set_index('productid')['tax_rate'].astype(float).to_dict()
product_weight_arr    = product_df.set_index('productid')['weight'].astype(float).to_dict()
product_unitcost_arr  = product_df.set_index('productid')['unitcost'].astype(float).to_dict()

customer_tier_arr     = customer_df[customer_df['customerid'] > 0]['tier'].values
customer_spend_mult_arr = customer_df[customer_df['customerid'] > 0]['spendmultiplier'].astype(float).values
store_size_mult_arr   = store_df[store_df['storeid'] > 0]['storesizemultiplier'].astype(float).values

# Selection weights – higher multipliers increase probability of appearing in sales
cust_weights  = customer_spend_mult_arr * np.where(customer_tier_arr == 'Platinum', 3.0,
                                          np.where(customer_tier_arr == 'Gold', 1.8,
                                          np.where(customer_tier_arr == 'Silver', 1.0, 0.5)))
cust_weights /= cust_weights.sum()
store_weights = store_size_mult_arr / store_size_mult_arr.sum()
promo_weights = np.ones(len(promo_ids_arr)) / len(promo_ids_arr)

# Distribute the 10M rows across days proportionally to the daily target
avg_transaction_value    = 125.0
expected_n_transactions  = daily_net_sales_target / avg_transaction_value
total_expected           = expected_n_transactions.sum()
daily_n_trans            = np.floor(N_SALES * expected_n_transactions / total_expected).astype(int)

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

# Prepare CSV file – write header only first
f_path = f"{OUTPUT_DIR}/fact_sales.csv"
if os.path.exists(f_path):
    os.remove(f_path)

pd.DataFrame(columns=[
    'salesid','datekey','productid','customerid','storeid','promoid',
    'qty','unitprice','tax_rate','net','payment','channel',
    'grossvalue','discountamount','taxamount','shipcost','isreturn',
    'shipweight','discountapplied','returnreason','deliverydays','hour'
]).to_csv(f_path, index=False)

# Vectorized optimization: Map store type using lookup arrays
store_id_keys   = store_df['storeid'].values
store_type_vals = store_df['type'].values
store_id_to_index = {sid: idx for idx, sid in enumerate(store_id_keys)}

current_buffer = []
sales_id       = 1

# --- Main generation loop (one iteration per day) ---
for day_idx in range(n_dates):
    target = daily_net_sales_target[day_idx]
    n_tr   = daily_n_trans[day_idx]
    if n_tr == 0:
        continue
    datekey = datekeys[day_idx]

    # Randomly choose dimension references for each transaction
    prod_choices  = np.random.choice(product_ids_arr, n_tr)
    cust_choices  = np.random.choice(customer_ids_arr, n_tr, p=cust_weights)
    store_choices = np.random.choice(store_ids_arr, n_tr, p=store_weights)
    promo_has     = np.random.choice([0, 1], n_tr, p=[0.65, 0.35])
    promo_choices = np.where(promo_has == 1,
                             np.random.choice(promo_ids_arr, n_tr, p=promo_weights), 0)

    # Seasonal price multiplier (annual sinusoidal)
    daily_price_mult = 1.0 + 0.02 * np.sin(2 * np.pi * day_idx / 365)
    
    # Vectorized fast retrieval of product mapping attributes
    unit_prices = np.array([product_unitprice_arr[pid] for pid in prod_choices]) * daily_price_mult
    tax_rates   = np.array([product_tax_rate_arr[pid] for pid in prod_choices])
    weights     = np.array([product_weight_arr[pid] for pid in prod_choices])

    # Initial random quantities and discount factors
    raw_qty     = np.random.poisson(2, n_tr) + 1
    disc_factor = np.random.uniform(0, 0.3, n_tr)

    # Compute scaling factor so that sum(net) ≈ target
    gross_temp = raw_qty * unit_prices
    net_temp   = gross_temp * (1 - disc_factor) + (gross_temp * (1 - disc_factor) * tax_rates)
    total_net  = net_temp.sum()
    scale_factor = (target / total_net) if total_net > 0 else 1.0

    # Scale quantities and recalculate monetary columns
    scaled_qty     = np.maximum(np.round(raw_qty * scale_factor).astype(int), 1)
    gross          = scaled_qty * unit_prices
    net_before_tax = gross * (1 - disc_factor)
    tax            = net_before_tax * tax_rates
    net_sales      = net_before_tax + tax
    disc_amount    = gross - net_before_tax

    # Discount flag
    disc_amount_rounded = disc_amount.round(2)
    discountapplied     = (disc_amount_rounded != 0).astype(int)

    # Channel, payment, delivery
    channel   = np.random.choice(CHANNELS, n_tr, p=[0.5, 0.3, 0.15, 0.05])
    payment   = np.random.choice(PAYMENT, n_tr)
    is_online = np.isin(channel, ['Online', 'Mobile App'])

    delivery_days = np.ones(n_tr, dtype=int)
    if is_online.sum() > 0:
        delivery_days[is_online] = np.random.negative_binomial(2, 0.4, size=is_online.sum()) + 1
    delivery_days = np.where(channel == 'In-Store', 0, np.clip(delivery_days, 1, 10))

    # Return probability
    return_prob = np.where(channel == 'Online', 0.08,
                  np.where(channel == 'Mobile App', 0.07,
                  np.where(channel == 'In-Store', 0.02, 0.04)))
    return_prob = return_prob * (1 + 0.2 * (delivery_days > 5))
    is_return   = (np.random.random(n_tr) < return_prob).astype(int)

    # Shipping cost
    shipcost = np.where(is_online, (weights * scaled_qty * 0.5).round(2), 0.0)

    # Return reason
    return_reason_arr = np.full(n_tr, "No return", dtype=object)
    mask_ret = is_return == 1
    if mask_ret.any():
        return_reason_arr[mask_ret] = np.random.choice(RETURN_REASONS, mask_ret.sum())

    # Negate values for returns
    gross                = np.where(is_return == 1, -gross, gross)
    net_sales            = np.where(is_return == 1, -net_sales, net_sales)
    disc_amount_rounded  = np.where(is_return == 1, -disc_amount_rounded, disc_amount_rounded)
    tax                  = np.where(is_return == 1, -tax, tax)
    shipcost             = np.where(is_return == 1, 0.0, shipcost)

    # Hour of transaction (Optimized store mapping using fast index lookups)
    store_mapped_indices = np.array([store_id_to_index[sid] for sid in store_choices])
    store_types_for_rows = store_type_vals[store_mapped_indices]
    hour_arr             = generate_hours_vectorized(channel, store_types_for_rows)

    # Build chunk DataFrame with strict decimal representations for floats
    batch_df = pd.DataFrame({
        'salesid':         np.arange(sales_id, sales_id + n_tr),
        'datekey':         datekey,
        'productid':       prod_choices,
        'customerid':      cust_choices,
        'storeid':         store_choices,
        'promoid':         promo_choices,
        'qty':             scaled_qty,
        'unitprice':       unit_prices.round(2),
        'tax_rate':        tax_rates.round(2),
        'net':             net_sales.round(2),
        'payment':         payment,
        'channel':         channel,
        'grossvalue':      gross.round(2),
        'discountamount':  disc_amount_rounded,
        'taxamount':       tax.round(2),
        'shipcost':        shipcost.round(2),
        'isreturn':        is_return,
        'shipweight':      (weights * scaled_qty).round(2),
        'discountapplied': discountapplied,
        'returnreason':    return_reason_arr,
        'deliverydays':    delivery_days,
        'hour':            hour_arr
    })

    current_buffer.append(batch_df)
    sales_id += n_tr

    if sum(len(df) for df in current_buffer) >= CHUNK_SIZE:
        combined_batch = pd.concat(current_buffer)
        
        # Format floating-point decimals to fixed strings before writing to prevent parsing issues in bulk inserts
        float_cols = ['unitprice', 'tax_rate', 'net', 'grossvalue', 'discountamount', 'taxamount', 'shipcost', 'shipweight']
        for col in float_cols:
            combined_batch[col] = combined_batch[col].map(lambda x: f"{x:.2f}")

        combined_batch.to_csv(f_path, mode='a', header=False, index=False, quoting=csv.QUOTE_MINIMAL)
        current_buffer.clear()
        print(f"Progress: {sales_id-1:,} / {N_SALES:,} rows generated...")

# Write remaining rows
if current_buffer:
    combined_batch = pd.concat(current_buffer)
    float_cols = ['unitprice', 'tax_rate', 'net', 'grossvalue', 'discountamount', 'taxamount', 'shipcost', 'shipweight']
    for col in float_cols:
        combined_batch[col] = combined_batch[col].map(lambda x: f"{x:.2f}")
    combined_batch.to_csv(f_path, mode='a', header=False, index=False, quoting=csv.QUOTE_MINIMAL)

print("\nFact table generation completed.")


# ============================================================================
# 7. FINAL DATA QUALITY CHECKS
#    Quick validation of the generated CSV files.
# ============================================================================
print("\nRunning final data quality checks...")
df_check = pd.read_csv(f_path, nrows=10000)
assert df_check['promoid'].isna().sum() == 0,        "promoid contains NULLs!"
assert df_check['returnreason'].isna().sum() == 0,   "returnreason contains NULLs!"
assert df_check['hour'].isna().sum() == 0,           "hour contains NULLs!"

instore_check = df_check[df_check['channel'] == 'In-Store']
if not instore_check.empty:
    assert (instore_check['deliverydays'] == 0).all(), "In-Store deliverydays not zero!"
print("✓ Sample fact table: No NULLs, In-Store deliverydays=0.")

# Optimized single-pass referential integrity check across the entire 10 million rows
check_all_referential_integrity(
    f_path,
    set(product_df['productid']),
    set(customer_df['customerid']),
    set(store_df['storeid']),
    set(promo_df['promoid'])
)

total_rows = sum(1 for _ in open(f_path)) - 1
assert total_rows == N_SALES, f"Row count mismatch: expected {N_SALES}, got {total_rows}"
print(f"✓ Fact table contains exactly {N_SALES:,} rows.")

print("\n✅ All data quality checks passed.")
print(f"\nAll files created. Data range: {START_DATE.date()} to {END_DATE.date()}")
print(f"Script finished at {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
# ============================================================================
# End of generate_retail_data.py
# ============================================================================