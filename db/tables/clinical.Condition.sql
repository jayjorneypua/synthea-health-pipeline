--=====================================================================================================
--                                        clinical.Condition Table
--=====================================================================================================
-- Purpose:  Diagnoses recorded during an encounter. Natural key: encounter + code + start date
--           + Occurrence (1, 2, 3 when the same code repeats at the same time).
--=====================================================================================================
IF OBJECT_ID(N'clinical.Condition', N'U') IS NULL BEGIN
    PRINT N'clinical.Condition - Creating';

    CREATE TABLE clinical.Condition (
          ID                  INT                 NOT NULL     IDENTITY(0, 1)
        , ID_Patient          INT                 NOT NULL     CONSTRAINT df_clinical_condition_ID_Patient    DEFAULT(0)  --from clinical.Patient
        , ID_Encounter        INT                 NOT NULL     CONSTRAINT df_clinical_condition_ID_Encounter  DEFAULT(0)  --from clinical.Encounter
        , ID_Code             INT                 NOT NULL     CONSTRAINT df_clinical_condition_ID_Code       DEFAULT(0)  --from ref.Code

        --------------------------------------------------------------------------------
        , StartDate           DATE                NOT NULL     CONSTRAINT df_clinical_condition_StartDate     DEFAULT('1900-01-01')
        , StopDate            DATE                NULL
        , Occurrence          INT                 NOT NULL     CONSTRAINT df_clinical_condition_Occurrence    DEFAULT(1)

        --------------------------------------------------------------------------------
        -- Standard Fields
        --------------------------------------------------------------------------------
        , Deleted             BIT                 NOT NULL     CONSTRAINT df_clinical_condition_Deleted       DEFAULT(0)
        , ID_CreatedBy        INT                 NOT NULL     CONSTRAINT df_clinical_condition_ID_CreatedBy  DEFAULT(1)
        , CreatedDate         DATETIME2           NOT NULL     CONSTRAINT df_clinical_condition_CreatedDate   DEFAULT(SYSUTCDATETIME())
        , ID_UpdatedBy        INT                 NOT NULL     CONSTRAINT df_clinical_condition_ID_UpdatedBy  DEFAULT(0)
        , UpdatedDate         DATETIME2           NULL

        , CONSTRAINT pk_clinical_condition_ID PRIMARY KEY CLUSTERED (ID)
    );

    SET IDENTITY_INSERT clinical.Condition ON;
    INSERT INTO clinical.Condition (ID) VALUES (0);
    SET IDENTITY_INSERT clinical.Condition OFF;

    CREATE UNIQUE NONCLUSTERED INDEX UX_Condition_NaturalKey ON clinical.Condition (ID_Encounter, ID_Code, StartDate, Occurrence) WHERE ID > 0;
    CREATE NONCLUSTERED INDEX IX_Condition_ID_Patient ON clinical.Condition (ID_Patient);
    CREATE NONCLUSTERED INDEX IX_Condition_ID_Code ON clinical.Condition (ID_Code);

    ALTER TABLE clinical.Condition ADD CONSTRAINT fk_clinical_condition_ID_Patient   FOREIGN KEY (ID_Patient)   REFERENCES clinical.Patient(ID);
    ALTER TABLE clinical.Condition ADD CONSTRAINT fk_clinical_condition_ID_Encounter FOREIGN KEY (ID_Encounter) REFERENCES clinical.Encounter(ID);
    ALTER TABLE clinical.Condition ADD CONSTRAINT fk_clinical_condition_ID_Code      FOREIGN KEY (ID_Code)      REFERENCES ref.Code(ID);
    ALTER TABLE clinical.Condition ADD CONSTRAINT fk_clinical_condition_ID_CreatedBy FOREIGN KEY (ID_CreatedBy) REFERENCES security.[User](ID);
    ALTER TABLE clinical.Condition ADD CONSTRAINT fk_clinical_condition_ID_UpdatedBy FOREIGN KEY (ID_UpdatedBy) REFERENCES security.[User](ID);
END
GO

PRINT N'clinical.Condition - Script Done';
GO