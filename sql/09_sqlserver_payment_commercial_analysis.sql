-- Check payment-record coverage across delivered orders.
SELECT COUNT(DISTINCT(ord.order_id)) AS delivered_order_count, 
COUNT(DISTINCT CASE WHEN pay.order_id IS NOT NULL THEN ord.order_id END) AS orders_with_payment,
COUNT(DISTINCT CASE WHEN pay.order_id IS NULL THEN ord.order_id END) AS orders_without_payment
FROM orders ord
LEFT JOIN payments pay ON ord.order_id = pay.order_id
WHERE ord.order_status = 'delivered';

-- Aggregate payment records to one row per delivered order with payments.
SELECT ord.order_id,
COUNT(pay.payment_value) AS payment_transaction_count,
COUNT(DISTINCT(pay.payment_type)) AS distinct_payment_type_count,
SUM(pay.payment_value) AS total_payment_value,
MAX(pay.payment_installments) AS maximum_payment_installments
FROM orders ord
INNER JOIN payments pay ON ord.order_id = pay.order_id
WHERE ord.order_status = 'delivered'
GROUP BY ord.order_id
ORDER BY ord.order_id;

-- Identify delivered orders with multiple payment records or payment methods.
;WITH order_payment_summary AS (SELECT ord.order_id,
COUNT(pay.payment_value) AS payment_transaction_count,
COUNT(DISTINCT(pay.payment_type)) AS distinct_payment_type_count,
SUM(pay.payment_value) AS total_payment_value,
MAX(pay.payment_installments) AS maximum_payment_installments
FROM orders ord
INNER JOIN payments pay ON ord.order_id = pay.order_id
WHERE ord.order_status = 'delivered'
GROUP BY ord.order_id)

SELECT COUNT(*) AS orders_with_payment,
COUNT(CASE WHEN payment_transaction_count > 1 THEN 1 END) AS multiple_payment_record_orders,
COUNT(CASE WHEN distinct_payment_type_count > 1 THEN 1 END) AS multiple_payment_method_orders
FROM order_payment_summary;

-- Aggregate delivered-order payments by order and payment method.
SELECT ord.order_id, pay.payment_type,
SUM(pay.payment_value) AS payment_type_value,
COUNT(pay.payment_value) AS payment_type_transaction_count,
MAX(pay.payment_installments) AS payment_type_maximum_installments
FROM orders ord
INNER JOIN payments pay ON ord.order_id = pay.order_id
WHERE ord.order_status = 'delivered'
GROUP BY ord.order_id, pay.payment_type
ORDER BY ord.order_id, pay.payment_type;

-- Identify the largest payment-method value within each delivered order.
;WITH order_payment_type_summary AS (SELECT ord.order_id, pay.payment_type,
SUM(pay.payment_value) AS payment_type_value,
COUNT(pay.payment_value) AS payment_type_transaction_count,
MAX(pay.payment_installments) AS payment_type_maximum_installments
FROM orders ord
INNER JOIN payments pay ON ord.order_id = pay.order_id
WHERE ord.order_status = 'delivered'
GROUP BY ord.order_id, pay.payment_type)

SELECT *, MAX(payment_type_value) OVER (PARTITION BY order_id) AS maximum_payment_type_value
FROM order_payment_type_summary
ORDER BY order_id, payment_type;

-- Select payment methods with the largest payment value within each delivered order.
;WITH order_payment_type_summary AS (SELECT ord.order_id, pay.payment_type,
SUM(pay.payment_value) AS payment_type_value,
COUNT(pay.payment_value) AS payment_type_transaction_count,
MAX(pay.payment_installments) AS payment_type_maximum_installments
FROM orders ord
INNER JOIN payments pay ON ord.order_id = pay.order_id
WHERE ord.order_status = 'delivered'
GROUP BY ord.order_id, pay.payment_type),

payment_type_maxima AS (SELECT *, MAX(payment_type_value) OVER (PARTITION BY order_id) AS maximum_payment_type_value
FROM order_payment_type_summary)

SELECT * FROM payment_type_maxima
WHERE payment_type_value=maximum_payment_type_value
ORDER BY order_id, payment_type

-- Validate dominant-payment-method coverage and uniqueness.
;WITH order_payment_type_summary AS (SELECT ord.order_id, pay.payment_type,
SUM(pay.payment_value) AS payment_type_value,
COUNT(pay.payment_value) AS payment_type_transaction_count,
MAX(pay.payment_installments) AS payment_type_maximum_installments
FROM orders ord
INNER JOIN payments pay ON ord.order_id = pay.order_id
WHERE ord.order_status = 'delivered'
GROUP BY ord.order_id, pay.payment_type),

payment_type_maxima AS (SELECT *, 
MAX(payment_type_value) OVER (PARTITION BY order_id) AS maximum_payment_type_value
FROM order_payment_type_summary)

SELECT COUNT(*) AS selected_method_count,
COUNT(DISTINCT(order_id)) AS distinct_order_count,
(COUNT(*) - COUNT(DISTINCT(order_id))) AS extra_selected_method_count
FROM payment_type_maxima
WHERE payment_type_value=maximum_payment_type_value;

-- Count delivered orders by their dominant payment method.
;WITH order_payment_type_summary AS (SELECT ord.order_id, pay.payment_type,
SUM(pay.payment_value) AS payment_type_value,
COUNT(pay.payment_value) AS payment_type_transaction_count,
MAX(pay.payment_installments) AS payment_type_maximum_installments
FROM orders ord
INNER JOIN payments pay ON ord.order_id = pay.order_id
WHERE ord.order_status = 'delivered'
GROUP BY ord.order_id, pay.payment_type),

payment_type_maxima AS (SELECT *, 
MAX(payment_type_value) OVER (PARTITION BY order_id) AS maximum_payment_type_value
FROM order_payment_type_summary)

SELECT payment_type AS dominant_payment_type,COUNT(*) AS order_count
FROM payment_type_maxima
WHERE payment_type_value = maximum_payment_type_value
GROUP BY payment_type
ORDER BY order_count DESC, payment_type ASC;

-- Calculate delivered-order shares by dominant payment method.
;WITH order_payment_type_summary AS (SELECT ord.order_id, pay.payment_type,
SUM(pay.payment_value) AS payment_type_value,
COUNT(pay.payment_value) AS payment_type_transaction_count,
MAX(pay.payment_installments) AS payment_type_maximum_installments
FROM orders ord
INNER JOIN payments pay ON ord.order_id = pay.order_id
WHERE ord.order_status = 'delivered'
GROUP BY ord.order_id, pay.payment_type),

payment_type_maxima AS (SELECT *, 
MAX(payment_type_value) OVER (PARTITION BY order_id) AS maximum_payment_type_value
FROM order_payment_type_summary),

dominant_method_counts  AS (SELECT payment_type AS dominant_payment_type,
       COUNT(*) AS order_count
FROM payment_type_maxima
WHERE payment_type_value = maximum_payment_type_value
GROUP BY payment_type)

SELECT dominant_payment_type,
order_count,
order_count * 100.0/ NULLIF(SUM(order_count) OVER (), 0) AS order_share_pct
FROM dominant_method_counts
ORDER BY order_count DESC, dominant_payment_type ASC;

-- Attach each order's total payment value to its dominant payment method.
;WITH order_payment_summary AS (SELECT ord.order_id,
SUM(pay.payment_value) AS total_payment_value
FROM orders AS ord
INNER JOIN payments AS pay ON ord.order_id = pay.order_id
WHERE ord.order_status = 'delivered'
GROUP BY ord.order_id),

order_payment_type_summary AS (SELECT ord.order_id,
pay.payment_type,
SUM(pay.payment_value) AS payment_type_value
FROM orders AS ord
INNER JOIN payments AS pay ON ord.order_id = pay.order_id
WHERE ord.order_status = 'delivered'
GROUP BY ord.order_id, pay.payment_type),

payment_type_maxima AS (SELECT *,
MAX(payment_type_value) OVER (PARTITION BY order_id) AS maximum_payment_type_value
FROM order_payment_type_summary)

SELECT ops.order_id,
ptm.payment_type AS dominant_payment_type,
ops.total_payment_value
FROM order_payment_summary AS ops
INNER JOIN payment_type_maxima AS ptm
ON ops.order_id = ptm.order_id
WHERE ptm.payment_type_value = ptm.maximum_payment_type_value
ORDER BY ops.order_id;

-- Summarize total order payment value by dominant payment method.
;WITH order_payment_summary AS (SELECT ord.order_id,
SUM(pay.payment_value) AS total_payment_value
FROM orders AS ord
INNER JOIN payments AS pay ON ord.order_id = pay.order_id
WHERE ord.order_status = 'delivered'
GROUP BY ord.order_id),

order_payment_type_summary AS (SELECT ord.order_id,
pay.payment_type,
SUM(pay.payment_value) AS payment_type_value
FROM orders AS ord
INNER JOIN payments AS pay ON ord.order_id = pay.order_id
WHERE ord.order_status = 'delivered'
GROUP BY ord.order_id, pay.payment_type),

payment_type_maxima AS (SELECT *,
MAX(payment_type_value) OVER (PARTITION BY order_id) AS maximum_payment_type_value
FROM order_payment_type_summary),

order_payment_analysis AS (SELECT ops.order_id,
ptm.payment_type AS dominant_payment_type,
ops.total_payment_value
FROM order_payment_summary AS ops
INNER JOIN payment_type_maxima AS ptm
ON ops.order_id = ptm.order_id
WHERE ptm.payment_type_value = ptm.maximum_payment_type_value)

SELECT dominant_payment_type, COUNT(order_id) AS order_count,
SUM(total_payment_value) AS total_payment_value,
AVG(total_payment_value) AS average_payment_value_per_order
FROM order_payment_analysis
GROUP BY dominant_payment_type
ORDER BY total_payment_value DESC, dominant_payment_type ASC;

-- Calculate order counts, payment totals, averages, and payment-value shares by dominant method.
;WITH order_payment_summary AS (SELECT ord.order_id,
SUM(pay.payment_value) AS total_payment_value
FROM orders AS ord
INNER JOIN payments AS pay ON ord.order_id = pay.order_id
WHERE ord.order_status = 'delivered'
GROUP BY ord.order_id),

order_payment_type_summary AS (SELECT ord.order_id,
pay.payment_type,
SUM(pay.payment_value) AS payment_type_value
FROM orders AS ord
INNER JOIN payments AS pay ON ord.order_id = pay.order_id
WHERE ord.order_status = 'delivered'
GROUP BY ord.order_id, pay.payment_type),

payment_type_maxima AS (SELECT *,
MAX(payment_type_value) OVER (PARTITION BY order_id) AS maximum_payment_type_value
FROM order_payment_type_summary),

order_payment_analysis AS (SELECT ops.order_id,
ptm.payment_type AS dominant_payment_type,
ops.total_payment_value
FROM order_payment_summary AS ops
INNER JOIN payment_type_maxima AS ptm
ON ops.order_id = ptm.order_id
WHERE ptm.payment_type_value = ptm.maximum_payment_type_value),

dominant_method_summary AS (SELECT dominant_payment_type, COUNT(order_id) AS order_count,
SUM(total_payment_value) AS total_payment_value,
AVG(total_payment_value) AS average_payment_value_per_order
FROM order_payment_analysis
GROUP BY dominant_payment_type)

SELECT *,
total_payment_value * 100.0/ NULLIF(SUM(total_payment_value) OVER (), 0) AS payment_value_share_pct
FROM dominant_method_summary
ORDER BY total_payment_value DESC, dominant_payment_type ASC;

/*
Dominant-payment-method findings:
- Payment records were available for 96,477 of 96,478
  delivered orders; one order had no payment record.
- 2,875 orders had multiple payment records, and
  2,182 used multiple payment methods.
- Every eligible order had one highest-value payment method,
  with no tied maxima.
- Credit cards dominated 75.44% of eligible orders.
  These orders accounted for 78.42% of total payment value.
- Boleto dominated 19.89% of orders, vouchers 3.13%,
  and debit cards 1.54%.
- Total payment value was R$15,422,461.77.
- Average payment per order was R$166.18 for credit-card-
  dominant orders, R$144.33 for boleto, R$115.71 for
  vouchers, and R$140.41 for debit cards.
- Payment totals include all payments for each order,
  grouped by that order's dominant method.
- SQL and Python counts, totals, averages, and payment-value
  shares reconciled within the documented tolerances.
*/