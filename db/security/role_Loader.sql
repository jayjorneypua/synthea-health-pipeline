--=====================================================================================================
--                                        role_Loader Role
--=====================================================================================================
-- Purpose:  Python loader and spLoad_All. INSERT / DELETE on stage tables, EXECUTE on stage procs.
--           Granted at schema level so it survives stage tables being recreated on deploy.
--           Procs reach ref / clinical through ownership chaining (all schemas owned by dbo).
--=====================================================================================================
IF DATABASE_PRINCIPAL_ID(N'role_Loader') IS NULL BEGIN
    PRINT N'role_Loader - Creating';
    CREATE ROLE role_Loader AUTHORIZATION dbo;
END
GO

GRANT INSERT, DELETE, EXECUTE ON SCHEMA::stage TO role_Loader;
GO

PRINT N'role_Loader - Script Done';
GO