# Predictive Customer Retention Analysis using SQL

## Final Project Package — Original Phases 1–16

**Primary technology:** MySQL 8.0+ and MySQL Workbench  
**Supporting tools:** CSV/Excel preparation, Power BI-ready SQL views, and Python for reproducible dataset generation and validation only  
**Database:** `predictive_customer_retention`  
**Reference date:** 2025-12-31  
**Package status:** Finalized and validated through Original Phase 16

## 1. Project purpose

This project analyzes customer purchasing behavior to measure customer retention, identify inactive and at-risk customers, perform RFM segmentation, calculate a transparent behavioral customer risk score, and prepare a Power BI-ready reporting data mart.

The project deliberately separates three concepts. RFM segments are descriptive customer-value classifications. The behavioral risk score is a deterministic SQL heuristic based on measurable purchasing behavior. It is not a machine-learning model, a calibrated churn probability, or proof of future churn.

## 2. Original lifecycle eligibility rule

All lifecycle-oriented calculations use the approved rule:

```sql
order_statuses.is_eligible = 1
AND orders.order_date >= customers.signup_date
```

The 557 chronology-exception orders remain unchanged in the raw database. They are documented as data-quality exceptions and excluded from eligible lifecycle calculations. At the 2025-12-31 reference date, the eligible baseline is 35,017 completed orders, 7,069 eligible customers, and USD 53,997,988.41 in eligible line revenue.

## 3. Key validated metrics

| Metric | Validated value |
|---|---:|
| Customers | 8,000 |
| Products | 180 |
| Orders | 40,000 |
| Order items | 116,953 |
| Eligible completed orders | 35,017 |
| Eligible customers | 7,069 |
| Zero-purchase customers | 931 |
| Eligible line revenue | USD 53,997,988.41 |
| Period repeat retention | 67.12% |
| Weighted month-1 cohort retention | 25.05% |
| High / Medium / Low behavioral risk | 2,647 / 1,305 / 3,117 |
| Churn candidates | 2,491 |
| Chronology-exception orders | 557 |
| Chronology-exception customers | 404 |
| Power BI-ready SQL views | 14 |
| Phase 16 read-only stored procedures | 3 |

## 4. Original-plan phase mapping

| Original phase | Title | Status in this package |
|---:|---|---|
| 1 | Project setup | Complete |
| 2 | Dataset design and generation | Complete |
| 3 | Database creation | Complete |
| 4 | Table creation | Complete |
| 5 | Data insertion/import | Complete |
| 6 | Data-quality validation | Complete |
| 7 | Data cleaning | Covered non-destructively through documented chronology exceptions and lifecycle eligibility |
| 8 | Exploratory SQL analysis | Complete through the exploratory-analysis deliverables and evidence |
| 9 | Customer-level metrics | Complete through customer summary, RFM, retention, and risk features |
| 10 | RFM analysis | Complete |
| 11 | Retention analysis | Complete |
| 12 | Cohort analysis | Complete |
| 13 | Purchase trend analysis | Complete through exploratory trends and monthly data-mart views |
| 14 | Behavioral customer risk scoring | Complete and remediated |
| 15 | SQL views | Complete through 14 validated Power BI-ready views |
| 16 | Stored procedures and indexes | Complete: 3 read-only procedures and required indexes verified |
| 17 | Power BI dashboard | Not started; dashboard specification and data mart are included, but no `.pbix` was created |
| 18 | Documentation | Phase-level documentation is included; final consolidated reporting remains a later phase |
| 19 | Final validation | Phase-specific validation is included; whole-project final validation remains a later phase |
| 20 | Final project packaging | This ZIP is the packaging artifact for the completed scope through Original Phase 16 |

## 5. Package structure

```text
README_FINAL.md
project_plan_original_20_phases.md
data/raw/                         # Final Phase 2 CSV sources
scripts/                          # Reproducible generators and validators
sql/01_database/                  # Database namespace
sql/02_tables/                    # Staging and normalized DDL
sql/03_load/                      # CSV import SQL
sql/04_validation/                # Phase 3 schema and constraint validation
sql/05_data_quality/              # Phase 4 data-quality and exception review
sql/06_exploratory_analysis/     # Phase 4 exploratory SQL and reconciliation
sql/07_rfm_retention/             # Phase 5 RFM, retention, cohort, and validation SQL
sql/08_risk_scoring/              # Phase 6 remediated risk scoring and validation
sql/09_powerbi_datamart/          # Phase 7 data-mart views and reporting queries
sql/10_stored_procedures/         # Original Phase 16 procedures and validation

docs/phase1/                      # Phase 1 blueprint
docs/phase2/                      # Phase 2 specification and report
docs/phase3/                      # Phase 3 validation and index review
docs/phase4/                      # Phase 4 validation and exploratory report
docs/phase5/                      # Phase 5 methodology, validation, and review
docs/phase6/                      # Phase 6 methodology and remediated report
docs/phase7/                      # Power BI data-mart and dashboard specifications/reports
docs/phase16/                     # Stored-procedure methodology and validation report

evidence/validation_outputs/      # Phase 2 generation and validation evidence
evidence/phase3/                  # Database, import, schema, constraint, and index logs
evidence/phase4/                  # Data-quality and exploratory logs
evidence/phase5/                  # RFM, retention, cohort, and summary evidence
evidence/phase6/                  # Remediated risk results, validation, and repeatability evidence
evidence/phase7/                  # View creation, mart validation, reporting, and smoke-test evidence
evidence/phase16/                 # Procedure calls, boundary tests, and wrapper summary
```

## 6. Validation status

Every completed phase has a corresponding validation artifact. Database creation, table constraints, CSV import counts, foreign-key readiness, financial reconciliation, RFM reconciliation, retention/cohort formulas, risk-score bounds and flags, Power BI view grain, data-mart totals, stored-procedure behavior, and required-index coverage were validated.

The final package excludes superseded debug scripts, pre-remediation logs, obsolete rerun artifacts, temporary files, and duplicate outputs. The included Phase 6 files are the remediated versions with nonblank risk reasons and full-precision cadence thresholding.

## 7. Assumptions and limitations

The reference date is fixed at 2025-12-31. Eligible order value is based on `order_items.line_total`. Order-level discounts and shipping are retained at order grain and are not allocated to order items. Gross margin is a descriptive estimate using stored product cost.

The risk score is deterministic SQL behavior scoring. The dataset has no post-reference observation window, so churn candidates cannot be evaluated as actual future churn outcomes. RFM segments are descriptive and should not be interpreted as risk probabilities.

The project uses a normalized relational schema with primary keys, foreign keys, constraints, and analytical indexes. The data mart uses separate order and order-item grains; Power BI measures must avoid directly joining these grains without an appropriate aggregation model.

## 8. How to reproduce the project

Use MySQL 8.0+ and MySQL Workbench. Run the SQL scripts in numeric directory order after generating or importing the final CSV sources. Run each validation script after its corresponding build step. Create the Power BI model from the views under `sql/09_powerbi_datamart/` and follow `docs/phase7/powerbi_dashboard_specification.md`.

The project is intentionally stopped before Original Phase 17. No Power BI dashboard file or published report is included in this package.

## 9. Core supporting documents

| Document | Purpose |
|---|---|
| `project_plan_original_20_phases.md` | Original project sequence and phase objectives |
| `docs/phase1/phase1_blueprint.md` | Business and database architecture blueprint |
| `docs/phase2/phase2_validation_report.md` | Dataset generation and quality validation |
| `docs/phase3/phase3_validation_report.md` | MySQL schema, import, constraint, and index validation |
| `docs/phase4/phase4_validation_report.md` | Data-quality and exploratory-analysis validation |
| `docs/phase5/phase5_validation_report.md` | RFM and retention validation |
| `docs/phase6/phase6_validation_report.md` | Remediated behavioral risk-scoring validation |
| `docs/phase7/phase7_validation_report.md` | Power BI data-mart validation and final reporting |
| `docs/phase16/phase16_validation_report.md` | Stored-procedure and index validation |

## References

[1]: https://dev.mysql.com/doc/refman/8.0/en/create-table-foreign-keys.html "MySQL 8.0 Reference Manual — Foreign Key Constraints"

[2]: https://dev.mysql.com/doc/refman/8.0/en/create-view.html "MySQL 8.0 Reference Manual — CREATE VIEW Statement"

[3]: https://dev.mysql.com/doc/refman/8.0/en/create-procedure.html "MySQL 8.0 Reference Manual — CREATE PROCEDURE Statement"
