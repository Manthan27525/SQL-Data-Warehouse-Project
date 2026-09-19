/*
===============================================================================
Script:      init_database.sql
Purpose:     Initialise the environment for the SQL Data Warehouse project.
             Creates the 'DataWarehouse' database and the three schemas used
             by the medallion architecture:

               bronze - raw data, ingested as-is from the source systems
               silver - cleansed and standardised data
               gold   - business-ready data modelled for analytics/reporting

Target:      Microsoft SQL Server (T-SQL)
Run as:      A login with permission to create databases (e.g. sysadmin).
Usage:       Run once, before any of the bronze/silver/gold object scripts.

Note:        This script does not drop or overwrite an existing database.
             Re-running it after the database exists will fail on the
             CREATE statements.
===============================================================================
*/

-- Switch to the master database; databases are created from here.
USE master;

-- Create the data warehouse database.
CREATE DataWarehouse;

-- Switch into the new database so the schemas below are created inside it.
USE DataWarehouse;

-- Bronze layer: raw, unprocessed data loaded directly from the sources.
CREATE SCHEMA bronze;
GO

-- Silver layer: cleaned, deduplicated and standardised data.
CREATE SCHEMA silver;
GO

-- Gold layer: business-ready views/tables (e.g. star schema) for reporting.
CREATE SCHEMA gold;
GO
