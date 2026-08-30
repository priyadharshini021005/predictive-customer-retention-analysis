# Predictive Customer Retention Analysis using SQL

## Original 20-Phase Project Plan and Completion Mapping

The project is designed as a sequential MySQL and data-analytics workflow. The original sequence is preserved below, followed by the current completion status in this package.

| Original phase | Exact title | Objective and scope | Current status |
|---:|---|---|---|
| 1 | Project setup | Establish the GitHub-ready directory structure, documentation areas, scripts, SQL folders, evidence folders, and project assumptions. | Complete |
| 2 | Dataset design and generation | Design and generate realistic, internally consistent customer, product, order, and order-item CSV datasets with reproducibility and quality checks. | Complete |
| 3 | Database creation | Create the MySQL database namespace and confirm the MySQL 8.0 environment. | Complete |
| 4 | Table creation | Create staging and normalized relational tables with primary keys, foreign keys, checks, unique constraints, and analytical indexes. | Complete |
| 5 | Data insertion/import | Load the four CSV files into staging and normalized tables and reconcile imported row counts. | Complete |
| 6 | Data-quality validation | Validate nulls, duplicates, domains, dates, foreign-key readiness, transaction integrity, chronology, financial reconciliation, and constraint behavior. | Complete |
| 7 | Data cleaning | Resolve or document data-quality issues using a controlled, traceable policy. In this project, the 557 chronology exceptions remain unchanged and are excluded from lifecycle metrics through the approved eligibility rule. | Covered non-destructively |
| 8 | Exploratory SQL analysis | Use descriptive SQL analysis to study sales, customers, products, categories, channels, payment methods, order values, seasonality, and monthly trends. Reconcile outputs to validated completed-order totals. | Complete |
| 9 | Customer-level metrics | Build customer-level purchase metrics such as first/last order date, recency, order frequency, monetary value, active months, and recent activity. | Complete |
| 10 | RFM analysis | Implement Recency, Frequency, and Monetary measures, deterministic quintile scoring, descriptive segments, and customer-level reconciliation. | Complete |
| 11 | Retention analysis | Define and calculate period repeat retention, monthly active/new/returning customers, eligible revenue, and average order value. | Complete |
| 12 | Cohort analysis | Build cohort-month and elapsed-month retention metrics, month-0 and month-1 validation, and observation-completeness logic. | Complete |
| 13 | Purchase trend analysis | Analyze monthly purchasing trends and prepare trend outputs for reporting and visualization. | Complete |
| 14 | Behavioral customer risk scoring | Build a transparent, deterministic SQL behavioral risk score and churn-candidate indicator. Do not call it machine-learning prediction. | Complete and remediated |
| 15 | SQL views | Create reusable analytical views for customer summary, RFM, risk, retention, cohort, product, category, channel, payment, and KPI reporting. | Complete |
| 16 | Stored procedures and indexes | Create meaningful read-only stored procedures and verify required analytical indexes without unnecessary duplicate indexes. | Complete and validated |
| 17 | Power BI dashboard | Build the actual Power BI dashboard over the validated SQL data mart, including KPI cards, trends, retention/cohort visuals, RFM, risk, product/category, channel, and data-quality pages. | Not started |
| 18 | Documentation | Consolidate the methodology, assumptions, formulas, findings, limitations, dashboard interpretation, and technical instructions into the final project report. | Partially complete; phase-level documentation included |
| 19 | Final validation | Perform whole-project validation across source files, MySQL objects, calculations, views, procedures, dashboard inputs, documentation, and consistency. | Not started as a whole-project gate |
| 20 | Final project packaging | Produce the final submission package, clean obsolete artifacts, generate the final README, and provide the project ZIP. | Package created for completed scope through Phase 16; final post-Phase-17 packaging remains |

## Global rules

The database is normalized and uses primary keys, foreign keys, constraints, and indexes. The approved lifecycle rule is:

```sql
order_statuses.is_eligible = 1
AND orders.order_date >= customers.signup_date
```

The 557 chronology exceptions remain unchanged in the source database. They are documented as data-quality exceptions and excluded from lifecycle calculations. RFM segments are descriptive. The behavioral risk score is a deterministic SQL heuristic and is not a machine-learning prediction.

The project is intentionally packaged through Original Phase 16. Original Phase 17, the actual Power BI dashboard build, has not been executed.
