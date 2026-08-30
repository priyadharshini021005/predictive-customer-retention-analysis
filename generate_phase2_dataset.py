from __future__ import annotations

import csv
import json
import random
from collections import Counter, defaultdict
from datetime import date, timedelta
from decimal import Decimal, ROUND_HALF_UP
from pathlib import Path

ROOT = Path('/home/ubuntu/Predictive Customer Retention Analysis using SQL')
DATA_DIR = ROOT / 'data' / 'raw'
EVIDENCE_DIR = ROOT / 'evidence' / 'validation_outputs'

SEED = 20260821
rng = random.Random(SEED)

ANALYSIS_START = date(2024, 1, 1)
ANALYSIS_END = date(2025, 12, 31)
SIGNUP_START = date(2023, 6, 1)
SIGNUP_END = date(2025, 11, 30)

N_CUSTOMERS = 8000
N_PRODUCTS = 180
TARGET_ORDERS = 40000

CITIES = [
    ('New York', 'NY'), ('Los Angeles', 'CA'), ('Chicago', 'IL'),
    ('Houston', 'TX'), ('Phoenix', 'AZ'), ('Philadelphia', 'PA'),
    ('San Antonio', 'TX'), ('San Diego', 'CA'), ('Dallas', 'TX'),
    ('San Jose', 'CA'), ('Austin', 'TX'), ('Jacksonville', 'FL'),
    ('Fort Worth', 'TX'), ('Columbus', 'OH'), ('Charlotte', 'NC'),
    ('Seattle', 'WA'), ('Denver', 'CO'), ('Washington', 'DC'),
    ('Nashville', 'TN'), ('Boston', 'MA'), ('Portland', 'OR'),
    ('Las Vegas', 'NV'), ('Atlanta', 'GA'), ('Miami', 'FL'),
]
CITY_WEIGHTS = [11, 10, 9, 8, 7, 7, 6, 6, 6, 5, 5, 5, 5, 5, 5, 5, 5, 4, 4, 4, 4, 4, 4, 4]

GENDERS = ['Female', 'Male', 'Non-binary', 'Prefer not to say']
GENDER_WEIGHTS = [0.48, 0.45, 0.04, 0.03]
AGE_BANDS = ['18-24', '25-34', '35-44', '45-54', '55-64', '65+']
AGE_WEIGHTS = [0.11, 0.27, 0.25, 0.18, 0.13, 0.06]
ACQUISITION_CHANNELS = ['Organic Search', 'Paid Search', 'Social Media', 'Email', 'Referral', 'Direct']
ACQUISITION_WEIGHTS = [0.24, 0.18, 0.18, 0.14, 0.12, 0.14]
CUSTOMER_STATUSES = ['Active', 'Inactive']
CUSTOMER_STATUS_WEIGHTS = [0.90, 0.10]

CATEGORIES = [
    ('Electronics', 0.13, (35, 850)),
    ('Home & Kitchen', 0.12, (18, 420)),
    ('Apparel', 0.11, (15, 220)),
    ('Beauty & Personal Care', 0.09, (10, 180)),
    ('Sports & Outdoors', 0.09, (18, 500)),
    ('Books & Media', 0.08, (8, 130)),
    ('Toys & Games', 0.08, (12, 260)),
    ('Grocery & Gourmet', 0.08, (6, 95)),
    ('Pet Supplies', 0.07, (8, 170)),
    ('Office & Stationery', 0.06, (5, 120)),
    ('Garden & Tools', 0.05, (12, 380)),
    ('Travel & Accessories', 0.04, (15, 300)),
]
CATEGORY_NAMES = [row[0] for row in CATEGORIES]
CATEGORY_WEIGHTS = [row[1] for row in CATEGORIES]
CATEGORY_RANGES = {row[0]: row[2] for row in CATEGORIES}

PAYMENT_METHODS = ['Credit Card', 'Debit Card', 'Digital Wallet', 'Bank Transfer']
PAYMENT_WEIGHTS = [0.48, 0.25, 0.22, 0.05]
SALES_CHANNELS = ['Web', 'Mobile App', 'Marketplace', 'Retail Store']
PROFILE_CHANNEL_WEIGHTS = {
    'loyal': [0.43, 0.31, 0.16, 0.10],
    'regular': [0.46, 0.25, 0.19, 0.10],
    'occasional': [0.49, 0.20, 0.22, 0.09],
    'dormant': [0.55, 0.15, 0.20, 0.10],
    'one_time': [0.47, 0.18, 0.25, 0.10],
}
ORDER_STATUSES = ['Completed', 'Cancelled', 'Returned', 'Pending']
BASKET_SIZE_VALUES = [1, 2, 3, 4, 5]
BASKET_SIZE_WEIGHTS = [0.10, 0.25, 0.35, 0.23, 0.07]

PROFILE_COUNTS = {
    'loyal': 1000,
    'regular': 2500,
    'occasional': 2000,
    'dormant': 1500,
    'one_time': 500,
    'prospect': 500,
}
PROFILE_ORDER_COUNTS = {
    'loyal': 14,
    'regular': 8,
    'occasional': 2,
    'dormant': 1,
    'one_time': 1,
    'prospect': 0,
}


def q2(value: Decimal | float | int) -> Decimal:
    return Decimal(str(value)).quantize(Decimal('0.01'), rounding=ROUND_HALF_UP)


def money(value: Decimal) -> str:
    return f'{q2(value):.2f}'


def random_date(start: date, end: date) -> date:
    if start > end:
        raise ValueError(f'Invalid date range: {start} to {end}')
    return start + timedelta(days=rng.randint(0, (end - start).days))


def distinct_dates(start: date, end: date, count: int) -> list[date]:
    if count == 0:
        return []
    available = (end - start).days + 1
    if available < count:
        return [start + timedelta(days=min(i, available - 1)) for i in range(count)]
    return sorted(rng.sample(range(available), count)) and [
        start + timedelta(days=offset) for offset in sorted(rng.sample(range(available), count))
    ]


def weighted_recent_date(start: date, end: date, concentration: float) -> date:
    span = (end - start).days
    # A beta-like transformation creates more observations near the end while retaining history.
    u = rng.random()
    position = int((u ** concentration) * span)
    return start + timedelta(days=min(position, span))


def make_profiles() -> dict[int, str]:
    # Reserve two loyal customers for the explicit analysis-window boundary orders,
    # then shuffle the remaining customer profiles without changing planned counts.
    profiles: list[str] = ['loyal', 'loyal']
    for profile, count in PROFILE_COUNTS.items():
        remaining = count - 2 if profile == 'loyal' else count
        profiles.extend([profile] * remaining)
    tail = profiles[2:]
    rng.shuffle(tail)
    profiles = profiles[:2] + tail
    return {customer_id: profiles[customer_id - 1] for customer_id in range(1, N_CUSTOMERS + 1)}


def generate_customers(profiles: dict[int, str]) -> tuple[list[dict], dict[int, tuple[str, str]]]:
    customers = []
    locations: dict[int, tuple[str, str]] = {}
    for customer_id in range(1, N_CUSTOMERS + 1):
        profile = profiles[customer_id]
        if customer_id == 1:
            signup_date = date(2023, 6, 1)
        elif customer_id == 2:
            signup_date = date(2023, 7, 15)
        elif profile == 'dormant':
            signup_date = random_date(SIGNUP_START, date(2024, 3, 31))
        else:
            signup_date = random_date(SIGNUP_START, SIGNUP_END)
        city, state = rng.choices(CITIES, weights=CITY_WEIGHTS, k=1)[0]
        locations[customer_id] = (city, state)
        customers.append({
            'customer_id': customer_id,
            'customer_code': f'CUST-{customer_id:05d}',
            'signup_date': signup_date.isoformat(),
            'gender': rng.choices(GENDERS, weights=GENDER_WEIGHTS, k=1)[0],
            'age_band': rng.choices(AGE_BANDS, weights=AGE_WEIGHTS, k=1)[0],
            'city': city,
            'state': state,
            'acquisition_channel': rng.choices(ACQUISITION_CHANNELS, weights=ACQUISITION_WEIGHTS, k=1)[0],
            'customer_status': rng.choices(CUSTOMER_STATUSES, weights=CUSTOMER_STATUS_WEIGHTS, k=1)[0],
        })
    return customers, locations


def generate_products() -> tuple[list[dict], dict[int, str], dict[int, Decimal], dict[int, date]]:
    products = []
    product_category: dict[int, str] = {}
    product_price: dict[int, Decimal] = {}
    product_launch: dict[int, date] = {}
    product_id = 1
    for category, _, price_range in CATEGORIES:
        for item_number in range(1, 16):
            low, high = price_range
            base_price = q2(rng.uniform(low, high))
            cost_price = q2(base_price * Decimal(str(rng.uniform(0.48, 0.78))))
            launch_date = random_date(date(2023, 1, 1), date(2025, 3, 31))
            if product_id <= 12:
                launch_date = date(2023, 1, 1)
            discontinued = rng.random() < 0.08
            product_name = f'{category} {item_number:02d}'
            products.append({
                'product_id': product_id,
                'sku': f'SKU-{product_id:05d}',
                'product_name': product_name,
                'category': category,
                'unit_price': money(base_price),
                'cost_price': money(cost_price),
                'launch_date': launch_date.isoformat(),
                'product_status': 'Discontinued' if discontinued else 'Active',
            })
            product_category[product_id] = category
            product_price[product_id] = base_price
            product_launch[product_id] = launch_date
            product_id += 1
    return products, product_category, product_price, product_launch


def make_customer_preferences(profiles: dict[int, str]) -> dict[int, list[str]]:
    preferences: dict[int, list[str]] = {}
    for customer_id, profile in profiles.items():
        if profile == 'prospect':
            preferences[customer_id] = []
            continue
        n_pref = 3 if profile in {'loyal', 'regular'} else 2
        preferences[customer_id] = rng.choices(CATEGORY_NAMES, weights=CATEGORY_WEIGHTS, k=n_pref)
    return preferences


def order_dates_for_profile(profile: str, signup_date: date, count: int) -> list[date]:
    if count == 0:
        return []
    first_possible = max(ANALYSIS_START, signup_date)
    if profile == 'dormant':
        return [random_date(first_possible, date(2024, 6, 30))]
    if profile == 'one_time':
        return [weighted_recent_date(first_possible, ANALYSIS_END, 1.25)]
    if profile == 'occasional':
        first = weighted_recent_date(first_possible, date(2025, 5, 31), 1.05)
        second_start = min(first + timedelta(days=30), ANALYSIS_END)
        if second_start > ANALYSIS_END:
            second_start = first_possible
        second = weighted_recent_date(second_start, ANALYSIS_END, 1.10)
        if second < first:
            first, second = second, first
        return sorted({first, second}) if first != second else [first, min(first + timedelta(days=30), ANALYSIS_END)]
    concentration = 0.82 if profile == 'loyal' else 0.98
    dates: set[date] = set()
    while len(dates) < count:
        dates.add(weighted_recent_date(first_possible, ANALYSIS_END, concentration))
    return sorted(dates)


def choose_product(
    order_date: date,
    preferred_categories: list[str],
    product_category: dict[int, str],
    product_launch: dict[int, date],
    product_popularity: dict[int, float],
    used_products: set[int],
) -> int:
    available = [pid for pid, launch in product_launch.items() if launch <= order_date and pid not in used_products]
    if not available:
        available = [pid for pid in product_launch if pid not in used_products]
    preferred = [pid for pid in available if product_category[pid] in preferred_categories]
    pool = preferred if preferred and rng.random() < 0.68 else available
    weights = [product_popularity[pid] for pid in pool]
    return rng.choices(pool, weights=weights, k=1)[0]


def generate_orders_and_items(
    customers: list[dict],
    profiles: dict[int, str],
    locations: dict[int, tuple[str, str]],
    product_category: dict[int, str],
    product_price: dict[int, Decimal],
    product_launch: dict[int, date],
    preferences: dict[int, list[str]],
) -> tuple[list[dict], list[dict]]:
    product_popularity = {pid: rng.uniform(0.55, 2.80) for pid in product_category}
    raw_orders: list[dict] = []
    order_items: list[dict] = []
    provisional_id = 1
    customer_by_id = {row['customer_id']: row for row in customers}

    for customer_id in range(1, N_CUSTOMERS + 1):
        profile = profiles[customer_id]
        order_count = PROFILE_ORDER_COUNTS[profile]
        if order_count == 0:
            continue
        signup_date = date.fromisoformat(customer_by_id[customer_id]['signup_date'])
        order_dates = order_dates_for_profile(profile, signup_date, order_count)
        if customer_id == 1:
            order_dates[0] = ANALYSIS_START
            order_dates = sorted(set(order_dates))
            while len(order_dates) < order_count:
                candidate = weighted_recent_date(ANALYSIS_START, ANALYSIS_END, 0.82)
                if candidate not in order_dates:
                    order_dates.append(candidate)
            order_dates = sorted(order_dates)
        if customer_id == 2:
            order_dates[-1] = ANALYSIS_END
            order_dates = sorted(set(order_dates))
            while len(order_dates) < order_count:
                candidate = weighted_recent_date(ANALYSIS_START, ANALYSIS_END, 0.82)
                if candidate not in order_dates:
                    order_dates.append(candidate)
            order_dates = sorted(order_dates)
        for order_date in order_dates:
            sales_channel = rng.choices(SALES_CHANNELS, weights=PROFILE_CHANNEL_WEIGHTS[profile], k=1)[0]
            payment_method = rng.choices(PAYMENT_METHODS, weights=PAYMENT_WEIGHTS, k=1)[0]
            customer_city, customer_state = locations[customer_id]
            if rng.random() < 0.90:
                shipping_city, shipping_state = customer_city, customer_state
            else:
                shipping_city, shipping_state = rng.choices(CITIES, weights=CITY_WEIGHTS, k=1)[0]
            raw_orders.append({
                '_provisional_id': provisional_id,
                'customer_id': customer_id,
                'order_date': order_date,
                'payment_method': payment_method,
                'sales_channel': sales_channel,
                'shipping_city': shipping_city,
                'shipping_state': shipping_state,
                'profile': profile,
            })
            provisional_id += 1

    if len(raw_orders) != TARGET_ORDERS:
        raise AssertionError(f'Expected {TARGET_ORDERS} orders, created {len(raw_orders)}')

    raw_orders.sort(key=lambda row: (row['order_date'], row['customer_id'], row['_provisional_id']))
    # Assign status after sorting, then force the two boundary orders to be completed.
    noncompleted_count = 4500
    noncompleted_indices = rng.sample(range(len(raw_orders)), noncompleted_count)
    status_by_index: dict[int, str] = {}
    rng.shuffle(noncompleted_indices)
    for idx in noncompleted_indices[:2200]:
        status_by_index[idx] = 'Cancelled'
    for idx in noncompleted_indices[2200:3500]:
        status_by_index[idx] = 'Returned'
    for idx in noncompleted_indices[3500:]:
        status_by_index[idx] = 'Pending'
    boundary_indices = {
        idx for idx, row in enumerate(raw_orders)
        if (row['customer_id'] == 1 and row['order_date'] == ANALYSIS_START)
        or (row['customer_id'] == 2 and row['order_date'] == ANALYSIS_END)
    }
    for idx in boundary_indices:
        status_by_index.pop(idx, None)

    orders: list[dict] = []
    next_item_id = 1
    for order_id, row in enumerate(raw_orders, start=1):
        status = status_by_index.get(order_id - 1, 'Completed')
        basket_size = rng.choices(BASKET_SIZE_VALUES, weights=BASKET_SIZE_WEIGHTS, k=1)[0]
        used_products: set[int] = set()
        item_rows = []
        for _ in range(basket_size):
            product_id = choose_product(
                row['order_date'], preferences[row['customer_id']], product_category,
                product_launch, product_popularity, used_products,
            )
            used_products.add(product_id)
            quantity = rng.randint(1, 5)
            unit_price = product_price[product_id]
            gross = q2(unit_price * quantity)
            discount_rate = rng.choices([0.00, 0.05, 0.10, 0.15, 0.20], weights=[0.48, 0.22, 0.17, 0.10, 0.03], k=1)[0]
            line_discount = q2(gross * Decimal(str(discount_rate)))
            line_total = q2(gross - line_discount)
            item_rows.append({
                'order_item_id': next_item_id,
                'order_id': order_id,
                'product_id': product_id,
                'quantity': quantity,
                'unit_price': money(unit_price),
                'line_discount': money(line_discount),
                'line_total': money(line_total),
            })
            next_item_id += 1
        order_discount = q2(sum((Decimal(item['line_discount']) for item in item_rows), Decimal('0.00')))
        if row['sales_channel'] == 'Retail Store':
            shipping_amount = Decimal('0.00')
        else:
            shipping_amount = q2(rng.choice([0, 0, 4.99, 7.99, 12.99, 19.99, 29.99]))
        orders.append({
            'order_id': order_id,
            'order_number': f'ORD-{order_id:06d}',
            'customer_id': row['customer_id'],
            'order_date': row['order_date'].isoformat(),
            'order_status': status,
            'payment_method': row['payment_method'],
            'sales_channel': row['sales_channel'],
            'shipping_city': row['shipping_city'],
            'shipping_state': row['shipping_state'],
            'discount_amount': money(order_discount),
            'shipping_amount': money(shipping_amount),
        })
        order_items.extend(item_rows)

    return orders, order_items


def write_csv(path: Path, rows: list[dict], fieldnames: list[str]) -> None:
    with path.open('w', newline='', encoding='utf-8') as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def main() -> None:
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    EVIDENCE_DIR.mkdir(parents=True, exist_ok=True)
    profiles = make_profiles()
    customers, locations = generate_customers(profiles)
    products, product_category, product_price, product_launch = generate_products()
    preferences = make_customer_preferences(profiles)
    orders, order_items = generate_orders_and_items(
        customers, profiles, locations, product_category, product_price, product_launch, preferences,
    )

    write_csv(DATA_DIR / 'customers.csv', customers, list(customers[0].keys()))
    write_csv(DATA_DIR / 'products.csv', products, list(products[0].keys()))
    write_csv(DATA_DIR / 'orders.csv', orders, list(orders[0].keys()))
    write_csv(DATA_DIR / 'order_items.csv', order_items, list(order_items[0].keys()))

    report = {
        'seed': SEED,
        'analysis_start': ANALYSIS_START.isoformat(),
        'analysis_end': ANALYSIS_END.isoformat(),
        'reference_date': ANALYSIS_END.isoformat(),
        'row_counts': {
            'customers': len(customers),
            'products': len(products),
            'orders': len(orders),
            'order_items': len(order_items),
        },
        'profile_counts': dict(Counter(profiles.values())),
        'order_status_counts': dict(Counter(row['order_status'] for row in orders)),
        'generated_files': [
            str(DATA_DIR / 'customers.csv'),
            str(DATA_DIR / 'products.csv'),
            str(DATA_DIR / 'orders.csv'),
            str(DATA_DIR / 'order_items.csv'),
        ],
    }
    with (EVIDENCE_DIR / 'generation_metadata.json').open('w', encoding='utf-8') as handle:
        json.dump(report, handle, indent=2)
    print(json.dumps(report, indent=2))


if __name__ == '__main__':
    main()
