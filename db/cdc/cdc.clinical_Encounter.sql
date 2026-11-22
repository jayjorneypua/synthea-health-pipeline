--=====================================================================================================
--                                        cdc clinical_Encounter Capture Instance
--=====================================================================================================
-- Purpose:  Enables CDC on clinical.Encounter with net changes. Gated by role_Extractor.
--=====================================================================================================
IF NOT EXISTS (SELECT 1 FROM cdc.change_tables WHERE source_object_id = OBJECT_ID(N'clinical.[Encounter]')) BEGIN
    PRINT N'cdc clinical_Encounter - Enabling';
    EXEC sys.sp_cdc_enable_table
          @source_schema        = N'clinical'
        , @source_name          = N'Encounter'
        , @role_name            = N'role_Extractor'
        , @supports_net_changes = 1;
END
GO

PRINT N'cdc clinical_Encounter - Script Done';
GO
