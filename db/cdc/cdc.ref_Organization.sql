--=====================================================================================================
--                                        cdc ref_Organization Capture Instance
--=====================================================================================================
-- Purpose:  Enables CDC on ref.Organization with net changes. Gated by role_Extractor.
--=====================================================================================================
IF NOT EXISTS (SELECT 1 FROM cdc.change_tables WHERE source_object_id = OBJECT_ID(N'ref.[Organization]')) BEGIN
    PRINT N'cdc ref_Organization - Enabling';
    EXEC sys.sp_cdc_enable_table
          @source_schema        = N'ref'
        , @source_name          = N'Organization'
        , @role_name            = N'role_Extractor'
        , @supports_net_changes = 1;
END
GO

PRINT N'cdc ref_Organization - Script Done';
GO
