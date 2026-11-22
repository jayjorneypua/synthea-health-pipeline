--=====================================================================================================
--                                        synthea_dev Login
--=====================================================================================================
-- Purpose:  Developer / BI test login. Member of role_Developer (api views only, PII masked).
--           Password comes from env var SYNTHEA_DEV_PWD (sqlcmd scripting variable).
--=====================================================================================================
IF SUSER_ID(N'synthea_dev') IS NULL BEGIN
    PRINT N'synthea_dev login - Creating';
    CREATE LOGIN synthea_dev WITH PASSWORD = N'$(SYNTHEA_DEV_PWD)', DEFAULT_DATABASE = SyntheaHealth, CHECK_POLICY = ON;
END
GO

IF DATABASE_PRINCIPAL_ID(N'synthea_dev') IS NULL BEGIN
    PRINT N'synthea_dev user - Creating';
    CREATE USER synthea_dev FOR LOGIN synthea_dev;
END
GO

ALTER ROLE role_Developer ADD MEMBER synthea_dev;
GO

PRINT N'synthea_dev - Script Done';
GO