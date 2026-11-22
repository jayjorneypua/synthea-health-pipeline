--=====================================================================================================
--                                        synthea_extractor Login
--=====================================================================================================
-- Purpose:  Python CDC extractor (Airflow). Member of role_Extractor.
--           Password comes from env var SYNTHEA_EXTRACTOR_PWD (sqlcmd scripting variable).
--=====================================================================================================
IF SUSER_ID(N'synthea_extractor') IS NULL BEGIN
    PRINT N'synthea_extractor login - Creating';
    CREATE LOGIN synthea_extractor WITH PASSWORD = N'$(SYNTHEA_EXTRACTOR_PWD)', DEFAULT_DATABASE = SyntheaHealth, CHECK_POLICY = ON;
END
GO

IF DATABASE_PRINCIPAL_ID(N'synthea_extractor') IS NULL BEGIN
    PRINT N'synthea_extractor user - Creating';
    CREATE USER synthea_extractor FOR LOGIN synthea_extractor;
END
GO

ALTER ROLE role_Extractor ADD MEMBER synthea_extractor;
GO

PRINT N'synthea_extractor - Script Done';
GO