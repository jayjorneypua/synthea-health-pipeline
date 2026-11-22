--=====================================================================================================
--                                        Schemas
--=====================================================================================================
IF SCHEMA_ID(N'security') IS NULL EXEC(N'CREATE SCHEMA security');
IF SCHEMA_ID(N'ref')      IS NULL EXEC(N'CREATE SCHEMA ref');
IF SCHEMA_ID(N'clinical') IS NULL EXEC(N'CREATE SCHEMA clinical');
IF SCHEMA_ID(N'stage')    IS NULL EXEC(N'CREATE SCHEMA stage');
GO