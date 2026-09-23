/*
===============================================================================
Initial Table Definitions (early draft of the Bronze DDL)
===============================================================================
Script Purpose:
    This script creates a first draft of the raw CRM/ERP tables in the
    'bronze' schema.

Note:
    - Despite the file name, this script does NOT create the database or the
      bronze/silver/gold schemas; the 'bronze' schema must already exist.
    - The tables are created without an existence check, so re-running the
      script fails if the tables are already there.
    - This draft has been superseded by 'bronze/ddl_bronze.sql', which defines
      all six source tables with the final column names and data types
      (e.g. cst_gndr, prd_nm, integer sales dates). Use that script instead.
===============================================================================
*/

-------------------------------------------------------------------------------
-- CRM: Customer Information
-------------------------------------------------------------------------------
CREATE TABLE bronze.crm_cust_info(
cst_id INT,                        -- Customer ID (numeric, from the CRM)
cst_key NVARCHAR(50),              -- Customer business key
cst_firstname NVARCHAR(50),        -- Customer first name
cst_lastname NVARCHAR(50),         -- Customer last name
cst_marital_status NVARCHAR(50),   -- Marital status (raw source code)
cst_gender NVARCHAR(10),           -- Gender (raw source code)
cst_create_date DATE               -- Date the customer record was created
);

-------------------------------------------------------------------------------
-- CRM: Product Information
-------------------------------------------------------------------------------
CREATE TABLE bronze.crm_prd_info(
prd_id INT,                        -- Product ID
prd_key NVARCHAR(50),              -- Product key (category ID + product key)
prd_name NVARCHAR(50),             -- Product name
prd_cost INT,                      -- Product cost
prd_line NVARCHAR(10),             -- Product line (raw source code)
prd_start_dt DATE,                 -- Start date the product version is effective
prd_end_dt DATE                    -- End date the product version is effective
);

-------------------------------------------------------------------------------
-- CRM: Sales Details
-------------------------------------------------------------------------------
CREATE TABLE bronze.crm_sales_details(
sls_ord_num NVARCHAR(50),          -- Sales order number
sls_prd_key NVARCHAR(50),          -- Product key (links to crm_prd_info.prd_key)
sls_cust_id NVARCHAR(50),          -- Customer ID (links to crm_cust_info.cst_id)
sls_order_dt DATE,                 -- Order date
sls_due_dt DATE,                   -- Due date
sls_sales INT,                     -- Total sales amount for the line item
sls_quantity INT,                  -- Quantity of units ordered
sls_price INT                      -- Price per unit
);

-------------------------------------------------------------------------------
-- ERP: Customer Demographics
-------------------------------------------------------------------------------
CREATE TABLE bronze.erp_cust_az12(
cid INT,                           -- Customer ID
bdate DATE,                        -- Customer birth date
gender VARCHAR(10)                 -- Customer gender (raw source value)
);

