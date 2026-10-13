-- Create the Olist project database only if it does not already exist.
USE master;
GO

IF DB_ID(N'olist_analytics') IS NULL
BEGIN
    CREATE DATABASE olist_analytics;
END;
GO

-- Select the project database for subsequent work.
USE olist_analytics;
GO

-- Confirm the active database.
SELECT DB_NAME() AS current_database;