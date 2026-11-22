--=====================================================================================================
--                                        cdc EnableDatabase
--=====================================================================================================
-- Purpose:  Enables CDC on SyntheaHealth (creates the cdc schema). Needs sysadmin.
--           role_Extractor gets SELECT on the cdc schema to read change tables and functions.
--=====================================================================================================
IF (SELECT is_cdc_enabled FROM sys.databases WHERE name = DB_NAME()) = 0 BEGIN
    PRINT N'cdc database - Enabling';
    EXEC sys.sp_cdc_enable_db;
END
GO

GRANT SELECT ON SCHEMA::cdc TO role_Extractor;
GO

PRINT N'cdc EnableDatabase - Script Done';
GO