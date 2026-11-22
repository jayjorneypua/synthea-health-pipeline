--=====================================================================================================
--                                        synthea_loader Login
--=====================================================================================================
-- Purpose:  Python loader and spLoad_All (Airflow). Member of role_Loader.
--           Password comes from env var SYNTHEA_LOADER_PWD (sqlcmd scripting variable).
--=====================================================================================================
IF SUSER_ID(N'synthea_loader') IS NULL BEGIN
    PRINT N'synthea_loader login - Creating';
    CREATE LOGIN synthea_loader WITH PASSWORD = N'$(SYNTHEA_LOADER_PWD)', DEFAULT_DATABASE = SyntheaHealth, CHECK_POLICY = ON;
END
GO

IF DATABASE_PRINCIPAL_ID(N'synthea_loader') IS NULL BEGIN
    PRINT N'synthea_loader user - Creating';
    CREATE USER synthea_loader FOR LOGIN synthea_loader;
END
GO

ALTER ROLE role_Loader ADD MEMBER synthea_loader;
GO

PRINT N'synthea_loader - Script Done';
GO