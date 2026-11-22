--=====================================================================================================
--                                        role_Developer Role
--=====================================================================================================
-- Purpose:  Developers and BI. SELECT on the api views only, never the tables. PII stays masked.
--=====================================================================================================
IF DATABASE_PRINCIPAL_ID(N'role_Developer') IS NULL BEGIN
    PRINT N'role_Developer - Creating';
    CREATE ROLE role_Developer AUTHORIZATION dbo;
END
GO

GRANT SELECT ON SCHEMA::api TO role_Developer;
GO

PRINT N'role_Developer - Script Done';
GO