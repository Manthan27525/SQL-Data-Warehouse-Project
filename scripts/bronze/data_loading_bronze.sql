/*
===============================================================================
Stored Procedure: Load Bronze Layer (Source -> Bronze)
===============================================================================
Script Purpose:
    This stored procedure loads data into the 'bronze' schema from the external
    CSV files in the 'datasets' folder.
    It performs the following actions for each table:
    - Truncates the bronze table before loading, so the load can be re-run
      without creating duplicate rows.
    - Uses the BULK INSERT command to load the raw CSV data into the table.
    - Prints the load duration of each table and of the whole batch.

Parameters:
    None.
    This stored procedure does not accept any parameters or return any values.

Usage Example:
    EXEC bronze.load_bronze;

Note:
    - The bronze tables must already exist (run ddl_bronze.sql first).
    - The CSV file paths below are absolute paths on the local machine; update
      them if the project is moved or run on another server.
===============================================================================
*/

CREATE OR ALTER PROCEDURE bronze.load_bronze AS

BEGIN
    -- Timers: one pair for each table load, one pair for the whole batch
    DECLARE @start_time DATETIME,@end_time DATETIME, @batch_start_time DATETIME, @batch_end_time DATETIME
    BEGIN TRY
        PRINT '--------------------';
        PRINT 'Loading Bronze Layer';
        PRINT '--------------------';

        PRINT '--------------------';
        PRINT 'Loading CRM Data';
        print '--------------------';

        -- Start the timer for the whole batch
        SET @batch_start_time = GETDATE()

        -- ---------------------------------------------------------------------
        -- CRM: crm_cust_info
        -- ---------------------------------------------------------------------
        SET @start_time = GETDATE();
        -- Empty the table (only if it exists) so the load starts from scratch
        IF OBJECT_ID ('bronze.crm_cust_info','U') IS NOT NULL
        TRUNCATE TABLE bronze.crm_cust_info;
        BULK INSERT bronze.crm_cust_info
        FROM 'SQL-Data-Warehouse-Project\datasets\source_crm\cust_info.csv'
        WITH (
            FIRSTROW=2,             -- Skip the header row; data starts on row 2
            FIELDTERMINATOR = ',',  -- Columns in the CSV are comma separated
            TABLOCK                 -- Lock the whole table during the load for faster inserts
        );
        SET @end_time = GETDATE();
        PRINT '-----------------------------------------------------';
        PRINT 'Load Duration of crm_cust_info ' + CAST (DATEDIFF(second,@start_time,@end_time) AS NVARCHAR) + ' seconds';
        PRINT '-----------------------------------------------------';

        -- ---------------------------------------------------------------------
        -- CRM: crm_prd_info
        -- ---------------------------------------------------------------------
        SET @start_time = GETDATE();
        IF OBJECT_ID ('bronze.crm_prd_info','U') IS NOT NULL
        TRUNCATE TABLE bronze.crm_prd_info;
        BULK INSERT bronze.crm_prd_info
        FROM 'SQL-Data-Warehouse-Project\datasets\source_crm\prd_info.csv'
        WITH (
            FIRSTROW=2,
            FIELDTERMINATOR = ',',
            TABLOCK
        );
        SET @end_time = GETDATE();
        PRINT '-----------------------------------------------------';
        PRINT 'Load Duration of crm_prd_info ' + CAST (DATEDIFF(second,@start_time,@end_time) AS NVARCHAR) + ' seconds';
        PRINT '-----------------------------------------------------';

        -- ---------------------------------------------------------------------
        -- CRM: crm_sales_details
        -- ---------------------------------------------------------------------
        SET @start_time = GETDATE();
        IF OBJECT_ID ('bronze.crm_sales_details','U') IS NOT NULL
        TRUNCATE TABLE bronze.crm_sales_details;
        BULK INSERT bronze.crm_sales_details
        FROM 'SQL-Data-Warehouse-Project\datasets\source_crm\sales_details.csv'
        WITH (
            FIRSTROW=2,
            FIELDTERMINATOR = ',',
            TABLOCK
        );
        SET @end_time = GETDATE();
        PRINT '-----------------------------------------------------';
        PRINT 'Load Duration of crm_sales_details ' + CAST (DATEDIFF(second,@start_time,@end_time) AS NVARCHAR) + ' seconds';
        PRINT '-----------------------------------------------------';

        PRINT '--------------------';
        PRINT 'Loading ERP Data';
        print '--------------------';

        -- ---------------------------------------------------------------------
        -- ERP: erp_cust_az12
        -- ---------------------------------------------------------------------
        SET @start_time = GETDATE();
        IF OBJECT_ID ('bronze.erp_cust_az12','U') IS NOT NULL
        TRUNCATE TABLE bronze.erp_cust_az12;
        BULK INSERT bronze.erp_cust_az12
        FROM 'SQL-Data-Warehouse-Project\datasets\source_erp\CUST_AZ12.csv'
        WITH (
            FIRSTROW=2,
            FIELDTERMINATOR = ',',
            TABLOCK
        );
        SET @end_time = GETDATE();
        PRINT '-----------------------------------------------------';
        PRINT 'Load Duration of erp_cust_az12 ' + CAST (DATEDIFF(second,@start_time,@end_time) AS NVARCHAR) + ' seconds';
        PRINT '-----------------------------------------------------';

        -- ---------------------------------------------------------------------
        -- ERP: erp_loc_a101
        -- ---------------------------------------------------------------------
        SET @start_time = GETDATE();
        IF OBJECT_ID ('bronze.erp_loc_a101','U') IS NOT NULL
        TRUNCATE TABLE bronze.erp_loc_a101;
        BULK INSERT bronze.erp_loc_a101
        FROM 'SQL-Data-Warehouse-Project\datasets\source_erp\LOC_A101.csv'
        WITH (
            FIRSTROW=2,
            FIELDTERMINATOR = ',',
            TABLOCK
        );
        SET @end_time = GETDATE();
        PRINT '-----------------------------------------------------';
        PRINT 'Load Duration of erp_loc_a101 ' + CAST (DATEDIFF(second,@start_time,@end_time) AS NVARCHAR) + ' seconds';
        PRINT '-----------------------------------------------------';

        -- ---------------------------------------------------------------------
        -- ERP: erp_px_cat_g1v2
        -- ---------------------------------------------------------------------
        SET @start_time = GETDATE();
        IF OBJECT_ID ('bronze.erp_px_cat_g1v2','U') IS NOT NULL
        TRUNCATE TABLE bronze.erp_px_cat_g1v2;
        BULK INSERT bronze.erp_px_cat_g1v2
        FROM 'SQL-Data-Warehouse-Project\datasets\source_erp\PX_CAT_G1V2.csv'
        WITH (
            FIRSTROW=2,
            FIELDTERMINATOR = ',',
            TABLOCK
        );
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
        PRINT 'Error Occured During Loading Bronze Layer';
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

-- Run the procedure to load all bronze tables
EXEC bronze.load_bronze;
