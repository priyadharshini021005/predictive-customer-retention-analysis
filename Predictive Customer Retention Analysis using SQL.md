# Predictive Customer Retention Analysis using SQL

## Phase 1 — Project Setup and Solution Blueprint

**Status:** Complete for review and approval  
**Scope boundary:** Phase 1 only. No database, tables, dataset, Power BI dashboard, or final project report has been created.

> **Project principle:** The project will produce a transparent, SQL-based behavioral customer risk score. Unless a separate machine-learning model is added in a later phase, the score will not be described as a machine-learning prediction.

## 1. Complete Business Problem

The business has customer, product, and transaction information but lacks a consistent analytical system for understanding repeat purchasing and customer retention. Transaction data is often reviewed as individual orders or aggregate revenue, which makes it difficult to answer customer-level questions such as who is still active, who has stopped purchasing, which customers are showing early signs of disengagement, and which products or channels are associated with stronger repeat behavior.

The project will convert a realistic historical purchasing dataset into a validated, normalized MySQL database and a reusable SQL analytics layer. The analysis will measure customer purchasing behavior, retention, inactivity, cohort performance, RFM segments, and a deterministic behavioral risk score. The final analytical outputs will support targeted retention actions such as reactivation campaigns, loyalty treatment, customer-service follow-up, and channel or product-specific interventions.

The business problem is therefore defined as follows:

> **How can a business use validated customer and transaction data to measure retention, identify inactive and at-risk customers, explain the behavioral drivers of customer risk, and provide actionable retention insights through MySQL and Power BI?**

The project is designed for decision support rather than automated customer contact. The risk score will prioritize customers for review; it will not establish that a customer will definitely churn, and it will not infer causes that are not represented in the transaction data.

## 2. Project Objectives

| Objective | Intended outcome | Validation criterion |
|---|---|---|
| Establish a reliable relational foundation | A normalized customer, product, order, and order-item model with enforced relationships | Primary keys, foreign keys, constraints, and referential-integrity checks pass |
| Prepare realistic analytical data | Internally consistent historical transactions suitable for retention analysis | Row counts, uniqueness, date, amount, and relationship checks pass |
| Measure customer activity and retention | Customer-level, monthly, and cohort retention metrics | Metric definitions are documented and independently reconciled |
| Analyze customer value and behavior | RFM scores, order frequency, monetary value, purchase gaps, and product/channel behavior | Calculations agree with transaction-level source totals |
| Identify inactive and at-risk customers | A transparent behavioral score derived from measurable behavior | Score components are traceable to SQL fields and no risk band is randomly assigned |
| Create reusable SQL outputs | Views and selected stored procedures for repeatable analysis | Views execute successfully and return documented columns and grains |
| Deliver management-ready visual analysis | Power BI dashboard based on final SQL views | Dashboard measures reconcile to SQL outputs and support stakeholder questions |
| Produce a portfolio-ready project | Organized scripts, documentation, validation evidence, and reproducible workflow | Folder structure, naming, assumptions, and implementation order are consistent |

## 3. Target Users and Business Stakeholders

| Stakeholder | Primary decisions or uses | Expected analytical need |
|---|---|---|
| Business owner or senior management | Determine whether retention is improving and where revenue exposure exists | Retention trend, repeat-customer share, revenue concentration, and high-risk customer value |
| Marketing or CRM team | Prioritize reactivation, loyalty, and lifecycle campaigns | At-risk lists, RFM segments, cohort retention, and channel or product patterns |
| Sales or e-commerce team | Understand purchasing cadence and customer development | Order frequency, average order value, purchase gaps, and repeat conversion |
| Customer-success or service team | Identify customers requiring proactive follow-up | Inactivity status, risk drivers, recent-value context, and customer history |
| Finance or commercial team | Assess revenue represented by active, inactive, and at-risk customers | Completed-order revenue, monetary value, trend, and customer-value distribution |
| Data analyst or SQL developer | Reuse and extend the analytical model | Normalized tables, documented views, indexes, procedures, and validation queries |
| Academic evaluator or interviewer | Assess data modeling, SQL reasoning, and business interpretation | Clear assumptions, formulas, query techniques, evidence of validation, and limitations |

The dashboard and documentation will distinguish between an operational user who needs a prioritized customer list and an analytical user who needs definitions, calculations, and drill-down detail.

## 4. Key Business Questions

The SQL analysis must answer the following questions without inventing findings before the data is analyzed:

1. How many customers, products, orders, and order items are present in the validated dataset?
2. What are total completed-order revenue, order count, average order value, and unique active customers by month?
3. How does the customer base divide into one-time, repeat, active, inactive, and churn-proxy populations?
4. What share of customers and revenue is generated by repeat purchasers?
5. How many customers made a first completed purchase in each acquisition cohort month?
6. What percentage of each cohort makes a subsequent purchase in the following month and in later months?
7. Which customer segments have the highest recency, frequency, and monetary value combinations?
8. Which customers have the longest time since their last completed purchase?
9. Which customers are at risk under the documented behavioral scoring rules, and what measurable behaviors drive their scores?
10. Are high-value customers represented among inactive or high-risk groups?
11. How do product categories, products, and sales channels relate to order volume, revenue, and repeat purchasing?
12. Are purchasing cadence, average order value, or interpurchase gaps changing over time?
13. What customer-level and segment-level retention actions are supported by the observed data?
14. Which findings are robust across reasonable threshold or date-window checks, and which are sensitive to the chosen definitions?

## 5. Definitions and Measurement Policy

The following definitions are approved as the starting business policy. They are deliberately explicit so that the SQL, views, dashboard, and documentation use the same language.

| Concept | Phase 1 definition |
|---|---|
| Analysis period | A proposed 24-month historical window. Exact start and end dates will be finalized when the source dataset is designed in Phase 2. |
| Reference date | The latest eligible completed-order date in the analysis dataset, unless a fixed reporting cutoff is explicitly selected. The reference date must be documented for every snapshot. |
| Eligible order | An order with a valid customer, at least one valid order item, a non-null order date, and a status included in the completed-order policy. |
| Completed order | An order counted in purchasing, revenue, retention, RFM, and risk calculations. The final status mapping will be held in a lookup table and documented in the data dictionary. |
| Active customer | A customer with at least one completed order within the selected reporting window. |
| New customer | A customer whose first completed order in the available historical data falls within the selected period or cohort month. |
| Repeat customer | A customer with at least two distinct completed orders by the reference date. |
| One-time customer | A customer with exactly one distinct completed order by the reference date. |
| Monthly retention | For a cohort month, the proportion of customers whose first completed order occurred in that month and who placed at least one completed order in a later month. Month-1 retention will be calculated only for cohorts with a complete subsequent month. |
| Period retention | The proportion of customers with at least one completed order in the selected period who also placed a second completed order within the selected period. |
| Inactive customer | A customer with prior completed purchasing history whose days since the last completed order exceed the initial inactivity threshold of 90 days. |
| Churn proxy | A customer with prior completed purchasing history whose days since the last completed order exceed the initial churn-proxy threshold of 180 days. This is an analytical inactivity proxy, not confirmed contractual churn. |
| Not enough history | A customer whose first completed order is too recent to be assessed fairly against the inactivity or churn-proxy threshold. |
| Recency | Days from the reference date to the customer’s last completed order. Lower is better in RFM and generally lower risk. |
| Frequency | Count of distinct completed orders by the reference date. Higher is generally stronger repeat behavior. |
| Monetary value | Sum of eligible completed-order item net amounts, calculated from quantity, unit price, and documented line-level discounts. It is revenue-based customer value, not profit or lifetime contribution margin. |
| Purchase gap | Time between consecutive completed orders for a customer. Average or median historical gap and the latest gap may be used in consistency checks and risk scoring. |
| Behavioral risk score | A deterministic 0–100 score calculated from documented transaction behaviors such as recency, frequency, purchase-gap deterioration, and spend trend. It is not a machine-learning prediction. |

The 90-day and 180-day thresholds are initial business assumptions. They must be sensitivity-tested after the data is available, especially if the observed purchase cycle is materially shorter or longer than those thresholds. Customers without a completed order are not treated as churned customers because this project analyzes purchasing history rather than a full prospect or subscription population.

## 6. Proposed Technology Stack

| Layer | Proposed technology | Role in the project |
|---|---|---|
| Source preparation | CSV and/or Excel | Hold prepared customer, product, order, and order-item extracts before database import |
| Database engine | MySQL 8.0 or later | Store normalized data, enforce relationships, and execute analysis |
| Database design and execution | MySQL Workbench | Create and inspect the model, manage SQL scripts, review EER diagrams, and validate objects |
| SQL analytics | MySQL SQL | Use joins, aggregations, subqueries, CTEs, CASE statements, date logic, and window functions |
| Analytical delivery | Power BI Desktop | Connect to final MySQL views, create measures and visuals, and deliver interactive filtering |
| Optional modeling | Python only if a separate machine-learning model is genuinely added | Keep any statistical or machine-learning model separate from the SQL behavioral score |
| Version control | Git and GitHub-ready directory structure | Track SQL, documentation, source templates, validation evidence, and dashboard guidance |

MySQL 8.0 is appropriate for the planned SQL techniques because its documentation covers common table expressions and window functions used for reusable query logic, ranking, running calculations, and cohort or customer-level comparisons [1] [2]. MySQL Workbench supports database modeling, EER diagrams, foreign-key relationships, views, routines, and forward engineering, which fits the sequential database-design requirement [3]. Power Query provides a MySQL database connector for Power BI, with import and native SQL options; the Oracle MySQL Connector/NET package is a stated prerequisite for Power BI Desktop connections [4].

The default Power BI connection design will import the final analytical views rather than expose all normalized tables to report authors. This keeps business logic centralized in MySQL and reduces the risk of inconsistent dashboard calculations. The exact connection mode and deployment configuration will be finalized during the dashboard phase.

## 7. High-Level Database Architecture

The proposed architecture has three logical layers inside the project’s MySQL environment:

| Logical layer | Contents | Purpose |
|---|---|---|
| Staging or raw-ingestion layer | Temporary `stg_` tables that mirror CSV or Excel extracts | Preserve the imported shape, support repeatable loading, and isolate raw-data issues before normalization |
| Core normalized layer | Customer, product, lookup, order, and order-item tables | Provide the authoritative relational model with keys, constraints, and indexes |
| Analytics layer | SQL views and selected stored procedures | Publish customer summaries, RFM outputs, risk scores, retention metrics, cohort results, and trend metrics for analysis and Power BI |

The core layer will use a transaction-oriented relational design. Customer and product master data will be separated from transactional order data. The order header will store one row per order, while the order-item table will store one row per product line within an order. Lookup tables will standardize controlled values such as order status, payment method, and sales channel.

A conceptual data flow is:

```text
CSV / Excel extracts
        |
        v
Staging tables and import checks
        |
        v
Normalized MySQL core tables
        |
        v
Data-quality and reconciliation checks
        |
        v
SQL analysis: customer metrics, RFM, retention, cohorts, trends
        |
        v
Deterministic behavioral customer risk score
        |
        v
Documented SQL views and stored procedures
        |
        v
Power BI semantic model, dashboard, and stakeholder insights
```

The staging layer is an ingestion aid and is not the business-facing analytical model. The normalized core layer remains the source of truth. Analytical views will be built from validated core tables and will expose stable, documented grains and column definitions.

## 8. Proposed Tables and Purpose

The following tables are proposed for the normalized core model. This is a design specification only; no tables have been created in Phase 1.

| Table | Grain | Purpose | Key design notes |
|---|---|---|---|
| `customers` | One row per customer | Store durable customer identity and descriptive attributes needed for segmentation and cohort analysis | Surrogate customer key; unique business/customer reference; signup or registration date; non-sensitive demographic or geographic attributes only |
| `categories` | One row per product category | Standardize product grouping for category-level sales and retention analysis | Unique category name; controlled master data |
| `products` | One row per product or SKU | Store product identity, category, price reference, and active/inactive product status | Foreign key to `categories`; unique SKU; no repeated category text in every order item |
| `payment_methods` | One row per payment method | Standardize the payment method used on an order | Lookup table referenced by `orders` |
| `order_statuses` | One row per supported order status | Define which order statuses are eligible for revenue and customer-behavior analysis | The completed-order policy will be documented here; cancelled or invalid statuses will be excluded from eligible metrics |
| `sales_channels` | One row per sales or acquisition channel | Standardize channel analysis such as web, mobile, marketplace, or store | Lookup table referenced by `orders` |
| `orders` | One row per customer order | Store order-level dates, customer ownership, status, channel, payment method, and order-level attributes | Foreign keys to customer and lookup tables; unique order reference; order date and status are central filter fields |
| `order_items` | One row per product line within an order | Store the products purchased, quantity, unit price, and line-level discount or net amount | Resolves the order-to-product many-to-many relationship; foreign keys to `orders` and `products`; positive quantity and non-negative monetary constraints |

The staging layer will mirror the inbound extracts using tables such as `stg_customers`, `stg_categories`, `stg_products`, `stg_orders`, and `stg_order_items` when needed. These are not substitutes for the core tables. A load process will validate uniqueness, nullability, date ranges, lookup values, amount fields, and foreign-key readiness before inserting into the normalized layer.

An optional `etl_load_log` table may be introduced if repeatable reloads or audit evidence are required. It would store load timestamp, source file name, row counts, and validation status. It is not required for the first analytical version and will be included only if it adds clear reproducibility value.

## 9. Table Relationships and Cardinality

| Parent table | Child table | Relationship | Business meaning |
|---|---|---|---|
| `categories` | `products` | 1-to-many | One category can contain many products; each product belongs to one category in the proposed model |
| `customers` | `orders` | 1-to-many | One customer can place many orders; each order belongs to one customer |
| `order_statuses` | `orders` | 1-to-many | One status can apply to many orders; each order has one controlled status |
| `payment_methods` | `orders` | 1-to-many | One payment method can be used on many orders; each order records one method |
| `sales_channels` | `orders` | 1-to-many | One channel can contain many orders; each order records one channel |
| `orders` | `order_items` | 1-to-many | One order contains one or more product lines; each line belongs to one order |
| `products` | `order_items` | 1-to-many | One product can appear on many order lines; each line references one product |
| `orders` | `products` | many-to-many through `order_items` | An order can contain multiple products, and a product can be purchased in many orders |

The model will use primary keys on every core table, foreign keys for all parent-child relationships, unique constraints for business identifiers such as customer reference, SKU, and order reference, and checks for values such as positive quantities and non-negative prices or discounts. Appropriate indexes will be added to foreign keys and high-use analytical filters after the initial query patterns are known.

## 10. Expected Data Volume

The intended dataset is large enough to demonstrate SQL analysis while remaining practical for MySQL Workbench and an academic or portfolio environment. These are planning targets rather than observed findings.

| Table or extract | Expected rows | Planning rationale |
|---|---:|---|
| `customers` | Approximately 8,000 | Supports customer segmentation and a meaningful one-time/repeat split |
| `categories` | Approximately 12 | Provides useful but manageable category-level comparisons |
| `products` | Approximately 180 | Allows product-level and category-level purchasing analysis |
| `payment_methods` | 4–6 | Small controlled lookup domain |
| `order_statuses` | 3–5 | Includes completed and non-eligible operational statuses |
| `sales_channels` | 4–6 | Supports channel comparison without excessive sparsity |
| `orders` | Approximately 40,000 | Represents roughly 24 months of customer purchasing with a mix of one-time and repeat customers |
| `order_items` | Approximately 100,000–120,000 | Represents an average of roughly 2.5–3.0 lines per order |
| Staging extracts | Approximately equal to inbound source rows | Allows import-level validation before core-table insertion |

The exact volumes will be confirmed after dataset generation and will be reported as actual counts in the Phase 2 validation results. The dataset should include realistic variation in signup dates, order cadence, order values, categories, products, statuses, and channels. It must also include enough recent and older orders to support inactivity, churn-proxy, cohort, and trend analysis.

## 11. SQL Analysis Scope

The analysis layer will be designed around the following reusable outputs:

| Analytical output | Intended grain | Main measures |
|---|---|---|
| Customer summary | One row per customer | First and last completed order, order count, total monetary value, average order value, purchase gap statistics, active/inactive status |
| RFM analysis | One row per eligible customer at a reference date | Recency, frequency, monetary value, component scores, combined RFM score, RFM segment |
| Customer risk | One row per eligible customer at a reference date | Component risk points, total behavioral risk score, risk band, inactivity status, risk explanation fields |
| Retention metrics | One row per reporting month or period | Active customers, new customers, repeat customers, retained customers, repeat rate, period retention, eligible cohort base |
| Cohort retention | One row per cohort month and elapsed month | Cohort size, retained customers, retention rate, revenue or order contribution where appropriate |
| Purchase trends | One row per month, category, product, or channel depending on view | Orders, customers, units, revenue, average order value, repeat-customer share |

The implementation will intentionally demonstrate joins, aggregations, subqueries, CTEs, CASE expressions, and window functions. Window functions may support rankings, quintiles, cohort comparisons, first/last purchase logic, and customer-level comparisons. CTEs will make multi-stage calculations such as cohort bases and risk components readable and auditable [1] [2].

## 12. RFM and Behavioral Risk Design Direction

### RFM analysis

RFM will be calculated only from eligible completed orders. Recency will be measured in days from the documented reference date to the last completed order. Frequency will count distinct completed orders. Monetary value will sum eligible order-item net amounts. Customers will receive 1–5 component scores using documented quintile or equivalent SQL logic: lower recency is better, while higher frequency and monetary value are better. The final segment labels will be derived from scores rather than manually assigned.

RFM is a descriptive segmentation method. It identifies behavior and value patterns but does not, by itself, estimate the probability of churn.

### Behavioral risk score

The proposed SQL risk score is a deterministic 0–100 index based on measurable customer behavior. An initial weighting design is:

| Component | Maximum points | Behavioral interpretation |
|---|---:|---|
| Recency risk | 40 | More days since the last completed order produce more risk points |
| Frequency risk | 25 | Fewer completed orders produce more risk points, subject to a minimum-history rule |
| Purchase-gap risk | 15 | A latest purchase gap materially longer than the customer’s historical cadence produces more risk points |
| Spend-trend risk | 20 | A documented decline in recent spend compared with an earlier comparable period produces more risk points |
| **Total** | **100** | **Higher score means greater behavioral disengagement signal** |

Initial bands will be Low (0–29), Medium (30–59), and High (60–100). These cutoffs are policy assumptions and will be tested against the distribution of the generated data. If a component cannot be calculated because the customer lacks enough history, the SQL will apply a documented neutral or not-enough-history rule rather than fabricate a value.

The score will be explainable through component columns such as `recency_risk_points`, `frequency_risk_points`, `gap_risk_points`, and `spend_trend_risk_points`. The dashboard will display both the total score and its main drivers. No random assignment of Low, Medium, or High risk is permitted.

## 13. Overall Project Workflow

| Stage | Planned work | Exit evidence |
|---|---|---|
| 1. Project setup | Confirm business problem, objectives, stakeholders, architecture, table plan, volumes, workflow, assumptions, and folder structure | Approved Phase 1 blueprint |
| 2. Dataset design and generation | Define source columns, generate or prepare realistic CSV/Excel data, and document generation rules | Source files, data dictionary, and generation validation |
| 3. Database creation | Create the MySQL database or schema namespace and establish the intended execution order | Successful database-creation script and Workbench connection |
| 4. Table creation | Create staging and normalized core tables with keys, constraints, and indexes | DDL execution log and model/EER evidence |
| 5. Data insertion or import | Load staging data, validate it, and insert valid rows into core tables | Load counts and rejected-row or exception evidence |
| 6. Data-quality validation | Test duplicates, nulls, invalid dates, negative values, orphan keys, status mapping, and amount reconciliation | Validation query results and documented exceptions |
| 7. Data cleaning | Correct or exclude invalid records according to documented rules | Clean-load counts and change log |
| 8. Exploratory SQL analysis | Profile orders, revenue, customers, products, channels, and time patterns | Exploratory query outputs and observations grounded in data |
| 9. Customer metrics | Build first/last order, order count, monetary value, average order value, and purchase-gap measures | Customer-level reconciliation results |
| 10. RFM analysis | Calculate and validate RFM components, scores, and segments | RFM view/query outputs and formula checks |
| 11. Retention analysis | Calculate active, repeat, retained, inactive, and churn-proxy metrics | Period and retention reconciliation |
| 12. Cohort analysis | Build acquisition cohorts and elapsed-month retention measures | Cohort matrix or view with complete-cohort rules |
| 13. Purchase trends | Analyze monthly, category, product, and channel trends | Trend outputs reconciled to completed orders |
| 14. Behavioral risk scoring | Implement deterministic weighted components and explanatory fields | Risk view, score distribution, and threshold checks |
| 15. SQL views | Publish customer summary, RFM, risk, retention, cohort, and trend views | View definitions and execution checks |
| 16. Procedures and indexes | Add useful parameterized procedures and optimize verified query paths | Procedure tests and explain/index evidence |
| 17. Power BI dashboard | Connect to final views, create measures and visuals, and validate dashboard totals | Dashboard file or build specification with SQL reconciliation |
| 18. Documentation | Explain business problem, model, formulas, assumptions, findings, limitations, and usage | User-facing project documentation |
| 19. Final validation | Run end-to-end checks across database, SQL, dashboard, and documentation | Final validation checklist |
| 20. Packaging | Organize GitHub-ready files and remove temporary or sensitive artifacts | Final project package and README |

This sequence intentionally prevents Power BI work from starting before the relational model, data quality, and SQL analytical outputs are validated.

## 14. Proposed GitHub-Ready Folder Structure

The project will eventually use a structure similar to the following. In Phase 1, only the Phase 1 blueprint document has been created.

```text
Predictive Customer Retention Analysis using SQL/
├── README.md
├── docs/
│   ├── business_problem.md
│   ├── data_dictionary.md
│   ├── assumptions_and_formulas.md
│   ├── validation_report.md
│   └── phase1/
│       └── phase1_blueprint.md
├── data/
│   ├── raw/
│   ├── cleaned/
│   └── templates/
├── sql/
│   ├── 01_database/
│   ├── 02_tables/
│   ├── 03_load/
│   ├── 04_validation/
│   ├── 05_cleaning/
│   ├── 06_exploration/
│   ├── 07_customer_metrics/
│   ├── 08_rfm/
│   ├── 09_retention/
│   ├── 10_cohorts/
│   ├── 11_trends/
│   ├── 12_risk_scoring/
│   ├── 13_views/
│   ├── 14_procedures/
│   └── 15_indexes/
├── powerbi/
│   ├── dashboard_guidance.md
│   └── screenshots/
├── model/
│   └── mysql_workbench/
└── evidence/
    ├── row_counts/
    ├── validation_outputs/
    └── dashboard_reconciliation/
```

The actual Power BI file, database scripts, data files, and validation evidence will be added only in their respective later phases.

## 15. Assumptions and Limitations

| Area | Explicit assumption or limitation | Control in later phases |
|---|---|---|
| Data origin | The project will use a synthetic or prepared portfolio dataset, not confidential production data | Record the source type and generation/preparation rules |
| Customer identity | Each customer has one stable customer identifier in the analytical source | Validate uniqueness and reject ambiguous duplicate identifiers |
| Order identity | Each order has one stable order reference and belongs to one customer | Enforce uniqueness and foreign-key checks |
| Order composition | Each eligible order contains at least one order item | Enforce order-item existence and reconcile header/detail totals |
| Product taxonomy | Each product belongs to one category in the first version | Validate category references; document any future multi-category extension |
| Revenue | Monetary value is based on eligible completed-order item amounts, not profit, tax, shipping, or accounting revenue unless those fields are explicitly added | Document the exact net-amount formula and reconcile totals |
| Cancellations and returns | Non-completed statuses are excluded from retention and RFM calculations; partial-return accounting is outside the first version unless a returns source is added | Document status mapping and test exclusion counts |
| Retention observability | A transaction dataset cannot prove customer intent or contractual churn | Use “churn proxy” and “inactive” terminology, not confirmed churn unless a true churn field exists |
| Recency thresholds | Initial inactivity and churn-proxy thresholds are 90 and 180 days | Perform sensitivity testing using observed purchase cadence |
| Cohort completeness | Newest cohorts may not have a complete follow-up month | Exclude incomplete cohorts from metrics that require a future observation period |
| Risk scoring | Risk is a deterministic behavioral index, not an ML probability | Publish component scores, weights, and definitions; keep any future ML model separate |
| Privacy | No unnecessary personally identifiable information is required for the analysis | Use surrogate keys or anonymized customer references and avoid sensitive attributes |
| Time zones | Dates will be treated consistently in one documented business time zone | Normalize date handling before loading and use a single reference-date policy |
| Currency | The initial dataset will use one documented currency | Do not compare monetary values across currencies without conversion logic |
| Dashboard source | Power BI will consume validated SQL views rather than independently recreating core business logic | Reconcile dashboard totals to SQL view outputs |
| Performance | The proposed volumes are intended for a practical academic/portfolio environment, not production-scale benchmarking | Validate execution plans and add indexes after query patterns are known |

Important decisions that remain intentionally gated are the exact historical date range, final source-column layout, precise order-status values, treatment of any discount or return fields, and the final risk-threshold sensitivity results. These cannot be finalized responsibly before the dataset specification and validation work in Phase 2.

## 16. Phase 1 Validation Summary

| Validation item | Result | Evidence or rationale |
|---|---|---|
| Business problem defined | Passed | A complete decision-support problem statement is documented |
| Project objectives defined | Passed | Objectives include outcomes and validation criteria |
| Stakeholders identified | Passed | Seven stakeholder groups and their analytical needs are mapped |
| Business questions defined | Passed | Fourteen SQL questions cover customer behavior, retention, cohorts, trends, and risk |
| Technology stack finalized | Passed | MySQL 8.0+, MySQL Workbench, CSV/Excel, Power BI, optional Python, Git/GitHub are specified |
| High-level architecture defined | Passed | Staging, normalized core, and analytics layers are documented |
| Tables and purposes proposed | Passed | Eight normalized core tables are specified with grain and design notes |
| Relationships defined | Passed | Parent-child cardinalities and the order-item bridge role are documented |
| Data volumes planned | Passed as planning targets | Target row counts are stated and will be replaced by actual Phase 2 counts |
| End-to-end workflow defined | Passed | All twenty requested phases are sequenced from setup through packaging |
| Assumptions documented | Passed | Data, retention, risk, privacy, currency, and dashboard assumptions are explicit |
| Scope boundary respected | Passed | No database, table, dataset, Power BI dashboard, or final report was created |
| Findings invented before analysis | Passed | The document contains no observed business findings; all volumes and thresholds are labeled as planning assumptions |

**Phase 1 conclusion:** The project has a coherent business scope, normalized database direction, analytical measurement policy, stakeholder map, implementation sequence, and validation gate. The blueprint is ready for review. Phase 2 should begin only after approval, at which point the source columns, exact date range, generation rules, and data dictionary will be designed before any database objects are created.

## Approval Gate

Please review this blueprint and approve Phase 1 before Phase 2 begins. The next phase will design and generate the realistic source dataset; it will not create the MySQL database or tables until the dataset design and validation are complete.

## References

[1]: https://dev.mysql.com/doc/refman/8.0/en/with.html "MySQL 8.0 Reference Manual — WITH (Common Table Expressions)"

[2]: https://dev.mysql.com/doc/refman/8.0/en/window-functions-usage.html "MySQL 8.0 Reference Manual — Window Function Concepts and Syntax"

[3]: https://dev.mysql.com/doc/workbench/en/wb-getting-started-tutorial-creating-a-model.html "MySQL Workbench Manual — Creating a Model"

[4]: https://learn.microsoft.com/en-us/power-query/connectors/mysql-database "Microsoft Learn — MySQL database connector for Power Query"
