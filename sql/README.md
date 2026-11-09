# Olist SQL Server Setup

## Purpose and scope

The SQL Server database contains eight cleaned source tables from the
Python preparation stage.

Import verification uses all source records. Business analysis uses
delivered orders unless explicitly stated otherwise.

## Environment

- Database: `olist_analytics`
- Database engine: Microsoft SQL Server
- SQL client: SQL Server Management Studio (SSMS)
- Source folder: `data/processed/`
- Source profiling notebook: `notebooks/08_sql_data_preparation.ipynb`

## Source files and imported tables

All tables use the `dbo` schema.

| Cleaned CSV file | SQL table | Expected rows |
|---|---|---:|
| olist_customers_clean.csv | customers | 99,441 |
| olist_orders_clean.csv | orders | 99,441 |
| olist_order_items_clean.csv | order_items | 112,650 |
| olist_products_clean.csv | products | 32,951 |
| olist_sellers_clean.csv | sellers | 3,095 |
| olist_order_payments_clean.csv | payments | 103,886 |
| olist_order_reviews_clean.csv | reviews | 99,224 |
| product_category_name_translation_clean.csv | category_translation | 71 |

## Import process

The tables were created and populated using the SSMS Import Flat File wizard.

1. Create or select the `olist_analytics` database.
2. Right-click the database and select Tasks > Import Flat File.
3. Select a cleaned CSV from `data/processed/`.
4. Set the destination table name using the mapping above.
5. Inspect the preview and confirm that headers are column names,
   not imported data rows.
6. Review data types, text lengths, and nullability before completing
   the import.
7. Repeat for all eight files.
8. Run the import-validation queries before adding the remaining constraints.

No separate CREATE TABLE script was used for this import workflow.

## Data-type decisions

- Order, product, seller, and review IDs use `CHAR(32)`.
- `customers.customer_id` was initially imported as `NVARCHAR(50)`
  and subsequently aligned to `CHAR(32) NOT NULL`.
- `customers.customer_unique_id` remains `NVARCHAR(50)`.
- Customer and seller ZIP-code prefixes use `CHAR(5)` to retain leading zeros.
- `price`, `freight_value`, and `payment_value` use `DECIMAL(12,2)`.
- Product numeric attributes use nullable `DECIMAL(10,0)` columns.
- Timestamp fields use `DATETIME2`; estimated delivery dates use `DATE`.
- Quality flags remain `NVARCHAR(5)` containing 'True' or 'False'.
- Review-response duration remains `NVARCHAR(50)` in its original
  duration-string format.
- Review titles and messages use nullable `NVARCHAR(100)` and
  `NVARCHAR(1000)`, respectively.
- Source missing values are retained as SQL NULL where applicable.

Column definitions were inspected against the Python source profiles
rather than accepted solely from the wizard's inferred types.

## Script sequence

| File | Purpose |
|---|---|
| 01_sqlserver_database_setup.sql | Database setup |
| 03_sqlserver_import_validation.sql | Imported structure, counts, keys, relationships, missing values, and monetary checks |
| 04_sqlserver_database_constraints.sql | Customer-ID alignment, primary keys, foreign keys, and constraint verification |
| 05_sqlserver_business_kpis.sql | Delivered-order business KPIs and monthly trends |
| 06_sqlserver_category_product_analysis.sql | Category and product performance |
| 07_sqlserver_regional_customer_analysis.sql | Regional performance and customer analysis |
| 08_sqlserver_delivery_review_analysis.sql | Delivery performance and customer reviews |
| 09_sqlserver_payment_commercial_analysis.sql | Payment methods, installments, reconciliation, order-value bands, and freight burden |

Import the CSV files after database setup and before running import validation.

The constraint script records changes applied to the imported tables.
Its creation statements are not designed for repeated execution against
existing constraints. Review the current database state before running it.

## Primary keys

| Table | Primary-key columns |
|---|---|
| customers | customer_id |
| orders | order_id |
| order_items | order_id, order_item_id |
| products | product_id |
| sellers | seller_id |
| payments | order_id, payment_sequential |
| reviews | review_id, order_id |
| category_translation | product_category_name |

`review_id` alone is not unique; the review-order combination is the key.

## Foreign keys

| Child column | Referenced column |
|---|---|
| orders.customer_id | customers.customer_id |
| order_items.order_id | orders.order_id |
| order_items.product_id | products.product_id |
| order_items.seller_id | sellers.seller_id |
| payments.order_id | orders.order_id |
| reviews.order_id | orders.order_id |

All six foreign keys were confirmed enabled and trusted:
`is_disabled = 0` and `is_not_trusted = 0`.

## Known exceptions and import correction

- 610 products have a missing source category.
- 13 products have non-missing categories without matching translations:
  - `portateis_cozinha_e_preparadores_de_alimentos`: 10 products.
  - `pc_gamer`: 3 products.
- Consequently, 623 products have a missing English category name.
- No foreign key is enforced from products to category_translation
  because of the 13 unmatched non-missing category values.
- An accidentally imported header row in category_translation was removed.
  Its final row count is 71.

## Monetary reconciliation

Full-table SQL totals match the cleaned Python sources to two decimal places.

| Measure | Python and SQL total (BRL) |
|---|---:|
| Merchandise: SUM(order_items.price) | 13,591,643.70 |
| Freight: SUM(order_items.freight_value) | 2,251,909.54 |
| Payments: SUM(payments.payment_value) | 16,008,872.12 |

These are full-source totals, not delivered-order-only business metrics.

## Verified checkpoint

- All eight imported row counts match the cleaned sources.
- Candidate keys contain no duplicates or missing key values.
- The six core relationships contain no unmatched references.
- Known missing values and category exceptions were retained.
- Monetary totals reconcile with Python.
- Customer-ID type alignment preserved 99,441 unique customer records.
- All eight tables have primary keys.
- All six core foreign keys are enabled and trusted.