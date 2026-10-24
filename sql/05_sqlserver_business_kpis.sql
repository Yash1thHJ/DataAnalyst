-- Summarize delivered-order volume and the purchase-date range.
SELECT COUNT(order_id) AS delivered_order_count, MIN(order_purchase_timestamp) AS first_purchase_timestamp, MAX(order_purchase_timestamp) AS last_purchase_timestamp 
FROM orders
WHERE order_status ='delivered';

-- Calculate merchandise GMV and freight totals for delivered orders.
SELECT SUM(price) AS delivered_merchandise_gmv, SUM(freight_value) AS delivered_freight_value FROM order_items
WHERE order_id IN (SELECT order_id FROM orders WHERE order_status='delivered');

-- Calculate average merchandise value per delivered order, excluding freight.
SELECT SUM(price) AS delivered_merchandise_gmv, COUNT(DISTINCT order_id) AS delivered_order_count, 
(SUM(price)/COUNT(DISTINCT order_id)) AS average_order_merchandise_value 
FROM order_items
WHERE order_id IN (SELECT order_id FROM orders WHERE order_status='delivered');

-- Summarize delivered orders, merchandise GMV, and average order value by purchase month.
SELECT YEAR(ord.order_purchase_timestamp) AS purchase_year, 
MONTH(ord.order_purchase_timestamp) AS purchase_month,
COUNT(DISTINCT ord.order_id) AS delivered_order_count,
SUM(ot.price) AS merchandise_gmv,
(SUM(ot.price)/COUNT(DISTINCT ord.order_id)) AS average_order_merchandise_value
FROM orders ord
JOIN order_items ot ON ord.order_id = ot.order_id
where ord.order_status = 'delivered'
GROUP BY YEAR(ord.order_purchase_timestamp), MONTH(ord.order_purchase_timestamp)
ORDER BY YEAR(ord.order_purchase_timestamp), MONTH(ord.order_purchase_timestamp);

-- Reconcile monthly delivered-order counts and merchandise GMV with overall totals.
;WITH monthly_kpis AS (SELECT YEAR(ord.order_purchase_timestamp) AS purchase_year, 
MONTH(ord.order_purchase_timestamp) AS purchase_month,
COUNT(DISTINCT ord.order_id) AS delivered_order_count,
SUM(ot.price) AS merchandise_gmv,
(SUM(ot.price)/COUNT(DISTINCT ord.order_id)) AS average_order_merchandise_value
FROM orders ord
JOIN order_items ot ON ord.order_id = ot.order_id
where ord.order_status = 'delivered'
GROUP BY YEAR(ord.order_purchase_timestamp), MONTH(ord.order_purchase_timestamp))

SELECT COUNT(purchase_month) as month_count, SUM(delivered_order_count) AS total_delivered_orders, SUM(merchandise_gmv) AS total_merchandise_gmv
FROM monthly_kpis;

-- Represent each purchase month with a single month-start date.
SELECT
DATEFROMPARTS(YEAR(ord.order_purchase_timestamp), MONTH(ord.order_purchase_timestamp),1) AS purchase_month_start,
COUNT(DISTINCT ord.order_id) AS delivered_order_count,
SUM(ot.price) AS merchandise_gmv,
(SUM(ot.price)/COUNT(DISTINCT ord.order_id)) AS average_order_merchandise_value
FROM orders ord
JOIN order_items ot ON ord.order_id = ot.order_id
where ord.order_status = 'delivered'
GROUP BY YEAR(ord.order_purchase_timestamp), MONTH(ord.order_purchase_timestamp)
ORDER BY YEAR(ord.order_purchase_timestamp), MONTH(ord.order_purchase_timestamp);

-- Display previous observed month values alongside monthly business KPIs.
;WITH monthly_kpis AS (SELECT
DATEFROMPARTS(YEAR(ord.order_purchase_timestamp), MONTH(ord.order_purchase_timestamp),1) AS purchase_month_start,
COUNT(DISTINCT ord.order_id) AS delivered_order_count,
SUM(ot.price) AS merchandise_gmv,
(SUM(ot.price)/COUNT(DISTINCT ord.order_id)) AS average_order_merchandise_value
FROM orders ord
JOIN order_items ot ON ord.order_id = ot.order_id
where ord.order_status = 'delivered'
GROUP BY YEAR(ord.order_purchase_timestamp), MONTH(ord.order_purchase_timestamp))

SELECT *, 
LAG(purchase_month_start) OVER( ORDER BY purchase_month_start) AS previous_month_start,
LAG(delivered_order_count) OVER( ORDER BY purchase_month_start) AS previous_month_order_count,
LAG(merchandise_gmv) OVER( ORDER BY purchase_month_start) AS previous_month_gmv
FROM monthly_kpis;

-- Calculate month-over-month changes only for consecutive purchase months.
;WITH monthly_kpis AS (SELECT
DATEFROMPARTS(YEAR(ord.order_purchase_timestamp), MONTH(ord.order_purchase_timestamp),1) AS purchase_month_start,
COUNT(DISTINCT ord.order_id) AS delivered_order_count,
SUM(ot.price) AS merchandise_gmv,
(SUM(ot.price)/COUNT(DISTINCT ord.order_id)) AS average_order_merchandise_value
FROM orders ord
JOIN order_items ot ON ord.order_id = ot.order_id
where ord.order_status = 'delivered'
GROUP BY YEAR(ord.order_purchase_timestamp), MONTH(ord.order_purchase_timestamp)),

monthly_kpis_calc AS (SELECT *, 
LAG(purchase_month_start) OVER( ORDER BY purchase_month_start) AS previous_month_start,
LAG(delivered_order_count) OVER( ORDER BY purchase_month_start) AS previous_month_order_count,
LAG(merchandise_gmv) OVER( ORDER BY purchase_month_start) AS previous_month_gmv
FROM monthly_kpis)

SELECT *,
CASE WHEN DATEDIFF(MONTH, previous_month_start, purchase_month_start) = 1 THEN ((delivered_order_count - previous_month_order_count)*100.0/NULLIF(previous_month_order_count, 0))
	 ELSE NULL
END AS order_count_mom_pct, 
CASE WHEN DATEDIFF(MONTH, previous_month_start, purchase_month_start) = 1 THEN ((merchandise_gmv - previous_month_gmv)*100.0/NULLIF(previous_month_gmv, 0))
	 ELSE NULL
END AS merchandise_gmv_mom_pct
FROM monthly_kpis_calc
ORDER BY purchase_month_start;

/*
Monthly business findings:
- November 2017 had the highest observed delivered-order count (7,289) and merchandise GMV (R$987,765.37).
- Compared with October 2017, orders increased by 62.77% and merchandise GMV increased by 52.37%.
- December 2017 orders declined by 24.37% and merchandise GMV declined by 26.50% compared with November.
- Very large growth percentages in October 2016 and January 2017 reflect comparison against just one order.
- December 2016 growth is NULL because November 2016 had zero orders and zero merchandise GMV, making percentage growth undefined.
- Results describe delivered orders grouped by purchase month. Boundary months may have incomplete coverage, so interpret their comparisons cautiously.
*/

-- Create a complete monthly calendar for the delivered-order analysis period.
;WITH month_calendar AS (
    SELECT CAST('2016-09-01' AS DATE) AS purchase_month_start 
    UNION ALL
    SELECT DATEADD(MONTH, 1, purchase_month_start)
    FROM month_calendar
    WHERE  purchase_month_start < '2018-08-01')
select * from month_calendar
order by purchase_month_start

-- Combine the complete monthly calendar with delivered-order KPIs.
;WITH monthly_kpis AS (SELECT
DATEFROMPARTS(YEAR(ord.order_purchase_timestamp), MONTH(ord.order_purchase_timestamp),1) AS purchase_month_start,
COUNT(DISTINCT ord.order_id) AS delivered_order_count,
SUM(ot.price) AS merchandise_gmv,
(SUM(ot.price)/COUNT(DISTINCT ord.order_id)) AS average_order_merchandise_value
FROM orders ord
JOIN order_items ot ON ord.order_id = ot.order_id
where ord.order_status = 'delivered'
GROUP BY YEAR(ord.order_purchase_timestamp), MONTH(ord.order_purchase_timestamp)),

month_calendar AS (SELECT CAST('2016-09-01' AS DATE) AS purchase_month_start 
UNION ALL
SELECT DATEADD(MONTH, 1, purchase_month_start)
FROM month_calendar
WHERE  purchase_month_start < '2018-08-01')

SELECT mc.purchase_month_start,
COALESCE(mk.delivered_order_count, 0) AS delivered_order_count,
COALESCE(mk.merchandise_gmv, 0) AS merchandise_gmv,
mk.average_order_merchandise_value
FROM month_calendar AS mc
LEFT JOIN monthly_kpis AS mk
ON mc.purchase_month_start = mk.purchase_month_start
ORDER BY mc.purchase_month_start;

-- Calculate monthly growth using the complete calendar, including zero-order months.
;WITH monthly_kpis AS (SELECT
DATEFROMPARTS(YEAR(ord.order_purchase_timestamp), MONTH(ord.order_purchase_timestamp),1) AS purchase_month_start,
COUNT(DISTINCT ord.order_id) AS delivered_order_count,
SUM(ot.price) AS merchandise_gmv,
(SUM(ot.price)/COUNT(DISTINCT ord.order_id)) AS average_order_merchandise_value
FROM orders ord
JOIN order_items ot ON ord.order_id = ot.order_id
where ord.order_status = 'delivered'
GROUP BY YEAR(ord.order_purchase_timestamp), MONTH(ord.order_purchase_timestamp)),

month_calendar AS (SELECT CAST('2016-09-01' AS DATE) AS purchase_month_start 
UNION ALL
SELECT DATEADD(MONTH, 1, purchase_month_start)
FROM month_calendar
WHERE  purchase_month_start < '2018-08-01'),

monthly_kpis_complete AS ( SELECT mc.purchase_month_start,
COALESCE(mk.delivered_order_count, 0) AS delivered_order_count,
COALESCE(mk.merchandise_gmv, 0) AS merchandise_gmv,
mk.average_order_merchandise_value
FROM month_calendar AS mc
LEFT JOIN monthly_kpis AS mk
ON mc.purchase_month_start = mk.purchase_month_start),

monthly_kpis_calc AS (SELECT *, 
LAG(purchase_month_start) OVER (ORDER BY purchase_month_start) AS previous_month_start,
LAG(delivered_order_count) OVER (ORDER BY purchase_month_start) AS previous_month_order_count,
LAG(merchandise_gmv) OVER (ORDER BY purchase_month_start) AS previous_month_gmv
FROM monthly_kpis_complete)

SELECT *,
(((delivered_order_count - previous_month_order_count) * 100.0)/ NULLIF(previous_month_order_count, 0)) AS order_count_mom_pct,
(((merchandise_gmv - previous_month_gmv) * 100.0)/ NULLIF(previous_month_gmv, 0)) AS merchandise_gmv_mom_pct
FROM monthly_kpis_calc
ORDER BY purchase_month_start

/*
Monthly KPI reconciliation:
- Compared all 24 calendar months with the Python monthly KPI summary.
- Monthly order counts and merchandise GMV match.
- Average order values and growth percentages agree to two decimal places.
- November 2016 has zero orders and GMV, with growth of -100%.
- December 2016 growth is NULL because the previous month's order count and GMV are zero.
- SQL NULL and Python NaN represent the same undefined results here.
*/

