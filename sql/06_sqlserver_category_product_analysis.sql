-- Rank product categories by merchandise GMV for delivered orders.
SELECT COALESCE(pd.product_category_name_english, 'missing') AS product_category_name_english,
COUNT(DISTINCT(ord.order_id)) AS delivered_order_count, 
COUNT(ot.order_item_id) AS delivered_item_count, 
SUM(ot.price) AS merchandise_gmv
FROM orders AS ord
JOIN order_items AS ot ON ord.order_id = ot.order_id 
JOIN products AS pd ON ot.product_id = pd.product_id
WHERE ord.order_status = 'delivered'
GROUP BY COALESCE(pd.product_category_name_english, 'missing') 
ORDER BY SUM(ot.price) DESC;

-- Reconcile category-level item counts and merchandise GMV with delivered-order totals.
;WITH category_kpis AS (SELECT COALESCE(pd.product_category_name_english, 'missing') AS product_category_name_english,
COUNT(DISTINCT(ord.order_id)) AS delivered_order_count, 
COUNT(ot.order_item_id) AS delivered_item_count, 
SUM(ot.price) AS merchandise_gmv
FROM orders AS ord
JOIN order_items AS ot ON ord.order_id = ot.order_id 
JOIN products AS pd ON ot.product_id = pd.product_id
WHERE ord.order_status = 'delivered'
GROUP BY COALESCE(pd.product_category_name_english, 'missing'))

SELECT COUNT(product_category_name_english) AS category_count, 
SUM(delivered_item_count) AS total_delivered_items,
SUM(merchandise_gmv) AS total_merchandise_gmv
FROM category_kpis;

-- Calculate each category's share of delivered-order merchandise GMV.
;WITH category_kpis AS (SELECT COALESCE(pd.product_category_name_english, 'missing') AS product_category_name_english,
COUNT(DISTINCT(ord.order_id)) AS delivered_order_count, 
COUNT(ot.order_item_id) AS delivered_item_count, 
SUM(ot.price) AS merchandise_gmv
FROM orders AS ord
JOIN order_items AS ot ON ord.order_id = ot.order_id 
JOIN products AS pd ON ot.product_id = pd.product_id
WHERE ord.order_status = 'delivered'
GROUP BY COALESCE(pd.product_category_name_english, 'missing'))

SELECT *, ((merchandise_gmv * 100.0/NULLIF(SUM(merchandise_gmv) OVER(),0))) AS gmv_share_pct FROM category_kpis
ORDER BY merchandise_gmv DESC;

-- Validate category GMV-share coverage and percentage totals.
;WITH category_kpis AS (SELECT COALESCE(pd.product_category_name_english, 'missing') AS product_category_name_english,
COUNT(DISTINCT(ord.order_id)) AS delivered_order_count, 
COUNT(ot.order_item_id) AS delivered_item_count, 
SUM(ot.price) AS merchandise_gmv
FROM orders AS ord
JOIN order_items AS ot ON ord.order_id = ot.order_id 
JOIN products AS pd ON ot.product_id = pd.product_id
WHERE ord.order_status = 'delivered'
GROUP BY COALESCE(pd.product_category_name_english, 'missing')),

category_gmv_shares AS (SELECT *, 
((merchandise_gmv * 100.0/NULLIF(SUM(merchandise_gmv) OVER(),0))) AS gmv_share_pct 
FROM category_kpis)

SELECT COUNT(product_category_name_english) AS category_count, 
COUNT(CASE WHEN gmv_share_pct IS NULL THEN 1 END) AS missing_gmv_share_count,
COUNT(CASE WHEN gmv_share_pct<0 THEN 1
		   WHEN gmv_share_pct>100 THEN 1 END) AS invalid_gmv_share_count,
SUM(gmv_share_pct) AS total_gmv_share_pct
FROM category_gmv_shares;

-- Identify the ten categories contributing the most delivered-order merchandise GMV.
;WITH category_kpis AS (SELECT COALESCE(pd.product_category_name_english, 'missing') AS product_category_name_english,
COUNT(DISTINCT(ord.order_id)) AS delivered_order_count, 
COUNT(ot.order_item_id) AS delivered_item_count, 
SUM(ot.price) AS merchandise_gmv
FROM orders AS ord
JOIN order_items AS ot ON ord.order_id = ot.order_id 
JOIN products AS pd ON ot.product_id = pd.product_id
WHERE ord.order_status = 'delivered'
GROUP BY COALESCE(pd.product_category_name_english, 'missing')),

category_gmv_shares AS (SELECT *, 
((merchandise_gmv * 100.0/NULLIF(SUM(merchandise_gmv) OVER(),0))) AS gmv_share_pct 
FROM category_kpis)

SELECT TOP 10 *
FROM category_gmv_shares
ORDER BY merchandise_gmv DESC, product_category_name_english ASC;

-- Calculate the combined merchandise GMV contribution of the top ten categories.
;WITH category_kpis AS (SELECT COALESCE(pd.product_category_name_english, 'missing') AS product_category_name_english,
COUNT(DISTINCT(ord.order_id)) AS delivered_order_count, 
COUNT(ot.order_item_id) AS delivered_item_count, 
SUM(ot.price) AS merchandise_gmv
FROM orders AS ord
JOIN order_items AS ot ON ord.order_id = ot.order_id 
JOIN products AS pd ON ot.product_id = pd.product_id
WHERE ord.order_status = 'delivered'
GROUP BY COALESCE(pd.product_category_name_english, 'missing')),

category_gmv_shares AS (SELECT *, 
((merchandise_gmv * 100.0/NULLIF(SUM(merchandise_gmv) OVER(),0))) AS gmv_share_pct 
FROM category_kpis),

top_10_categories AS (SELECT TOP 10 * FROM category_gmv_shares 
ORDER BY merchandise_gmv DESC, product_category_name_english ASC)

SELECT COUNT(product_category_name_english) AS top_category_count, 
SUM(merchandise_gmv) AS top_10_merchandise_gmv,
SUM(merchandise_gmv) * 100.0/ NULLIF((SELECT SUM(merchandise_gmv) FROM category_kpis), 0) AS top_10_gmv_share_pct
FROM top_10_categories;

/*
The top ten categories contributed R$8,254,334.23,
representing 62.43% of delivered-order merchandise GMV.
Health and beauty was the largest category by merchandise GMV.
*/

-- Summarize delivered-order merchandise performance by product.
SELECT ot.product_id,
COALESCE(pd.product_category_name_english, 'missing') AS product_category_name_english,
COUNT(DISTINCT(ord.order_id)) AS delivered_order_count,
COUNT(ot.order_item_id) AS delivered_item_count,
SUM(ot.price) AS merchandise_gmv
FROM orders AS ord
JOIN order_items AS ot ON ord.order_id = ot.order_id 
JOIN products AS pd ON ot.product_id = pd.product_id
WHERE ord.order_status = 'delivered'
GROUP BY ot.product_id, COALESCE(pd.product_category_name_english, 'missing')
ORDER BY merchandise_gmv DESC, ot.product_id ASC;

-- Reconcile product-level counts and merchandise GMV with delivered-order totals.
;WITH product_kpis AS (SELECT ot.product_id, 
COALESCE(pd.product_category_name_english, 'missing') AS product_category_name_english,
COUNT(DISTINCT(ord.order_id)) AS delivered_order_count,
COUNT(ot.order_item_id) AS delivered_item_count,
SUM(ot.price) AS merchandise_gmv
FROM orders AS ord
JOIN order_items AS ot ON ord.order_id = ot.order_id 
JOIN products AS pd ON ot.product_id = pd.product_id
WHERE ord.order_status = 'delivered'
GROUP BY ot.product_id,COALESCE(pd.product_category_name_english, 'missing'))

SELECT COUNT(product_id) AS product_count,
COUNT(DISTINCT(product_id)) AS distinct_product_count,
SUM(delivered_item_count) AS total_delivered_items,
SUM(merchandise_gmv) AS total_merchandise_gmv
FROM product_kpis;

-- Rank products by merchandise GMV within each product category.
;WITH product_kpis AS (SELECT ot.product_id, 
COALESCE(pd.product_category_name_english, 'missing') AS product_category_name_english, 
COUNT(DISTINCT(ord.order_id)) AS delivered_order_count,
COUNT(ot.order_item_id) AS delivered_item_count,
SUM(ot.price) AS merchandise_gmv
FROM orders AS ord
JOIN order_items AS ot ON ord.order_id = ot.order_id 
JOIN products AS pd ON ot.product_id = pd.product_id
WHERE ord.order_status = 'delivered'
GROUP BY ot.product_id, COALESCE(pd.product_category_name_english, 'missing'))

SELECT *, 
DENSE_RANK() OVER (PARTITION BY product_category_name_english ORDER BY merchandise_gmv DESC) AS product_gmv_rank
FROM product_kpis
WHERE product_category_name_english <> 'missing'
ORDER BY product_category_name_english, product_gmv_rank, product_id;

-- Validate product-ranking coverage and confirm no eligible products have missing ranks.
;WITH product_kpis AS (SELECT ot.product_id, 
COALESCE(pd.product_category_name_english, 'missing') AS product_category_name_english, 
COUNT(DISTINCT(ord.order_id)) AS delivered_order_count,
COUNT(ot.order_item_id) AS delivered_item_count,
SUM(ot.price) AS merchandise_gmv
FROM orders AS ord
JOIN order_items AS ot ON ord.order_id = ot.order_id 
JOIN products AS pd ON ot.product_id = pd.product_id
WHERE ord.order_status = 'delivered'
GROUP BY ot.product_id, COALESCE(pd.product_category_name_english, 'missing')),

ranked_products AS (SELECT *, 
DENSE_RANK() OVER (PARTITION BY product_category_name_english ORDER BY merchandise_gmv DESC) AS product_gmv_rank
FROM product_kpis
WHERE product_category_name_english <> 'missing')

SELECT COUNT(product_id) AS total_products, 
COUNT(DISTINCT(product_category_name_english)) AS distinct_product_category,
COUNT(CASE WHEN product_gmv_rank IS NULL THEN 1 END) AS missing_product_gmv_rank
FROM ranked_products;

-- Identify categories whose product ranking does not start at one.
;WITH product_kpis AS (SELECT ot.product_id, 
COALESCE(pd.product_category_name_english, 'missing') AS product_category_name_english, 
COUNT(DISTINCT(ord.order_id)) AS delivered_order_count,
COUNT(ot.order_item_id) AS delivered_item_count,
SUM(ot.price) AS merchandise_gmv
FROM orders AS ord
JOIN order_items AS ot ON ord.order_id = ot.order_id 
JOIN products AS pd ON ot.product_id = pd.product_id
WHERE ord.order_status = 'delivered'
GROUP BY ot.product_id, COALESCE(pd.product_category_name_english, 'missing')),

ranked_products AS (SELECT *, 
DENSE_RANK() OVER (PARTITION BY product_category_name_english ORDER BY merchandise_gmv DESC) AS product_gmv_rank
FROM product_kpis
WHERE product_category_name_english <> 'missing')

SELECT product_category_name_english, MIN(product_gmv_rank) AS minimum_rank_per_category 
FROM ranked_products
GROUP BY product_category_name_english
HAVING MIN(product_gmv_rank) <> 1;

-- Select the top three product GMV ranks within each category, retaining ties.
;WITH product_kpis AS (SELECT ot.product_id, 
COALESCE(pd.product_category_name_english, 'missing') AS product_category_name_english, 
COUNT(DISTINCT(ord.order_id)) AS delivered_order_count,
COUNT(ot.order_item_id) AS delivered_item_count,
SUM(ot.price) AS merchandise_gmv
FROM orders AS ord
JOIN order_items AS ot ON ord.order_id = ot.order_id 
JOIN products AS pd ON ot.product_id = pd.product_id
WHERE ord.order_status = 'delivered'
GROUP BY ot.product_id, COALESCE(pd.product_category_name_english, 'missing')),

ranked_products AS (SELECT *, 
DENSE_RANK() OVER (PARTITION BY product_category_name_english ORDER BY merchandise_gmv DESC) AS product_gmv_rank
FROM product_kpis
WHERE product_category_name_english <> 'missing')

SELECT * FROM ranked_products
WHERE product_gmv_rank IN (1,2,3)
ORDER BY product_category_name_english, product_gmv_rank, product_id;

-- Validate category coverage and product uniqueness in the top-three-rank selection.
;WITH product_kpis AS (SELECT ot.product_id, 
COALESCE(pd.product_category_name_english, 'missing') AS product_category_name_english, 
COUNT(DISTINCT(ord.order_id)) AS delivered_order_count,
COUNT(ot.order_item_id) AS delivered_item_count,
SUM(ot.price) AS merchandise_gmv
FROM orders AS ord
JOIN order_items AS ot ON ord.order_id = ot.order_id 
JOIN products AS pd ON ot.product_id = pd.product_id
WHERE ord.order_status = 'delivered'
GROUP BY ot.product_id, COALESCE(pd.product_category_name_english, 'missing')),

ranked_products AS (SELECT *, 
DENSE_RANK() OVER (PARTITION BY product_category_name_english ORDER BY merchandise_gmv DESC) AS product_gmv_rank
FROM product_kpis
WHERE product_category_name_english <> 'missing'),

top_ranked_products AS ( SELECT * FROM ranked_products
WHERE product_gmv_rank IN (1,2,3))

SELECT COUNT(product_id) AS total_products,
COUNT(DISTINCT(product_category_name_english)) AS distinct_categories_name,
COUNT(DISTINCT(product_id)) AS distinct_product_id,
COUNT( CASE WHEN product_gmv_rank < 1 THEN 1
			WHEN product_gmv_rank > 3 THEN 1 END) AS rank_outside_range
FROM top_ranked_products