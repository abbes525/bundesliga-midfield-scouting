-- Portable database setup; preserves an existing database.
USE master;
GO

IF DB_ID(N'FootballRecruitmentDW') IS NULL
BEGIN
    EXEC(N'CREATE DATABASE FootballRecruitmentDW;');
END;
GO

USE FootballRecruitmentDW;
GO

IF SCHEMA_ID(N'staging') IS NULL
BEGIN
    EXEC(N'CREATE SCHEMA staging AUTHORIZATION dbo;');
END;
GO

IF SCHEMA_ID(N'analytics') IS NULL
BEGIN
    EXEC(N'CREATE SCHEMA analytics AUTHORIZATION dbo;');
END;
GO

SELECT
    DB_NAME() AS database_name,
    name AS schema_name
FROM sys.schemas
WHERE name IN (N'staging', N'analytics')
ORDER BY name;
