/*
===============================================================================
Stored Procedure: Load Silver Layer (Bronze -> Silver)
===============================================================================
Script Purpose:
    This stored procedure performs the ETL (Extract, Transform, Load) process
    that populates the 'silver' schema tables from the 'bronze' schema.
    It performs the following actions for each table:
    - Truncates the silver table before loading, so the load can be re-run
      without creating duplicate rows.
    - Inserts cleansed and standardized data from the matching bronze table:
        * trims unwanted spaces
        * maps coded values to readable names (e.g. 'M' -> 'Male')
        * removes duplicates and rows with missing keys
        * converts integer dates to DATE and fixes invalid dates
        * derives missing / inconsistent values (sales, price, end dates)
        * reformats keys so CRM and ERP data can be joined
    - Prints the load duration of each table and of the whole batch.

Parameters:
    None.
    This stored procedure does not accept any parameters or return any values.

Usage Example:
    EXEC silver.load_silver;

Note:
    - The silver tables must already exist (run ddl_silver.sql first), and the
      bronze layer must be loaded first (EXEC bronze.load_bronze).
===============================================================================
*/

CREATE OR ALTER PROCEDURE silver.load_silver AS
BEGIN

    -- Timers: one pair for each table load, one pair for the whole batch
    DECLARE @start_time DATETIME,@end_time DATETIME, @batch_start_time DATETIME, @batch_end_time DATETIME
    BEGIN TRY

        PRINT '--------------------';
        PRINT 'Loading Silver Layer';
        PRINT '--------------------';

        PRINT '--------------------';
        PRINT 'Loading CRM Data';
        print '--------------------';

        -- Start the timer for the whole batch
        SET @batch_start_time = GETDATE()

        -- ---------------------------------------------------------------------
        -- CRM: crm_cust_info
        -- - Trims first/last names
        -- - Maps marital status (S/M) and gender (F/M) codes to readable values
        -- - Keeps one row per cst_id and drops rows with no cst_id
        -- ---------------------------------------------------------------------
        SET @start_time = GETDATE();

        TRUNCATE TABLE silver.crm_cust_info;
        INSERT INTO silver.crm_cust_info(
               cst_id,
               cst_key,
               cst_firstname,
               cst_lastname,
               cst_marital_status,
               cst_gender,
               cst_create_date
        )

        SELECT cst_id,
        cst_key,
        TRIM(cst_firstname) AS cst_firstname,
        TRIM(cst_lastname) AS cst_lastname,
        -- Normalize marital status codes to readable values
        CASE WHEN UPPER(TRIM(cst_marital_status))='S' THEN 'Single'
             WHEN UPPER(TRIM(cst_marital_status))='M' THEN 'Married'
             ELSE 'N/A'
        END cst_marital_status,
        -- Normalize gender codes to readable values
        CASE WHEN UPPER(TRIM(cst_gndr))='F' THEN 'Female'
             WHEN UPPER(TRIM(cst_gndr))='M' THEN 'Male'
             ELSE 'N/A'
        END cst_gender,
        cst_create_date
        -- Deduplicate: number the rows of each customer from newest to oldest
        -- create date and keep only the most recent one (flag_last = 1)
        FROM (SELECT *,
               ROW_NUMBER() OVER (PARTITION BY cst_id ORDER BY cst_create_date DESC) AS flag_last
        FROM   bronze.crm_cust_info) AS t
        WHERE cst_id IS NOT NULL AND flag_last=1;

        SET @end_time = GETDATE();
        PRINT '-----------------------------------------------------';
        PRINT 'Load Duration of crm_cust_info ' + CAST (DATEDIFF(second,@start_time,@end_time) AS NVARCHAR) + ' seconds';
        PRINT '-----------------------------------------------------';

        -- ---------------------------------------------------------------------
        -- CRM: crm_prd_info
        -- - Splits prd_key into a category ID and the product key
        -- - Maps product line codes to readable names
        -- - Recalculates end dates from the next version's start date
        -- ---------------------------------------------------------------------
        SET @start_time = GETDATE();

        TRUNCATE TABLE silver.crm_prd_info;
        INSERT INTO silver.crm_prd_info(
               prd_id,
               cat_id,
               prd_key,
               prd_name,
               prd_cost,
               prd_line,
               prd_start_dt,
               prd_end_dt
        )

        SELECT
        prd_id,
        -- First 5 characters are the category ID; use '_' to match erp_px_cat_g1v2.id
        REPLACE(SUBSTRING(prd_key,1,5),'-','_') AS cat_id,
        -- Remaining characters (from position 7) are the product key used in sales
        SUBSTRING(prd_key,7,LEN(prd_key)) AS prd_key,
        prd_nm AS prd_name,
        prd_cost,
        -- Map product line codes to readable names
        CASE WHEN UPPER(TRIM(prd_line))='M' THEN 'Mountain'
             WHEN UPPER(TRIM(prd_line))='R' THEN 'Road'
             WHEN UPPER(TRIM(prd_line))='S' THEN 'Other Sales'
             WHEN UPPER(TRIM(prd_line))='T' THEN 'Touring'
             ELSE 'N/A'
        END prd_line,
        CAST(prd_start_dt AS DATE) AS prd_start_dt,
        -- End date = one day before the next version of the same product
        -- starts; the current (latest) version gets a NULL end date
        CAST(DATEADD(
                    DAY,
                    -1,
                    LEAD(prd_start_dt) OVER (
                        PARTITION BY prd_key
                        ORDER BY prd_start_dt
                    )
                ) AS DATE) AS prd_end_dt
         FROM bronze.crm_prd_info;

         SET @end_time = GETDATE();
         PRINT '-----------------------------------------------------';
         PRINT 'Load Duration of crm_prd_info ' + CAST (DATEDIFF(second,@start_time,@end_time) AS NVARCHAR) + ' seconds';
         PRINT '-----------------------------------------------------';

        -- ---------------------------------------------------------------------
        -- CRM: crm_sales_details
        -- - Converts YYYYMMDD integer dates to DATE (invalid dates -> NULL)
        -- - Recalculates sales and price when missing or inconsistent
        -- ---------------------------------------------------------------------
        SET @start_time = GETDATE();

        TRUNCATE TABLE silver.crm_sales_details;
         INSERT INTO silver.crm_sales_details(
                sls_ord_num,
                sls_prd_key,
                sls_cust_id,
                sls_order_dt,
                sls_ship_dt,
                sls_due_dt,
                sls_sales,
                sls_quantity,
                sls_price
         )
         SELECT
         sls_ord_num,
         sls_prd_key,
         sls_cust_id,
         -- Dates: 0 or anything that isn't 8 digits (YYYYMMDD) is invalid -> NULL
         CASE WHEN sls_order_dt=0 OR LEN(sls_order_dt) != 8 THEN NULL
              ELSE CAST(CAST(sls_order_dt AS VARCHAR) AS DATE)
         END AS sls_order_dt,
         CASE WHEN sls_ship_dt=0 OR LEN(sls_ship_dt) != 8 THEN NULL
              ELSE CAST(CAST(sls_ship_dt AS VARCHAR) AS DATE)
         END AS sls_ship_dt,
         CASE WHEN sls_due_dt=0 OR LEN(sls_due_dt) != 8 THEN NULL
              ELSE CAST(CAST(sls_due_dt AS VARCHAR) AS DATE)
         END AS sls_due_dt,
         -- Sales: recalculate as quantity * |price| if missing, non-positive
         -- or not equal to quantity * price
         CASE WHEN sls_sales IS NULL OR sls_sales <=0 OR sls_sales!=sls_quantity*ABS(sls_price)
              THEN sls_quantity*ABS(sls_price)
              ELSE sls_sales
         END AS sls_sales,
         sls_quantity,
         -- Price: derive from sales / quantity if missing or non-positive
         -- (NULLIF avoids a divide-by-zero error)
         CASE WHEN sls_price IS NULL OR sls_price<=0
              THEN sls_sales / NULLIF(sls_quantity,0)
              ELSE sls_price
         END AS sls_price
         FROM bronze.crm_sales_details;

        SET @end_time = GETDATE();
        PRINT '-----------------------------------------------------';
        PRINT 'Load Duration of crm_sales_details ' + CAST (DATEDIFF(second,@start_time,@end_time) AS NVARCHAR) + ' seconds';
        PRINT '-----------------------------------------------------';

        PRINT '--------------------';
        PRINT 'Loading ERP Data';
        print '--------------------';


        -- ---------------------------------------------------------------------
        -- ERP: erp_cust_az12
        -- - Removes the 'NAS' prefix from cid so it matches crm_cust_info.cst_key
        -- - Sets future birth dates to NULL
        -- - Normalizes gender values
        -- ---------------------------------------------------------------------
        SET @start_time = GETDATE();

         TRUNCATE TABLE silver.erp_cust_az12;
         INSERT INTO silver.erp_cust_az12(
                cid,
                bdate,
                gen
         )
         SELECT
         -- Strip the 3-character 'NAS' prefix
         CASE WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid,4,LEN(cid))
              ELSE cid
         END cid,
         -- Birth dates in the future are invalid
         CASE WHEN bdate > GETDATE() THEN NULL
              ELSE bdate
         END AS bdate,
         -- Map gender codes / names to 'Female', 'Male' or 'N/A'
         CASE WHEN UPPER(TRIM(gen)) IN ('F','FEMALE') THEN 'Female'
              WHEN UPPER(TRIM(gen)) IN ('M','MALE') THEN 'Male'
              ELSE 'N/A'
         END AS gen
         FROM bronze.erp_cust_az12;

        SET @end_time = GETDATE();
        PRINT '-----------------------------------------------------';
        PRINT 'Load Duration of erp_cust_az12 ' + CAST (DATEDIFF(second,@start_time,@end_time) AS NVARCHAR) + ' seconds';
        PRINT '-----------------------------------------------------';


        -- ---------------------------------------------------------------------
        -- ERP: erp_loc_a101
        -- - Removes the hyphen from cid so it matches crm_cust_info.cst_key
        -- - Normalizes country codes to full names; blanks/NULLs -> 'N/A'
        -- ---------------------------------------------------------------------
         SET @start_time = GETDATE();

         TRUNCATE TABLE silver.erp_loc_a101;
         INSERT INTO silver.erp_loc_a101(
                cid,
                country
         )
         SELECT
         REPLACE(cid,'-','') cid,
         CASE WHEN TRIM(cntry) = 'DE' THEN 'Germany'
              WHEN TRIM(cntry) IN ('US','USA') THEN 'United States'
              WHEN TRIM(cntry) = '' OR cntry IS NULL THEN 'N/A'
              ELSE TRIM(cntry)
         END AS country
         FROM bronze.erp_loc_a101;

        SET @end_time = GETDATE();
        PRINT '-----------------------------------------------------';
        PRINT 'Load Duration of erp_loc_a101 ' + CAST (DATEDIFF(second,@start_time,@end_time) AS NVARCHAR) + ' seconds';
        PRINT '-----------------------------------------------------';

        -- ---------------------------------------------------------------------
        -- ERP: erp_px_cat_g1v2
        -- - Source data is already clean, so it is copied as-is
        -- ---------------------------------------------------------------------
        SET @start_time = GETDATE();

        TRUNCATE TABLE silver.erp_px_cat_g1v2;
        INSERT INTO silver.erp_px_cat_g1v2(
               id,
               cat,
               subcat,
               maintenance
        )
        SELECT
        id,
        cat,
        subcat,
        maintenance
        FROM bronze.erp_px_cat_g1v2;
        SET @end_time = GETDATE();

        PRINT '-----------------------------------------------------';
        PRINT 'Load Duration of erp_px_cat_g1v2 ' + CAST (DATEDIFF(second,@start_time,@end_time) AS NVARCHAR) + ' seconds';
        PRINT '-----------------------------------------------------';

        PRINT '-------------------------';
        PRINT 'Data Loaded Successfully';
        PRINT '-------------------------';

    END TRY
    -- Error handling: if any load above fails, report the error details
    -- instead of letting the procedure stop with an unhandled error
    BEGIN CATCH
        PRINT '-----------------------------------------';
        PRINT 'Error Occured During Loading Silver Layer';
        PRINT 'Error Message ' + ERROR_MESSAGE();
        PRINT 'Error Number ' + CAST(ERROR_NUMBER() AS NVARCHAR);
        PRINT 'Error State ' + CAST(ERROR_STATE() AS NVARCHAR);
        PRINT '-----------------------------------------';
    END CATCH;

    -- Stop the batch timer and report the total load time
    SET @batch_end_time = GETDATE();

    PRINT '-----------------------------------------------------';
    PRINT 'Data Load Duration  ' + CAST (DATEDIFF(second,@batch_start_time,@batch_end_time) AS NVARCHAR) + ' seconds';
    PRINT '-----------------------------------------------------';

END;
GO

-- Run the procedure to load all silver tables
EXEC silver.load_silver;