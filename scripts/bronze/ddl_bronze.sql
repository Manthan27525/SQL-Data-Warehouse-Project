/*
===============================================================================
DDL Script: Create Bronze Tables
===============================================================================
Script Purpose:
    This script creates tables in the 'bronze' schema, dropping existing tables
    if they already exist.
	  Run this script to re-define the DDL structure of 'bronze' Tables

Source Systems:
    - CRM: crm_cust_info, crm_prd_info, crm_sales_details
    - ERP: erp_loc_a101, erp_cust_az12, erp_px_cat_g1v2

Note:
    Bronze tables mirror the raw source files as-is (no transformations,
    constraints or keys), so they can be reloaded quickly and audited against
    the original data. Cleansing happens in the silver layer.
===============================================================================
*/

-------------------------------------------------------------------------------
-- CRM: Customer Information
-- Source: cust_info.csv
-------------------------------------------------------------------------------

-- Drop the table first (if it exists) so the script can be re-run safely.
-- 'U' = user-defined table.
IF OBJECT_ID('bronze.crm_cust_info', 'U') IS NOT NULL
    DROP TABLE bronze.crm_cust_info;
GO

CREATE TABLE bronze.crm_cust_info (
    cst_id              INT,            -- Customer ID (numeric, from the CRM)
    cst_key             NVARCHAR(50),   -- Customer business key (used to join with ERP data)
    cst_firstname       NVARCHAR(50),   -- Customer first name
    cst_lastname        NVARCHAR(50),   -- Customer last name
    cst_marital_status  NVARCHAR(50),   -- Marital status (raw source code)
    cst_gndr            NVARCHAR(50),   -- Gender (raw source code)
    cst_create_date     DATE            -- Date the customer record was created
);
GO

-------------------------------------------------------------------------------
-- CRM: Product Information
-- Source: prd_info.csv
-------------------------------------------------------------------------------

IF OBJECT_ID('bronze.crm_prd_info', 'U') IS NOT NULL
    DROP TABLE bronze.crm_prd_info;
GO

CREATE TABLE bronze.crm_prd_info (
    prd_id       INT,            -- Product ID
    prd_key      NVARCHAR(50),   -- Product key (combines category ID and product key)
    prd_nm       NVARCHAR(50),   -- Product name
    prd_cost     INT,            -- Product cost
    prd_line     NVARCHAR(50),   -- Product line (raw source code)
    prd_start_dt DATETIME,       -- Start date the product version is effective
    prd_end_dt   DATETIME        -- End date the product version is effective
);
GO

-------------------------------------------------------------------------------
-- CRM: Sales Details
-- Source: sales_details.csv
-------------------------------------------------------------------------------

IF OBJECT_ID('bronze.crm_sales_details', 'U') IS NOT NULL
    DROP TABLE bronze.crm_sales_details;
GO

CREATE TABLE bronze.crm_sales_details (
    sls_ord_num  NVARCHAR(50),   -- Sales order number
    sls_prd_key  NVARCHAR(50),   -- Product key (links to crm_prd_info.prd_key)
    sls_cust_id  INT,            -- Customer ID (links to crm_cust_info.cst_id)
    sls_order_dt INT,            -- Order date, stored as an integer (e.g. YYYYMMDD) in the source
    sls_ship_dt  INT,            -- Shipping date, stored as an integer (e.g. YYYYMMDD) in the source
    sls_due_dt   INT,            -- Due date, stored as an integer (e.g. YYYYMMDD) in the source
    sls_sales    INT,            -- Total sales amount for the line item
    sls_quantity INT,            -- Quantity of units ordered
    sls_price    INT             -- Price per unit
);
GO

-------------------------------------------------------------------------------
-- ERP: Customer Location
-- Source: LOC_A101.csv
-------------------------------------------------------------------------------

IF OBJECT_ID('bronze.erp_loc_a101', 'U') IS NOT NULL
    DROP TABLE bronze.erp_loc_a101;
GO

CREATE TABLE bronze.erp_loc_a101 (
    cid    NVARCHAR(50),   -- Customer ID (e.g. 'AW-00011000'; contains a hyphen, so it must be cleaned before joining to crm_cust_info.cst_key)
    cntry  NVARCHAR(50)    -- Customer country (raw values, may be full names or codes)
);
GO

-------------------------------------------------------------------------------
-- ERP: Customer Demographics
-- Source: CUST_AZ12.csv
-------------------------------------------------------------------------------

IF OBJECT_ID('bronze.erp_cust_az12', 'U') IS NOT NULL
    DROP TABLE bronze.erp_cust_az12;
GO

CREATE TABLE bronze.erp_cust_az12 (
    cid    NVARCHAR(50),   -- Customer ID (e.g. 'NASAW00011000'; may carry a 'NAS' prefix that must be removed before joining to crm_cust_info.cst_key)
    bdate  DATE,           -- Customer birth date
    gen    NVARCHAR(50)    -- Customer gender (raw source value)
);
GO

-------------------------------------------------------------------------------
-- ERP: Product Categories
-- Source: PX_CAT_G1V2.csv
-------------------------------------------------------------------------------

IF OBJECT_ID('bronze.erp_px_cat_g1v2', 'U') IS NOT NULL
    DROP TABLE bronze.erp_px_cat_g1v2;
GO

CREATE TABLE bronze.erp_px_cat_g1v2 (
    id           NVARCHAR(50),   -- Category ID (e.g. 'AC_BR'; uses '_' where crm_prd_info.prd_key uses '-')
    cat          NVARCHAR(50),   -- Product category
    subcat       NVARCHAR(50),   -- Product subcategory
    maintenance  NVARCHAR(50)    -- Whether the product requires maintenance (Yes/No)
);
GO
