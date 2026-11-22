--=====================================================================================================
--                                        cdc Jobs
--=====================================================================================================
-- Purpose:  CDC cleanup retention = 30 days (default is 3). The pipeline runs manually, so a short
--           retention could purge changes before the extractor reads them. Runs after the tables
--           because the cleanup job is created by the first sp_cdc_enable_table.
--=====================================================================================================
EXEC sys.sp_cdc_change_job @job_type = N'cleanup', @retention = 43200;
GO

PRINT N'cdc Jobs - Script Done';
GO