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

-- Inspect credit-card installment coverage for delivered orders.
SELECT COUNT(pay.order_id) AS credit_card_payment_record_count,
COUNT(CASE WHEN pay.payment_installments IS NULL THEN ord.order_id END) AS missing_installment_count,
COUNT(CASE WHEN pay.payment_installments < 1 THEN ord.order_id END) AS invalid_installment_count,
COUNT(CASE WHEN pay.payment_installments >= 1 THEN ord.order_id END) AS valid_installment_count
FROM orders ord 
JOIN payments AS pay ON ord.order_id = pay.order_id
WHERE pay.payment_type = 'credit_card' AND ord.order_status='delivered';

-- Classify valid delivered-order credit-card payments into installment groups.
SELECT ord.order_id, pay.payment_sequential, pay.payment_installments, pay.payment_value,
(CASE WHEN pay.payment_installments = 1 THEN 'Single installment'
         WHEN pay.payment_installments BETWEEN 2 AND 3 THEN '2–3 installments'
         WHEN pay.payment_installments BETWEEN 4 AND 6 THEN '4–6 installments'
         WHEN pay.payment_installments BETWEEN 7 AND 12 THEN '7–12 installments'
         WHEN pay.payment_installments BETWEEN 13 AND 24 THEN '13–24 installments'
 END) AS installment_group
FROM orders ord 
JOIN payments AS pay ON ord.order_id = pay.order_id
WHERE pay.payment_type = 'credit_card' AND ord.order_status='delivered' AND pay.payment_installments >= 1
ORDER BY ord.order_id, pay.payment_sequential;

-- Summarize valid credit-card payments and record shares by installment group.
;WITH classified_installments AS (SELECT ord.order_id, pay.payment_sequential, pay.payment_installments, pay.payment_value,
(CASE WHEN pay.payment_installments = 1 THEN 'Single installment'
         WHEN pay.payment_installments BETWEEN 2 AND 3 THEN '2–3 installments'
         WHEN pay.payment_installments BETWEEN 4 AND 6 THEN '4–6 installments'
         WHEN pay.payment_installments BETWEEN 7 AND 12 THEN '7–12 installments'
         WHEN pay.payment_installments BETWEEN 13 AND 24 THEN '13–24 installments'
 END) AS installment_group
FROM orders ord 
JOIN payments AS pay ON ord.order_id = pay.order_id
WHERE pay.payment_type = 'credit_card' AND ord.order_status='delivered' AND pay.payment_installments >= 1)

SELECT installment_group,
COUNT(*) AS payment_record_count,
SUM(payment_value) AS total_payment_value,
AVG(payment_value) AS average_payment_value,
COUNT(*) * 100.0/ NULLIF(SUM(COUNT(*)) OVER (), 0) AS payment_record_share_pct
FROM classified_installments
GROUP BY installment_group
ORDER BY MIN(payment_installments);

-- Summarize valid credit-card payments by installment group, including counts, totals, averages, shares, and medians.
;WITH classified_installments AS (SELECT ord.order_id, pay.payment_sequential, pay.payment_installments, pay.payment_value,
(CASE WHEN pay.payment_installments = 1 THEN 'Single installment'
         WHEN pay.payment_installments BETWEEN 2 AND 3 THEN '2–3 installments'
         WHEN pay.payment_installments BETWEEN 4 AND 6 THEN '4–6 installments'
         WHEN pay.payment_installments BETWEEN 7 AND 12 THEN '7–12 installments'
         WHEN pay.payment_installments BETWEEN 13 AND 24 THEN '13–24 installments'
 END) AS installment_group
FROM orders ord 
JOIN payments AS pay ON ord.order_id = pay.order_id
WHERE pay.payment_type = 'credit_card' AND ord.order_status='delivered' AND pay.payment_installments >= 1),

installment_medians AS (SELECT *,
PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY payment_value) OVER (PARTITION BY installment_group) AS median_payment_value
FROM classified_installments)

SELECT installment_group, 
COUNT(*) AS payment_record_count,
SUM(payment_value) AS total_payment_value,
AVG(payment_value) AS average_payment_value,
COUNT(*) * 100.0/ NULLIF(SUM(COUNT(*)) OVER (), 0) AS payment_record_share_pct,
MAX(median_payment_value) AS median_payment_value
FROM installment_medians
GROUP BY installment_group
ORDER BY MIN(payment_installments);

/*
Credit-card installment analysis — findings and validation

Scope:
- 74,584 valid credit-card payment records from delivered orders.
- Two zero-installment records excluded.
- Counts represent payment records, not unique orders.

Findings:
- Single-installment payments: 24,759 records (33.20%).
- Payments using 2–3 installments: 22,239 records (29.82%).
- Median payment value increased across installment groups:
  R$67.74 for single installments to R$252.09 for 13–24 installments.
- The 13–24 installment group contained 179 records (0.24%).
- These patterns describe an association, not causation.

SQL–Python reconciliation:
- All five installment groups matched.
- Payment-record counts matched exactly.
- Payment totals, averages, and medians differed by less than R$0.01.
- Payment-record shares differed by less than 0.00001 percentage points.
*/

-- Payment-value reconciliation against merchandise and freight.

-- Aggregate merchandise and freight values to one row per delivered order.
SELECT ord.order_id,
SUM(ot.price) AS order_merchandise_value,
SUM(ot.freight_value) AS order_freight_value,
SUM(ot.price) + SUM(ot.freight_value) AS expected_order_value
FROM orders AS ord
JOIN order_items AS ot ON ord.order_id = ot.order_id
WHERE ord.order_status = 'delivered'
GROUP BY ord.order_id
ORDER BY ord.order_id;

-- Validate delivered-order merchandise, freight, and expected-value totals.
;WITH order_commercial_summary AS (SELECT ord.order_id,
SUM(ot.price) AS order_merchandise_value,
SUM(ot.freight_value) AS order_freight_value,
SUM(ot.price) + SUM(ot.freight_value) AS expected_order_value
FROM orders AS ord
JOIN order_items AS ot ON ord.order_id = ot.order_id
WHERE ord.order_status = 'delivered'
GROUP BY ord.order_id)

SELECT COUNT(*) AS order_count,
COUNT(DISTINCT order_id) AS distinct_order_count,
SUM(order_merchandise_value) AS total_merchandise_value,
SUM(order_freight_value) AS total_freight_value,
SUM(expected_order_value) AS total_expected_order_value
FROM order_commercial_summary;

-- Combine delivered-order commercial values with separately aggregated payment totals.
;WITH order_commercial_summary AS (SELECT ord.order_id,
SUM(ot.price) AS order_merchandise_value,
SUM(ot.freight_value) AS order_freight_value,
SUM(ot.price) + SUM(ot.freight_value) AS expected_order_value
FROM orders AS ord
JOIN order_items AS ot ON ord.order_id = ot.order_id
WHERE ord.order_status = 'delivered'
GROUP BY ord.order_id),

order_payment_summary AS (SELECT order_id, 
SUM(payment_value) AS total_payment_value
FROM payments
GROUP BY order_id)

SELECT ocs.order_id,
ocs.order_merchandise_value,
ocs.order_freight_value,
ocs.expected_order_value,
ops.total_payment_value
FROM order_commercial_summary AS ocs
LEFT JOIN order_payment_summary AS ops ON ocs.order_id = ops.order_id
ORDER BY ocs.order_id;

-- Validate order uniqueness and payment coverage after joining commercial and payment summaries.
;WITH order_commercial_summary AS (SELECT ord.order_id,
SUM(ot.price) AS order_merchandise_value,
SUM(ot.freight_value) AS order_freight_value,
SUM(ot.price) + SUM(ot.freight_value) AS expected_order_value
FROM orders AS ord
JOIN order_items AS ot ON ord.order_id = ot.order_id
WHERE ord.order_status = 'delivered'
GROUP BY ord.order_id),

order_payment_summary AS (SELECT order_id, 
SUM(payment_value) AS total_payment_value
FROM payments
GROUP BY order_id),

order_payment_reconciliation  AS (SELECT ocs.order_id,
ocs.order_merchandise_value,
ocs.order_freight_value,
ocs.expected_order_value,
ops.total_payment_value
FROM order_commercial_summary AS ocs
LEFT JOIN order_payment_summary AS ops ON ocs.order_id = ops.order_id)

SELECT
COUNT(*) AS order_count,
COUNT(DISTINCT order_id) AS distinct_order_count,
COUNT(total_payment_value) AS orders_with_payment,
COUNT(CASE WHEN total_payment_value IS NULL THEN 1 END) AS orders_without_payment
FROM order_payment_reconciliation;

-- Calculate the difference between total payment value and expected order value.
;WITH order_commercial_summary AS (SELECT ord.order_id,
SUM(ot.price) AS order_merchandise_value,
SUM(ot.freight_value) AS order_freight_value,
SUM(ot.price) + SUM(ot.freight_value) AS expected_order_value
FROM orders AS ord
JOIN order_items AS ot ON ord.order_id = ot.order_id
WHERE ord.order_status = 'delivered'
GROUP BY ord.order_id),

order_payment_summary AS (SELECT order_id, 
SUM(payment_value) AS total_payment_value
FROM payments
GROUP BY order_id),

order_payment_reconciliation  AS (SELECT ocs.order_id,
ocs.order_merchandise_value,
ocs.order_freight_value,
ocs.expected_order_value,
ops.total_payment_value
FROM order_commercial_summary AS ocs
LEFT JOIN order_payment_summary AS ops ON ocs.order_id = ops.order_id)

SELECT *,
total_payment_value - expected_order_value AS payment_difference, 
ABS(total_payment_value - expected_order_value) AS absolute_payment_difference
FROM order_payment_reconciliation
ORDER BY order_id;

-- Inspect delivered orders with the largest absolute payment differences.
;WITH order_commercial_summary AS (SELECT ord.order_id,
SUM(ot.price) AS order_merchandise_value,
SUM(ot.freight_value) AS order_freight_value,
SUM(ot.price) + SUM(ot.freight_value) AS expected_order_value
FROM orders AS ord
JOIN order_items AS ot ON ord.order_id = ot.order_id
WHERE ord.order_status = 'delivered'
GROUP BY ord.order_id),

order_payment_summary AS (SELECT order_id, 
SUM(payment_value) AS total_payment_value
FROM payments
GROUP BY order_id),

order_payment_reconciliation  AS (SELECT ocs.order_id,
ocs.order_merchandise_value,
ocs.order_freight_value,
ocs.expected_order_value,
ops.total_payment_value
FROM order_commercial_summary AS ocs
LEFT JOIN order_payment_summary AS ops ON ocs.order_id = ops.order_id)

SELECT TOP 10 *,
total_payment_value - expected_order_value AS payment_difference,
ABS(total_payment_value - expected_order_value)
AS absolute_payment_difference
FROM order_payment_reconciliation
ORDER BY absolute_payment_difference DESC, order_id ASC;

-- Inspect the delivered order with missing payment data.
;WITH order_commercial_summary AS (SELECT ord.order_id,
SUM(ot.price) AS order_merchandise_value,
SUM(ot.freight_value) AS order_freight_value,
SUM(ot.price) + SUM(ot.freight_value) AS expected_order_value
FROM orders AS ord
JOIN order_items AS ot ON ord.order_id = ot.order_id
WHERE ord.order_status = 'delivered'
GROUP BY ord.order_id),

order_payment_summary AS (SELECT order_id, 
SUM(payment_value) AS total_payment_value
FROM payments
GROUP BY order_id),

order_payment_reconciliation  AS (SELECT ocs.order_id,
ocs.order_merchandise_value,
ocs.order_freight_value,
ocs.expected_order_value,
ops.total_payment_value
FROM order_commercial_summary AS ocs
LEFT JOIN order_payment_summary AS ops ON ocs.order_id = ops.order_id)

SELECT *
FROM order_payment_reconciliation
WHERE total_payment_value IS NULL;

-- Classify delivered-order payment reconciliation results using differences rounded to cents.
;WITH order_commercial_summary AS (SELECT ord.order_id,
SUM(ot.price) AS order_merchandise_value,
SUM(ot.freight_value) AS order_freight_value,
SUM(ot.price) + SUM(ot.freight_value) AS expected_order_value
FROM orders AS ord
JOIN order_items AS ot ON ord.order_id = ot.order_id
WHERE ord.order_status = 'delivered'
GROUP BY ord.order_id),

order_payment_summary AS (SELECT order_id, 
SUM(payment_value) AS total_payment_value
FROM payments
GROUP BY order_id),

order_payment_reconciliation  AS (SELECT ocs.order_id,
ocs.order_merchandise_value,
ocs.order_freight_value,
ocs.expected_order_value,
ops.total_payment_value
FROM order_commercial_summary AS ocs
LEFT JOIN order_payment_summary AS ops ON ocs.order_id = ops.order_id)

SELECT *,
total_payment_value - expected_order_value AS payment_difference,
ABS(total_payment_value - expected_order_value) AS absolute_payment_difference,
CASE WHEN total_payment_value IS NULL THEN 'missing_payment'
     WHEN ROUND(total_payment_value - expected_order_value, 2) = 0 THEN 'matched'
     WHEN ROUND(total_payment_value - expected_order_value, 2) > 0 THEN 'payment_above_expected'
     WHEN ROUND(total_payment_value - expected_order_value, 2) < 0 THEN 'payment_below_expected'
     ELSE 'unclassified'
END AS payment_reconciliation_status
FROM order_payment_reconciliation
ORDER BY order_id;

-- Summarize delivered-order payment reconciliation by status.
;WITH order_commercial_summary AS (SELECT ord.order_id,
SUM(ot.price) AS order_merchandise_value,
SUM(ot.freight_value) AS order_freight_value,
SUM(ot.price) + SUM(ot.freight_value) AS expected_order_value
FROM orders AS ord
JOIN order_items AS ot ON ord.order_id = ot.order_id
WHERE ord.order_status = 'delivered'
GROUP BY ord.order_id),

order_payment_summary AS (SELECT order_id, 
SUM(payment_value) AS total_payment_value
FROM payments
GROUP BY order_id),

order_payment_reconciliation  AS (SELECT ocs.order_id,
ocs.order_merchandise_value,
ocs.order_freight_value,
ocs.expected_order_value,
ops.total_payment_value
FROM order_commercial_summary AS ocs
LEFT JOIN order_payment_summary AS ops ON ocs.order_id = ops.order_id),

classified_payments  AS (SELECT *,
total_payment_value - expected_order_value AS payment_difference,
ABS(total_payment_value - expected_order_value) AS absolute_payment_difference,
CASE WHEN total_payment_value IS NULL THEN 'missing_payment'
     WHEN ROUND(total_payment_value - expected_order_value, 2) = 0 THEN 'matched'
     WHEN ROUND(total_payment_value - expected_order_value, 2) > 0 THEN 'payment_above_expected'
     WHEN ROUND(total_payment_value - expected_order_value, 2) < 0 THEN 'payment_below_expected'
     ELSE 'unclassified'
END AS payment_reconciliation_status
FROM order_payment_reconciliation)

SELECT payment_reconciliation_status,
COUNT(*) AS order_count,
COUNT(*) * 100.0/ NULLIF(SUM(COUNT(*)) OVER (), 0) AS order_share_pct,
SUM(payment_difference) AS total_payment_difference,
SUM(absolute_payment_difference) AS total_absolute_payment_difference
FROM classified_payments
GROUP BY payment_reconciliation_status
ORDER BY payment_reconciliation_status;

/*
Payment-value reconciliation — findings and validation

Scope:
- 96,478 delivered orders retained, with one row per order.
- Merchandise and freight were aggregated separately from payments.
- Classification uses payment differences rounded to two decimal places.

Findings:
- 95,908 orders (99.41%) matched merchandise plus freight.
- 362 orders had payments above expected value:
  combined positive differences of R$3,032.24.
- 207 orders had payments below expected value:
  combined shortfalls of R$200.76.
- 569 orders had discrepancies, with total absolute differences
  of R$3,233.00.
- One order had missing payment data and expected value R$143.46.
  Its payment total and differences remain NULL.
- These differences do not establish their underlying cause.

SQL–Python validation:
- All four statuses matched, with exact order counts.
- Order shares differed by less than 0.00001 percentage points.
- Signed and absolute difference totals differed by less than R$0.01.
- Missing values matched between SQL and Python.
*/

-- Classify delivered orders into merchandise-value bands matching Python.
;WITH order_commercial_summary AS (SELECT ord.order_id,
SUM(ot.price) AS order_merchandise_value,
SUM(ot.freight_value) AS order_freight_value,
SUM(ot.price) + SUM(ot.freight_value) AS expected_order_value
FROM orders AS ord
JOIN order_items AS ot ON ord.order_id = ot.order_id
WHERE ord.order_status = 'delivered'
GROUP BY ord.order_id)

SELECT *, 
(CASE WHEN order_merchandise_value > 0 AND order_merchandise_value <= 50 THEN '0-50'
        WHEN order_merchandise_value > 50 AND order_merchandise_value <= 100 THEN '50-100'
        WHEN order_merchandise_value > 100 AND order_merchandise_value <= 150 THEN '100-150'
        WHEN order_merchandise_value > 150 AND order_merchandise_value <= 400 THEN '150-400'
        WHEN order_merchandise_value > 400 AND order_merchandise_value <= 1000 THEN '400-1000'
        WHEN order_merchandise_value > 1000 THEN '1000+'
        END) AS order_value_band
FROM order_commercial_summary
ORDER BY order_id

-- Validate order uniqueness and merchandise-value-band coverage.
;WITH order_commercial_summary AS (SELECT ord.order_id,
SUM(ot.price) AS order_merchandise_value,
SUM(ot.freight_value) AS order_freight_value,
SUM(ot.price) + SUM(ot.freight_value) AS expected_order_value
FROM orders AS ord
JOIN order_items AS ot ON ord.order_id = ot.order_id
WHERE ord.order_status = 'delivered'
GROUP BY ord.order_id),

classified_order_values AS (SELECT *, 
(CASE WHEN order_merchandise_value > 0 AND order_merchandise_value <= 50 THEN '0-50'
        WHEN order_merchandise_value > 50 AND order_merchandise_value <= 100 THEN '50-100'
        WHEN order_merchandise_value > 100 AND order_merchandise_value <= 150 THEN '100-150'
        WHEN order_merchandise_value > 150 AND order_merchandise_value <= 400 THEN '150-400'
        WHEN order_merchandise_value > 400 AND order_merchandise_value <= 1000 THEN '400-1000'
        WHEN order_merchandise_value > 1000 THEN '1000+'
        END) AS order_value_band
FROM order_commercial_summary)

SELECT COUNT(*) AS order_count,
COUNT(DISTINCT order_id) AS distinct_order_count,
COUNT(CASE WHEN order_value_band IS NULL THEN 1 END) AS missing_order_value_band_count,
COUNT(DISTINCT order_value_band) AS distinct_order_value_band_count
FROM classified_order_values;

-- Summarize delivered-order counts, merchandise values, and their percentage shares by order-value band.
;WITH order_commercial_summary AS (SELECT ord.order_id,
SUM(ot.price) AS order_merchandise_value,
SUM(ot.freight_value) AS order_freight_value,
SUM(ot.price) + SUM(ot.freight_value) AS expected_order_value
FROM orders AS ord
JOIN order_items AS ot ON ord.order_id = ot.order_id
WHERE ord.order_status = 'delivered'
GROUP BY ord.order_id),

classified_order_values AS (SELECT *, 
(CASE WHEN order_merchandise_value > 0 AND order_merchandise_value <= 50 THEN '0-50'
        WHEN order_merchandise_value > 50 AND order_merchandise_value <= 100 THEN '50-100'
        WHEN order_merchandise_value > 100 AND order_merchandise_value <= 150 THEN '100-150'
        WHEN order_merchandise_value > 150 AND order_merchandise_value <= 400 THEN '150-400'
        WHEN order_merchandise_value > 400 AND order_merchandise_value <= 1000 THEN '400-1000'
        WHEN order_merchandise_value > 1000 THEN '1000+'
        END) AS order_value_band
FROM order_commercial_summary)

SELECT order_value_band,
COUNT(*) AS order_count,
SUM(order_merchandise_value) AS total_merchandise_value,
AVG(order_merchandise_value) AS average_merchandise_value,
COUNT(*) * 100.0 / NULLIF(SUM(COUNT(*)) OVER (), 0) AS order_share_pct,
SUM(order_merchandise_value) * 100.0 / NULLIF(SUM(SUM(order_merchandise_value)) OVER (), 0) AS merchandise_value_share_pct
FROM classified_order_values
GROUP BY order_value_band
ORDER BY MIN(order_merchandise_value);

/*
Order-value-band findings and SQL–Python reconciliation:
- All six bands matched, covering 96,478 delivered orders.
- Total merchandise value: R$13,221,498.11.
- Order counts matched exactly.
- Merchandise totals and averages differed by less than R$0.01.
- Order and merchandise-value shares differed by less than
  0.00001 percentage points.
- Orders worth R$100 or less represented 58.72% of orders
  and 22.86% of merchandise value.
- The R$150–400 band contributed the largest merchandise-value
  share at 32.79%.
*/