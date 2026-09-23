/*
===============================================================================
Initialize Database and Schemas
===============================================================================
Script Purpose:
    This script creates the 'DataWarehouse' database and the three schemas of
    the Medallion Architecture:
    - bronze : raw data loaded as-is from the source CSV files
    - silver : cleansed and standardized data
    - gold   : business-ready star schema (views)

Note:
    - Run this script first, before any other script in the project.
    - The script is safe to re-run: the database and each schema are only
      created if they do not already exist, so no existing data is dropped.
===============================================================================
*/

USE master;
GO

-- Create the database only if it does not exist yet
IF DB_ID('DataWarehouse') IS NULL
    CREATE DATABASE DataWarehouse;
GO

USE DataWarehouse;
GO

-- CREATE SCHEMA must be the only statement in its batch, so it is wrapped in
-- EXEC to allow the existence check
IF SCHEMA_ID('bronze') IS NULL
    EXEC('CREATE SCHEMA bronze');
GO

IF SCHEMA_ID('silver') IS NULL
    EXEC('CREATE SCHEMA silver');
GO

IF SCHEMA_ID('gold') IS NULL
    EXEC('CREATE SCHEMA gold');
GO
