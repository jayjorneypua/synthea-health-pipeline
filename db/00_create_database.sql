--=====================================================================================================
--                                        SyntheaHealth Database
--=====================================================================================================
-- Purpose:  Source (OLTP) database. SIMPLE recovery keeps the log small; CDC still works.
--=====================================================================================================
IF DB_ID(N'SyntheaHealth') IS NULL BEGIN
    PRINT N'SyntheaHealth - Creating';
    CREATE DATABASE SyntheaHealth;
END
GO

ALTER DATABASE SyntheaHealth SET RECOVERY SIMPLE;
GO