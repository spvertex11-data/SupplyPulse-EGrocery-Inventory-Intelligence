
-- Step 2: Create the main cleaned inventory table
-- Purpose:
-- Store the cleaned and feature-engineered data created in Python


CREATE TABLE inventory_data (

    -- Product information
    sku_id VARCHAR(50),
    sku_name VARCHAR(255),
    category VARCHAR(100),
    abc_class VARCHAR(10),

    -- Supplier information
    supplier_id VARCHAR(50),
    supplier_name VARCHAR(255),

    -- Warehouse information
    warehouse_id VARCHAR(50),
    warehouse_location VARCHAR(255),

    -- Batch information
    batch_id VARCHAR(50),

    -- Important inventory dates
    received_date DATE,
    last_purchase_date DATE,
    expiry_date DATE,

    -- Inventory age
    stock_age_days INTEGER,

    -- Physical stock quantities
    quantity_on_hand INTEGER,
    quantity_reserved INTEGER,
    quantity_committed INTEGER,
    damaged_qty INTEGER,
    returns_qty INTEGER,

    -- Demand and sales information
    avg_daily_sales NUMERIC(12,2),
    forecast_next_30d NUMERIC(12,2),
    days_of_inventory NUMERIC(12,2),

    -- Replenishment information
    reorder_point INTEGER,
    safety_stock INTEGER,
    lead_time_days INTEGER,

    -- Financial information
    unit_cost_usd NUMERIC(12,2),
    last_purchase_price_usd NUMERIC(12,2),
    total_inventory_value_usd NUMERIC(18,2),

    -- Product movement information
    sku_churn_rate NUMERIC(12,2),
    order_frequency_per_month NUMERIC(12,2),

    -- Supplier performance
    supplier_ontime_pct NUMERIC(12,2),

    -- Inventory handling method
    fifo_fefo VARCHAR(50),

    -- Inventory status
    inventory_status VARCHAR(100),

    -- Audit information
    count_variance NUMERIC(12,2),
    audit_date DATE,
    audit_variance_pct NUMERIC(12,2),

    -- Demand forecasting performance
    demand_forecast_accuracy_pct NUMERIC(12,2),

    -- Additional notes
    notes TEXT,

 
    -- Business Features Created in Python
    
    -- Available-to-Promise inventory
    atp NUMERIC(12,2),

    -- ATP after preventing negative sellable stock
    sellable_atp NUMERIC(12,2),

    -- 1 = Oversold, 0 = Not Oversold
    oversold_flag SMALLINT,

    -- 1 = Below Safety Stock
    below_safety_stock_flag SMALLINT,

    -- 1 = SKU requires reorder review
    reorder_flag SMALLINT,

    -- Number of days current sellable stock can support demand
    sellable_coverage_days NUMERIC(12,2),

    -- 1 = Already expired
    expired_flag SMALLINT,

    -- 1 = Expiring within next 30 days
    expiry_30_days_flag SMALLINT,

    -- 1 = Potential dead stock
    dead_stock_flag SMALLINT
);

SELECT * FROM inventory_data;

-- Import the corrected cleaned CSV into PostgreSQL

COPY inventory_data
FROM 'D:/PROJECT/SupplyPulse_Project/Data/Cleaned/supplypulse_inventory_cleaned.csv'
WITH (
    FORMAT CSV,
    HEADER TRUE,
    DELIMITER ',',
    QUOTE '"',
    ESCAPE '"'
);


-- Check imported row count

SELECT COUNT(*) AS total_rows
FROM inventory_data;


-- Display sample inventory records after import

SELECT
    sku_id,
    sku_name,
    category,
    warehouse_id,
    quantity_on_hand,
    reorder_point,
    atp,
    reorder_flag
FROM inventory_data
LIMIT 10;


-- ============================================================
-- Query 1: Executive Inventory Summary
-- Purpose:
-- Give management a quick overview of inventory health,
-- financial exposure, and operational risk.
-- ============================================================

SELECT

    -- Count total unique SKUs
    COUNT(DISTINCT sku_id) AS total_skus,

    -- Calculate total inventory value
    ROUND(
        SUM(total_inventory_value_usd),
        2
    ) AS total_inventory_value_usd,

    -- Count oversold SKUs
    SUM(oversold_flag) AS oversold_skus,

    -- Count SKUs below safety stock
    SUM(below_safety_stock_flag) AS below_safety_stock_skus,

    -- Count SKUs requiring reorder review
    SUM(reorder_flag) AS reorder_review_skus,

    -- Count SKUs expiring within 30 days
    SUM(expiry_30_days_flag) AS expiring_30_days_skus,

    -- Count potential dead stock SKUs
    SUM(dead_stock_flag) AS potential_dead_stock_skus

FROM inventory_data;



-- ============================================================
-- Query 2: ATP and Oversold Risk Analysis
-- Purpose:
-- Identify SKUs where actual sellable inventory is very low
-- or where committed demand exceeds physical stock.
-- ============================================================

SELECT
    sku_id,
    sku_name,
    category,
    warehouse_id,

    -- Physical inventory
    quantity_on_hand,

    -- Inventory already reserved
    quantity_reserved,

    -- Inventory already committed
    quantity_committed,

    -- Actual sellable stock
    atp,

    -- Oversold indicator
    oversold_flag

FROM inventory_data

-- Show only risky SKUs
WHERE atp <= 0

-- Most negative ATP first
ORDER BY atp ASC;



-- ============================================================
-- Query 3: Below Safety Stock Analysis
-- Purpose:
-- Identify SKUs where sellable inventory (ATP)
-- has fallen below the required safety stock level.
-- ============================================================

SELECT
    sku_id,
    sku_name,
    category,
    warehouse_id,
    supplier_name,

    -- Actual sellable stock
    atp,

    -- Minimum buffer stock
    safety_stock,

    -- Difference between ATP and Safety Stock
    (atp - safety_stock) AS safety_stock_gap,

    -- Reorder information
    reorder_point,
    lead_time_days

FROM inventory_data

-- Show only SKUs below safety stock
WHERE below_safety_stock_flag = 1

-- Highest shortage first
ORDER BY safety_stock_gap ASC;



-- ============================================================
-- Query 4: Reorder Priority Analysis
-- Purpose:
-- Identify SKUs that require replenishment review
-- and rank them by urgency.
-- ============================================================

SELECT
    sku_id,
    sku_name,
    category,
    abc_class,
    warehouse_id,
    supplier_name,

    -- Current sellable stock
    atp,

    -- Reorder trigger level
    reorder_point,

    -- Difference between ATP and Reorder Point
    (atp - reorder_point) AS reorder_gap,

    -- Supplier replenishment time
    lead_time_days,

    -- Current sellable coverage
    sellable_coverage_days,

    -- Reorder indicator
    reorder_flag

FROM inventory_data

-- Show only SKUs requiring reorder review
WHERE reorder_flag = 1

-- Highest urgency first:
-- 1) A-class products
-- 2) Largest negative reorder gap
-- 3) Longer supplier lead time
ORDER BY
    CASE
        WHEN abc_class = 'A' THEN 1
        WHEN abc_class = 'B' THEN 2
        WHEN abc_class = 'C' THEN 3
        ELSE 4
    END,
    reorder_gap ASC,
    lead_time_days DESC;



-- ============================================================
-- Query 5: 30-Day Expiry Risk and Financial Exposure
-- Purpose:
-- Identify inventory that is expected to expire within 30 days
-- and calculate the financial value at risk.
-- ============================================================

SELECT
    sku_id,
    sku_name,
    category,
    warehouse_id,
    supplier_name,

    -- Current expiry date
    expiry_date,

    -- Current inventory quantity
    quantity_on_hand,

    -- Sellable inventory
    atp,

    -- Financial value of the inventory
    total_inventory_value_usd,

    -- Expiry risk indicator
    expiry_30_days_flag

FROM inventory_data

-- Show only stock expiring within 30 days
WHERE expiry_30_days_flag = 1

-- Highest financial exposure first
ORDER BY total_inventory_value_usd DESC;


-- Calculate the total financial value of inventory
-- expected to expire within the next 30 days

SELECT

    COUNT(*) AS expiring_sku_count,

    ROUND(
        SUM(total_inventory_value_usd),
        2
    ) AS value_expiring_within_30_days_usd

FROM inventory_data

WHERE expiry_30_days_flag = 1;



-- ============================================================
-- Query 6: Potential Dead Stock Analysis
-- Purpose:
-- Identify old inventory that may not be moving
-- and may be blocking working capital.
-- ============================================================

SELECT
    sku_id,
    sku_name,
    category,
    abc_class,
    warehouse_id,
    supplier_name,

    -- Number of days stock has been held
    stock_age_days,

    -- Current quantity
    quantity_on_hand,

    -- Current sellable inventory
    atp,

    -- Financial value tied up in the SKU
    total_inventory_value_usd,

    -- Potential dead stock indicator
    dead_stock_flag

FROM inventory_data

-- Show only potential dead stock
WHERE dead_stock_flag = 1

-- Oldest and highest-value inventory first
ORDER BY
    stock_age_days DESC,
    total_inventory_value_usd DESC;



-- Calculate the overall financial value tied up
-- in potential dead stock

SELECT
    COUNT(*) AS potential_dead_stock_skus,

    ROUND(
        SUM(total_inventory_value_usd),
        2
    ) AS potential_dead_stock_value_usd

FROM inventory_data

WHERE dead_stock_flag = 1;


-- ============================================================
-- Query 7: Warehouse Risk Comparison
-- Purpose:
-- Compare warehouses using multiple inventory risk indicators
-- so management can identify the locations needing attention.
-- ============================================================

SELECT
    warehouse_id,
    warehouse_location,

    -- Total number of SKUs handled by the warehouse
    COUNT(*) AS total_skus,

    -- Total inventory value stored in the warehouse
    ROUND(
        SUM(total_inventory_value_usd),
        2
    ) AS inventory_value_usd,

    -- Count SKUs below safety stock
    SUM(below_safety_stock_flag) AS below_safety_stock_skus,

    -- Count SKUs requiring reorder review
    SUM(reorder_flag) AS reorder_review_skus,

    -- Count oversold SKUs
    SUM(oversold_flag) AS oversold_skus,

    -- Count SKUs expiring within 30 days
    SUM(expiry_30_days_flag) AS expiring_30_days_skus,

    -- Count potential dead stock SKUs
    SUM(dead_stock_flag) AS potential_dead_stock_skus

FROM inventory_data

GROUP BY
    warehouse_id,
    warehouse_location

-- Highest safety-stock risk first
ORDER BY
    below_safety_stock_skus DESC,
    oversold_skus DESC;



-- ============================================================
-- Warehouse Safety Stock Risk Percentage
-- Purpose:
-- Compare warehouse risk fairly by using percentage
-- instead of only raw SKU counts.
-- ============================================================

SELECT
    warehouse_id,
    warehouse_location,

    COUNT(*) AS total_skus,

    SUM(below_safety_stock_flag) AS below_safety_stock_skus,

    ROUND(
        100.0 * SUM(below_safety_stock_flag) / COUNT(*),
        2
    ) AS below_safety_stock_pct

FROM inventory_data

GROUP BY
    warehouse_id,
    warehouse_location

ORDER BY
    below_safety_stock_pct DESC;



-- ============================================================
-- Query 8: Supplier Reliability and Lead Time Analysis
-- Purpose:
-- Compare suppliers based on delivery reliability,
-- average lead time, SKU coverage, and inventory value.
-- ============================================================

SELECT
    supplier_name,

    -- Number of SKUs supplied
    COUNT(*) AS total_skus,

    -- Average supplier on-time delivery percentage
    ROUND(
        AVG(supplier_ontime_pct),
        2
    ) AS avg_ontime_pct,

    -- Average replenishment lead time
    ROUND(
        AVG(lead_time_days),
        2
    ) AS avg_lead_time_days,

    -- Total inventory value supplied
    ROUND(
        SUM(total_inventory_value_usd),
        2
    ) AS inventory_value_usd

FROM inventory_data

GROUP BY supplier_name

-- Weakest supplier reliability first
ORDER BY
    avg_ontime_pct ASC,
    avg_lead_time_days DESC;


-- ============================================================
-- Supplier Performance vs 95% Target
-- Purpose:
-- Identify suppliers performing below the desired
-- on-time delivery benchmark.
-- ============================================================

SELECT
    supplier_name,

    ROUND(
        AVG(supplier_ontime_pct),
        2
    ) AS avg_ontime_pct,

    ROUND(
        AVG(lead_time_days),
        2
    ) AS avg_lead_time_days,

    CASE
        WHEN AVG(supplier_ontime_pct) >= 95
            THEN 'Meets Target'
        ELSE 'Below Target'
    END AS supplier_status

FROM inventory_data

GROUP BY supplier_name

ORDER BY avg_ontime_pct ASC;




-- ============================================================
-- Query 9: ABC Class Inventory Value Distribution
-- Purpose:
-- Analyze how total inventory value is distributed
-- across A, B, and C inventory classes.
-- ============================================================

SELECT
    abc_class,

    -- Count total SKUs in each ABC class
    COUNT(*) AS total_skus,

    -- Calculate total inventory value in each class
    ROUND(
        SUM(total_inventory_value_usd),
        2
    ) AS inventory_value_usd,

    -- Calculate percentage contribution to total inventory value
    ROUND(
        100.0 * SUM(total_inventory_value_usd)
        / SUM(SUM(total_inventory_value_usd)) OVER (),
        2
    ) AS inventory_value_pct

FROM inventory_data

GROUP BY abc_class

ORDER BY inventory_value_usd DESC;





-- ============================================================
-- Query 10: Inventory Value by Category
-- Purpose:
-- Identify which product categories hold the highest
-- amount of inventory capital.
-- ============================================================

SELECT
    category,

    -- Count SKUs in each category
    COUNT(*) AS total_skus,

    -- Calculate total inventory value by category
    ROUND(
        SUM(total_inventory_value_usd),
        2
    ) AS inventory_value_usd,

    -- Calculate average inventory value per SKU
    ROUND(
        AVG(total_inventory_value_usd),
        2
    ) AS avg_inventory_value_per_sku

FROM inventory_data

GROUP BY category

-- Highest inventory value first
ORDER BY inventory_value_usd DESC;





-- ============================================================
-- Query 11: Forecast Accuracy by Category
-- Purpose:
-- Compare demand forecast accuracy across product categories
-- and identify categories with weak demand planning.
-- ============================================================

SELECT
    category,

    -- Count SKUs in each category
    COUNT(*) AS total_skus,

    -- Calculate average forecast accuracy
    ROUND(
        AVG(demand_forecast_accuracy_pct),
        2
    ) AS avg_forecast_accuracy_pct,

    -- Compare category performance against the 85% target
    CASE
        WHEN AVG(demand_forecast_accuracy_pct) >= 85
            THEN 'Meets Target'
        ELSE 'Below Target'
    END AS forecast_status

FROM inventory_data

GROUP BY category

-- Lowest forecast accuracy first
ORDER BY avg_forecast_accuracy_pct ASC;






-- ============================================================
-- Query 12: Sellable Coverage Days Analysis
-- Purpose:
-- Identify SKUs with very low or very high sellable coverage
-- so management can detect stockout or overstock risk.
-- ============================================================

SELECT
    sku_id,
    sku_name,
    category,
    warehouse_id,

    -- Actual sellable stock
    sellable_atp,

    -- Average daily demand
    avg_daily_sales,

    -- Number of days current stock can support demand
    sellable_coverage_days,

    -- Create a simple coverage status
    CASE
        WHEN sellable_coverage_days < 3
            THEN 'Critical Low Coverage'

        WHEN sellable_coverage_days >= 3
             AND sellable_coverage_days < 7
            THEN 'Low Coverage'

        WHEN sellable_coverage_days >= 7
             AND sellable_coverage_days <= 14
            THEN 'Healthy Coverage'

        ELSE 'High Coverage'
    END AS coverage_status

FROM inventory_data

WHERE sellable_coverage_days IS NOT NULL

-- Lowest coverage first
ORDER BY sellable_coverage_days ASC;




-- ============================================================
-- Coverage Status Summary
-- Purpose:
-- Count how many SKUs fall into each inventory coverage band.
-- ============================================================

SELECT

    CASE
        WHEN sellable_coverage_days < 3
            THEN 'Critical Low Coverage'

        WHEN sellable_coverage_days >= 3
             AND sellable_coverage_days < 7
            THEN 'Low Coverage'

        WHEN sellable_coverage_days >= 7
             AND sellable_coverage_days <= 14
            THEN 'Healthy Coverage'

        ELSE 'High Coverage'
    END AS coverage_status,

    COUNT(*) AS sku_count

FROM inventory_data

WHERE sellable_coverage_days IS NOT NULL

GROUP BY coverage_status

ORDER BY sku_count DESC;





-- ============================================================
-- Query 13: Damaged and Returned Inventory Analysis
-- Purpose:
-- Identify categories with high damaged and returned quantities
-- so management can investigate quality or handling issues.
-- ============================================================

SELECT
    category,

    -- Total damaged units
    SUM(damaged_qty) AS total_damaged_qty,

    -- Total returned units
    SUM(returns_qty) AS total_returns_qty,

    -- Combined problem quantity
    SUM(damaged_qty + returns_qty) AS total_issue_qty,

    -- Total quantity on hand for context
    SUM(quantity_on_hand) AS total_quantity_on_hand

FROM inventory_data

GROUP BY category

-- Highest combined damaged + returned quantity first
ORDER BY total_issue_qty DESC;




-- ============================================================
-- Damage and Return Rate by Category
-- Purpose:
-- Compare categories fairly using a percentage,
-- not just raw damaged/returned counts.
-- ============================================================

SELECT
    category,

    SUM(damaged_qty + returns_qty) AS total_issue_qty,

    SUM(quantity_on_hand) AS total_quantity_on_hand,

    ROUND(
        100.0 * SUM(damaged_qty + returns_qty)
        / NULLIF(SUM(quantity_on_hand), 0),
        2
    ) AS issue_rate_pct

FROM inventory_data

GROUP BY category

ORDER BY issue_rate_pct DESC;





-- ============================================================
-- Query 14: Inventory Audit Variance Analysis
-- Purpose:
-- Identify SKUs and warehouses where physical inventory
-- differs significantly from system-recorded inventory.
-- ============================================================

SELECT
    sku_id,
    sku_name,
    category,
    warehouse_id,

    -- Difference found during physical inventory count
    count_variance,

    -- Percentage variance between physical and system stock
    audit_variance_pct,

    -- Inventory value for financial context
    total_inventory_value_usd

FROM inventory_data

-- Show records with the largest absolute variance first
ORDER BY ABS(audit_variance_pct) DESC
LIMIT 20;




-- ============================================================
-- Warehouse Audit Variance Summary
-- Purpose:
-- Compare warehouses based on average inventory record variance.
-- ============================================================

SELECT
    warehouse_id,
    warehouse_location,

    -- Average signed audit variance
    ROUND(
        AVG(audit_variance_pct),
        2
    ) AS avg_audit_variance_pct,

    -- Average absolute variance gives a better view of error size
    ROUND(
        AVG(ABS(audit_variance_pct)),
        2
    ) AS avg_absolute_variance_pct,

    -- Number of SKUs audited
    COUNT(*) AS audited_skus

FROM inventory_data

GROUP BY
    warehouse_id,
    warehouse_location

ORDER BY avg_absolute_variance_pct DESC;





-- ============================================================
-- Query 15: High-Value A-Class SKUs at Risk
-- Purpose:
-- Identify important A-class inventory that is exposed
-- to stockout, reorder, oversold, or expiry risk.
-- ============================================================

SELECT
    sku_id,
    sku_name,
    category,
    warehouse_id,
    supplier_name,

    -- Inventory value
    total_inventory_value_usd,

    -- Sellable stock
    atp,

    -- Safety stock level
    safety_stock,

    -- Reorder point
    reorder_point,

    -- Key risk indicators
    oversold_flag,
    below_safety_stock_flag,
    reorder_flag,
    expiry_30_days_flag,

    -- Sellable coverage
    sellable_coverage_days

FROM inventory_data

-- Focus only on high-priority A-class SKUs
WHERE abc_class = 'A'

-- Show only A-class SKUs with at least one major risk
AND (
       oversold_flag = 1
    OR below_safety_stock_flag = 1
    OR reorder_flag = 1
    OR expiry_30_days_flag = 1
)

-- Highest financial exposure first
ORDER BY total_inventory_value_usd DESC;




-- ============================================================
-- Query 16: Supplier Risk Exposure on Critical SKUs
-- Purpose:
-- Identify suppliers whose SKUs have the highest level
-- of inventory risk and financial exposure.
-- ============================================================

SELECT
    supplier_name,

    -- Total SKUs supplied
    COUNT(*) AS total_skus,

    -- Count risky SKUs
    SUM(below_safety_stock_flag) AS below_safety_stock_skus,
    SUM(reorder_flag) AS reorder_review_skus,
    SUM(oversold_flag) AS oversold_skus,
    SUM(expiry_30_days_flag) AS expiring_30_days_skus,

    -- Total number of major risk flags
    SUM(
        below_safety_stock_flag
        + reorder_flag
        + oversold_flag
        + expiry_30_days_flag
    ) AS total_risk_flags,

    -- Inventory value supplied
    ROUND(
        SUM(total_inventory_value_usd),
        2
    ) AS inventory_value_usd,

    -- Supplier delivery performance
    ROUND(
        AVG(supplier_ontime_pct),
        2
    ) AS avg_ontime_pct,

    ROUND(
        AVG(lead_time_days),
        2
    ) AS avg_lead_time_days

FROM inventory_data

GROUP BY supplier_name

-- Suppliers with the highest risk exposure first
ORDER BY
    total_risk_flags DESC,
    inventory_value_usd DESC;


-- ============================================================
-- Query 17: Warehouse × Category Risk Matrix
-- Purpose:
-- Identify warehouse-category combinations with the
-- highest concentration of inventory risk.
-- ============================================================

SELECT
    warehouse_id,
    warehouse_location,
    category,

    -- Total SKUs in each warehouse-category combination
    COUNT(*) AS total_skus,

    -- Risk indicators
    SUM(below_safety_stock_flag) AS below_safety_stock_skus,
    SUM(reorder_flag) AS reorder_review_skus,
    SUM(oversold_flag) AS oversold_skus,
    SUM(expiry_30_days_flag) AS expiring_30_days_skus,

    -- Combined risk count
    SUM(
        below_safety_stock_flag
        + reorder_flag
        + oversold_flag
        + expiry_30_days_flag
    ) AS total_risk_flags,

    -- Financial exposure
    ROUND(
        SUM(total_inventory_value_usd),
        2
    ) AS inventory_value_usd

FROM inventory_data

GROUP BY
    warehouse_id,
    warehouse_location,
    category

-- Highest-risk combinations first
ORDER BY
    total_risk_flags DESC,
    inventory_value_usd DESC;


-- ============================================================
-- Query 18: Top Critical SKUs Action List
-- Purpose:
-- Create a prioritized action list of SKUs that need
-- immediate management attention.
-- ============================================================

SELECT
    sku_id,
    sku_name,
    category,
    abc_class,
    warehouse_id,
    supplier_name,

    -- Current sellable stock
    atp,

    -- Key planning levels
    safety_stock,
    reorder_point,
    sellable_coverage_days,

    -- Financial exposure
    total_inventory_value_usd,

    -- Risk indicators
    oversold_flag,
    below_safety_stock_flag,
    reorder_flag,
    expiry_30_days_flag,

    -- Combined risk score
    (
        oversold_flag
        + below_safety_stock_flag
        + reorder_flag
        + expiry_30_days_flag
    ) AS risk_score

FROM inventory_data

-- Show only SKUs with at least one major risk
WHERE
       oversold_flag = 1
    OR below_safety_stock_flag = 1
    OR reorder_flag = 1
    OR expiry_30_days_flag = 1

-- Highest-risk and highest-value SKUs first
ORDER BY
    risk_score DESC,
    total_inventory_value_usd DESC

LIMIT 25;



-- ============================================================
-- Query 19: Inventory Risk by ABC Class
-- Purpose:
-- Compare inventory risk across A, B, and C classes
-- to understand whether high-priority inventory is exposed.
-- ============================================================

SELECT
    abc_class,

    -- Total SKUs in each class
    COUNT(*) AS total_skus,

    -- Key risk counts
    SUM(below_safety_stock_flag) AS below_safety_stock_skus,
    SUM(reorder_flag) AS reorder_review_skus,
    SUM(oversold_flag) AS oversold_skus,
    SUM(expiry_30_days_flag) AS expiring_30_days_skus,

    -- Combined risk flags
    SUM(
        below_safety_stock_flag
        + reorder_flag
        + oversold_flag
        + expiry_30_days_flag
    ) AS total_risk_flags,

    -- Financial value in each ABC class
    ROUND(
        SUM(total_inventory_value_usd),
        2
    ) AS inventory_value_usd

FROM inventory_data

GROUP BY abc_class

ORDER BY
    CASE
        WHEN abc_class = 'A' THEN 1
        WHEN abc_class = 'B' THEN 2
        WHEN abc_class = 'C' THEN 3
        ELSE 4
    END;


-- ============================================================
-- Risk Percentage by ABC Class
-- Purpose:
-- Compare classes fairly by calculating the percentage
-- of SKUs with at least one major risk.
-- ============================================================

SELECT
    abc_class,

    COUNT(*) AS total_skus,

    COUNT(
        CASE
            WHEN oversold_flag = 1
              OR below_safety_stock_flag = 1
              OR reorder_flag = 1
              OR expiry_30_days_flag = 1
            THEN 1
        END
    ) AS risky_skus,

    ROUND(
        100.0 *
        COUNT(
            CASE
                WHEN oversold_flag = 1
                  OR below_safety_stock_flag = 1
                  OR reorder_flag = 1
                  OR expiry_30_days_flag = 1
                THEN 1
            END
        ) / COUNT(*),
        2
    ) AS risky_sku_pct

FROM inventory_data

GROUP BY abc_class

ORDER BY risky_sku_pct DESC;


-- ============================================================
-- Query 20: Final Management Action Summary
-- Purpose:
-- Convert inventory risk indicators into clear management
-- actions and show the financial value linked to each action.
-- ============================================================

WITH inventory_actions AS (

    SELECT
        sku_id,
        sku_name,
        category,
        abc_class,
        warehouse_id,
        supplier_name,
        total_inventory_value_usd,

        -- Assign one primary action to each SKU
        -- Higher-risk conditions are checked first
        CASE

            -- Highest priority:
            -- Customer demand already exceeds sellable stock
            WHEN oversold_flag = 1
                THEN 'Immediate Stock Recovery'

            -- Inventory may soon expire and create financial loss
            WHEN expiry_30_days_flag = 1
                THEN 'Clear Near-Expiry Stock'

            -- SKU is below safety stock and needs replenishment review
            WHEN below_safety_stock_flag = 1
                THEN 'Urgent Replenishment'

            -- SKU has reached its reorder point
            WHEN reorder_flag = 1
                THEN 'Reorder Review'

            -- Old inventory may be blocking capital
            WHEN dead_stock_flag = 1
                THEN 'Dead Stock Clearance'

            -- No major risk detected
            ELSE 'Monitor Normally'

        END AS recommended_action

    FROM inventory_data
)

SELECT
    recommended_action,

    -- Number of SKUs requiring this action
    COUNT(*) AS sku_count,

    -- Inventory value linked to this action
    ROUND(
        SUM(total_inventory_value_usd),
        2
    ) AS inventory_value_usd,

    -- Percentage of all SKUs
    ROUND(
        100.0 * COUNT(*) / SUM(COUNT(*)) OVER (),
        2
    ) AS sku_percentage

FROM inventory_actions

GROUP BY recommended_action

-- Show the largest action groups first
ORDER BY sku_count DESC;


-- Final validation:
-- Confirm that all cleaned records are available in PostgreSQL

SELECT COUNT(*) AS total_rows
FROM inventory_data;

-- Final validation:
-- Check that Python-created analytical features
-- are available and populated correctly in PostgreSQL

SELECT
    sku_id,
    atp,
    sellable_atp,
    oversold_flag,
    below_safety_stock_flag,
    reorder_flag,
    sellable_coverage_days,
    expired_flag,
    expiry_30_days_flag,
    dead_stock_flag
FROM inventory_data
LIMIT 10;


-- Final validation:
-- Check for unexpected missing values in core analytical fields

SELECT
    COUNT(*) FILTER (WHERE sku_id IS NULL) AS missing_sku_id,
    COUNT(*) FILTER (WHERE quantity_on_hand IS NULL) AS missing_qoh,
    COUNT(*) FILTER (WHERE total_inventory_value_usd IS NULL) AS missing_inventory_value,
    COUNT(*) FILTER (WHERE atp IS NULL) AS missing_atp,
    COUNT(*) FILTER (WHERE reorder_flag IS NULL) AS missing_reorder_flag
FROM inventory_data;



