#!/usr/bin/env python3
"""
ChainSight synthetic data generator.

Simulates NovaTech Manufacturing & Commerce day by day (2023-01-01 .. 2025-12-31):

  suppliers -> purchase orders -> raw material stock -> machine runs (production)
  -> plant finished goods -> warehouse replenishment -> warehouse stock
  -> e-commerce orders -> fulfilment (or backorder) -> shipment -> delivery -> return

Because the simulation is stateful, a supplier delay really does reduce material
stock, which reduces production, which empties warehouses, which delays orders.
Nothing downstream is drawn independently of what happened upstream.

Usage:
    python scripts/generate_data.py                 # full scale (~250k orders)
    python scripts/generate_data.py --scale 0.1     # 10% volume, fast
    python scripts/generate_data.py --seed 7 --out data/raw

Output: dirty RAW csv files (all text) in --out, plus a manifest of injected issues.
"""
import argparse
import json
import os
import time
from collections import defaultdict

import numpy as np
import pandas as pd

START = pd.Timestamp("2023-01-01")
END = pd.Timestamp("2025-12-31")
ND = (END - START).days + 1
DATES = pd.date_range(START, END)
DOW = DATES.dayofweek.values
MONTH = DATES.month.values
YEAR_IDX = DATES.year.values - 2023

REGIONS = ["North America", "Europe", "Asia Pacific", "Latin America", "Middle East & Africa"]
REGION_SHARE = np.array([0.34, 0.28, 0.24, 0.08, 0.06])
PROMISE_DAYS = np.array([12, 10, 12, 14, 15])          # delivery promise shown at checkout, by region
REGION_TRANSIT_FACTOR = np.array([1.0, 1.0, 1.3, 1.8, 1.9])

CITIES = {
    "North America": [("New York", "NY", "United States"), ("Chicago", "IL", "United States"),
                      ("Dallas", "TX", "United States"), ("Los Angeles", "CA", "United States"),
                      ("Seattle", "WA", "United States"), ("Atlanta", "GA", "United States"),
                      ("Austin", "TX", "United States"), ("Toronto", "ON", "Canada"),
                      ("Vancouver", "BC", "Canada")],
    "Europe": [("London", "England", "United Kingdom"), ("Manchester", "England", "United Kingdom"),
               ("Berlin", "Berlin", "Germany"), ("Munich", "Bavaria", "Germany"),
               ("Paris", "Ile-de-France", "France"), ("Madrid", "Madrid", "Spain"),
               ("Amsterdam", "North Holland", "Netherlands"), ("Milan", "Lombardy", "Italy"),
               ("Wroclaw", "Lower Silesia", "Poland")],
    "Asia Pacific": [("Mumbai", "Maharashtra", "India"), ("Bengaluru", "Karnataka", "India"),
                     ("Chennai", "Tamil Nadu", "India"), ("Delhi", "Delhi", "India"),
                     ("Singapore", "Singapore", "Singapore"), ("Tokyo", "Tokyo", "Japan"),
                     ("Sydney", "NSW", "Australia"), ("Melbourne", "VIC", "Australia"),
                     ("Seoul", "Seoul", "South Korea"), ("Shenzhen", "Guangdong", "China")],
    "Latin America": [("Sao Paulo", "SP", "Brazil"), ("Rio de Janeiro", "RJ", "Brazil"),
                      ("Mexico City", "CDMX", "Mexico"), ("Monterrey", "NL", "Mexico"),
                      ("Santiago", "RM", "Chile")],
    "Middle East & Africa": [("Dubai", "Dubai", "United Arab Emirates"), ("Riyadh", "Riyadh", "Saudi Arabia"),
                             ("Johannesburg", "Gauteng", "South Africa"), ("Cape Town", "Western Cape", "South Africa"),
                             ("Cairo", "Cairo", "Egypt")],
}
WAREHOUSE_CITIES = [["Dallas", "Chicago", "Seattle"], ["Amsterdam", "Munich", "Madrid"],
                    ["Singapore", "Mumbai", "Sydney"], ["Sao Paulo", "Mexico City", "Santiago"],
                    ["Dubai", "Johannesburg", "Cairo"]]
PLANT_CITIES = ["Austin", "Wroclaw", "Chennai", "Shenzhen", "Monterrey"]

CATEGORIES = ["Smart Home", "Computer Accessories", "Mobile Accessories", "Audio", "Wearables",
              "Networking", "Gaming Accessories"]
CAT_COUNT = [80, 90, 90, 80, 60, 55, 45]                      # = 500 products
SUBCATS = {
    "Smart Home": ["Smart Plug", "Smart Camera", "Smart Light", "Smart Sensor", "Smart Thermostat"],
    "Computer Accessories": ["Keyboard", "Mouse", "Webcam", "USB Hub", "Docking Station", "Laptop Stand"],
    "Mobile Accessories": ["Charger", "Cable", "Power Bank", "Phone Case", "Wireless Charger"],
    "Audio": ["Earbuds", "Headphones", "Bluetooth Speaker", "Soundbar", "Microphone"],
    "Wearables": ["Fitness Band", "Smart Watch", "Smart Ring", "Watch Strap"],
    "Networking": ["Router", "Mesh System", "Range Extender", "Network Switch", "Network Adapter"],
    "Gaming Accessories": ["Gaming Mouse", "Gaming Keyboard", "Controller", "Gaming Headset", "Mousepad"],
}
PRICE_RANGE = {"Smart Home": (15, 180), "Computer Accessories": (12, 150), "Mobile Accessories": (8, 90),
               "Audio": (20, 260), "Wearables": (25, 320), "Networking": (20, 280), "Gaming Accessories": (15, 220)}
COST_RATIO = {"Smart Home": (0.52, 0.66), "Computer Accessories": (0.50, 0.64), "Mobile Accessories": (0.45, 0.60),
              "Audio": (0.58, 0.72), "Wearables": (0.55, 0.70), "Networking": (0.55, 0.68),
              "Gaming Accessories": (0.52, 0.66)}
RETURN_BASE = {"Smart Home": .05, "Computer Accessories": .035, "Mobile Accessories": .03, "Audio": .06,
               "Wearables": .07, "Networking": .045, "Gaming Accessories": .05}
DEFECT_BASE = {"Smart Home": .018, "Computer Accessories": .012, "Mobile Accessories": .010, "Audio": .020,
               "Wearables": .025, "Networking": .015, "Gaming Accessories": .014}
# monthly demand seasonality by category (Jan..Dec)
SEASON = {
    "Smart Home": [1.0, .9, .95, .95, .95, 1.0, 1.0, 1.0, 1.0, 1.1, 1.55, 1.45],
    "Computer Accessories": [.95, .9, .95, .95, .95, .95, 1.05, 1.35, 1.25, 1.0, 1.35, 1.3],
    "Mobile Accessories": [.95, .9, .95, .95, .95, 1.0, 1.0, 1.05, 1.25, 1.2, 1.4, 1.35],
    "Audio": [.9, .85, .9, .95, 1.0, 1.1, 1.05, 1.0, 1.0, 1.1, 1.7, 1.75],
    "Wearables": [1.3, 1.0, .95, .95, .95, 1.0, 1.0, 1.0, 1.05, 1.0, 1.6, 1.5],
    "Networking": [1.2, 1.0, .95, .95, .95, .95, .95, 1.0, 1.0, 1.0, 1.45, 1.2],
    "Gaming Accessories": [.9, .9, .95, .95, 1.0, 1.15, 1.15, 1.0, 1.0, 1.05, 1.8, 1.8],
}
OVERALL_SEASON = np.array([1.02, .92, .95, .95, .97, 1.02, 1.0, 1.05, 1.05, 1.08, 1.5, 1.45])
DOW_FACTOR = np.array([.95, .90, .95, 1.0, 1.05, 1.12, 1.10])

# raw-material families: (family, variants, abbreviation, cost_low, cost_high)
FAMILIES = [("PCB Board", 4, "PCB", 3, 12), ("Battery Cell", 4, "BAT", 2, 9), ("Plastic Housing", 5, "HSG", .6, 3),
            ("Display Panel", 3, "DSP", 4, 22), ("Sensor Module", 4, "SNS", 1, 6), ("WiFi Module", 3, "WM", 2.5, 6),
            ("Bluetooth Module", 3, "BTM", 1.5, 4), ("Cable Assembly", 4, "CBL", .4, 2.5),
            ("USB Connector", 3, "USB", .2, 1.2), ("Microphone Capsule", 2, "MIC", .8, 2.5),
            ("Speaker Driver", 4, "SPK", 1.5, 7), ("Charging Coil", 2, "CHG", .8, 2.2),
            ("Lens Assembly", 3, "LNS", 1.5, 6), ("Silicone Strap", 3, "STP", .7, 2.5),
            ("Mechanical Switch", 3, "SWT", .2, .9), ("Packaging Box", 6, "PKG", .3, 1.4),
            ("Antenna", 3, "ANT", .5, 2), ("Heat Sink", 3, "HTS", .6, 2.4), ("Fan Module", 2, "FAN", 1, 3.5),
            ("IC Chip", 4, "ICX", 1.5, 9)]
CAT_FAMILIES = {
    "Smart Home": ["PCB Board", "WiFi Module", "Sensor Module", "Plastic Housing", "Lens Assembly", "IC Chip",
                   "Packaging Box", "Cable Assembly", "Antenna"],
    "Computer Accessories": ["PCB Board", "USB Connector", "Plastic Housing", "Mechanical Switch", "Cable Assembly",
                             "Sensor Module", "Packaging Box", "IC Chip", "Heat Sink"],
    "Mobile Accessories": ["Battery Cell", "Charging Coil", "Cable Assembly", "USB Connector", "Plastic Housing",
                           "PCB Board", "Packaging Box", "IC Chip"],
    "Audio": ["Speaker Driver", "Microphone Capsule", "Bluetooth Module", "Battery Cell", "PCB Board",
              "Plastic Housing", "Silicone Strap", "Packaging Box", "IC Chip"],
    "Wearables": ["Display Panel", "Battery Cell", "Sensor Module", "Silicone Strap", "Bluetooth Module",
                  "PCB Board", "Charging Coil", "Packaging Box", "IC Chip"],
    "Networking": ["PCB Board", "WiFi Module", "Antenna", "Heat Sink", "Fan Module", "Plastic Housing", "IC Chip",
                   "USB Connector", "Packaging Box", "Cable Assembly"],
    "Gaming Accessories": ["Mechanical Switch", "Sensor Module", "PCB Board", "Plastic Housing", "Cable Assembly",
                           "Bluetooth Module", "Speaker Driver", "Silicone Strap", "Packaging Box", "IC Chip"],
}
PLANT_BY_CAT = {  # category -> plant indices (0..4) and weights
    "Smart Home": ([1, 2], [.6, .4]), "Computer Accessories": ([0, 4], [.6, .4]),
    "Mobile Accessories": ([2, 3], [.5, .5]), "Audio": ([3, 2], [.7, .3]), "Wearables": ([3], [1.0]),
    "Networking": ([1, 0], [.7, .3]), "Gaming Accessories": ([0, 4, 3], [.4, .3, .3]),
}
DEFECT_TYPES = ["Cosmetic Flaw", "Dimensional Out-of-Spec", "Functional Failure", "Soldering Defect", "Packaging Damage"]
DEFECT_MIX = {  # probabilities by category
    "Smart Home": [.15, .15, .30, .30, .10], "Computer Accessories": [.25, .25, .25, .10, .15],
    "Mobile Accessories": [.25, .20, .25, .15, .15], "Audio": [.15, .15, .35, .25, .10],
    "Wearables": [.15, .15, .35, .30, .05], "Networking": [.10, .15, .35, .30, .10],
    "Gaming Accessories": [.25, .25, .25, .15, .10],
}
RETURN_REASONS = ["Defective / Not Working", "Not as Described", "Changed Mind", "Arrived Late",
                  "Wrong Item Shipped", "Better Price Elsewhere"]
FIRST = ["Aarav", "Maria", "Liam", "Sofia", "Chen", "Aisha", "Noah", "Emma", "Mateo", "Priya", "Oliver", "Yuki",
         "Lucas", "Fatima", "Ethan", "Hana", "Diego", "Anna", "Omar", "Lena", "Arjun", "Chloe", "Ravi", "Zoe",
         "Kenji", "Nora", "Tariq", "Ivy", "Luis", "Mei", "Sam", "Isla", "Ben", "Rhea", "Jack", "Amara", "Leo",
         "Sana", "Max", "Elif"]
LAST = ["Sharma", "Garcia", "Smith", "Rossi", "Wang", "Khan", "Johnson", "Muller", "Silva", "Patel", "Brown",
        "Tanaka", "Lopez", "Ali", "Davis", "Kim", "Fernandez", "Novak", "Hassan", "Fischer", "Reddy", "Martin",
        "Iyer", "Taylor", "Sato", "Costa", "Ahmed", "Evans", "Torres", "Zhang", "Nair", "Walker", "Cohen",
        "Singh", "Moreau", "Okafor", "Ricci", "Haddad", "Young", "Bianchi"]
SUP_PREFIX = ["Apex", "Vertex", "Quantum", "Sino", "Pacific", "Titan", "Orion", "Helix", "Zenith", "Aurora",
              "Summit", "Nimbus", "Cobalt", "Argon", "Lumen", "Pioneer", "Meridian", "Stellar", "Fusion", "Kinetic"]
SUP_SUFFIX = ["Components Ltd", "Electronics Co", "Industries", "Micro Systems", "Precision Parts",
              "Materials Inc", "Technologies", "Manufacturing Group"]
SUP_COUNTRIES = ["China", "China", "China", "Taiwan", "South Korea", "Japan", "Vietnam", "Germany", "United States",
                 "Mexico", "India", "Malaysia"]
MACHINE_TYPES = ["SMT Line", "Injection Molder", "Assembly Cell", "Ultrasonic Welder", "Test & Burn-in Station",
                 "Packaging Line"]
DT_TYPES = ["Mechanical Failure", "Electrical Failure", "Changeover", "Material Shortage", "Micro-stop",
            "Operator / Idle"]


def build_promotions():
    """Return list of promotions: (name, type, discount, start, end, categories or None for all)."""
    promos = []
    for y in (2023, 2024, 2025):
        promos += [
            (f"New Year Sale {y}", "Seasonal", .10, f"{y}-01-01", f"{y}-01-07", ["Wearables"]),
            (f"Spring Refresh {y}", "Seasonal", .15, f"{y}-03-15", f"{y}-03-24", ["Mobile Accessories"]),
            (f"Summer Sale {y}", "Seasonal", .20, f"{y}-06-20", f"{y}-07-05", ["Audio", "Gaming Accessories"]),
            (f"Back to School {y}", "Seasonal", .12, f"{y}-08-10", f"{y}-08-25", ["Computer Accessories"]),
            (f"Black Friday {y}", "Event", .25, f"{y}-11-24", f"{y}-11-30", None),
            (f"Cyber Week {y}", "Event", .20, f"{y}-12-01", f"{y}-12-04", ["Audio", "Gaming Accessories", "Smart Home"]),
            (f"Holiday Deals {y}", "Seasonal", .10, f"{y}-12-10", f"{y}-12-20", None),
        ]
    # 2025: deep clearance on Audio - drives revenue up while margin falls (investigation scenario 2)
    promos.append(("Audio Mega Clearance 2025", "Clearance", .30, "2025-02-01", "2025-04-15", ["Audio"]))
    promos.append(("Smart Home Spring Push 2025", "Seasonal", .18, "2025-04-20", "2025-05-10", ["Smart Home"]))
    return promos


def fill_lines(cells, qty, stock):
    """FIFO allocation of order lines against stock. Returns boolean 'filled' per line (original order)."""
    order = np.argsort(cells, kind="stable")
    c = cells[order]
    q = qty[order]
    cs = np.cumsum(q)
    start = np.r_[True, c[1:] != c[:-1]]
    base = np.maximum.accumulate(np.where(start, cs - q, 0))
    ok = (cs - base) <= stock[c]
    filled = np.zeros(len(cells), dtype=bool)
    filled[order] = ok
    np.subtract.at(stock, c[ok], q[ok])
    return filled


def gen(scale, seed, out):
    t0 = time.time()
    rng = np.random.default_rng(seed)
    log = lambda m: print(f"[{time.time() - t0:6.1f}s] {m}", flush=True)

    # ------------------------------------------------------------------ locations
    loc_rows, city_to_loc, reg_cities = [], {}, [[] for _ in REGIONS]
    for ri, r in enumerate(REGIONS):
        for city, st, cty in CITIES[r]:
            loc_rows.append((f"L{len(loc_rows) + 1:03d}", city, st, cty, r))
            city_to_loc[city] = len(loc_rows) - 1
            reg_cities[ri].append(len(loc_rows) - 1)
    locations = pd.DataFrame(loc_rows, columns=["location_id", "city", "state_province", "country", "region"])

    # ------------------------------------------------------------------ customers
    NC = max(200, int(20000 * scale))
    c_reg = rng.choice(5, NC, p=REGION_SHARE)
    c_loc = np.zeros(NC, dtype=int)
    for r in range(5):
        idx = np.where(c_reg == r)[0]
        c_loc[idx] = rng.choice(reg_cities[r], len(idx))
    base_share = 0.40
    signup = np.where(rng.random(NC) < base_share, -rng.integers(30, 900, NC),
                      (rng.beta(1.0, 0.85, NC) * ND).astype(int))
    churn_flag = rng.random(NC) < 0.45
    churn_day = np.where(churn_flag, signup + rng.exponential(420, NC).astype(int) + 60, 10 ** 6)
    c_act = rng.gamma(0.6, 1.0, NC) + 0.02
    c_ret = rng.lognormal(0, 0.5, NC) * np.where(rng.random(NC) < 0.03, 4.0, 1.0)
    fn = rng.choice(FIRST, NC)
    ln = rng.choice(LAST, NC)
    customers = pd.DataFrame({
        "customer_id": [f"C{i + 1:06d}" for i in range(NC)],
        "first_name": fn, "last_name": ln,
        "email": [f"{a.lower()}.{b.lower()}{i}@mail.example" for i, (a, b) in enumerate(zip(fn, ln))],
        "phone": [f"+{rng.integers(10, 99)}-{rng.integers(1000000, 9999999)}" for _ in range(NC)],
        "location_id": locations.location_id.values[c_loc],
        "signup_date": (START + pd.to_timedelta(signup, unit="D")).strftime("%Y-%m-%d"),
        "marketing_opt_in": rng.choice(["Y", "N"], NC, p=[.62, .38]),
    })
    log(f"customers {NC}")

    # ------------------------------------------------------------------ products
    cat_idx = np.repeat(np.arange(7), CAT_COUNT)
    NP = len(cat_idx)
    series = ["Core", "Pulse", "Edge", "Prime", "Aero", "Flux", "Orbit", "Vertex"]
    p_sub, p_name, p_price, p_cost_ratio = [], [], np.zeros(NP), np.zeros(NP)
    for i in range(NP):
        cat = CATEGORIES[cat_idx[i]]
        sub = rng.choice(SUBCATS[cat])
        p_sub.append(sub)
        p_name.append(f"Nova {rng.choice(series)} {sub} {rng.choice(['Mini', 'Pro', 'Max', 'Lite', 'S', 'X'])} {rng.integers(1, 9)}00")
        lo, hi = PRICE_RANGE[cat]
        p_price[i] = np.round(np.exp(rng.uniform(np.log(lo), np.log(hi))) / 5) * 5 - 0.01
        clo, chi = COST_RATIO[cat]
        p_cost_ratio[i] = rng.uniform(clo, chi)
    p_price = np.maximum(p_price, 7.99)
    p_cost = np.round(p_price * p_cost_ratio, 2)
    # cost inflation on Audio / Gaming in 2025 (materials), prices unchanged -> margin pressure
    infl = np.ones((3, NP))
    infl[1] = np.where(np.isin(cat_idx, [3, 6]), 1.02, 1.0)
    infl[2] = np.where(np.isin(cat_idx, [3, 6]), 1.07, np.where(np.isin(cat_idx, [1, 5]), 1.02, 1.0))
    p_weight = np.round(rng.uniform(.08, 1.6, NP) * np.where(np.isin(cat_idx, [5, 3]), 1.8, 1), 2)
    pop = rng.lognormal(0, 1.0, NP)
    pop /= pop.sum()
    launch = np.where(rng.random(NP) < .08, rng.integers(60, 700, NP), -rng.integers(100, 900, NP))
    plant_of = np.zeros(NP, dtype=int)
    for i in range(NP):
        pl, w = PLANT_BY_CAT[CATEGORIES[cat_idx[i]]]
        plant_of[i] = rng.choice(pl, p=w)
    def_base = np.array([DEFECT_BASE[CATEGORIES[c]] for c in cat_idx]) * rng.lognormal(0, .3, NP)
    # scenario: 12 Wearables / Fitness Bands produced at the Shenzhen plant with elevated defects
    wear = np.where((cat_idx == 4) & (plant_of == 3))[0]
    high_def = rng.choice(wear, min(12, len(wear)), replace=False)
    def_base[high_def] = rng.uniform(.06, .09, len(high_def))
    # scenario products
    cams = [i for i in range(NP) if p_sub[i] == "Smart Camera"]
    cams = sorted(cams, key=lambda i: -pop[i])[:2]                    # "Product X / Y"
    earbuds = sorted([i for i in range(NP) if p_sub[i] == "Earbuds"], key=lambda i: -pop[i])
    promo_pressure = earbuds[0]
    overprod = np.zeros(NP, dtype=bool)                                # production exceeds demand
    cand = [i for i in range(NP) if p_sub[i] in ("Mousepad", "Phone Case") and pop[i] < np.median(pop)]
    overprod[rng.choice(cand, min(24, len(cand)), replace=False)] = True
    # capacity multiple vs average demand: most products comfortable, a few constrained
    cap_mult = np.clip(rng.lognormal(np.log(2.4), .35, NP), 1.5, 6)
    constrained = list(cams) + [promo_pressure] + earbuds[1:3] + [i for i in np.argsort(-pop)[:60]
                                                                  if CATEGORIES[cat_idx[i]] in ("Audio", "Smart Home")][:8]
    cap_mult *= 1.6                                                    # headroom for ~20%/yr demand growth
    cap_mult[constrained] = rng.uniform(.95, 1.15, len(constrained))   # ...except the capacity-constrained products
    products = pd.DataFrame({
        "product_id": [f"P{i + 1:04d}" for i in range(NP)],
        "sku": [f"NV-{CATEGORIES[c][:2].upper()}-{i + 1:04d}" for i, c in enumerate(cat_idx)],
        "product_name": p_name, "category": [CATEGORIES[c] for c in cat_idx], "sub_category": p_sub,
        "list_price": np.round(p_price, 2), "unit_cost_2023": p_cost,
        "unit_cost_2024": np.round(p_cost * infl[1], 2), "unit_cost_2025": np.round(p_cost * infl[2], 2),
        "weight_kg": p_weight,
        "launch_date": (START + pd.to_timedelta(launch, unit="D")).strftime("%Y-%m-%d"),
        "manufacturing_plant_id": [f"PL{p + 1}" for p in plant_of],
    })
    log(f"products {NP}")

    # ------------------------------------------------------------------ materials, BOM
    mat_rows, fam_idx = [], defaultdict(list)
    for fam, nv, abbr, lo, hi in FAMILIES:
        for v in range(nv):
            mat_rows.append((fam, f"{fam} {abbr}-{(v + 1) * 100}", round(float(rng.uniform(lo, hi)), 2)))
            fam_idx[fam].append(len(mat_rows) - 1)
    NMAT = len(mat_rows)
    wm200 = [i for i, r in enumerate(mat_rows) if r[1] == "WiFi Module WM-200"][0]
    materials = pd.DataFrame({
        "material_id": [f"M{i + 1:03d}" for i in range(NMAT)], "material_name": [r[1] for r in mat_rows],
        "material_family": [r[0] for r in mat_rows], "standard_cost": [r[2] for r in mat_rows],
        "unit_of_measure": "EA"})
    BOM = np.zeros((NP + 1, NMAT))                                     # row NP is a padding row
    for i in range(NP):
        cat = CATEGORIES[cat_idx[i]]
        pool = list(CAT_FAMILIES[cat])
        must = [f for f in ("PCB Board", "Packaging Box") if f in pool]
        others = [f for f in pool if f not in must]
        fams = must + list(rng.choice(others, size=min(len(others), rng.integers(2, 5)), replace=False))
        for f in fams:
            v = rng.choice(fam_idx[f])
            if f == "WiFi Module":
                v = wm200 if (i in cams or rng.random() < .22) else rng.choice(fam_idx[f])
            BOM[i, v] = 1 if f in ("Packaging Box", "PCB Board", "Plastic Housing") else rng.integers(1, 3)
    bom_rows = [(f"P{i + 1:04d}", f"M{m + 1:03d}", BOM[i, m]) for i in range(NP) for m in np.where(BOM[i] > 0)[0]]
    bom = pd.DataFrame(bom_rows, columns=["product_id", "material_id", "qty_per_unit"])

    # ------------------------------------------------------------------ suppliers
    NS = 110
    names = [f"{a} {b}" for a in SUP_PREFIX for b in SUP_SUFFIX]
    names.remove("Apex Components Ltd")
    rng.shuffle(names)
    sup_names = ["Apex Components Ltd"] + names[:NS - 1]
    s_lead = np.clip(rng.lognormal(np.log(14), .45, NS), 5, 45)
    s_late = np.where(rng.random(NS) < .15, rng.uniform(.30, .50, NS), rng.uniform(.03, .14, NS))
    s_delay = rng.uniform(2, 8, NS)
    s_def = np.where(rng.random(NS) < .10, rng.uniform(.03, .06, NS), rng.uniform(.002, .02, NS))
    s_price = rng.uniform(.9, 1.15, NS)
    s_lead[0], s_late[0], s_delay[0], s_def[0], s_price[0] = 18, .18, 5, .012, .97   # supplier S001 "Supplier A"
    s_country = rng.choice(SUP_COUNTRIES, NS)
    suppliers = pd.DataFrame({
        "supplier_id": [f"S{i + 1:03d}" for i in range(NS)], "supplier_name": sup_names, "country": s_country,
        "supplier_tier": rng.choice(["Tier 1", "Tier 2", "Tier 3"], NS, p=[.3, .5, .2]),
        "payment_terms_days": rng.choice([30, 45, 60, 90], NS), "quoted_lead_time_days": np.round(s_lead).astype(int)})
    # supplier-material sourcing (2-3 suppliers per material, with share)
    mat_sup, mat_share, sm_rows = [], [], []
    for m in range(NMAT):
        k = rng.integers(2, 4)
        sel = list(rng.choice(np.arange(1, NS), k, replace=False))
        if m == wm200:
            sel = [0] + sel[:2]
            shares = np.array([.70, .18, .12])
        else:
            if rng.random() < .12:
                sel[0] = 0
            shares = np.sort(rng.dirichlet(np.ones(k) * 2))[::-1]
        mat_sup.append(sel)
        mat_share.append(shares / shares.sum())
        for s, sh in zip(sel, shares):
            sm_rows.append((f"S{s + 1:03d}", f"M{m + 1:03d}", round(float(sh), 3)))
    supplier_materials = pd.DataFrame(sm_rows, columns=["supplier_id", "material_id", "sourcing_share"])
    rop_days = np.array([np.mean([s_lead[s] for s in mat_sup[m]]) + 12 for m in range(NMAT)])

    # ------------------------------------------------------------------ warehouses, plants, machines, carriers
    wh_rows, wh_reg = [], []
    for r, cs in enumerate(WAREHOUSE_CITIES):
        for c in cs:
            wh_rows.append((f"W{len(wh_rows) + 1:02d}", f"{c} Distribution Center", f"L{city_to_loc[c] + 1:03d}",
                            REGIONS[r], int(rng.integers(40, 120)) * 1000))
            wh_reg.append(r)
    NW = len(wh_rows)
    warehouses = pd.DataFrame(wh_rows, columns=["warehouse_id", "warehouse_name", "location_id", "region", "capacity_units"])
    wh_reg = np.array(wh_reg)
    wh_mult = np.ones(NW)
    lean = [1, 7]                    # lean warehouses -> stockouts
    heavy = [4, 10]                  # heavy warehouses -> excess
    wh_mult[lean] = .45
    wh_mult[heavy] = 1.9
    wh_cap_w = warehouses.capacity_units.values.astype(float)
    reg_wh = [np.where(wh_reg == r)[0] for r in range(5)]
    reg_cdf = [np.cumsum(wh_cap_w[ix] / wh_cap_w[ix].sum()) for ix in reg_wh]
    NPL = 5
    plants = pd.DataFrame({
        "plant_id": [f"PL{i + 1}" for i in range(NPL)],
        "plant_name": [f"NovaTech {c} Plant" for c in PLANT_CITIES],
        "location_id": [f"L{city_to_loc[c] + 1:03d}" for c in PLANT_CITIES],
        "opened_year": [2012, 2016, 2018, 2010, 2020]})
    plant_perf = np.array([.93, .89, .84, .91, .80])
    plant_def = np.array([.9, 1.0, 1.1, 1.0, 1.5])
    plant_fail = np.array([.9, 1.0, 1.2, .95, 1.5])
    mach_per_plant = [19, 24, 14, 35, 18]
    mach_plant, mach_rows = [], []
    for pl in range(NPL):
        for k in range(mach_per_plant[pl]):
            mach_plant.append(pl)
            mach_rows.append((f"MC-PL{pl + 1}-{k + 1:02d}", f"PL{pl + 1}", f"Line {'ABCD'[k % 4]}",
                              MACHINE_TYPES[k % len(MACHINE_TYPES)], int(rng.integers(2010, 2024)),
                              rng.choice(["Siemens", "Fanuc", "ABB", "Yamaha", "Omron", "Mitsubishi"])))
    NM = len(mach_rows)
    mach_plant = np.array(mach_plant)
    machines = pd.DataFrame(mach_rows, columns=["machine_id", "plant_id", "production_line", "machine_type",
                                                "install_year", "manufacturer"])
    mach_speed = rng.uniform(.92, 1.08, NM)
    mach_perf = rng.uniform(.95, 1.03, NM)
    mach_def = rng.lognormal(0, .2, NM)
    p_fail = .05 * rng.lognormal(0, .45, NM) * plant_fail[mach_plant]
    bad = rng.choice(NM, 9, replace=False)                              # chronic downtime machines
    p_fail[bad] *= 4.5
    mach_def[bad] *= 1.6
    mach_sev = np.where(np.isin(np.arange(NM), bad), 1.8, 1.0) * rng.uniform(.8, 1.2, NM)
    pm_interval = rng.integers(60, 120, NM)
    pm_comply = np.where(np.isin(np.arange(NM), bad), .03, .6)
    elec_prob = rng.uniform(.2, .45, NM)
    carriers = pd.DataFrame({
        "carrier_id": [f"CR{i + 1}" for i in range(5)],
        "carrier_name": ["SwiftShip Express", "AeroParcel", "MetroPost", "GlobeLine Freight", "TransContinental Logistics"],
        "service_level": ["Express", "Express", "Standard", "Economy", "Standard"]})
    car_days = np.array([2.0, 2.2, 3.0, 4.5, 3.5])
    car_late = np.array([.03, .05, .09, .15, .20])
    car_cost = np.array([1.35, 1.25, 1.0, .75, .95])
    car_w = np.array([[.30, .25, .25, .12, .08], [.28, .25, .27, .12, .08], [.20, .20, .25, .15, .20],
                      [.15, .15, .20, .20, .30], [.15, .15, .20, .20, .30]])  # region x carrier

    # ------------------------------------------------------------------ promotions
    promo_defs = build_promotions()
    promo_disc = np.zeros((ND, 7))
    promo_id = -np.ones((ND, 7), dtype=int)
    promo_rows = []
    for j, (nm, tp, disc, s, e, cats) in enumerate(promo_defs):
        sd, ed = (pd.Timestamp(s) - START).days, (pd.Timestamp(e) - START).days
        cidx = list(range(7)) if cats is None else [CATEGORIES.index(c) for c in cats]
        for c in cidx:
            sl = slice(sd, ed + 1)
            better = promo_disc[sl, c] < disc
            promo_disc[sl, c] = np.where(better, disc, promo_disc[sl, c])
            promo_id[sl, c] = np.where(better, j, promo_id[sl, c])
        promo_rows.append((f"PR{j + 1:03d}", nm, tp, disc, s, e, "All" if cats is None else ", ".join(cats)))
    promotions = pd.DataFrame(promo_rows, columns=["promotion_id", "promotion_name", "promotion_type",
                                                   "discount_pct", "start_date", "end_date", "category_scope"])
    special = np.ones((ND, NP))
    for s, e in (("2024-11-24", "2024-11-30"), ("2025-06-20", "2025-07-05")):
        special[(pd.Timestamp(s) - START).days:(pd.Timestamp(e) - START).days + 1, promo_pressure] = 3.5

    # ------------------------------------------------------------------ demand calibration
    ORDERS_TARGET = 250000 * scale
    promo_any = promo_disc.max(1)
    growth = 1 + .20 * np.arange(ND) / 365
    day_f = OVERALL_SEASON[MONTH - 1] * DOW_FACTOR[DOW] * growth * (1 + 1.0 * promo_any)
    base_rate = ORDERS_TARGET / day_f.sum()
    n_orders_day = rng.poisson(base_rate * day_f)
    units_est = ORDERS_TARGET * 2.4 * 1.45
    d_base = pop * units_est / ND                                       # avg units/day per product
    cat_season = np.array([SEASON[c] for c in CATEGORIES])              # 7x12

    # machine <- product assignment
    MK = 9
    MP = -np.ones((NM, MK), dtype=int)
    cnt = np.zeros(NM, dtype=int)
    n_mach_prod = np.ones(NP, dtype=int)
    for pl in range(NPL):
        mlist = np.where(mach_plant == pl)[0]
        plist = [p for p in np.argsort(-pop) if plant_of[p] == pl]
        top = set(plist[:int(len(plist) * .15)])
        for r, p in enumerate(plist):
            targets = [mlist[r % len(mlist)]]
            if p in top or p in constrained:
                targets.append(mlist[(r + len(mlist) // 2) % len(mlist)])
            n_mach_prod[p] = len(targets)
            for m in targets:
                if cnt[m] < MK:
                    MP[m, cnt[m]] = p
                    cnt[m] += 1
    cap_run = np.maximum(8, np.ceil(3.0 * cap_mult * d_base / (2 * n_mach_prod))).astype(int)
    thr = np.where(overprod, 150.0, 18.0)                               # plant buffer target (days of demand)
    cover_wh = np.where(overprod, 4.0, 1.0) * 21.0
    # transit days warehouse <- plant
    plant_reg = np.array([0, 1, 2, 2, 3])
    transit = np.where(wh_reg[:, None] == plant_reg[None, :], rng.integers(2, 5, (NW, NPL)),
                       rng.integers(6, 15, (NW, NPL)))

    # ------------------------------------------------------------------ state
    ew_cell = (d_base[None, :] * (wh_cap_w / wh_cap_w.sum())[:, None]).reshape(-1) * .8 + 1e-4
    stock = np.ceil(21 * ew_cell).astype(np.int64)
    backlog = np.zeros(NW * NP, dtype=np.int64)
    in_transit = np.zeros(NW * NP, dtype=np.int64)
    plant_fg = np.ceil(d_base * 14).astype(np.int64)
    pending = defaultdict(list)
    arrivals = defaultdict(list)
    override = {}
    u0 = np.zeros((NPL, NMAT))
    for p in range(NP):
        u0[plant_of[p]] += d_base[p] * BOM[p]
    u = u0.copy() + 1e-6
    u_c = u0.copy()
    plant_mask = np.zeros((NPL, NP))
    plant_mask[plant_of, np.arange(NP)] = 1
    mat_stock = np.ceil(u0 * 25)
    on_order = np.zeros((NPL, NMAT))
    valid_cell = u0 > 0
    mat_arrivals = defaultdict(list)
    last_prod = -np.ones(NM, dtype=int)
    last_pm = -rng.integers(0, 60, NM)
    run_gid = 0
    cust_chunks, line_chunks = [], []
    snaps_wh, snaps_mat, snap_days = [], [], []
    po_rec, del_rec = [], []
    run_rec, dt_rec, wo_rec, def_rec = [], [], [], []
    n_lines_total = 0
    ewma_prod = d_base.copy() + 1e-3
    day_orders_offset = 0
    order_rows_cust, order_rows_day, order_rows_wh, order_rows_nl = [], [], [], []
    stockout_lines = 0

    def target_fn(day):
        floor_ = np.tile(launch + 20 <= day, NW) * np.repeat(np.maximum(1, np.round(wh_mult * 2)), NP)
        return np.maximum(np.ceil(np.tile(cover_wh, NW) * np.repeat(wh_mult, NP) * ew_cell), floor_)

    def serve_pending(cell, d):
        lst = pending[cell]
        while lst and stock[cell] >= lst[0][1]:
            g, q = lst.pop(0)
            stock[cell] -= q
            backlog[cell] -= q
            override[g] = d + 1
        if not lst:
            del pending[cell]

    log("simulation start")
    for d in range(ND):
        mo = MONTH[d] - 1
        # ---- 1. arrivals: warehouse transfers and raw materials
        if d in arrivals:
            for idx, q in arrivals.pop(d):
                np.add.at(stock, idx, q)
                np.add.at(in_transit, idx, -q)
                for c in np.unique(idx):
                    if c in pending:
                        serve_pending(c, d)
        if d in mat_arrivals:
            for pl_, m_, good_, ordq_ in mat_arrivals.pop(d):
                mat_stock[pl_, m_] += good_
                on_order[pl_, m_] = max(0.0, on_order[pl_, m_] - ordq_)

        # ---- 2. orders
        n = n_orders_day[d]
        if n > 0:
            active = (signup <= d) & (churn_day > d)
            pw = c_act * active
            cust = rng.choice(NC, n, p=pw / pw.sum())
            nl = np.minimum(1 + rng.poisson(1.4, n), 6)
            tl = nl.sum()
            w = pop * cat_season[cat_idx, mo] * (1 + 5 * promo_disc[d, cat_idx]) * (launch <= d) * special[d]
            prod = rng.choice(NP, tl, p=w / w.sum())
            cheap = p_price[prod] < 40
            qty = np.where(cheap, rng.choice([1, 2, 3, 4], tl, p=[.55, .28, .12, .05]),
                           rng.choice([1, 2, 3, 4], tl, p=[.80, .15, .04, .01]))
            reg = c_reg[cust]
            u_ = rng.random(n)
            whs = np.array([reg_wh[r][np.searchsorted(reg_cdf[r], x, side="left").clip(0, len(reg_wh[r]) - 1)]
                            for r, x in zip(reg, u_)])
            o_of_line = np.repeat(np.arange(n), nl)
            wh_line = whs[o_of_line]
            cells = wh_line * NP + prod
            filled = fill_lines(cells, qty, stock)
            fulfil = np.where(filled, d + (rng.random(tl) < .4).astype(int), -1)
            gidx = n_lines_total + np.arange(tl)
            for k in np.where(~filled)[0]:
                pending[cells[k]].append((gidx[k], qty[k]))
                backlog[cells[k]] += qty[k]
            stockout_lines += int((~filled).sum())
            cat_l = cat_idx[prod]
            pdisc = promo_disc[d, cat_l]
            coupon = np.where(rng.random(tl) < .08, rng.choice([.05, .10], tl), 0.0)
            disc = np.where(pdisc > 0, pdisc, coupon)
            pid = np.where(pdisc > 0, promo_id[d, cat_l], -1)
            line_chunks.append(pd.DataFrame({
                "o": day_orders_offset + o_of_line, "p": prod, "q": qty, "disc": disc, "promo": pid,
                "fulfil": fulfil, "d": d}))
            order_rows_cust.append(cust)
            order_rows_day.append(np.full(n, d))
            order_rows_wh.append(whs)
            order_rows_nl.append(nl)
            day_orders_offset += n
            n_lines_total += tl
            dem = np.zeros(NW * NP)
            np.add.at(dem, cells, qty)
            ew_cell = ew_cell * (1 - 1 / 28) + dem / 28
            ewma_prod = ew_cell.reshape(NW, NP).sum(0) + 1e-3
        else:
            ew_cell *= (1 - 1 / 28)

        # ---- 3. warehouse replenishment (Mon & Thu)
        if DOW[d] in (0, 3):
            target = target_fn(d)
            need = np.maximum(0, target - stock - in_transit + backlog).astype(np.int64).reshape(NW, NP)
            need_p = need.sum(0)
            frac = np.minimum(1.0, plant_fg / np.maximum(need_p, 1))
            send = np.floor(need * frac[None, :] + rng.random((NW, NP))).astype(np.int64)
            send = np.minimum(send, need)
            over = send.sum(0) > plant_fg
            send[:, over] = np.floor(need[:, over] * frac[None, over]).astype(np.int64)
            plant_fg -= send.sum(0)
            sf = send.reshape(-1)
            nz = np.nonzero(sf)[0]
            if len(nz):
                in_transit[nz] += sf[nz]
                w_i, p_i = nz // NP, nz % NP
                arr_d = d + transit[w_i, plant_of[p_i]] + rng.integers(0, 3, len(nz))
                for dd in np.unique(arr_d):
                    sel = arr_d == dd
                    arrivals[dd].append((nz[sel], sf[nz[sel]]))

        # ---- 4. maintenance (preventive) then production
        busy = np.zeros(NM, dtype=bool)
        due = ((d - last_pm) >= pm_interval) & (rng.random(NM) < pm_comply)
        for m in np.where(due)[0]:
            last_pm[m] = d
            busy[m] = True
            dur = float(np.round(rng.uniform(3, 8), 1))
            wo_rec.append((d, m, "Preventive", dur, float(np.round(rng.uniform(250, 900), 2)), -1))
        cons_today = np.zeros((NPL, NMAT))
        wants = np.maximum(0, target_fn(d) - stock - in_transit + backlog).reshape(NW, NP).sum(0)
        for shift in (1, 2):
            cover = (plant_fg - wants) / np.maximum(ewma_prod, .05)       # pull system: plant buffer net of warehouse needs
            ratio = np.where(launch + 30 <= d, cover / thr, np.inf)
            ratio_pad = np.append(ratio, np.inf)
            rm = ratio_pad[np.where(MP < 0, NP, MP)]
            k = rm.argmin(1)
            best = rm[np.arange(NM), k]
            psel = MP[np.arange(NM), k]
            run = (~busy) & (best < 1.0) & (psel >= 0)
            idx = np.where(run)[0]
            if len(idx) == 0:
                continue
            R = len(idx)
            mm, pp, pl = idx, psel[idx], mach_plant[idx]
            rate = cap_run[pp] / 480.0 * mach_speed[mm]
            changeover = np.where(last_prod[mm] != pp, rng.integers(10, 26, R), 0)
            pf = p_fail[mm] * (1 + (d - last_pm[mm]) / 150.0)
            fail = rng.random(R) < pf
            fail_min = np.where(fail, np.minimum(rng.lognormal(np.log(75), .7, R) * mach_sev[mm], 470), 0).round()
            micro = np.where(rng.random(R) < .22, rng.integers(3, 14, R), 0)
            idle = np.where(rng.random(R) < .03, rng.integers(15, 46, R), 0)
            down = np.minimum(changeover + fail_min + micro + idle, 470)
            # scale parts proportionally if capped
            sc = np.where(changeover + fail_min + micro + idle > 0,
                          down / np.maximum(changeover + fail_min + micro + idle, 1), 1)
            changeover, fail_min, micro, idle = (changeover * sc).round(), (fail_min * sc).round(), \
                (micro * sc).round(), (idle * sc).round()
            op0 = 480 - (changeover + fail_min + micro + idle)
            need_m = (rate * op0)[:, None] * BOM[pp]
            tot_need = np.zeros((NPL, NMAT))
            np.add.at(tot_need, pl, need_m)
            ratio_m = np.where(tot_need > 0, np.minimum(1.0, mat_stock / np.maximum(tot_need, 1e-9)), 1.0)
            fac = np.where(BOM[pp] > 0, ratio_m[pl], 1.0).min(1)
            short_min = ((1 - fac) * op0).round()
            op = op0 - short_min
            perf = np.clip(rng.normal(plant_perf[pl] * mach_perf[mm], .04), .5, 1.0)
            total = np.floor(rate * op * perf).astype(np.int64)
            drate = np.clip(def_base[pp] * plant_def[pl] * mach_def[mm] * rng.lognormal(0, .25, R), 0, .5)
            defects = rng.binomial(total, drate)
            good = total - defects
            cons = total[:, None] * BOM[pp]
            np.add.at(cons_today, pl, cons)
            np.add.at(mat_stock, pl, -cons)
            mat_stock = np.maximum(mat_stock, 0)
            np.add.at(plant_fg, pp, good)
            gids = run_gid + np.arange(R)
            run_gid += R
            run_rec.append(pd.DataFrame({
                "g": gids, "d": d, "shift": shift, "m": mm, "p": pp, "planned_min": 480,
                "downtime_min": (480 - op).astype(int), "operating_min": op.astype(int),
                "rate": np.round(rate, 5), "planned_qty": np.round(rate * 480, 1), "total": total,
                "good": good, "defects": defects}))
            for typ, arr in ((2, changeover), (0, fail_min), (4, micro), (5, idle), (3, short_min)):
                s_ = arr > 0
                if s_.any():
                    t_ = np.full(s_.sum(), typ)
                    if typ == 0:
                        t_ = np.where(rng.random(s_.sum()) < elec_prob[mm[s_]], 1, 0)
                    dt_rec.append(pd.DataFrame({"run": gids[s_], "d": d, "m": mm[s_], "type": t_, "min": arr[s_]}))
            big = fail_min >= 45
            for g_, m_, fm in zip(gids[big], mm[big], fail_min[big]):
                wo_rec.append((d, m_, "Corrective", float(np.round(fm / 60 * rng.uniform(1.2, 2.5), 1)),
                               float(np.round(rng.uniform(400, 3500), 2)), g_))
            hasdef = defects > 0
            if hasdef.any():
                cats_h = cat_idx[pp[hasdef]]
                probs = np.array([DEFECT_MIX[CATEGORIES[c]] for c in cats_h])
                rem = defects[hasdef].copy()
                remp = np.ones(len(rem))
                for j in range(5):
                    pj = probs[:, j] / np.maximum(remp, 1e-9)
                    cj = rng.binomial(rem, np.clip(pj, 0, 1)) if j < 4 else rem
                    s_ = cj > 0
                    if s_.any():
                        def_rec.append(pd.DataFrame({"run": gids[hasdef][s_], "type": j, "qty": cj[s_]}))
                    rem = rem - cj
                    remp = remp - probs[:, j]
            last_prod[mm] = pp
            # reduce 'busy' machines? one run per shift; machines remain available for shift 2

        # ---- 5. purchasing
        u_c = u_c * (1 - 1 / 30) + cons_today / 30
        u = np.maximum(1.15 * ((plant_mask * ewma_prod[None, :]) @ BOM[:NP]), 1.1 * u_c) + 1e-6
        pos = mat_stock + on_order
        trig = valid_cell & (u > 1e-4) & (pos <= u * rop_days[None, :])
        for pl_, m_ in zip(*np.where(trig)):
            qty_o = max(20, int(np.ceil(u[pl_, m_] * 4)))
            sup = mat_sup[m_][rng.choice(len(mat_sup[m_]), p=mat_share[m_])]
            promised = int(np.round(s_lead[sup] * rng.uniform(.92, 1.08)))
            lp, dm = s_late[sup], s_delay[sup]
            if sup == 0 and 548 <= d <= 685:                            # Jul-Nov 2024 Supplier A disruption
                lp, dm = .75, 14
            late = rng.random() < lp
            delay = int(np.ceil(rng.gamma(2.0, dm / 2.0))) if late else int(rng.choice([0, 0, 0, -1, -2]))
            actual = max(2, promised + delay)
            price = round(float(materials.standard_cost.values[m_] * s_price[sup] * (1 + .03 * YEAR_IDX[d]) *
                                rng.uniform(.97, 1.03)), 3)
            short = rng.random() < .06
            recvd = int(qty_o * (rng.uniform(.85, .98) if short else 1.0))
            rej = int(rng.binomial(recvd, min(.5, s_def[sup] * rng.uniform(.7, 1.3))))
            po_rec.append((d, pl_, sup, m_, qty_o, price, d + promised))
            arr = d + actual
            if arr < ND:
                del_rec.append((len(po_rec) - 1, arr, recvd, rej))
                mat_arrivals[arr].append((pl_, m_, recvd - rej, qty_o))
            on_order[pl_, m_] += qty_o

        # ---- 6. weekly snapshot (Sunday)
        if DOW[d] == 6:
            snap_days.append(d)
            snaps_wh.append((stock.copy().astype(np.int32), backlog.copy().astype(np.int32),
                             in_transit.copy().astype(np.int32)))
            snaps_mat.append((mat_stock.copy().astype(np.float32), on_order.copy().astype(np.float32)))
        if d % 180 == 0:
            log(f"day {d}/{ND} orders={day_orders_offset} runs={run_gid} POs={len(po_rec)}")

    log(f"simulation done: orders={day_orders_offset} lines={n_lines_total} runs={run_gid} POs={len(po_rec)} "
        f"backordered_lines={stockout_lines}")

    # ================================================================== build clean tables
    ol = pd.concat(line_chunks, ignore_index=True)
    if override:
        gi = np.fromiter(override.keys(), dtype=np.int64)
        gv = np.fromiter(override.values(), dtype=np.int64)
        ol.loc[gi, "fulfil"] = gv
    o_cust = np.concatenate(order_rows_cust)
    o_day = np.concatenate(order_rows_day)
    o_wh = np.concatenate(order_rows_wh)
    o_nl = np.concatenate(order_rows_nl)
    NO = len(o_cust)
    starts = np.r_[0, np.cumsum(o_nl)[:-1]]
    f_arr = ol.fulfil.values
    f_min = np.minimum.reduceat(f_arr, starts)
    f_max = np.maximum.reduceat(f_arr, starts)
    is_open = f_min < 0
    ship_day = np.where(is_open, -1, f_max + rng.integers(0, 2, NO))
    wait = ship_day - o_day
    cancel_p = .025 + np.where(is_open, 0.0, np.where(wait > 7, np.minimum(.5, .05 + .012 * (wait - 7)), 0))
    cancel_p = np.where(is_open & (ND - 1 - o_day > 30), .5, cancel_p)
    cancelled = rng.random(NO) < cancel_p
    reg_o = c_reg[o_cust]
    carr = np.minimum((rng.random(NO)[:, None] > np.cumsum(car_w[reg_o], 1)).sum(1), 4)
    transit_d = np.round(car_days[carr] * REGION_TRANSIT_FACTOR[reg_o] + rng.gamma(1.5, .6, NO)).astype(int).clip(1)
    peak = ((MONTH[o_day] == 11) & (DATES.day.values[o_day] >= 20)) | ((MONTH[o_day] == 12) & (DATES.day.values[o_day] <= 24))
    transit_d += np.where(peak & (rng.random(NO) < .35), rng.integers(1, 3, NO), 0)
    transit_d += np.where(rng.random(NO) < car_late[carr] * np.where(reg_o >= 3, 1.4, 1.0), rng.integers(2, 7, NO), 0)
    deliv_day = ship_day + transit_d
    promised_day = o_day + PROMISE_DAYS[reg_o]
    status = np.where(cancelled, "Cancelled", np.where(is_open, "Backordered",
                      np.where(deliv_day > ND - 1, "In Transit", "Delivered")))
    ts = lambda days: (START + pd.to_timedelta(days, unit="D")).strftime("%Y-%m-%d")
    ol["w"] = ol.q * p_weight[ol.p.values]
    ship_w = ol.groupby("o").w.sum().reindex(np.arange(NO)).values
    orders = pd.DataFrame({
        "order_id": [f"ORD-{i + 1:07d}" for i in range(NO)], "customer_id": customers.customer_id.values[o_cust],
        "order_date": ts(o_day), "order_status": status,
        "channel": rng.choice(["Web", "Mobile App"], NO, p=[.58, .42]),
        "payment_method": rng.choice(["Credit Card", "Debit Card", "PayPal", "Bank Transfer", "Wallet", "COD"], NO,
                                     p=[.38, .2, .17, .08, .12, .05]),
        "warehouse_id": warehouses.warehouse_id.values[o_wh], "promised_delivery_date": ts(promised_day)})
    yr = YEAR_IDX[ol.d.values]
    order_items = pd.DataFrame({
        "order_item_id": [f"OI-{i + 1:08d}" for i in range(len(ol))], "order_id": orders.order_id.values[ol.o.values],
        "product_id": products.product_id.values[ol.p.values], "quantity": ol.q.values,
        "unit_price": p_price[ol.p.values].round(2), "discount_pct": ol.disc.values.round(2),
        "promotion_id": np.where(ol.promo.values >= 0, [f"PR{x + 1:03d}" for x in ol.promo.values], None),
        "unit_cost": np.round(p_cost[ol.p.values] * infl[yr, ol.p.values], 2)})
    shp = np.where(~cancelled & ~is_open)[0]
    sw = ship_w[shp]
    ship_cost = np.round(3.5 + 1.1 * sw * car_cost[carr[shp]] * REGION_TRANSIT_FACTOR[reg_o[shp]] * .9 +
                         rng.uniform(0, 1.5, len(shp)), 2)
    shipments = pd.DataFrame({
        "shipment_id": [f"SHP-{i + 1:07d}" for i in range(len(shp))], "order_id": orders.order_id.values[shp],
        "carrier_id": carriers.carrier_id.values[carr[shp]], "warehouse_id": warehouses.warehouse_id.values[o_wh[shp]],
        "ship_date": ts(ship_day[shp]), "promised_delivery_date": ts(promised_day[shp]),
        "delivered_date": np.where(deliv_day[shp] <= ND - 1, ts(np.minimum(deliv_day[shp], ND - 1)), None),
        "shipping_cost": ship_cost, "weight_kg": np.round(sw, 2),
        "shipment_status": np.where(deliv_day[shp] <= ND - 1, "Delivered", "In Transit")})

    # returns
    ol["status"] = status[ol.o.values]
    ol["deliv"] = deliv_day[ol.o.values]
    ol["prom"] = promised_day[ol.o.values]
    el = ol[(ol.status == "Delivered")].copy()
    rb = np.array([RETURN_BASE[CATEGORIES[c]] for c in cat_idx])
    late = (el.deliv - el.prom).values
    pr_ = np.clip(rb[el.p.values] * (1 + 8 * def_base[el.p.values]) * c_ret[o_cust[el.o.values]] *
                  (1 + .5 * (late > 3)), 0, .6)
    rmask = rng.random(len(el)) < pr_
    rl = el[rmask]
    base_rp = np.array([.22, .18, .30, .08, .08, .14])
    rp = np.tile(base_rp, (len(rl), 1))
    rp[:, 0] *= 1 + 25 * def_base[rl.p.values]
    rp[:, 3] *= 1 + 4 * ((rl.deliv - rl.prom).values > 0)
    rp /= rp.sum(1, keepdims=True)
    reason_i = (rng.random(len(rl))[:, None] > np.cumsum(rp, 1)).sum(1).clip(0, 5)
    ret_day = rl.deliv.values + rng.integers(2, 31, len(rl))
    keep = ret_day <= ND - 1
    rl, reason_i, ret_day = rl[keep], reason_i[keep], ret_day[keep]
    qret = np.where(rng.random(len(rl)) < .7, rl.q.values, 1).clip(1, rl.q.values)
    returns = pd.DataFrame({
        "return_id": [f"RET-{i + 1:07d}" for i in range(len(rl))],
        "order_item_id": [f"OI-{i + 1:08d}" for i in rl.index.values],
        "order_id": orders.order_id.values[rl.o.values], "product_id": products.product_id.values[rl.p.values],
        "return_date": ts(ret_day), "quantity_returned": qret,
        "return_reason": np.array(RETURN_REASONS)[reason_i],
        "refund_amount": np.round(qret * p_price[rl.p.values] * (1 - rl.disc.values), 2),
        "restocked": np.where(reason_i == 0, "N", "Y")})
    log(f"orders={NO} items={len(order_items)} shipments={len(shipments)} returns={len(returns)}")

    # inventory snapshots
    ns_ = len(snap_days)
    cell_w = np.repeat(np.arange(NW), NP)
    cell_p = np.tile(np.arange(NP), NW)
    sd_arr = np.repeat(snap_days, NW * NP)
    inventory = pd.DataFrame({
        "snapshot_date": ts(sd_arr),
        "warehouse_id": np.tile(warehouses.warehouse_id.values[cell_w], ns_),
        "product_id": np.tile(products.product_id.values[cell_p], ns_),
        "qty_on_hand": np.concatenate([s[0] for s in snaps_wh]),
        "qty_backordered": np.concatenate([s[1] for s in snaps_wh]),
        "qty_in_transit": np.concatenate([s[2] for s in snaps_wh])})
    vp, vm = np.where(valid_cell)
    matinv = pd.DataFrame({
        "snapshot_date": np.repeat(ts(np.array(snap_days)), len(vp)),
        "plant_id": np.tile(plants.plant_id.values[vp], ns_), "material_id": np.tile(materials.material_id.values[vm], ns_),
        "qty_on_hand": np.concatenate([s[0][vp, vm] for s in snaps_mat]).round(0).astype(int),
        "qty_on_order": np.concatenate([s[1][vp, vm] for s in snaps_mat]).round(0).astype(int)})

    # purchasing
    po = pd.DataFrame(po_rec, columns=["d", "pl", "sup", "m", "qty", "price", "prom"])
    po_no = po.groupby(["d", "pl", "sup"]).ngroup()
    purchase_orders = pd.DataFrame({
        "po_line_id": [f"POL-{i + 1:07d}" for i in range(len(po))],
        "po_number": [f"PO-{x + 1:06d}" for x in po_no], "order_date": ts(po.d.values),
        "plant_id": plants.plant_id.values[po.pl.values], "supplier_id": suppliers.supplier_id.values[po.sup.values],
        "material_id": materials.material_id.values[po.m.values], "quantity_ordered": po.qty.values,
        "unit_price": po.price.values, "promised_date": ts(po.prom.values)})
    dl = pd.DataFrame(del_rec, columns=["po", "arr", "recv", "rej"])
    supplier_deliveries = pd.DataFrame({
        "receipt_id": [f"REC-{i + 1:07d}" for i in range(len(dl))],
        "po_line_id": purchase_orders.po_line_id.values[dl.po.values], "received_date": ts(dl.arr.values),
        "qty_received": dl.recv.values, "qty_rejected": dl.rej.values})

    # production
    rr = pd.concat(run_rec, ignore_index=True)
    production_runs = pd.DataFrame({
        "run_id": [f"RUN-{g + 1:07d}" for g in rr.g.values], "run_date": ts(rr.d.values), "shift": rr["shift"].values,
        "machine_id": machines.machine_id.values[rr.m.values], "plant_id": plants.plant_id.values[mach_plant[rr.m.values]],
        "product_id": products.product_id.values[rr.p.values], "planned_minutes": rr.planned_min.values,
        "downtime_minutes": rr.downtime_min.values, "operating_minutes": rr.operating_min.values,
        "rated_units_per_min": rr.rate.values, "planned_qty": rr.planned_qty.values,
        "total_units": rr.total.values, "good_units": rr.good.values, "defect_units": rr.defects.values})
    dd = pd.concat(dt_rec, ignore_index=True)
    downtime = pd.DataFrame({
        "downtime_id": [f"DT-{i + 1:07d}" for i in range(len(dd))], "run_id": [f"RUN-{g + 1:07d}" for g in dd.run.values],
        "event_date": ts(dd.d.values), "machine_id": machines.machine_id.values[dd.m.values],
        "plant_id": plants.plant_id.values[mach_plant[dd.m.values]],
        "downtime_type": np.array(DT_TYPES)[dd.type.values], "duration_minutes": dd["min"].values.astype(int),
        "is_planned": np.where(dd.type.values == 2, "Y", "N")})
    wo = pd.DataFrame(wo_rec, columns=["d", "m", "type", "dur", "cost", "g"])
    maintenance = pd.DataFrame({
        "work_order_id": [f"WO-{i + 1:06d}" for i in range(len(wo))], "machine_id": machines.machine_id.values[wo.m.values],
        "plant_id": plants.plant_id.values[mach_plant[wo.m.values]], "work_order_date": ts(wo.d.values),
        "maintenance_type": wo.type.values, "duration_hours": wo.dur.values, "cost": wo.cost.values,
        "triggered_by_run_id": np.where(wo.g.values >= 0, [f"RUN-{g + 1:07d}" for g in wo.g.values], None)})
    df_ = pd.concat(def_rec, ignore_index=True)
    defects = pd.DataFrame({
        "defect_id": [f"DEF-{i + 1:07d}" for i in range(len(df_))], "run_id": [f"RUN-{g + 1:07d}" for g in df_.run.values],
        "defect_type": np.array(DEFECT_TYPES)[df_.type.values], "defect_qty": df_.qty.values,
        "detection_stage": rng.choice(["In-line Inspection", "Final Test"], len(df_), p=[.6, .4]),
        "disposition": rng.choice(["Scrap", "Rework"], len(df_), p=[.8, .2])})
    log(f"runs={len(production_runs)} downtime={len(downtime)} maint={len(maintenance)} defects={len(defects)} "
        f"POs={len(purchase_orders)} deliveries={len(supplier_deliveries)} inventory={len(inventory)}")

    clean = dict(locations=locations, customers=customers, products=products, materials=materials, bom=bom,
                 suppliers=suppliers, supplier_materials=supplier_materials, warehouses=warehouses, plants=plants,
                 machines=machines, carriers=carriers, promotions=promotions, orders=orders, order_items=order_items,
                 shipments=shipments, returns=returns, inventory_snapshots=inventory, material_inventory_snapshots=matinv,
                 purchase_orders=purchase_orders, supplier_deliveries=supplier_deliveries,
                 production_runs=production_runs, downtime_events=downtime, maintenance_orders=maintenance,
                 defects=defects)
    return clean, dict(scenario_products=dict(supplier_a_cameras=[products.product_id[i] for i in cams],
                                              promo_pressure=products.product_id[promo_pressure],
                                              high_defect=[products.product_id[i] for i in high_def],
                                              overproduction_count=int(overprod.sum()),
                                              lean_warehouses=[f"W{i + 1:02d}" for i in lean],
                                              heavy_warehouses=[f"W{i + 1:02d}" for i in heavy],
                                              chronic_machines=[machines.machine_id[i] for i in bad],
                                              wm200_material=materials.material_id[wm200]),
                       c_ret=c_ret, o_cust=o_cust)


# ====================================================================== dirty injection
def inject_dirt(clean, aux, seed):
    rng = np.random.default_rng(seed + 1)
    raw = {k: v.copy() for k, v in clean.items()}
    man = {}

    def pick(df, frac, mask=None):
        pool = np.where(mask)[0] if mask is not None else np.arange(len(df))
        n = max(1, int(len(pool) * frac)) if len(pool) else 0
        return rng.choice(pool, n, replace=False) if n else np.array([], dtype=int)

    def set_(name, col, idx, vals, key):
        raw[name].iloc[idx, raw[name].columns.get_loc(col)] = vals
        man[key] = man.get(key, 0) + len(idx)

    def dup_rows(name, frac, key):
        df = raw[name]
        idx = pick(df, frac)
        raw[name] = pd.concat([df, df.iloc[idx]], ignore_index=True)
        man[key] = len(idx)

    def ddmmyyyy(s):
        return pd.to_datetime(s).dt.strftime("%d/%m/%Y")

    # ---- customers
    c = raw["customers"]
    nd = int(len(c) * .02)
    di = rng.choice(len(c), nd, replace=False)
    dups = c.iloc[di].copy()
    dups["customer_id"] = [f"C9{i + 1:05d}" for i in range(nd)]
    dups["first_name"] = dups.first_name.str.lower()
    dups["last_name"] = dups.last_name.str.upper() + " "
    raw["customers"] = pd.concat([c, dups], ignore_index=True)
    man["customers_duplicate_records"] = nd
    # repoint ~40% of those customers' orders to the duplicate id
    o = raw["orders"]
    mp = dict(zip(c.customer_id.values[di], dups.customer_id.values))
    cand = np.where(o.customer_id.isin(mp.keys()))[0]
    sw = cand[rng.random(len(cand)) < .4]
    o.iloc[sw, o.columns.get_loc("customer_id")] = o.customer_id.iloc[sw].map(mp).values
    man["orders_pointing_to_duplicate_customer"] = len(sw)
    c = raw["customers"]
    keep_email = c.customer_id.str.startswith("C9").values | c.customer_id.isin(c.customer_id.values[di]).values   # duplicates must stay matchable
    set_("customers", "email", pick(c, .015, ~keep_email), None, "customers_null_email")
    set_("customers", "phone", pick(c, .08), None, "customers_null_phone")
    ix = pick(c, .03)
    set_("customers", "first_name", ix, c.first_name.iloc[ix].values + "  ", "customers_whitespace_name")
    ix = pick(c, .02)
    set_("customers", "last_name", ix, c.last_name.iloc[ix].str.lower().values, "customers_lowercase_name")
    ix = pick(c, .02)
    set_("customers", "signup_date", ix, ddmmyyyy(c.signup_date.iloc[ix]).values, "customers_ddmmyyyy_signup")

    # ---- suppliers / products
    s = raw["suppliers"]
    ix = pick(s, .10)
    set_("suppliers", "country", ix, rng.choice(["china", "CHINA", " China", "Taiwan "], len(ix)), "suppliers_country_variants")
    p = raw["products"]
    variants = {"Smart Home": ["smart home", "SMART HOME", "Smart  Home", "Smart-Home"],
                "Computer Accessories": ["computer accessories", "Computer Accessory", "COMPUTER ACCESSORIES "],
                "Mobile Accessories": ["mobile accessories", "Mobile Accessory", "Mobile  Accessories"],
                "Audio": ["audio", "AUDIO", "Audio "], "Wearables": ["wearables", "Wearable", "WEARABLES"],
                "Networking": ["networking", "NETWORKING", "Networking "],
                "Gaming Accessories": ["gaming accessories", "Gaming Accessory", "GAMING ACCESSORIES"]}
    ix = pick(p, .08)
    set_("products", "category", ix, [rng.choice(variants[v]) for v in p.category.iloc[ix]], "products_category_variants")
    ix = pick(p, .02)
    set_("products", "product_name", ix, p.product_name.iloc[ix].values + "   ", "products_trailing_whitespace")
    dup_rows("products", .006, "products_duplicate_rows")

    # ---- orders
    o = raw["orders"]
    sm = {"Delivered": ["delivered", "DELIVERED", "Delivrd", "Delivered "], "Cancelled": ["canceled", "CANCELLED", "cancelled"],
          "In Transit": ["in transit", "IN_TRANSIT"], "Backordered": ["backordered", "Back-ordered"]}
    ix = pick(o, .025)
    set_("orders", "order_status", ix, [rng.choice(sm[v]) for v in o.order_status.iloc[ix]], "orders_status_variants")
    ix = pick(o, .001)
    set_("orders", "order_status", ix, rng.choice(["unknown", "N/A", "???"], len(ix)), "orders_invalid_status")
    ix = pick(o, .004)
    set_("orders", "order_date", ix, ddmmyyyy(o.order_date.iloc[ix]).values, "orders_ddmmyyyy_date")
    ix = pick(o, .0003)
    set_("orders", "order_date", ix, None, "orders_null_order_date")
    ix = pick(o, .03)
    set_("orders", "payment_method", ix, o.payment_method.iloc[ix].str.upper().values, "orders_payment_case")
    dup_rows("orders", .002, "orders_duplicate_rows")

    # ---- order items
    oi = raw["order_items"]
    ix = pick(oi, .0005)
    set_("order_items", "quantity", ix, -oi.quantity.iloc[ix].values, "order_items_negative_qty")
    ix = pick(oi, .0004)
    set_("order_items", "product_id", ix, "P9999", "order_items_invalid_product")
    ix = pick(oi, .003)
    set_("order_items", "product_id", ix, " " + oi.product_id.iloc[ix].str.lower().values, "order_items_product_case_whitespace")
    dup_rows("order_items", .002, "order_items_duplicate_rows")

    # ---- shipments
    sh = raw["shipments"]
    ix = pick(sh, .0005, sh.delivered_date.notna().values)
    set_("shipments", "delivered_date", ix, "2024-02-30", "shipments_invalid_delivered_date")
    ix = pick(sh, .0008, sh.delivered_date.notna().values)
    set_("shipments", "delivered_date", ix, None, "shipments_null_delivered_date")
    ix = pick(sh, .005)
    set_("shipments", "carrier_id", ix, sh.carrier_id.iloc[ix].str.lower().values + " ", "shipments_carrier_case_whitespace")
    ix = pick(sh, .02)
    set_("shipments", "shipment_status", ix, sh.shipment_status.iloc[ix].str.upper().values, "shipments_status_case")
    dup_rows("shipments", .002, "shipments_duplicate_rows")

    # ---- returns
    r = raw["returns"]
    ix = pick(r, .03)
    set_("returns", "return_reason", ix, r.return_reason.iloc[ix].str.lower().values, "returns_reason_case")
    ix = pick(r, .001)
    set_("returns", "return_date", ix, "2022-12-31", "returns_date_before_order")
    dup_rows("returns", .0015, "returns_duplicate_rows")

    # ---- inventory snapshots
    iv = raw["inventory_snapshots"]
    ix = pick(iv, .0001)
    set_("inventory_snapshots", "qty_on_hand", ix, -3, "inventory_negative_qty")
    ix = pick(iv, .0005)
    set_("inventory_snapshots", "product_id", ix, iv.product_id.iloc[ix].values + " ", "inventory_product_trailing_space")
    dup_rows("inventory_snapshots", .0005, "inventory_duplicate_rows")

    # ---- purchasing
    po = raw["purchase_orders"]
    ix = pick(po, .003)
    set_("purchase_orders", "supplier_id", ix, None, "purchase_orders_null_supplier")
    ix = pick(po, .0002)
    set_("purchase_orders", "quantity_ordered", ix, -po.quantity_ordered.iloc[ix].values, "purchase_orders_negative_qty")
    ix = pick(po, .005)
    set_("purchase_orders", "supplier_id", ix, po.supplier_id.iloc[ix].str.lower().values, "purchase_orders_supplier_case")
    sd = raw["supplier_deliveries"]
    ix = pick(sd, .0005)
    set_("supplier_deliveries", "received_date", ix, "2022-06-15", "deliveries_date_before_po")

    # ---- production / downtime / defects / maintenance
    pr = raw["production_runs"]
    ix = pick(pr, .003)
    set_("production_runs", "machine_id", ix, pr.machine_id.iloc[ix].str.lower().values, "runs_machine_case")
    ix = pick(pr, .0002)
    set_("production_runs", "total_units", ix, -5, "runs_negative_units")
    ix = pick(pr, .0002)
    set_("production_runs", "good_units", ix, pr.total_units.iloc[ix].values + 7, "runs_good_gt_total")
    dt = raw["downtime_events"]
    ix = pick(dt, .0002)
    set_("downtime_events", "duration_minutes", ix, -10, "downtime_negative_duration")
    dup_rows("downtime_events", .001, "downtime_duplicate_rows")
    mo = raw["maintenance_orders"]
    set_("maintenance_orders", "cost", pick(mo, .005), None, "maintenance_null_cost")
    de = raw["defects"]
    ix = pick(de, .02)
    set_("defects", "defect_type", ix, de.defect_type.iloc[ix].str.lower().values, "defects_type_case")
    return raw, man


def main():
    ap = argparse.ArgumentParser(description="Generate ChainSight synthetic RAW data")
    ap.add_argument("--scale", type=float, default=1.0, help="1.0 = ~250k orders; 0.1 = quick test")
    ap.add_argument("--seed", type=int, default=42)
    ap.add_argument("--out", default=os.path.join(os.path.dirname(__file__), "..", "data", "raw"))
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    clean, aux = gen(a.scale, a.seed, a.out)
    raw, man = inject_dirt(clean, aux, a.seed)
    for name, df in raw.items():
        df.to_csv(os.path.join(a.out, f"{name}.csv"), index=False, na_rep="")
    proc = os.path.join(a.out, "..", "processed")
    os.makedirs(proc, exist_ok=True)
    meta = {"seed": a.seed, "scale": a.scale, "clean_row_counts": {k: len(v) for k, v in clean.items()},
            "raw_row_counts": {k: len(v) for k, v in raw.items()}, "injected_issues": man,
            "scenarios": aux["scenario_products"]}
    json.dump(meta, open(os.path.join(proc, "generation_manifest.json"), "w"), indent=2, default=str)
    print(json.dumps({"raw_row_counts": meta["raw_row_counts"]}, indent=1))


if __name__ == "__main__":
    main()
