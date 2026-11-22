--=====================================================================================================
--                                        role_Extractor Role
--=====================================================================================================
-- Purpose:  CDC gating role (passed as @role_name when enabling CDC). Grants are added in the CDC
--           step, because reading change data also needs SELECT on the captured source columns.
--=====================================================================================================
IF DATABASE_PRINCIPAL_ID(N'role_Extractor') IS NULL BEGIN
    PRINT N'role_Extractor - Creating';
    CREATE ROLE role_Extractor AUTHORIZATION dbo;
END
GO

PRINT N'role_Extractor - Script Done';
GO