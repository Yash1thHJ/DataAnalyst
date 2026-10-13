-- Compare imported row counts with the validated Python source tables.
with table_counts as (
	select 'customers' as table_name, count(*) as actual_row_count, 99441 as expected_row_count from customers

	union all
	select 'orders', count(*), 99441 from orders

	union all
	select 'order_items', count(*), 112650 from order_items

	union all
	select 'products', count(*), 32951 from products

	union all
	select 'sellers', count(*), 3095 from sellers

	union all
	select 'payments', count(*), 103886 from payments

	union all
	select 'reviews', count(*), 99224 from reviews

	union all
	select 'category_translation', count(*), 71 from category_translation
	)
select table_name, actual_row_count, expected_row_count, actual_row_count - expected_row_count as row_count_difference,
	case 
		when actual_row_count = expected_row_count then 'Passed'
		else 'Failed'
	end as validation_status
from table_counts
order by table_name


-- Inspect category translations to investigate the extra imported row.
select * from category_translation
where product_category_name = 'product_category_name' and product_category_name_english = 'product_category_name_english'

-- Remove the CSV header mistakenly imported as a data row.
delete from category_translation where product_category_name='product_category_name' and product_category_name_english='product_category_name_english'

-- Inspect imported column definitions, including numeric precision and scale.
SELECT TABLE_NAME, COLUMN_NAME, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH, IS_NULLABLE, NUMERIC_PRECISION, NUMERIC_SCALE
FROM INFORMATION_SCHEMA.COLUMNS
where TABLE_NAME in ('customers', 'orders', 'order_items', 'products', 'sellers', 'payments', 'reviews', 'category_translation')
order by TABLE_NAME, ORDINAL_POSITION;

-- Compare total customer rows with distinct customer IDs.
select count(*) as total_rows, count(distinct customer_id) as distinct_customer_ids from customers

-- Validate order-ID uniqueness in the orders table.
select count(*) as total_rows, count(distinct order_id) as distinct_order_ids from orders

-- Validate product-ID uniqueness in the products table.
select count(*) as total_rows, count(distinct product_id) as distinct_product_ids from products

-- Validate seller-ID uniqueness in the sellers table.
select count(*) as total_rows, count(distinct seller_id) as distinct_seller_ids from sellers

-- Validate category-name uniqueness in the category_translation table.
select count(*) as total_rows, count(distinct product_category_name) as distinct_product_category_name from category_translation

-- Check for duplicate order-ID and item-ID combinations in order_items.
select count(*) as duplicate_count from order_items
group by order_id, order_item_id
having count(*) > 1;

-- Check for duplicate order-ID and payment-sequence combinations in payments.
select count(*) as duplicate_count from payments
group by order_id, payment_sequential
having count(*) > 1;

-- Check for duplicate review-ID and order-ID combinations in reviews.
select count(*) as duplicate_count from reviews
group by review_id, order_id
having count(*) > 1;

-- Check for missing identifiers in the composite keys of item, payment, and review records.
select count(*) as null_count from order_items
where order_id is null or order_item_id is null

select count(*) as null_count from payments
where order_id is null or payment_sequential is null

select count(*) as null_count from reviews
where review_id is null or order_id is null

-- Check for orders whose customer ID has no matching customer record.

select count(*) as unmatched_customer_count from orders 
where customer_id not in (select customer_id from customers)

-- Check for order items whose order ID has no matching order record.
select count(*) as unmatched_order_item_count from order_items
where order_id not in (select order_id from orders)

-- Check for order items whose product ID has no matching product record.
select count(*) from order_items
where product_id not in (select product_id from products)

-- Check for order items whose seller ID has no matching seller record.
select count(*) from order_items
where seller_id not in (select seller_id from sellers)

-- Check for payment records whose order ID has no matching order record.
select count(*) from payments
where order_id not in (select order_id from orders)

-- Check for review records whose order ID has no matching order record.
select count(*) from reviews
where order_id not in (select order_id from orders)

-- Check for products with a non-NULL category name missing from category_translation.
select count(*) as product_count from products
where product_category_name is not null and product_category_name not in (select product_category_name from category_translation)

-- Identify untranslated category names and count products in each category.
select product_category_name ,count(*) as product_count  from products
where product_category_name is not null and product_category_name not in (select product_category_name from category_translation)
group by product_category_name
order by product_count desc

-- Count products with a missing original category name.
select count(*) as null_product_category_name from products
where product_category_name is null

-- Count products with a missing English category translation.
select count(*) as null_product_category_name_english from products
where product_category_name_english is null

-- Validate missing timestamp counts in the imported orders table.
(SELECT 'order_approved_at' AS column_name, COUNT(*) AS missing_count FROM orders
WHERE order_approved_at IS NULL
union all 
SELECT 'order_delivered_carrier_date' AS column_name, COUNT(*) AS missing_count FROM orders
WHERE order_delivered_carrier_date IS NULL
union all
SELECT 'order_delivered_customer_date' AS column_name, COUNT(*) AS missing_count FROM orders
WHERE order_delivered_customer_date IS NULL);

-- Validate missing review-title and review-message counts after import.
(select 'review_comment_title' as column_name,  count(*) as missing_count from reviews
where review_comment_title is null
union all
select 'review_comment_message' as column_name,  count(*) as missing_count from reviews
where review_comment_message is null);

-- Validate missing geolocation-reference states in the sellers table.
select count(*) as missing_geolocation_reference_state from sellers
where geolocation_reference_state is null;

-- Validate missing product attribute counts after import.
(select 'product_name_length' as column_name , count(*) as missing_count from products 
where product_name_length is null

union all
select 'product_description_length' as column_name , count(*) as missing_count from products 
where product_description_length is null

union all
select 'product_photos_qty' as column_name , count(*) as missing_count from products 
where product_photos_qty is null

union all
select 'product_weight_g' as column_name , count(*) as missing_count from products 
where product_weight_g is null

union all
select 'product_length_cm' as column_name , count(*) as missing_count from products 
where product_length_cm is null

union all
select 'product_height_cm' as column_name , count(*) as missing_count from products 
where product_height_cm is null

union all
select 'product_width_cm' as column_name , count(*) as missing_count from products 
where product_width_cm is null);

-- Inspect the values and record counts of the payment-quality exception flag.
select flag_payment_quality_exception, count(*) as missing_count from payments
group by flag_payment_quality_exception

-- Inspect the values and record counts of the untranslated-category flag.
select flag_untranslated_category, count(*) as missing_count from products
group by flag_untranslated_category

-- Calculate full-table merchandise and freight totals for import reconciliation.
select sum(price) as total_merchandise_value , sum(freight_value) as total_freight_value from order_items

-- Calculate the full-table payment total for import reconciliation.
select sum(payment_value) as total_payment_value from payments