--=====================================================================================================
--                                        role_Clinician Role
--=====================================================================================================
-- Purpose:  Clinical users. SELECT on the api views plus UNMASK, so PII is shown in clear text.
--=====================================================================================================
IF DATABASE_PRINCIPAL_ID(N'role_Clinician') IS NULL BEGIN
    PRINT N'role_Clinician - Creating';
    CREATE ROLE role_Clinician AUTHORIZATION dbo;
END
GO

GRANT SELECT ON SCHEMA::api TO role_Clinician;
GRANT UNMASK TO role_Clinician;
GO

PRINT N'role_Clinician - Script Done';
GO