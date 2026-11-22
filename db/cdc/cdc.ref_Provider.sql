--=====================================================================================================
--                                        cdc ref_Provider Capture Instance
--=====================================================================================================
-- Purpose:  Enables CDC on ref.Provider with net changes. Gated by role_Extractor.
--=====================================================================================================
IF NOT EXISTS (SELECT 1 FROM cdc.change_tables WHERE source_object_id = OBJECT_ID(N'ref.[Provider]')) BEGIN
    PRINT N'cdc ref_Provider - Enabling';
    EXEC sys.sp_cdc_enable_table
          @source_schema        = N'ref'
        , @source_name          = N'Provider'
        , @role_name            = N'role_Extractor'
        , @supports_net_changes = 1;
END
GO

PRINT N'cdc ref_Provider - Script Done';
GO
