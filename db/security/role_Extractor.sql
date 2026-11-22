--=====================================================================================================
--                                        role_Extractor Role
--=====================================================================================================
-- Purpose:  CDC gating role (passed as @role_name when enabling CDC). Reading change data needs
--           SELECT on the captured source columns, so ref and clinical are granted here.
--=====================================================================================================
IF DATABASE_PRINCIPAL_ID(N'role_Extractor') IS NULL BEGIN
    PRINT N'role_Extractor - Creating';
    CREATE ROLE role_Extractor AUTHORIZATION dbo;
END
GO

GRANT SELECT ON SCHEMA::ref TO role_Extractor;
GRANT SELECT ON SCHEMA::clinical TO role_Extractor;
GO

PRINT N'role_Extractor - Script Done';
GO