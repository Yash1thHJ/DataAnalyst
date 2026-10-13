-- Inspect customer-ID lengths before aligning the SQL column type.
SELECT MIN(LEN(customer_id)) AS minimum_id_length, MAX(LEN(customer_id)) AS maximum_id_length FROM customers;

-- Inspect existing constraints on the customers table before changing its ID type.
SELECT TABLE_NAME, CONSTRAINT_NAME, CONSTRAINT_TYPE FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS
WHERE TABLE_NAME = 'customers' AND TABLE_SCHEMA = 'dbo';

-- Identify the column used by the customers primary key.
SELECT CONSTRAINT_NAME, COLUMN_NAME, ORDINAL_POSITION FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE
WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'customers' AND CONSTRAINT_NAME = 'PK_olist_customers_clean';

-- Check whether any foreign keys reference the customers primary key.
SELECT CONSTRAINT_NAME, UNIQUE_CONSTRAINT_NAME FROM INFORMATION_SCHEMA.REFERENTIAL_CONSTRAINTS
WHERE UNIQUE_CONSTRAINT_SCHEMA = 'dbo' AND UNIQUE_CONSTRAINT_NAME = 'PK_olist_customers_clean';

-- Inspect indexes on customers before changing the customer-ID data type.
EXEC sp_helpindex 'dbo.customers';

-- Temporarily remove the customers primary key before altering customer_id.
ALTER TABLE dbo.customers
DROP CONSTRAINT PK_olist_customers_clean;

-- Change customer_id to CHAR(32) while preserving its NOT NULL requirement.
ALTER TABLE dbo.customers 
ALTER COLUMN customer_id CHAR(32) NOT NULL;

-- Restore the clustered primary key on customer_id.
ALTER TABLE	dbo.customers
ADD CONSTRAINT PK_olist_customers_clean
PRIMARY KEY CLUSTERED (customer_id);

USE olist_analytics;

-- Enable transaction rollback on runtime errors.
SET XACT_ABORT ON;

BEGIN TRY
    -- Treat the three structural changes as one transaction.
    BEGIN TRANSACTION;

    -- Temporarily remove the existing primary key.
    ALTER TABLE dbo.customers
    DROP CONSTRAINT PK_olist_customers_clean;

    -- Align customer_id with the type used in orders.
    ALTER TABLE dbo.customers
    ALTER COLUMN customer_id CHAR(32) NOT NULL;

    -- Restore the original clustered primary key.
    ALTER TABLE dbo.customers
    ADD CONSTRAINT PK_olist_customers_clean
        PRIMARY KEY CLUSTERED (customer_id);

    -- Save the changes after all three statements succeed.
    COMMIT TRANSACTION;

    PRINT 'Customer-ID type alignment completed successfully.';
END TRY
BEGIN CATCH
    -- Undo the changes if a transaction remains open.
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    -- Report the original error.
    THROW;
END CATCH;

-- Verify the stored customer-ID type after alignment.
SELECT TABLE_NAME, COLUMN_NAME, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH, IS_NULLABLE FROM INFORMATION_SCHEMA.COLUMNS
WHERE COLUMN_NAME='customer_id' AND TABLE_SCHEMA = 'dbo' AND TABLE_NAME IN ('customers','orders');

-- Verify customer row count and ID uniqueness after the data-type change.
SELECT COUNT(*) total_rows, COUNT(DISTINCT customer_id) distinct_customer_ids,SUM(CASE WHEN customer_id IS NULL THEN 1 ELSE 0 END) missing_customer_ids 
FROM dbo.customers;

-- Verify order-to-customer references after the customer-ID type change.
SELECT COUNT(customer_id) unmatched_customer_count FROM orders
WHERE customer_id NOT IN (SELECT customer_id FROM customers);

-- Confirm that the customers primary key was restored.
SELECT CONSTRAINT_NAME, CONSTRAINT_TYPE FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS
WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'customers';

-- List existing primary keys across the eight imported tables
SELECT TABLE_NAME, CONSTRAINT_NAME FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS 
WHERE TABLE_SCHEMA = 'dbo' AND CONSTRAINT_TYPE = 'PRIMARY KEY' AND
TABLE_NAME IN ('category_translation', 'customers', 'order_items', 'orders', 'payments', 'products', 'reviews', 'sellers')
ORDER BY TABLE_NAME;

-- Add a composite primary key to identify each order item uniquely.
ALTER TABLE dbo.order_items
ADD CONSTRAINT PK_order_items
PRIMARY KEY (order_id, order_item_id);

-- Add a composite primary key to identify each payment record uniquely.
ALTER TABLE dbo.payments
ADD CONSTRAINT PK_payments
PRIMARY KEY (order_id, payment_sequential);

-- Add a composite primary key to identify each review-order record uniquely.
ALTER TABLE dbo.reviews
ADD CONSTRAINT PK_reviews
PRIMARY KEY (review_id, order_id);

-- Add a foreign key linking each order to its customer.
ALTER TABLE dbo.orders
ADD CONSTRAINT FK_orders_customers
FOREIGN KEY (customer_id)
REFERENCES dbo.customers (customer_id);

-- Link each order item to its order and validate existing rows.
ALTER TABLE dbo.order_items
ADD CONSTRAINT FK_order_items_orders
FOREIGN KEY (order_id)
REFERENCES dbo.orders (order_id);

-- Confirm that both foreign keys are enabled and existing data was validated.
SELECT name, is_disabled, is_not_trusted
FROM sys.foreign_keys
WHERE name IN ('FK_orders_customers', 'FK_order_items_orders')
ORDER BY name;

-- Link each order item to its product and validate existing rows.
ALTER TABLE dbo.order_items
ADD CONSTRAINT FK_order_items_products
FOREIGN KEY (product_id)
REFERENCES dbo.products (product_id);

-- Link each order item to its seller and validate existing rows.
ALTER TABLE dbo.order_items
ADD CONSTRAINT FK_order_items_sellers
FOREIGN KEY (seller_id)
REFERENCES dbo.sellers (seller_id);

-- Link each payment record to its order and validate existing rows.
ALTER TABLE dbo.payments
ADD CONSTRAINT FK_payments_orders
FOREIGN KEY (order_id)
REFERENCES dbo.orders (order_id);

-- Link each review record to its order and validate existing rows.
ALTER TABLE dbo.reviews
ADD CONSTRAINT FK_reviews_orders
FOREIGN KEY (order_id)
REFERENCES dbo.orders (order_id);

-- Verify that all six project foreign keys are enabled and trusted.
SELECT name, is_disabled, is_not_trusted FROM sys.foreign_keys
order by name;

/*
SQL database setup checkpoint
- Full-source merchandise, freight, and payment totals reconcile with Python.
- customers.customer_id and orders.customer_id use CHAR(32) NOT NULL.
- All eight imported tables have primary keys.
- All six core foreign keys are enabled and trusted.

Category-translation exception
- 13 products have non-missing categories without matching translations.
- 610 products have missing category names.
- No foreign key is enforced between products and category_translation.

Execution note
- This script records changes already applied.
- Do not rerun constraint-creation statements against existing constraints.
*/