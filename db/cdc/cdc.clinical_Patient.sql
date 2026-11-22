--=====================================================================================================
--                                        cdc clinical_Patient Capture Instance
--=====================================================================================================
-- Purpose:  Enables CDC on clinical.Patient with net changes. Gated by role_Extractor.
--=====================================================================================================
IF NOT EXISTS (SELECT 1 FROM cdc.change_tables WHERE source_object_id = OBJECT_ID(N'clinical.[Patient]')) BEGIN
    PRINT N'cdc clinical_Patient - Enabling';
    EXEC sys.sp_cdc_enable_table
          @source_schema        = N'clinical'
        , @source_name          = N'Patient'
        , @role_name            = N'role_Extractor'
        , @supports_net_changes = 1;
END
GO

GRANT UNMASK ON clinical.Patient(BirthDate) TO role_Extractor;
GRANT UNMASK ON cdc.clinical_Patient_CT(BirthDate) TO role_Extractor;
GO

PRINT N'cdc clinical_Patient - Script Done';
GO
