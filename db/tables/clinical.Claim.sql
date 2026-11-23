--=====================================================================================================
--                                        clinical.Claim Table
--=====================================================================================================
-- Purpose:  Billing claim per encounter or medication. Status, outstanding and last billed come in
--           three sets: Primary (primary insurance), Secondary (secondary insurance), Patient. Dates are UTC.
--=====================================================================================================
IF OBJECT_ID(N'clinical.Claim', N'U') IS NULL BEGIN
    PRINT N'clinical.Claim - Creating';

    CREATE TABLE clinical.Claim (
          ID                       INT                 NOT NULL     IDENTITY(0, 1)
        , ID_Patient               INT                 NOT NULL     CONSTRAINT df_clinical_claim_ID_Patient              DEFAULT(0)  --from clinical.Patient
        , ID_Provider              INT                 NOT NULL     CONSTRAINT df_clinical_claim_ID_Provider             DEFAULT(0)  --from ref.Provider
        , ID_Encounter             INT                 NOT NULL     CONSTRAINT df_clinical_claim_ID_Encounter            DEFAULT(0)  --from clinical.Encounter
        , ID_DiagnosisCode         INT                 NOT NULL     CONSTRAINT df_clinical_claim_ID_DiagnosisCode        DEFAULT(0)  --from ref.Code (primary diagnosis)

        --------------------------------------------------------------------------------
        , SourceKey                UNIQUEIDENTIFIER    NOT NULL     CONSTRAINT df_clinical_claim_SourceKey               DEFAULT('00000000-0000-0000-0000-000000000000')
        , ServiceDate              DATETIME2(0)        NOT NULL     CONSTRAINT df_clinical_claim_ServiceDate             DEFAULT('1900-01-01')
        , CurrentIllnessDate       DATETIME2(0)        NULL
        , PrimaryStatus            NVARCHAR(20)        NOT NULL     CONSTRAINT df_clinical_claim_PrimaryStatus           DEFAULT('')
        , SecondaryStatus          NVARCHAR(20)        NOT NULL     CONSTRAINT df_clinical_claim_SecondaryStatus         DEFAULT('')
        , PatientStatus            NVARCHAR(20)        NOT NULL     CONSTRAINT df_clinical_claim_PatientStatus           DEFAULT('')
        , PrimaryOutstanding       DECIMAL(14, 2)      NOT NULL     CONSTRAINT df_clinical_claim_PrimaryOutstanding      DEFAULT(0)
        , SecondaryOutstanding     DECIMAL(14, 2)      NOT NULL     CONSTRAINT df_clinical_claim_SecondaryOutstanding    DEFAULT(0)
        , PatientOutstanding       DECIMAL(14, 2)      NOT NULL     CONSTRAINT df_clinical_claim_PatientOutstanding      DEFAULT(0)
        , PrimaryLastBilledDate    DATETIME2(0)        NULL
        , SecondaryLastBilledDate  DATETIME2(0)        NULL
        , PatientLastBilledDate    DATETIME2(0)        NULL
        , PrimaryClaimType         TINYINT             NOT NULL     CONSTRAINT df_clinical_claim_PrimaryClaimType        DEFAULT(0)  --1 professional, 2 institutional
        , SecondaryClaimType       TINYINT             NOT NULL     CONSTRAINT df_clinical_claim_SecondaryClaimType      DEFAULT(0)

        --------------------------------------------------------------------------------
        -- Standard Fields
        --------------------------------------------------------------------------------
        , Deleted                  BIT                 NOT NULL     CONSTRAINT df_clinical_claim_Deleted                 DEFAULT(0)
        , ID_CreatedBy             INT                 NOT NULL     CONSTRAINT df_clinical_claim_ID_CreatedBy            DEFAULT(1)
        , CreatedDate              DATETIME2           NOT NULL     CONSTRAINT df_clinical_claim_CreatedDate             DEFAULT(SYSUTCDATETIME())
        , ID_UpdatedBy             INT                 NOT NULL     CONSTRAINT df_clinical_claim_ID_UpdatedBy            DEFAULT(0)
        , UpdatedDate              DATETIME2           NULL

        , CONSTRAINT pk_clinical_claim_ID PRIMARY KEY CLUSTERED (ID)
    );

    SET IDENTITY_INSERT clinical.Claim ON;
    INSERT INTO clinical.Claim (ID, PrimaryStatus) VALUES (0, N'(None)');
    SET IDENTITY_INSERT clinical.Claim OFF;

    CREATE UNIQUE NONCLUSTERED INDEX UX_Claim_SourceKey ON clinical.Claim (SourceKey) WHERE ID > 0;
    CREATE NONCLUSTERED INDEX IX_Claim_ID_Patient ON clinical.Claim (ID_Patient, ServiceDate);
    CREATE NONCLUSTERED INDEX IX_Claim_ID_Encounter ON clinical.Claim (ID_Encounter);
    CREATE NONCLUSTERED INDEX IX_Claim_ID_Provider ON clinical.Claim (ID_Provider);

    ALTER TABLE clinical.Claim ADD CONSTRAINT fk_clinical_claim_ID_Patient       FOREIGN KEY (ID_Patient)       REFERENCES clinical.Patient(ID);
    ALTER TABLE clinical.Claim ADD CONSTRAINT fk_clinical_claim_ID_Provider      FOREIGN KEY (ID_Provider)      REFERENCES ref.Provider(ID);
    ALTER TABLE clinical.Claim ADD CONSTRAINT fk_clinical_claim_ID_Encounter     FOREIGN KEY (ID_Encounter)     REFERENCES clinical.Encounter(ID);
    ALTER TABLE clinical.Claim ADD CONSTRAINT fk_clinical_claim_ID_DiagnosisCode FOREIGN KEY (ID_DiagnosisCode) REFERENCES ref.Code(ID);
    ALTER TABLE clinical.Claim ADD CONSTRAINT fk_clinical_claim_ID_CreatedBy     FOREIGN KEY (ID_CreatedBy)     REFERENCES security.[User](ID);
    ALTER TABLE clinical.Claim ADD CONSTRAINT fk_clinical_claim_ID_UpdatedBy     FOREIGN KEY (ID_UpdatedBy)     REFERENCES security.[User](ID);
END
GO

PRINT N'clinical.Claim - Script Done';
GO