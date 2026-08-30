from __future__ import annotations
from datetime import date, datetime

import csv
import json
from collections import Counter, defaultdict
from datetime import date
from decimal import Decimal, InvalidOperation
from pathlib import Path

ROOT = Path('C:/Users/laksh/PycharmProjects/PythonProject')
DATA_DIR = ROOT / 'data' / 'raw'
EVIDENCE_DIR = ROOT / 'evidence' / 'validation_outputs'

ANALYSIS_START = date(2024, 1, 1)
ANALYSIS_END = date(2025, 12, 31)
SIGNUP_START = date(2023, 6, 1)
SIGNUP_END = date(2025, 11, 30)

EXPECTED_FIELDS = {
    'customers.csv': ['customer_id', 'customer_code', 'signup_date', 'gender', 'age_band', 'city', 'state', 'acquisition_channel', 'customer_status'],
    'products.csv': ['product_id', 'sku', 'product_name', 'category', 'unit_price', 'cost_price', 'launch_date', 'product_status'],
    'orders.csv': ['order_id', 'order_number', 'customer_id', 'order_date', 'order_status', 'payment_method', 'sales_channel', 'shipping_city', 'shipping_state', 'discount_amount', 'shipping_amount'],
    'order_items.csv': ['order_item_id', 'order_id', 'product_id', 'quantity', 'unit_price', 'line_discount', 'line_total'],
}

DOMAINS = {
    'gender': {'Female', 'Male', 'Non-binary', 'Prefer not to say'},
    'age_band': {'18-24', '25-34', '35-44', '45-54', '55-64', '65+'},
    'acquisition_channel': {'Organic Search', 'Paid Search', 'Social Media', 'Email', 'Referral', 'Direct'},
    'customer_status': {'Active', 'Inactive'},
    'category': {'Electronics', 'Home & Kitchen', 'Apparel', 'Beauty & Personal Care', 'Sports & Outdoors', 'Books & Media', 'Toys & Games', 'Grocery & Gourmet', 'Pet Supplies', 'Office & Stationery', 'Garden & Tools', 'Travel & Accessories'},
    'product_status': {'Active', 'Discontinued'},
    'order_status': {'Completed', 'Cancelled', 'Returned', 'Pending'},
    'payment_method': {'Credit Card', 'Debit Card', 'Digital Wallet', 'Bank Transfer'},
    'sales_channel': {'Web', 'Mobile App', 'Marketplace', 'Retail Store'},
}


def read_csv(filename: str) -> tuple[list[dict[str, str]], list[str]]:
    path = DATA_DIR / filename
    with path.open('r', newline='', encoding='utf-8-sig') as handle:
        reader = csv.DictReader(handle)
        fields = reader.fieldnames or []
        rows = list(reader)
    return rows, fields

def parse_date(value, label):
    try:
        return date.fromisoformat(value)
    except ValueError:
        try:
            return datetime.strptime(value, '%d-%m-%Y').date()
        except ValueError as exc:
            raise AssertionError(f'Invalid date in {label}: {value}') from exc


def parse_decimal(value: str, label: str) -> Decimal:
    try:
        return Decimal(value).quantize(Decimal('0.01'))
    except (InvalidOperation, ValueError) as exc:
        raise AssertionError(f'Invalid decimal in {label}: {value}') from exc


def check(condition: bool, message: str, failures: list[str]) -> None:
    if not condition:
        failures.append(message)


def validate() -> dict:
    failures: list[str] = []
    files: dict[str, tuple[list[dict[str, str]], list[str]]] = {}
    for filename, expected_fields in EXPECTED_FIELDS.items():
        path = DATA_DIR / filename
        check(path.exists(), f'Missing file: {path}', failures)
        if not path.exists():
            continue
        rows, fields = read_csv(filename)
        files[filename] = (rows, fields)
        check(fields == expected_fields, f'{filename}: schema mismatch: {fields}', failures)
        check(len(rows) > 0, f'{filename}: file is empty', failures)
        for row_number, row in enumerate(rows, start=2):
            for field in expected_fields:
                check(row.get(field, '') != '', f'{filename} row {row_number}: blank required field {field}', failures)

    customers = files['customers.csv'][0]
    products = files['products.csv'][0]
    orders = files['orders.csv'][0]
    order_items = files['order_items.csv'][0]

    customer_ids = [int(row['customer_id']) for row in customers]
    customer_codes = [row['customer_code'] for row in customers]
    product_ids = [int(row['product_id']) for row in products]
    skus = [row['sku'] for row in products]
    order_ids = [int(row['order_id']) for row in orders]
    order_numbers = [row['order_number'] for row in orders]
    item_ids = [int(row['order_item_id']) for row in order_items]

    check(len(customer_ids) == len(set(customer_ids)), 'customers: duplicate customer_id values', failures)
    check(len(customer_codes) == len(set(customer_codes)), 'customers: duplicate customer_code values', failures)
    check(len(product_ids) == len(set(product_ids)), 'products: duplicate product_id values', failures)
    check(len(skus) == len(set(skus)), 'products: duplicate sku values', failures)
    check(len(order_ids) == len(set(order_ids)), 'orders: duplicate order_id values', failures)
    check(len(order_numbers) == len(set(order_numbers)), 'orders: duplicate order_number values', failures)
    check(len(item_ids) == len(set(item_ids)), 'order_items: duplicate order_item_id values', failures)
    check(all(value > 0 for value in customer_ids + product_ids + order_ids + item_ids), 'Primary keys must be positive', failures)

    customer_set = set(customer_ids)
    product_set = set(product_ids)
    order_set = set(order_ids)
    product_price = {int(row['product_id']): parse_decimal(row['unit_price'], f"products.product_id={row['product_id']}.unit_price") for row in products}
    product_launch = {int(row['product_id']): parse_date(row['launch_date'], f"products.product_id={row['product_id']}.launch_date") for row in products}
    customer_signup = {int(row['customer_id']): parse_date(row['signup_date'], f"customers.customer_id={row['customer_id']}.signup_date") for row in customers}
    order_by_id = {int(row['order_id']): row for row in orders}

    for row in customers:
        customer_id = int(row['customer_id'])
        signup = customer_signup[customer_id]
        check(SIGNUP_START <= signup <= SIGNUP_END, f'customers: signup_date outside planned window for {customer_id}', failures)
        for field, domain_key in [('gender', 'gender'), ('age_band', 'age_band'), ('acquisition_channel', 'acquisition_channel'), ('customer_status', 'customer_status')]:
            check(row[field] in DOMAINS[domain_key], f'customers: invalid {field}={row[field]}', failures)

    for row in products:
        pid = int(row['product_id'])
        unit_price = parse_decimal(row['unit_price'], f'products.product_id={pid}.unit_price')
        cost_price = parse_decimal(row['cost_price'], f'products.product_id={pid}.cost_price')
        check(unit_price > 0, f'products: non-positive unit_price for {pid}', failures)
        check(cost_price > 0, f'products: non-positive cost_price for {pid}', failures)
        check(cost_price < unit_price, f'products: cost_price is not below unit_price for {pid}', failures)
        check(row['category'] in DOMAINS['category'], f'products: invalid category={row["category"]}', failures)
        check(row['product_status'] in DOMAINS['product_status'], f'products: invalid product_status={row["product_status"]}', failures)
        check(product_launch[pid] <= ANALYSIS_END, f'products: launch_date after analysis end for {pid}', failures)

    status_counter = Counter()
    order_items_by_order: dict[int, list[dict[str, str]]] = defaultdict(list)
    item_product_pairs: set[tuple[int, int]] = set()
    eligible_revenue = Decimal('0.00')
    all_order_revenue = Decimal('0.00')
    order_discount_sums: dict[int, Decimal] = defaultdict(lambda: Decimal('0.00'))

    for row in orders:
        oid = int(row['order_id'])
        cid = int(row['customer_id'])
        order_date = parse_date(row['order_date'], f'orders.order_id={oid}.order_date')
        discount = parse_decimal(row['discount_amount'], f'orders.order_id={oid}.discount_amount')
        shipping = parse_decimal(row['shipping_amount'], f'orders.order_id={oid}.shipping_amount')
        check(cid in customer_set, f'orders: orphan customer_id={cid} for order {oid}', failures)
        check(ANALYSIS_START <= order_date <= ANALYSIS_END, f'orders: order_date outside analysis window for {oid}', failures)
        check(discount >= 0, f'orders: negative discount for {oid}', failures)
        check(shipping >= 0, f'orders: negative shipping for {oid}', failures)
        check(row['order_status'] in DOMAINS['order_status'], f'orders: invalid order_status={row["order_status"]}', failures)
        check(row['payment_method'] in DOMAINS['payment_method'], f'orders: invalid payment_method={row["payment_method"]}', failures)
        check(row['sales_channel'] in DOMAINS['sales_channel'], f'orders: invalid sales_channel={row["sales_channel"]}', failures)
        status_counter[row['order_status']] += 1

    for row in order_items:
        item_id = int(row['order_item_id'])
        oid = int(row['order_id'])
        pid = int(row['product_id'])
        quantity = int(row['quantity'])
        unit_price = parse_decimal(row['unit_price'], f'order_items.order_item_id={item_id}.unit_price')
        discount = parse_decimal(row['line_discount'], f'order_items.order_item_id={item_id}.line_discount')
        line_total = parse_decimal(row['line_total'], f'order_items.order_item_id={item_id}.line_total')
        check(oid in order_set, f'order_items: orphan order_id={oid} for item {item_id}', failures)
        check(pid in product_set, f'order_items: orphan product_id={pid} for item {item_id}', failures)
        check(quantity >= 1, f'order_items: invalid quantity for item {item_id}', failures)
        check(unit_price > 0, f'order_items: non-positive unit_price for item {item_id}', failures)
        check(discount >= 0, f'order_items: negative line_discount for item {item_id}', failures)
        gross = (unit_price * quantity).quantize(Decimal('0.01'))
        expected_total = (gross - discount).quantize(Decimal('0.01'))
        check(discount <= gross, f'order_items: discount exceeds gross for item {item_id}', failures)
        check(line_total == expected_total, f'order_items: line_total mismatch for item {item_id}', failures)
        check(product_price[pid] == unit_price, f'order_items: unit price does not match product price for item {item_id}', failures)
        check(product_launch[pid] <= parse_date(order_by_id[oid]['order_date'], f'orders.order_id={oid}.order_date'), f'order_items: product {pid} purchased before launch on order {oid}', failures)
        check((oid, pid) not in item_product_pairs, f'order_items: duplicate product {pid} within order {oid}', failures)
        item_product_pairs.add((oid, pid))
        order_items_by_order[oid].append(row)
        order_discount_sums[oid] += discount
        all_order_revenue += line_total
        if order_by_id[oid]['order_status'] == 'Completed':
            eligible_revenue += line_total

    for row in orders:
        oid = int(row['order_id'])
        check(oid in order_items_by_order, f'orders: order {oid} has no order items', failures)
        expected_discount = parse_decimal(row['discount_amount'], f'orders.order_id={oid}.discount_amount')
        check(order_discount_sums[oid] == expected_discount, f'orders: discount reconciliation failed for order {oid}', failures)

    order_dates = [parse_date(row['order_date'], f'orders.order_id={row["order_id"]}.order_date') for row in orders]
    customer_order_counts = Counter(int(row['customer_id']) for row in orders if row['order_status'] == 'Completed')
    completed_dates = [parse_date(row['order_date'], f'orders.order_id={row["order_id"]}.order_date') for row in orders if row['order_status'] == 'Completed']
    check(min(order_dates) == ANALYSIS_START, f'orders: minimum date is {min(order_dates)}, expected {ANALYSIS_START}', failures)
    check(max(order_dates) == ANALYSIS_END, f'orders: maximum date is {max(order_dates)}, expected {ANALYSIS_END}', failures)
    check(ANALYSIS_START in completed_dates, 'orders: no completed order on analysis start date', failures)
    check(ANALYSIS_END in completed_dates, 'orders: no completed order on analysis end date', failures)
    check(set(status_counter) == set(DOMAINS['order_status']), 'orders: not all planned statuses are represented', failures)
    check(len(customer_order_counts) > 0, 'behavior: no completed customers', failures)
    check(any(count == 1 for count in customer_order_counts.values()), 'behavior: no one-time completed customers', failures)
    check(any(count >= 2 for count in customer_order_counts.values()), 'behavior: no repeat completed customers', failures)
    check(any(parse_date(row['order_date'], 'order') <= date(2024, 6, 30) for row in orders), 'behavior: no older orders for inactivity analysis', failures)
    check(any(parse_date(row['order_date'], 'order') >= date(2025, 10, 1) for row in orders), 'behavior: no recent orders for current activity analysis', failures)

    expected_counts = {'customers.csv': 8000, 'products.csv': 180, 'orders.csv': 40000}
    for filename, expected in expected_counts.items():
        check(len(files[filename][0]) == expected, f'{filename}: expected {expected} rows, found {len(files[filename][0])}', failures)
    check(100000 <= len(order_items) <= 120000, f'order_items.csv: expected 100,000–120,000 rows, found {len(order_items)}', failures)

    result = {
        'status': 'PASS' if not failures else 'FAIL',
        'failure_count': len(failures),
        'failures': failures,
        'row_counts': {
            'customers': len(customers),
            'products': len(products),
            'orders': len(orders),
            'order_items': len(order_items),
        },
        'date_range': {
            'order_min': min(order_dates).isoformat(),
            'order_max': max(order_dates).isoformat(),
            'customer_signup_min': min(customer_signup.values()).isoformat(),
            'customer_signup_max': max(customer_signup.values()).isoformat(),
            'product_launch_min': min(product_launch.values()).isoformat(),
            'product_launch_max': max(product_launch.values()).isoformat(),
        },
        'order_status_counts': dict(status_counter),
        'completed_customer_count': len(customer_order_counts),
        'one_time_completed_customer_count': sum(1 for count in customer_order_counts.values() if count == 1),
        'repeat_completed_customer_count': sum(1 for count in customer_order_counts.values() if count >= 2),
        'completed_order_count': status_counter['Completed'],
        'eligible_completed_revenue': f'{eligible_revenue:.2f}',
        'all_status_line_revenue': f'{all_order_revenue:.2f}',
        'validation_scope': [
            'schema and file presence', 'null and blank required fields', 'primary-key uniqueness',
            'business-reference uniqueness', 'controlled domains', 'date windows', 'foreign-key readiness',
            'one-or-more-items-per-order', 'unique product per order', 'positive/non-negative numeric rules',
            'line-total reconciliation', 'order-discount reconciliation', 'product-price consistency',
            'product-launch chronology', 'status coverage', 'boundary-date coverage', 'behavioral coverage',
        ],
    }
    EVIDENCE_DIR.mkdir(parents=True, exist_ok=True)
    with (EVIDENCE_DIR / 'phase2_validation.json').open('w', encoding='utf-8-sig') as handle:
        json.dump(result, handle, indent=2)
    print(json.dumps(result, indent=2))
    if failures:
        raise SystemExit(1)


if __name__ == '__main__':
    validate()
