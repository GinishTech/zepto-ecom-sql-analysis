CREATE DATABASE IF NOT EXISTS zepto_db;
USE zepto_db;

SELECT * FROM zepto_v2;

-- ========================================================
-- ZEPTO E-COMMERCE DATA ANALYSIS PROJECT
-- Author: [Ginish Kumar]
-- ========================================================

USE zepto_db;

-- 1. KPI Summary: Total Products, Categories, and Average Discount
SELECT 
    COUNT(*) AS total_products,
    COUNT(DISTINCT Category) AS total_categories,
    ROUND(AVG(discountPercent), 2) AS avg_discount_percentage
FROM zepto_v2;

-- 2. Category Performance Analysis
-- Which categories offer the highest average discounts and have the most inventory?
SELECT 
    Category,
    COUNT(*) AS product_count,
    ROUND(AVG(mrp), 2) AS avg_original_price,
    ROUND(AVG(discountPercent), 2) AS avg_discount,
    SUM(availableQuantity) AS total_available_stock
FROM zepto_v2
GROUP BY Category
ORDER BY product_count DESC;

-- 3. Out of Stock Analysis by Category
-- Identifies supply chain gaps where products are highly unavailable
SELECT 
    Category,
    COUNT(*) AS total_items,
    SUM(CASE WHEN outOfStock = 'TRUE' THEN 1 ELSE 0 END) AS out_of_stock_items,
    ROUND((SUM(CASE WHEN outOfStock = 'TRUE' THEN 1 ELSE 0 END) / COUNT(*)) * 100, 2) AS out_of_stock_rate_percent
FROM zepto_v2
GROUP BY Category
ORDER BY out_of_stock_rate_percent DESC;

-- 4. Top 10 Most Expensive Products After Discount
SELECT name, Category, mrp, discountedSellingPrice
FROM zepto_v2
ORDER BY discountedSellingPrice DESC
LIMIT 10;

-- 5. Total Warehouse Inventory Valuation. Calculates the total monetary value of current available stock per category 
-- (assuming prices are scaled in paise/cents, we divide by $100$ to get the primary currency unit).
SELECT 
    Category,
    SUM(availableQuantity) AS total_items_in_stock,
    ROUND(SUM(discountedSellingPrice * availableQuantity) / 100, 2) AS total_inventory_value,
    ROUND(AVG(discountedSellingPrice) / 100, 2) AS avg_item_value
FROM zepto_v2
GROUP BY Category
ORDER BY total_inventory_value DESC;

-- 6.Normalizing Cost (Price Per 100 Grams)
-- E-commerce companies use normalized metrics to compare value across differently sized items. 
-- This query targets categories where item weight matters (like Munchies, Fruits, or Packaged Foods).
SELECT 
    Category,
    name,
    weightInGms,
    (discountedSellingPrice / 100) AS price,
    ROUND(((discountedSellingPrice / 100) / weightInGms) * 100, 2) AS price_per_100g
FROM zepto_v2
WHERE weightInGms > 0 AND Category IN ('Fruits & Vegetables', 'Munchies', 'Packaged Food')
ORDER BY price_per_100g ASC
LIMIT 20;

-- 7. Product Price Tier Segmentation
-- Classifies items within categories into 'Budget', 'Mid-Range', or 'Premium' tiers based on their baseline MRP. 
-- This helps an executive team understand product assortment strategies.
SELECT 
    Category,
    SUM(CASE WHEN mrp / 100 < 50 THEN 1 ELSE 0 END) AS budget_items_count,
    SUM(CASE WHEN mrp / 100 BETWEEN 50 AND 200 THEN 1 ELSE 0 END) AS mid_range_items_count,
    SUM(CASE WHEN mrp / 100 > 200 THEN 1 ELSE 0 END) AS premium_items_count,
    COUNT(*) AS total_items
FROM zepto_v2
GROUP BY Category
ORDER BY premium_items_count DESC;

-- 8.Niche & Keyword Analysis (Organic vs. Regular Products)
-- Isolating specific text tags to assess if premium products (like "Organic" or "Premium") yield higher prices or
-- different discounting behavior.
SELECT 
    CASE 
        WHEN LOWER(name) LIKE '%organic%' THEN 'Organic'
        ELSE 'Standard/Regular'
    END AS product_type,
    COUNT(*) AS item_count,
    ROUND(AVG(mrp) / 100, 2) AS avg_mrp,
    ROUND(AVG(discountPercent), 1) AS avg_discount_percent,
    ROUND(AVG(discountedSellingPrice) / 100, 2) AS avg_selling_price
FROM zepto_v2
GROUP BY 
    CASE 
        WHEN LOWER(name) LIKE '%organic%' THEN 'Organic'
        ELSE 'Standard/Regular'
    END;

-- 9.Identifying Top 3 Discounted Products per Category
-- This uses the DENSE_RANK() window function to
-- find the items offering the steepest discount percentages inside every single separate category vertical.
WITH RankedDiscounts AS (
    SELECT 
        Category,
        name,
        mrp / 100 AS original_mrp,
        discountPercent,
        DENSE_RANK() OVER(PARTITION BY Category ORDER BY discountPercent DESC, mrp DESC) as discount_rank
    FROM zepto_v2
)
SELECT Category, name, original_mrp, discountPercent, discount_rank
FROM RankedDiscounts
WHERE discount_rank <= 3;

-- 10.Inventory Pareto Analysis (The 80/20 Rule)Hiring managers love the Pareto principle. 
-- This advanced query uses a Running Total window function to identify 
-- which categories contribute to the top $80\%$ of total stock value in the company warehouse.
WITH CategoryValue AS (
    SELECT 
        Category,
        SUM(discountedSellingPrice * availableQuantity) AS cat_value
    FROM zepto_v2
    GROUP BY Category
),
RunningTotals AS (
    SELECT 
        Category,
        cat_value,
        SUM(cat_value) OVER() AS global_total_value,
        SUM(cat_value) OVER(ORDER BY cat_value DESC) AS running_total_value
    FROM CategoryValue
)
SELECT 
    Category,
    ROUND(cat_value / 100, 2) AS category_stock_value,
    ROUND((running_total_value / global_total_value) * 100, 2) AS cumulative_percentage,
    CASE 
        WHEN (running_total_value / global_total_value) <= 0.80 THEN 'Core Value Driver (Top 80%)'
        ELSE 'Long Tail Asset'
    END AS pareto_classification
FROM RunningTotals
ORDER BY category_stock_value DESC;