-- Check delivery-date coverage for delivered orders.
SELECT COUNT(order_id) AS delivered_order_count,
COUNT(CASE WHEN order_delivered_customer_date IS NOT NULL THEN 1 END) AS available_delivery_date_count,
COUNT(CASE WHEN order_delivered_customer_date IS NULL THEN 1 END) AS missing_delivery_date_count
FROM orders
WHERE order_status = 'delivered';

-- Calculate elapsed delivery duration in days for each delivered order.
SELECT order_id, order_purchase_timestamp, order_delivered_customer_date, 
(DATEDIFF_BIG(SECOND, order_purchase_timestamp, order_delivered_customer_date)/86400.0) AS delivery_duration_days
FROM orders
WHERE order_status = 'delivered'
ORDER BY order_id;

-- Validate delivery-duration coverage and identify negative durations.
;WITH delivery_metrics AS (SELECT order_id, order_purchase_timestamp, order_delivered_customer_date, 
(DATEDIFF_BIG(SECOND, order_purchase_timestamp, order_delivered_customer_date)/86400.0) AS delivery_duration_days
FROM orders
WHERE order_status = 'delivered')

SELECT COUNT(order_id) AS delivered_order_count,
COUNT(CASE WHEN delivery_duration_days IS NOT NULL THEN 1 END) AS available_duration_count,
COUNT(CASE WHEN delivery_duration_days IS NULL THEN 1 END) AS missing_duration_count,
COUNT(CASE WHEN delivery_duration_days < 0 THEN 1 END) AS negative_duration_count
FROM delivery_metrics;

-- Classify delivered orders by actual versus estimated delivery date.
SELECT order_id, 
CAST(order_delivered_customer_date AS DATE) order_delivered_customer_date,order_estimated_delivery_date,
(CASE WHEN CAST(order_delivered_customer_date AS DATE) IS NULL OR CAST(order_estimated_delivery_date AS DATE)  IS NULL THEN 'missing'
	  WHEN CAST(order_delivered_customer_date AS DATE) < CAST(order_estimated_delivery_date AS DATE)  THEN  'early'
	  WHEN CAST(order_delivered_customer_date AS DATE) = CAST(order_estimated_delivery_date AS DATE)  THEN  'on_time'
	  WHEN CAST(order_delivered_customer_date AS DATE) > CAST(order_estimated_delivery_date AS DATE)  THEN  'late'
 END) AS delivery_status
FROM orders
WHERE order_status = 'delivered'
ORDER BY order_id;

-- Validate delivery-status counts across all delivered orders.
;WITH classified_deliveries AS (SELECT order_id, 
CAST(order_delivered_customer_date AS DATE) order_delivered_customer_date,order_estimated_delivery_date,
(CASE WHEN CAST(order_delivered_customer_date AS DATE) IS NULL OR CAST(order_estimated_delivery_date AS DATE)  IS NULL THEN 'missing'
	  WHEN CAST(order_delivered_customer_date AS DATE) < CAST(order_estimated_delivery_date AS DATE)  THEN  'early'
	  WHEN CAST(order_delivered_customer_date AS DATE) = CAST(order_estimated_delivery_date AS DATE)  THEN  'on_time'
	  WHEN CAST(order_delivered_customer_date AS DATE) > CAST(order_estimated_delivery_date AS DATE)  THEN  'late'
 END) AS delivery_status
FROM orders
WHERE order_status = 'delivered')

SELECT delivery_status, COUNT(delivery_status) AS order_count
FROM classified_deliveries
GROUP BY delivery_status;

-- Calculate the late-delivery rate among orders with known delivery status.
;WITH classified_deliveries AS (SELECT order_id, 
 CAST(order_delivered_customer_date AS DATE) order_delivered_customer_date,order_estimated_delivery_date,
(CASE WHEN CAST(order_delivered_customer_date AS DATE) IS NULL OR CAST(order_estimated_delivery_date AS DATE)  IS NULL THEN 'missing'
	  WHEN CAST(order_delivered_customer_date AS DATE) < CAST(order_estimated_delivery_date AS DATE)  THEN  'early'
	  WHEN CAST(order_delivered_customer_date AS DATE) = CAST(order_estimated_delivery_date AS DATE)  THEN  'on_time'
	  WHEN CAST(order_delivered_customer_date AS DATE) > CAST(order_estimated_delivery_date AS DATE)  THEN  'late'
 END) AS delivery_status
FROM orders
WHERE order_status = 'delivered')

SELECT COUNT(order_id) AS delivery_status_eligible_count,
COUNT(CASE WHEN delivery_status = 'late' THEN 1 END) AS late_order_count,
(COUNT(CASE WHEN delivery_status = 'late' THEN 1 END)*100.0/COUNT(order_id)) AS late_delivery_rate_pct
FROM classified_deliveries
WHERE delivery_status != 'missing';

-- Aggregate review records to one row per order for delivery–review comparisons.
SELECT order_id, 
COUNT(review_id) AS review_record_count,
AVG(CAST(review_score AS DECIMAL(10, 4))) AS average_review_score
FROM reviews
GROUP BY order_id
ORDER BY order_id;

-- Validate order-level review coverage, record counts, and average-score ranges.
;WITH order_review_summary AS (SELECT order_id, 
COUNT(review_id) AS review_record_count,
AVG(CAST(review_score AS DECIMAL(10, 4))) AS average_review_score
FROM reviews
GROUP BY order_id)

SELECT COUNT(*) AS reviewed_order_count,
COUNT(DISTINCT(order_id)) AS distinct_order_count,
SUM(review_record_count) AS total_review_records,
COUNT(CASE WHEN average_review_score IS NULL THEN 1 END) AS missing_average_score_count,
COUNT(CASE WHEN average_review_score < 1 THEN 1
		   WHEN average_review_score > 5 THEN 1 END) AS invalid_average_score_count
FROM order_review_summary;

-- Combine delivered-order classifications with order-level review summaries.
;WITH classified_deliveries AS (SELECT order_id, 
 CAST(order_delivered_customer_date AS DATE) order_delivered_customer_date,order_estimated_delivery_date,
(CASE WHEN CAST(order_delivered_customer_date AS DATE) IS NULL OR CAST(order_estimated_delivery_date AS DATE)  IS NULL THEN 'missing'
	  WHEN CAST(order_delivered_customer_date AS DATE) < CAST(order_estimated_delivery_date AS DATE)  THEN  'early'
	  WHEN CAST(order_delivered_customer_date AS DATE) = CAST(order_estimated_delivery_date AS DATE)  THEN  'on_time'
	  WHEN CAST(order_delivered_customer_date AS DATE) > CAST(order_estimated_delivery_date AS DATE)  THEN  'late'
 END) AS delivery_status
FROM orders
WHERE order_status = 'delivered'),

order_review_summary AS (SELECT order_id, 
COUNT(review_id) AS review_record_count,
AVG(CAST(review_score AS DECIMAL(10, 4))) AS average_review_score
FROM reviews
GROUP BY order_id)

SELECT cd.order_id, cd.delivery_status, ors.review_record_count, ors.average_review_score 
FROM classified_deliveries AS cd
LEFT JOIN order_review_summary AS ors ON cd.order_id = ors.order_id
ORDER BY cd.order_id;

-- Validate order uniqueness and review coverage after combining deliveries and reviews.
;WITH classified_deliveries AS (SELECT order_id, 
 CAST(order_delivered_customer_date AS DATE) order_delivered_customer_date,order_estimated_delivery_date,
(CASE WHEN CAST(order_delivered_customer_date AS DATE) IS NULL OR CAST(order_estimated_delivery_date AS DATE)  IS NULL THEN 'missing'
	  WHEN CAST(order_delivered_customer_date AS DATE) < CAST(order_estimated_delivery_date AS DATE)  THEN  'early'
	  WHEN CAST(order_delivered_customer_date AS DATE) = CAST(order_estimated_delivery_date AS DATE)  THEN  'on_time'
	  WHEN CAST(order_delivered_customer_date AS DATE) > CAST(order_estimated_delivery_date AS DATE)  THEN  'late'
 END) AS delivery_status
FROM orders
WHERE order_status = 'delivered'),

order_review_summary AS (SELECT order_id, 
COUNT(review_id) AS review_record_count,
AVG(CAST(review_score AS DECIMAL(10, 4))) AS average_review_score
FROM reviews
GROUP BY order_id),

delivery_review_scope AS (SELECT cd.order_id, cd.delivery_status, ors.review_record_count, ors.average_review_score 
FROM classified_deliveries AS cd
LEFT JOIN order_review_summary AS ors ON cd.order_id = ors.order_id)

SELECT COUNT(*) AS delivered_order_count, COUNT(DISTINCT(ORDER_ID)) AS distinct_order_count,
COUNT(CASE WHEN average_review_score IS NOT NULL THEN 1 END) AS reviewed_order_count,
COUNT(CASE WHEN average_review_score IS NULL THEN 1 END) AS missing_review_order_count
FROM delivery_review_scope;

-- Compare review counts, coverage percentages, and average order review scores by delivery status.
;WITH classified_deliveries AS (SELECT order_id, 
 CAST(order_delivered_customer_date AS DATE) order_delivered_customer_date,order_estimated_delivery_date,
(CASE WHEN CAST(order_delivered_customer_date AS DATE) IS NULL OR CAST(order_estimated_delivery_date AS DATE)  IS NULL THEN 'missing'
	  WHEN CAST(order_delivered_customer_date AS DATE) < CAST(order_estimated_delivery_date AS DATE)  THEN  'early'
	  WHEN CAST(order_delivered_customer_date AS DATE) = CAST(order_estimated_delivery_date AS DATE)  THEN  'on_time'
	  WHEN CAST(order_delivered_customer_date AS DATE) > CAST(order_estimated_delivery_date AS DATE)  THEN  'late'
 END) AS delivery_status
FROM orders
WHERE order_status = 'delivered'),

order_review_summary AS (SELECT order_id, 
COUNT(review_id) AS review_record_count,
AVG(CAST(review_score AS DECIMAL(10, 4))) AS average_review_score
FROM reviews
GROUP BY order_id),

delivery_review_scope AS (SELECT cd.order_id, cd.delivery_status, ors.review_record_count, ors.average_review_score 
FROM classified_deliveries AS cd
LEFT JOIN order_review_summary AS ors ON cd.order_id = ors.order_id)

SELECT delivery_status, 
COUNT(order_id) AS order_count,
COUNT(CASE WHEN average_review_score IS NOT NULL THEN 1 END) AS reviewed_order_count,
COUNT(CASE WHEN average_review_score IS NULL THEN 1 END) AS missing_review_order_count,
AVG(average_review_score) AS mean_order_review_score,
COUNT(CASE WHEN average_review_score IS NOT NULL THEN 1 END) * 100.0/ NULLIF(COUNT(order_id), 0) AS review_coverage_pct
FROM delivery_review_scope
GROUP BY delivery_status;

-- Compare review coverage, average scores, and low-review-score rates by delivery status.
;WITH classified_deliveries AS (SELECT order_id, 
 CAST(order_delivered_customer_date AS DATE) order_delivered_customer_date,order_estimated_delivery_date,
(CASE WHEN CAST(order_delivered_customer_date AS DATE) IS NULL OR CAST(order_estimated_delivery_date AS DATE)  IS NULL THEN 'missing'
	  WHEN CAST(order_delivered_customer_date AS DATE) < CAST(order_estimated_delivery_date AS DATE)  THEN  'early'
	  WHEN CAST(order_delivered_customer_date AS DATE) = CAST(order_estimated_delivery_date AS DATE)  THEN  'on_time'
	  WHEN CAST(order_delivered_customer_date AS DATE) > CAST(order_estimated_delivery_date AS DATE)  THEN  'late'
 END) AS delivery_status
FROM orders
WHERE order_status = 'delivered'),

order_review_summary AS (SELECT order_id, 
COUNT(review_id) AS review_record_count,
AVG(CAST(review_score AS DECIMAL(10, 4))) AS average_review_score
FROM reviews
GROUP BY order_id),

delivery_review_scope AS (SELECT cd.order_id, cd.delivery_status, ors.review_record_count, ors.average_review_score 
FROM classified_deliveries AS cd
LEFT JOIN order_review_summary AS ors ON cd.order_id = ors.order_id)

SELECT delivery_status, 
COUNT(order_id) AS order_count,
COUNT(CASE WHEN average_review_score IS NOT NULL THEN 1 END) AS reviewed_order_count,
COUNT(CASE WHEN average_review_score IS NULL THEN 1 END) AS missing_review_order_count,
AVG(average_review_score) AS mean_order_review_score,
COUNT(CASE WHEN average_review_score IS NOT NULL THEN 1 END) * 100.0/ NULLIF(COUNT(order_id), 0) AS review_coverage_pct,
COUNT(CASE WHEN average_review_score <= 2 THEN 1 END) AS low_review_order_count,
COUNT(CASE WHEN average_review_score <= 2 THEN 1 END) * 100.0/ NULLIF(COUNT(CASE WHEN average_review_score IS NOT NULL THEN 1 END), 0) AS low_review_rate_pct
FROM delivery_review_scope
GROUP BY delivery_status
ORDER BY delivery_status;

/*
Delivery and review findings:
- Of 96,478 delivered orders, 96,470 had known delivery status.
  Eight orders had missing delivery dates.
- 6,534 orders arrived after the estimated delivery date:
  6.77% of orders with known delivery status.
- Reviews were available for 95,832 delivered orders;
  646 orders had no review.
- Late orders had a mean order review score of 2.27,
  compared with 4.29 for early orders and 4.04 for
  orders delivered on the estimated date.
- Among reviewed orders, 62.36% of late orders had an
  average review score of 2 or below, compared with
  9.19% of early orders and 12.27% of on-time orders.
- These results show an association between late delivery
  and lower review scores; they do not establish causation.
- SQL and Python delivery-review summaries reconciled
  across all four delivery-status groups.
*/