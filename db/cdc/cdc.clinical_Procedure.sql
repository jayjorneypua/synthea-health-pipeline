--=====================================================================================================
--                                        cdc clinical_Procedure Capture Instance
--=====================================================================================================
-- Purpose:  Enables CDC on clinical.Procedure with net changes. Gated by role_Extractor.
--=====================================================================================================
IF NOT EXISTS (SELECT 1 FROM cdc.change_tables WHERE source_object_id = OBJECT_ID(N'clinical.[Procedure]')) BEGIN
    PRINT N'cdc clinical_Procedure - Enabling';
    EXEC sys.sp_cdc_enable_table
          @source_schema        = N'clinical'
        , @source_name          = N'Procedure'
        , @role_name            = N'role_Extractor'
        , @supports_net_changes = 1;
END
GO

PRINT N'cdc clinical_Procedure - Script Done';
GO
