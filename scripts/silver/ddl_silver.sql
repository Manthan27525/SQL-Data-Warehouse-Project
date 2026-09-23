/*
===============================================================================
DDL Script: Create Silver Tables
===============================================================================
Script Purpose:
    This script creates tables in the 'silver' schema, dropping existing tables
    if they already exist.
	  Run this script to re-define the DDL structure of 'silver' Tables

Source Systems:
    - CRM: crm_cust_info, crm_prd_info, crm_sales_details
    - ERP: erp_loc_a101, erp_cust_az12, erp_px_cat_g1v2

Note:
    Silver tables hold the cleansed and standardized version of the bronze
    data. Compared to bronze, some columns are renamed (cst_gndr -> cst_gender,
    prd_nm -> prd_name, cntry -> country), crm_prd_info gets a derived cat_id
    column, and integer sales dates are stored as DATE.
    The tables are populated by silver.load_silver (data_loading_silver.sql).
===============================================================================
*/

-------------------------------------------------------------------------------
-- CRM: Customer Information
-------------------------------------------------------------------------------

-- Drop the table first (if it exists) so the script can be re-run safely.
-- 'U' = user-defined table.
IF OBJECT_ID('silver.crm_cust_info', 'U') IS NOT NULL
    DROP TABLE silver.crm_cust_info;
GO

CREATE TABLE silver.crm_cust_info (
    cst_id              INT,            -- Customer ID (unique after deduplication)
    cst_key             NVARCHAR(50),   -- Customer business key (used to join with ERP data)
    cst_firstname       NVARCHAR(50),   -- Customer first name (trimmed)
    cst_lastname        NVARCHAR(50),   -- Customer last name (trimmed)
    cst_marital_status  NVARCHAR(50),   -- 'Single', 'Married' or 'N/A'
    cst_gender          NVARCHAR(50),   -- 'Female', 'Male' or 'N/A'
    cst_create_date     DATE            -- Date the customer record was created
);
GO

-------------------------------------------------------------------------------
-- CRM: Product Information
-------------------------------------------------------------------------------

IF OBJECT_ID('silver.crm_prd_info', 'U') IS NOT NULL
    DROP TABLE silver.crm_prd_info;
GO

CREATE TABLE silver.crm_prd_info (
    prd_id       INT,            -- Product ID
    cat_id       NVARCHAR(50),   -- Category ID derived from prd_key (links to erp_px_cat_g1v2.id)
    prd_key      NVARCHAR(50),   -- Product key (links to crm_sales_details.sls_prd_key)
    prd_name     NVARCHAR(50),   -- Product name
    prd_cost     INT,            -- Product cost
    prd_line     NVARCHAR(50),   -- 'Mountain', 'Road', 'Other Sales', 'Touring' or 'N/A'
    prd_start_dt DATE,           -- Start date the product version is effective
    prd_end_dt   DATE            -- End date the product version is effective (NULL = current)
);
GO

-------------------------------------------------------------------------------
-- CRM: Sales Details
-------------------------------------------------------------------------------

IF OBJECT_ID('silver.crm_sales_details', 'U') IS NOT NULL
    DROP TABLE silver.crm_sales_details;
GO

CREATE TABLE silver.crm_sales_details (
    sls_ord_num  NVARCHAR(50),   -- Sales order number
    sls_prd_key  NVARCHAR(50),   -- Product key (links to crm_prd_info.prd_key)
    sls_cust_id  INT,            -- Customer ID (links to crm_cust_info.cst_id)
    sls_order_dt DATE,           -- Order date (NULL if invalid in the source)
    sls_ship_dt  DATE,           -- Shipping date (NULL if invalid in the source)
    sls_due_dt   DATE,           -- Due date (NULL if invalid in the source)
    sls_sales    INT,            -- Total sales amount (= quantity * price)
    sls_quantity INT,            -- Quantity of units ordered
    sls_price    INT             -- Price per unit
);
GO

-------------------------------------------------------------------------------
-- ERP: Customer Location
-------------------------------------------------------------------------------

IF OBJECT_ID('silver.erp_loc_a101', 'U') IS NOT NULL
    DROP TABLE silver.erp_loc_a101;
GO

CREATE TABLE silver.erp_loc_a101 (
    cid      NVARCHAR(50),   -- Customer ID without the hyphen (matches crm_cust_info.cst_key)
    country  NVARCHAR(50)    -- Full country name or 'N/A'
);
GO

-------------------------------------------------------------------------------
-- ERP: Customer Demographics
-------------------------------------------------------------------------------

IF OBJECT_ID('silver.erp_cust_az12', 'U') IS NOT NULL
    DROP TABLE silver.erp_cust_az12;
GO

CREATE TABLE silver.erp_cust_az12 (
    cid    NVARCHAR(50),   -- Customer ID without the 'NAS' prefix (matches crm_cust_info.cst_key)
    bdate  DATE,           -- Customer birth date (NULL if in the future)
    gen    NVARCHAR(50)    -- 'Female', 'Male' or 'N/A'
);
GO

-------------------------------------------------------------------------------
-- ERP: Product Categories
-------------------------------------------------------------------------------

IF OBJECT_ID('silver.erp_px_cat_g1v2', 'U') IS NOT NULL
    DROP TABLE silver.erp_px_cat_g1v2;
GO

CREATE TABLE silver.erp_px_cat_g1v2 (
    id           NVARCHAR(50),   -- Category ID (e.g. 'AC_BR')
    cat          NVARCHAR(50),   -- Product category
    subcat       NVARCHAR(50),   -- Product subcategory
    maintenance  NVARCHAR(50)    -- Whether the product requires maintenance (Yes/No)
);
GO
