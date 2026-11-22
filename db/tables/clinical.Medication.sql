--=====================================================================================================
--                                        clinical.Medication Table
--=====================================================================================================
-- Purpose:  Prescriptions written during an encounter, with costs. Dates are UTC.
--           Natural key: encounter + code + start date + Occurrence.
--=====================================================================================================
IF OBJECT_ID(N'clinical.Medication', N'U') IS NULL BEGIN
    PRINT N'clinical.Medication - Creating';

    CREATE TABLE clinical.Medication (
          ID                  INT                 NOT NULL     IDENTITY(0, 1)
        , ID_Patient          INT                 NOT NULL     CONSTRAINT df_clinical_medication_ID_Patient     DEFAULT(0)  --from clinical.Patient
        , ID_Encounter        INT                 NOT NULL     CONSTRAINT df_clinical_medication_ID_Encounter   DEFAULT(0)  --from clinical.Encounter
        , ID_Payer            INT                 NOT NULL     CONSTRAINT df_clinical_medication_ID_Payer       DEFAULT(0)  --from ref.Payer
        , ID_Code             INT                 NOT NULL     CONSTRAINT df_clinical_medication_ID_Code        DEFAULT(0)  --from ref.Code (RxNorm)
        , ID_ReasonCode       INT                 NOT NULL     CONSTRAINT df_clinical_medication_ID_ReasonCode  DEFAULT(0)  --from ref.Code (reason)

        --------------------------------------------------------------------------------
        , StartDate           DATETIME2(0)        NOT NULL     CONSTRAINT df_clinical_medication_StartDate      DEFAULT('1900-01-01')
        , StopDate            DATETIME2(0)        NULL
        , Occurrence          INT                 NOT NULL     CONSTRAINT df_clinical_medication_Occurrence     DEFAULT(1)
        , BaseCost            DECIMAL(14, 2)      NOT NULL     CONSTRAINT df_clinical_medication_BaseCost       DEFAULT(0)
        , PayerCoverage       DECIMAL(14, 2)      NOT NULL     CONSTRAINT df_clinical_medication_PayerCoverage  DEFAULT(0)
        , Dispenses           INT                 NOT NULL     CONSTRAINT df_clinical_medication_Dispenses      DEFAULT(0)
        , TotalCost           DECIMAL(14, 2)      NOT NULL     CONSTRAINT df_clinical_medication_TotalCost      DEFAULT(0)

        --------------------------------------------------------------------------------
        -- Standard Fields
        --------------------------------------------------------------------------------
        , Deleted             BIT                 NOT NULL     CONSTRAINT df_clinical_medication_Deleted        DEFAULT(0)
        , ID_CreatedBy        INT                 NOT NULL     CONSTRAINT df_clinical_medication_ID_CreatedBy   DEFAULT(1)
        , CreatedDate         DATETIME2           NOT NULL     CONSTRAINT df_clinical_medication_CreatedDate    DEFAULT(SYSUTCDATETIME())
        , ID_UpdatedBy        INT                 NOT NULL     CONSTRAINT df_clinical_medication_ID_UpdatedBy   DEFAULT(0)
        , UpdatedDate         DATETIME2           NULL

        , CONSTRAINT pk_clinical_medication_ID PRIMARY KEY CLUSTERED (ID)
    );

    SET IDENTITY_INSERT clinical.Medication ON;
    INSERT INTO clinical.Medication (ID) VALUES (0);
    SET IDENTITY_INSERT clinical.Medication OFF;

    CREATE UNIQUE NONCLUSTERED INDEX UX_Medication_NaturalKey ON clinical.Medication (ID_Encounter, ID_Code, StartDate, Occurrence) WHERE ID > 0;
    CREATE NONCLUSTERED INDEX IX_Medication_ID_Patient ON clinical.Medication (ID_Patient);
    CREATE NONCLUSTERED INDEX IX_Medication_ID_Payer ON clinical.Medication (ID_Payer);
    CREATE NONCLUSTERED INDEX IX_Medication_ID_Code ON clinical.Medication (ID_Code);

    ALTER TABLE clinical.Medication ADD CONSTRAINT fk_clinical_medication_ID_Patient    FOREIGN KEY (ID_Patient)    REFERENCES clinical.Patient(ID);
    ALTER TABLE clinical.Medication ADD CONSTRAINT fk_clinical_medication_ID_Encounter  FOREIGN KEY (ID_Encounter)  REFERENCES clinical.Encounter(ID);
    ALTER TABLE clinical.Medication ADD CONSTRAINT fk_clinical_medication_ID_Payer      FOREIGN KEY (ID_Payer)      REFERENCES ref.Payer(ID);
    ALTER TABLE clinical.Medication ADD CONSTRAINT fk_clinical_medication_ID_Code       FOREIGN KEY (ID_Code)       REFERENCES ref.Code(ID);
    ALTER TABLE clinical.Medication ADD CONSTRAINT fk_clinical_medication_ID_ReasonCode FOREIGN KEY (ID_ReasonCode) REFERENCES ref.Code(ID);
    ALTER TABLE clinical.Medication ADD CONSTRAINT fk_clinical_medication_ID_CreatedBy  FOREIGN KEY (ID_CreatedBy)  REFERENCES security.[User](ID);
    ALTER TABLE clinical.Medication ADD CONSTRAINT fk_clinical_medication_ID_UpdatedBy  FOREIGN KEY (ID_UpdatedBy)  REFERENCES security.[User](ID);
END
GO

PRINT N'clinical.Medication - Script Done';
GO