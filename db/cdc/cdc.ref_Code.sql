--=====================================================================================================
--                                        cdc ref_Code Capture Instance
--=====================================================================================================
-- Purpose:  Enables CDC on ref.Code with net changes. Gated by role_Extractor.
--=====================================================================================================
IF NOT EXISTS (SELECT 1 FROM cdc.change_tables WHERE source_object_id = OBJECT_ID(N'ref.[Code]')) BEGIN
    PRINT N'cdc ref_Code - Enabling';
    EXEC sys.sp_cdc_enable_table
          @source_schema        = N'ref'
        , @source_name          = N'Code'
        , @role_name            = N'role_Extractor'
        , @supports_net_changes = 1;
END
GO

PRINT N'cdc ref_Code - Script Done';
GO
