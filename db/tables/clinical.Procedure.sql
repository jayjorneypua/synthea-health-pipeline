--=====================================================================================================
--                                        clinical.Procedure Table
--=====================================================================================================
-- Purpose:  Procedures performed during an encounter, with cost. Dates are UTC.
--           Natural key: encounter + code + start date + Occurrence. [Procedure] is a reserved word.
--=====================================================================================================
IF OBJECT_ID(N'clinical.[Procedure]', N'U') IS NULL BEGIN
    PRINT N'clinical.Procedure - Creating';

    CREATE TABLE clinical.[Procedure] (
          ID                  INT                 NOT NULL     IDENTITY(0, 1)
        , ID_Patient          INT                 NOT NULL     CONSTRAINT df_clinical_procedure_ID_Patient     DEFAULT(0)  --from clinical.Patient
        , ID_Encounter        INT                 NOT NULL     CONSTRAINT df_clinical_procedure_ID_Encounter   DEFAULT(0)  --from clinical.Encounter
        , ID_Code             INT                 NOT NULL     CONSTRAINT df_clinical_procedure_ID_Code        DEFAULT(0)  --from ref.Code (SNOMED-CT)
        , ID_ReasonCode       INT                 NOT NULL     CONSTRAINT df_clinical_procedure_ID_ReasonCode  DEFAULT(0)  --from ref.Code (reason)

        --------------------------------------------------------------------------------
        , StartDate           DATETIME2(0)        NOT NULL     CONSTRAINT df_clinical_procedure_StartDate      DEFAULT('1900-01-01')
        , StopDate            DATETIME2(0)        NULL
        , Occurrence          INT                 NOT NULL     CONSTRAINT df_clinical_procedure_Occurrence     DEFAULT(1)
        , BaseCost            DECIMAL(14, 2)      NOT NULL     CONSTRAINT df_clinical_procedure_BaseCost       DEFAULT(0)

        --------------------------------------------------------------------------------
        -- Standard Fields
        --------------------------------------------------------------------------------
        , Deleted             BIT                 NOT NULL     CONSTRAINT df_clinical_procedure_Deleted        DEFAULT(0)
        , ID_CreatedBy        INT                 NOT NULL     CONSTRAINT df_clinical_procedure_ID_CreatedBy   DEFAULT(1)
        , CreatedDate         DATETIME2           NOT NULL     CONSTRAINT df_clinical_procedure_CreatedDate    DEFAULT(SYSUTCDATETIME())
        , ID_UpdatedBy        INT                 NOT NULL     CONSTRAINT df_clinical_procedure_ID_UpdatedBy   DEFAULT(0)
        , UpdatedDate         DATETIME2           NULL

        , CONSTRAINT pk_clinical_procedure_ID PRIMARY KEY CLUSTERED (ID)
    );

    SET IDENTITY_INSERT clinical.[Procedure] ON;
    INSERT INTO clinical.[Procedure] (ID) VALUES (0);
    SET IDENTITY_INSERT clinical.[Procedure] OFF;

    CREATE UNIQUE NONCLUSTERED INDEX UX_Procedure_NaturalKey ON clinical.[Procedure] (ID_Encounter, ID_Code, StartDate, Occurrence) WHERE ID > 0;
    CREATE NONCLUSTERED INDEX IX_Procedure_ID_Patient ON clinical.[Procedure] (ID_Patient);
    CREATE NONCLUSTERED INDEX IX_Procedure_ID_Code ON clinical.[Procedure] (ID_Code);

    ALTER TABLE clinical.[Procedure] ADD CONSTRAINT fk_clinical_procedure_ID_Patient    FOREIGN KEY (ID_Patient)    REFERENCES clinical.Patient(ID);
    ALTER TABLE clinical.[Procedure] ADD CONSTRAINT fk_clinical_procedure_ID_Encounter  FOREIGN KEY (ID_Encounter)  REFERENCES clinical.Encounter(ID);
    ALTER TABLE clinical.[Procedure] ADD CONSTRAINT fk_clinical_procedure_ID_Code       FOREIGN KEY (ID_Code)       REFERENCES ref.Code(ID);
    ALTER TABLE clinical.[Procedure] ADD CONSTRAINT fk_clinical_procedure_ID_ReasonCode FOREIGN KEY (ID_ReasonCode) REFERENCES ref.Code(ID);
    ALTER TABLE clinical.[Procedure] ADD CONSTRAINT fk_clinical_procedure_ID_CreatedBy  FOREIGN KEY (ID_CreatedBy)  REFERENCES security.[User](ID);
    ALTER TABLE clinical.[Procedure] ADD CONSTRAINT fk_clinical_procedure_ID_UpdatedBy  FOREIGN KEY (ID_UpdatedBy)  REFERENCES security.[User](ID);
END
GO

PRINT N'clinical.Procedure - Script Done';
GO