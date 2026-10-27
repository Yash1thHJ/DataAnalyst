-- Summarize delivered-order volume and merchandise GMV by customer state.
SELECT cust.customer_state, 
COUNT(DISTINCT(ord.order_id)) AS delivered_order_count,
COUNT(ot.order_item_id) AS delivered_item_count,
SUM(ot.price) AS merchandise_gmv
FROM orders AS ord
JOIN order_items AS ot ON ord.order_id = ot.order_id
JOIN customers AS cust ON ord.customer_id = cust.customer_id
WHERE ord.order_status = 'delivered'
GROUP BY cust.customer_state
ORDER BY merchandise_gmv DESC, cust.customer_state ASC;

-- Reconcile state-level order counts, item counts, and merchandise GMV with delivered-order totals.
;WITH state_kpis AS (SELECT cust.customer_state, 
COUNT(DISTINCT(ord.order_id)) AS delivered_order_count,
COUNT(ot.order_item_id) AS delivered_item_count,
SUM(ot.price) AS merchandise_gmv
FROM orders AS ord
JOIN order_items AS ot ON ord.order_id = ot.order_id
JOIN customers AS cust ON ord.customer_id = cust.customer_id
WHERE ord.order_status = 'delivered'
GROUP BY cust.customer_state)

SELECT COUNT(customer_state) AS state_count, 
SUM(delivered_order_count) AS total_delivered_orders,
SUM(delivered_item_count) AS total_delivered_items, 
SUM(merchandise_gmv) AS total_merchandise_gmv
FROM state_kpis;

-- Calculate average order merchandise value and GMV share by customer state.
;WITH state_kpis AS (SELECT cust.customer_state, 
COUNT(DISTINCT(ord.order_id)) AS delivered_order_count,
COUNT(ot.order_item_id) AS delivered_item_count,
SUM(ot.price) AS merchandise_gmv
FROM orders AS ord
JOIN order_items AS ot ON ord.order_id = ot.order_id
JOIN customers AS cust ON ord.customer_id = cust.customer_id
WHERE ord.order_status = 'delivered'
GROUP BY cust.customer_state)

SELECT *, (merchandise_gmv/delivered_order_count) AS average_order_merchandise_value,
(merchandise_gmv * 100.0/ NULLIF(SUM(merchandise_gmv) OVER (), 0)) AS gmv_share_pct
FROM state_kpis
ORDER BY merchandise_gmv DESC, customer_state ASC;

-- Validate state GMV-share coverage and percentage totals.
;WITH state_kpis AS (SELECT cust.customer_state, 
COUNT(DISTINCT(ord.order_id)) AS delivered_order_count,
COUNT(ot.order_item_id) AS delivered_item_count,
SUM(ot.price) AS merchandise_gmv
FROM orders AS ord
JOIN order_items AS ot ON ord.order_id = ot.order_id
JOIN customers AS cust ON ord.customer_id = cust.customer_id
WHERE ord.order_status = 'delivered'
GROUP BY cust.customer_state),

state_gmv_shares AS (SELECT *, 
(merchandise_gmv/delivered_order_count) AS average_order_merchandise_value,
(merchandise_gmv * 100.0/ NULLIF(SUM(merchandise_gmv) OVER (), 0)) AS gmv_share_pct
FROM state_kpis)

SELECT COUNT(customer_state) AS state_count, 
COUNT(CASE WHEN gmv_share_pct IS NULL THEN 1 END) AS missing_gmv_share_count,
COUNT(CASE  WHEN gmv_share_pct < 0 THEN 1 
			WHEN gmv_share_pct > 100 THEN 1 END ) AS invalid_gmv_share_count,
SUM(gmv_share_pct) AS total_gmv_share_pct
FROM state_gmv_shares;

-- Identify the five customer states contributing the most delivered-order merchandise GMV.
;WITH state_kpis AS (SELECT cust.customer_state, 
COUNT(DISTINCT(ord.order_id)) AS delivered_order_count,
COUNT(ot.order_item_id) AS delivered_item_count,
SUM(ot.price) AS merchandise_gmv
FROM orders AS ord
JOIN order_items AS ot ON ord.order_id = ot.order_id
JOIN customers AS cust ON ord.customer_id = cust.customer_id
WHERE ord.order_status = 'delivered'
GROUP BY cust.customer_state),

state_gmv_shares AS (SELECT *, 
(merchandise_gmv/delivered_order_count) AS average_order_merchandise_value,
(merchandise_gmv * 100.0/ NULLIF(SUM(merchandise_gmv) OVER (), 0)) AS gmv_share_pct
FROM state_kpis)

SELECT TOP 5 * FROM state_gmv_shares
ORDER BY merchandise_gmv DESC, customer_state ASC;

-- Calculate the combined merchandise GMV contribution of the top five customer states.
;WITH state_kpis AS (SELECT cust.customer_state, 
COUNT(DISTINCT(ord.order_id)) AS delivered_order_count,
COUNT(ot.order_item_id) AS delivered_item_count,
SUM(ot.price) AS merchandise_gmv
FROM orders AS ord
JOIN order_items AS ot ON ord.order_id = ot.order_id
JOIN customers AS cust ON ord.customer_id = cust.customer_id
WHERE ord.order_status = 'delivered'
GROUP BY cust.customer_state),

state_gmv_shares AS (SELECT *, 
(merchandise_gmv/delivered_order_count) AS average_order_merchandise_value,
(merchandise_gmv * 100.0/ NULLIF(SUM(merchandise_gmv) OVER (), 0)) AS gmv_share_pct
FROM state_kpis),

top_5_states AS (SELECT TOP 5 * 
FROM state_gmv_shares
ORDER BY merchandise_gmv DESC, customer_state ASC)

SELECT COUNT(*) AS top_state_count,
SUM(merchandise_gmv) AS top_5_merchandise_gmv,
(SUM(merchandise_gmv) * 100.0 / NULLIF((SELECT SUM(merchandise_gmv) FROM state_kpis), 0)) AS top_5_gmv_share_pct
FROM top_5_states;

/*
Regional GMV findings:
- São Paulo contributed 38.33% of delivered-order merchandise GMV.
- The five leading customer states—SP, RJ, MG, RS, and PR—
  contributed R$9,774,727.10, representing 73.93% of total GMV.
- State attribution uses the customer record associated with each order.
*/

-- Summarize delivered-order counts, item counts, and merchandise GMV by unique customer.
SELECT cust.customer_unique_id, 
COUNT(DISTINCT(ord.order_id)) AS customer_order_count,
COUNT(ot.order_item_id) AS customer_item_count,
SUM(ot.price) AS customer_gmv
FROM orders AS ord
JOIN order_items AS ot ON ord.order_id = ot.order_id
JOIN customers AS cust ON ord.customer_id = cust.customer_id
WHERE ord.order_status = 'delivered'
GROUP BY cust.customer_unique_id
ORDER BY customer_gmv DESC, cust.customer_unique_id ASC;

-- Reconcile customer-level counts and merchandise GMV with delivered-order totals.
;WITH customer_kpis AS (SELECT cust.customer_unique_id, 
COUNT(DISTINCT(ord.order_id)) AS customer_order_count,
COUNT(ot.order_item_id) AS customer_item_count,
SUM(ot.price) AS customer_gmv
FROM orders AS ord
JOIN order_items AS ot ON ord.order_id = ot.order_id
JOIN customers AS cust ON ord.customer_id = cust.customer_id
WHERE ord.order_status = 'delivered'
GROUP BY cust.customer_unique_id)

SELECT COUNT(customer_unique_id) AS customer_count, 
COUNT(DISTINCT(customer_unique_id)) AS distinct_customer_count, 
SUM(customer_order_count) AS total_delivered_orders,
SUM(customer_item_count) AS total_delivered_items,
SUM(customer_gmv) AS total_merchandise_gmv
FROM customer_kpis;

-- Classify customers as one-time or repeat based on delivered-order count.
;WITH customer_kpis AS (SELECT cust.customer_unique_id, 
COUNT(DISTINCT(ord.order_id)) AS customer_order_count,
COUNT(ot.order_item_id) AS customer_item_count,
SUM(ot.price) AS customer_gmv
FROM orders AS ord
JOIN order_items AS ot ON ord.order_id = ot.order_id
JOIN customers AS cust ON ord.customer_id = cust.customer_id
WHERE ord.order_status = 'delivered'
GROUP BY cust.customer_unique_id)

SELECT *, 
( CASE WHEN customer_order_count = 1 THEN 'one_time'
		WHEN customer_order_count > 1 THEN 'repeat' 
		END) AS customer_type
FROM customer_kpis;

-- Count one-time and repeat customers in the delivered-order scope.
;WITH customer_kpis AS (SELECT cust.customer_unique_id, 
COUNT(DISTINCT(ord.order_id)) AS customer_order_count,
COUNT(ot.order_item_id) AS customer_item_count,
SUM(ot.price) AS customer_gmv
FROM orders AS ord
JOIN order_items AS ot ON ord.order_id = ot.order_id
JOIN customers AS cust ON ord.customer_id = cust.customer_id
WHERE ord.order_status = 'delivered'
GROUP BY cust.customer_unique_id),

classified_customers AS (SELECT *, 
( CASE WHEN customer_order_count = 1 THEN 'one_time'
		WHEN customer_order_count > 1 THEN 'repeat' 
		END) AS customer_type
FROM customer_kpis)

SELECT customer_type, COUNT(customer_type) AS customer_count
FROM classified_customers
GROUP BY customer_type;

-- Compare delivered-order volume, item counts, and merchandise GMV by customer type.
;WITH customer_kpis AS (SELECT cust.customer_unique_id, 
COUNT(DISTINCT(ord.order_id)) AS customer_order_count,
COUNT(ot.order_item_id) AS customer_item_count,
SUM(ot.price) AS customer_gmv
FROM orders AS ord
JOIN order_items AS ot ON ord.order_id = ot.order_id
JOIN customers AS cust ON ord.customer_id = cust.customer_id
WHERE ord.order_status = 'delivered'
GROUP BY cust.customer_unique_id),

classified_customers AS (SELECT *, 
( CASE WHEN customer_order_count = 1 THEN 'one_time'
		WHEN customer_order_count > 1 THEN 'repeat' 
		END) AS customer_type
FROM customer_kpis)

SELECT customer_type, COUNT(customer_type) AS customer_count,
SUM(customer_order_count) AS total_order_count,
SUM(customer_item_count) AS total_item_count,
SUM(customer_gmv) AS total_gmv
FROM classified_customers
GROUP BY customer_type
ORDER BY customer_type;

-- Calculate customer, order, and merchandise GMV shares by customer type.
;WITH customer_kpis AS (SELECT cust.customer_unique_id, 
COUNT(DISTINCT(ord.order_id)) AS customer_order_count,
COUNT(ot.order_item_id) AS customer_item_count,
SUM(ot.price) AS customer_gmv
FROM orders AS ord
JOIN order_items AS ot ON ord.order_id = ot.order_id
JOIN customers AS cust ON ord.customer_id = cust.customer_id
WHERE ord.order_status = 'delivered'
GROUP BY cust.customer_unique_id),

classified_customers AS (SELECT *, 
( CASE WHEN customer_order_count = 1 THEN 'one_time'
		WHEN customer_order_count > 1 THEN 'repeat' 
		END) AS customer_type
FROM customer_kpis),

customer_type_summary AS (SELECT customer_type, COUNT(customer_type) AS customer_count,
SUM(customer_order_count) AS total_order_count,
SUM(customer_item_count) AS total_item_count,
SUM(customer_gmv) AS total_gmv
FROM classified_customers
GROUP BY customer_type)

SELECT *,(customer_count*100.0/NULLIF(SUM(customer_count) OVER (),0)) AS customer_share_pct,
(total_order_count*100.0/NULLIF(SUM(total_order_count) OVER (), 0)) AS order_share_pct,
(total_gmv*100.0/NULLIF(SUM(total_gmv) OVER(), 0)) AS gmv_share_pct
FROM customer_type_summary
ORDER BY customer_type;

/*
Customer-type findings:
- Of 93,358 customers with delivered orders, 90,557 placed one
  delivered order and 2,801 placed more than one.
- Repeat customers represented 3.00% of customers and contributed
  6.14% of delivered orders and 5.51% of merchandise GMV.
- Repeat customers generated R$728,408.75 in merchandise GMV.
- Customer classification uses delivered orders within the observed
  dataset period; it does not represent lifetime purchasing behavior.
*/

-- Export state-level commercial measures for full SQL–Python reconciliation.
;WITH state_kpis AS (SELECT cust.customer_state, 
COUNT(DISTINCT(ord.order_id)) AS delivered_order_count,
COUNT(ot.order_item_id) AS delivered_item_count,
SUM(ot.price) AS merchandise_gmv
FROM orders AS ord
JOIN order_items AS ot ON ord.order_id = ot.order_id
JOIN customers AS cust ON ord.customer_id = cust.customer_id
WHERE ord.order_status = 'delivered'
GROUP BY cust.customer_state)

SELECT *, (merchandise_gmv/delivered_order_count) AS average_order_merchandise_value,
(merchandise_gmv * 100.0/ NULLIF(SUM(merchandise_gmv) OVER (), 0)) AS gmv_share_pct
FROM state_kpis
ORDER BY merchandise_gmv DESC, customer_state ASC; 