/*
===============================================================================
DDL Script: Create Gold Views
===============================================================================
Script Purpose:
    This script creates the views of the 'gold' schema.
    The gold layer is the final, business-ready layer of the warehouse,
    modelled as a star schema:
    - gold.dim_customers : customer dimension
    - gold.dim_products  : product dimension
    - gold.fact_sales    : sales fact table

    Each view combines and renames the cleansed 'silver' tables into
    user-friendly columns, and generates surrogate keys for the dimensions.

Usage:
    Query the views directly for analytics and reporting, e.g.
        SELECT * FROM gold.fact_sales;

Note:
    - The silver layer must be loaded first (EXEC silver.load_silver).
    - Views read from silver at query time, so no separate load step is needed.
    - CREATE OR ALTER makes the script safe to re-run; each view is in its own
      batch (GO) because CREATE VIEW must be the only statement in a batch.
===============================================================================
*/

-------------------------------------------------------------------------------
-- Dimension: gold.dim_customers
-- One row per customer. Combines CRM customer info with ERP demographics
-- (birth date, gender) and location (country).
-------------------------------------------------------------------------------
CREATE OR ALTER VIEW gold.dim_customers AS
SELECT
ROW_NUMBER() OVER (ORDER BY cst_id) AS customer_key,   -- Surrogate key
ci.cst_id AS customer_id,
ci.cst_key AS customer_number,
ci.cst_firstname AS first_name,
ci.cst_lastname AS last_name,
ci.cst_marital_status AS marital_status,
-- CRM is the master source for gender; fall back to ERP when CRM is unknown
CASE WHEN  ci.cst_gender != 'n/a' THEN ci.cst_gender
     ELSE COALESCE(ca.gen,'N/A')
END AS gender,
ci.cst_create_date AS create_date,
ca.bdate AS birthdate,
la.country as country
FROM silver.crm_cust_info ci
-- LEFT JOINs keep every CRM customer, even without matching ERP data
LEFT JOIN silver.erp_cust_az12 ca
ON ci.cst_key = ca.cid
LEFT JOIN silver.erp_loc_a101 la
ON ci.cst_key=la.cid;
GO


-------------------------------------------------------------------------------
-- Dimension: gold.dim_products
-- One row per current product. Combines CRM product info with ERP
-- category, subcategory and maintenance details.
-------------------------------------------------------------------------------
CREATE OR ALTER VIEW gold.dim_products AS
SELECT
ROW_NUMBER() OVER (ORDER BY pn.prd_start_dt,pn.prd_key) AS product_key,   -- Surrogate key
pn.prd_id AS product_id,
pn.prd_key AS product_number,
pn.prd_name AS product_name,
pn.cat_id AS category_id,
pc.cat AS category,
pc.subcat AS subcategory,
pc.maintenance,
pn.prd_cost AS cost,
pn.prd_line AS product_line,
pn.prd_start_dt AS start_date
FROM silver.crm_prd_info pn
LEFT JOIN silver.erp_px_cat_g1v2 pc
ON pn.cat_id = pc.id
-- Keep only the current version of each product (historical versions
-- have an end date)
WHERE prd_end_dt IS NULL;
GO


-------------------------------------------------------------------------------
-- Fact: gold.fact_sales
-- One row per sales order line. Replaces the source product and customer
-- IDs with the dimension surrogate keys to link to the star schema.
-------------------------------------------------------------------------------
CREATE OR ALTER VIEW gold.fact_sales AS
SELECT
sd.sls_ord_num AS order_number,
pr.product_key,     -- FK to gold.dim_products
cu.customer_key,    -- FK to gold.dim_customers
sd.sls_order_dt AS order_date,
sd.sls_ship_dt AS shipping_date,
sd.sls_due_dt AS due_date,
sd.sls_sales AS sales_amount,
sd.sls_quantity AS quantity,
sd.sls_price AS price
FROM silver.crm_sales_details sd
-- Look up surrogate keys from the dimensions
LEFT JOIN gold.dim_products pr
ON sd.sls_prd_key = pr.product_number
LEFT JOIN gold.dim_customers cu
ON sd.sls_cust_id = cu.customer_id;
GO
