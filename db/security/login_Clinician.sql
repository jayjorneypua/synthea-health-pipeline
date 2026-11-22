--=====================================================================================================
--                                        synthea_clinician Login
--=====================================================================================================
-- Purpose:  Clinician test login. Member of role_Clinician (api views, PII unmasked).
--           Password comes from env var SYNTHEA_CLINICIAN_PWD (sqlcmd scripting variable).
--=====================================================================================================
IF SUSER_ID(N'synthea_clinician') IS NULL BEGIN
    PRINT N'synthea_clinician login - Creating';
    CREATE LOGIN synthea_clinician WITH PASSWORD = N'$(SYNTHEA_CLINICIAN_PWD)', DEFAULT_DATABASE = SyntheaHealth, CHECK_POLICY = ON;
END
GO

IF DATABASE_PRINCIPAL_ID(N'synthea_clinician') IS NULL BEGIN
    PRINT N'synthea_clinician user - Creating';
    CREATE USER synthea_clinician FOR LOGIN synthea_clinician;
END
GO

ALTER ROLE role_Clinician ADD MEMBER synthea_clinician;
GO

PRINT N'synthea_clinician - Script Done';
GO