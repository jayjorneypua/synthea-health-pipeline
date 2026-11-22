--=====================================================================================================
--                                        Schemas
--=====================================================================================================
IF SCHEMA_ID(N'security') IS NULL EXEC(N'CREATE SCHEMA security');
IF SCHEMA_ID(N'ref')      IS NULL EXEC(N'CREATE SCHEMA ref');
IF SCHEMA_ID(N'clinical') IS NULL EXEC(N'CREATE SCHEMA clinical');
IF SCHEMA_ID(N'stage')    IS NULL EXEC(N'CREATE SCHEMA stage');
IF SCHEMA_ID(N'api')      IS NULL EXEC(N'CREATE SCHEMA api AUTHORIZATION dbo');
IF SCHEMA_ID(N'etl')      IS NULL EXEC(N'CREATE SCHEMA etl AUTHORIZATION dbo');
GO