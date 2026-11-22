--=====================================================================================================
--                                        clinical.Encounter Table
--=====================================================================================================
-- Purpose:  Patient visits (wellness, ambulatory, emergency, inpatient...). Dates are UTC.
--=====================================================================================================
IF OBJECT_ID(N'clinical.Encounter', N'U') IS NULL BEGIN
    PRINT N'clinical.Encounter - Creating';

    CREATE TABLE clinical.Encounter (
          ID                  INT                 NOT NULL     IDENTITY(0, 1)
        , ID_Patient          INT                 NOT NULL     CONSTRAINT df_clinical_encounter_ID_Patient       DEFAULT(0)  --from clinical.Patient
        , ID_Organization     INT                 NOT NULL     CONSTRAINT df_clinical_encounter_ID_Organization  DEFAULT(0)  --from ref.Organization
        , ID_Provider         INT                 NOT NULL     CONSTRAINT df_clinical_encounter_ID_Provider      DEFAULT(0)  --from ref.Provider
        , ID_Payer            INT                 NOT NULL     CONSTRAINT df_clinical_encounter_ID_Payer         DEFAULT(0)  --from ref.Payer
        , ID_Code             INT                 NOT NULL     CONSTRAINT df_clinical_encounter_ID_Code          DEFAULT(0)  --from ref.Code (encounter type)
        , ID_ReasonCode       INT                 NOT NULL     CONSTRAINT df_clinical_encounter_ID_ReasonCode    DEFAULT(0)  --from ref.Code (reason)

        --------------------------------------------------------------------------------
        , SourceKey           UNIQUEIDENTIFIER    NOT NULL     CONSTRAINT df_clinical_encounter_SourceKey        DEFAULT('00000000-0000-0000-0000-000000000000')
        , EncounterClass      NVARCHAR(20)        NOT NULL     CONSTRAINT df_clinical_encounter_EncounterClass   DEFAULT('')
        , StartDate           DATETIME2(0)        NOT NULL     CONSTRAINT df_clinical_encounter_StartDate        DEFAULT('1900-01-01')
        , StopDate            DATETIME2(0)        NULL
        , BaseEncounterCost   DECIMAL(14, 2)      NOT NULL     CONSTRAINT df_clinical_encounter_BaseCost         DEFAULT(0)
        , TotalClaimCost      DECIMAL(14, 2)      NOT NULL     CONSTRAINT df_clinical_encounter_TotalClaimCost   DEFAULT(0)
        , PayerCoverage       DECIMAL(14, 2)      NOT NULL     CONSTRAINT df_clinical_encounter_PayerCoverage    DEFAULT(0)

        --------------------------------------------------------------------------------
        -- Standard Fields
        --------------------------------------------------------------------------------
        , Deleted             BIT                 NOT NULL     CONSTRAINT df_clinical_encounter_Deleted          DEFAULT(0)
        , ID_CreatedBy        INT                 NOT NULL     CONSTRAINT df_clinical_encounter_ID_CreatedBy     DEFAULT(1)
        , CreatedDate         DATETIME2           NOT NULL     CONSTRAINT df_clinical_encounter_CreatedDate      DEFAULT(SYSUTCDATETIME())
        , ID_UpdatedBy        INT                 NOT NULL     CONSTRAINT df_clinical_encounter_ID_UpdatedBy     DEFAULT(0)
        , UpdatedDate         DATETIME2           NULL

        , CONSTRAINT pk_clinical_encounter_ID PRIMARY KEY CLUSTERED (ID)
    );

    SET IDENTITY_INSERT clinical.Encounter ON;
    INSERT INTO clinical.Encounter (ID, EncounterClass) VALUES (0, N'(None)');
    SET IDENTITY_INSERT clinical.Encounter OFF;

    CREATE UNIQUE NONCLUSTERED INDEX UX_Encounter_SourceKey ON clinical.Encounter (SourceKey) WHERE ID > 0;
    CREATE NONCLUSTERED INDEX IX_Encounter_ID_Patient ON clinical.Encounter (ID_Patient, StartDate);
    CREATE NONCLUSTERED INDEX IX_Encounter_ID_Organization ON clinical.Encounter (ID_Organization);
    CREATE NONCLUSTERED INDEX IX_Encounter_ID_Provider ON clinical.Encounter (ID_Provider);
    CREATE NONCLUSTERED INDEX IX_Encounter_ID_Payer ON clinical.Encounter (ID_Payer);

    ALTER TABLE clinical.Encounter ADD CONSTRAINT fk_clinical_encounter_ID_Patient      FOREIGN KEY (ID_Patient)      REFERENCES clinical.Patient(ID);
    ALTER TABLE clinical.Encounter ADD CONSTRAINT fk_clinical_encounter_ID_Organization FOREIGN KEY (ID_Organization) REFERENCES ref.Organization(ID);
    ALTER TABLE clinical.Encounter ADD CONSTRAINT fk_clinical_encounter_ID_Provider     FOREIGN KEY (ID_Provider)     REFERENCES ref.Provider(ID);
    ALTER TABLE clinical.Encounter ADD CONSTRAINT fk_clinical_encounter_ID_Payer        FOREIGN KEY (ID_Payer)        REFERENCES ref.Payer(ID);
    ALTER TABLE clinical.Encounter ADD CONSTRAINT fk_clinical_encounter_ID_Code         FOREIGN KEY (ID_Code)         REFERENCES ref.Code(ID);
    ALTER TABLE clinical.Encounter ADD CONSTRAINT fk_clinical_encounter_ID_ReasonCode   FOREIGN KEY (ID_ReasonCode)   REFERENCES ref.Code(ID);
    ALTER TABLE clinical.Encounter ADD CONSTRAINT fk_clinical_encounter_ID_CreatedBy    FOREIGN KEY (ID_CreatedBy)    REFERENCES security.[User](ID);
    ALTER TABLE clinical.Encounter ADD CONSTRAINT fk_clinical_encounter_ID_UpdatedBy    FOREIGN KEY (ID_UpdatedBy)    REFERENCES security.[User](ID);
END
GO

PRINT N'clinical.Encounter - Script Done';
GO