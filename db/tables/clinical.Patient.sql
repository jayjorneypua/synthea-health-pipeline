--=====================================================================================================
--                                        clinical.Patient Table
--=====================================================================================================
-- Purpose:  Patients. SSN, driver's license and passport are deliberately not stored (data
--           minimization). PII columns use Dynamic Data Masking; only roles with UNMASK see values.
--=====================================================================================================
IF OBJECT_ID(N'clinical.Patient', N'U') IS NULL BEGIN
    PRINT N'clinical.Patient - Creating';

    CREATE TABLE clinical.Patient (
          ID                  INT                 NOT NULL     IDENTITY(0, 1)
        , ID_Location         INT                 NOT NULL     CONSTRAINT df_clinical_patient_ID_Location    DEFAULT(0)  --from ref.Location (city)

        --------------------------------------------------------------------------------
        , SourceKey           UNIQUEIDENTIFIER    NOT NULL     CONSTRAINT df_clinical_patient_SourceKey      DEFAULT('00000000-0000-0000-0000-000000000000')
        , Prefix              NVARCHAR(10)        NOT NULL     CONSTRAINT df_clinical_patient_Prefix         DEFAULT('')
        , FirstName           NVARCHAR(100)       MASKED WITH (FUNCTION = 'partial(1,"xxxx",0)')  NOT NULL     CONSTRAINT df_clinical_patient_FirstName      DEFAULT('')
        , MiddleName          NVARCHAR(100)       MASKED WITH (FUNCTION = 'partial(1,"xxxx",0)')  NOT NULL     CONSTRAINT df_clinical_patient_MiddleName     DEFAULT('')
        , LastName            NVARCHAR(100)       MASKED WITH (FUNCTION = 'partial(1,"xxxx",0)')  NOT NULL     CONSTRAINT df_clinical_patient_LastName       DEFAULT('')
        , Suffix              NVARCHAR(10)        NOT NULL     CONSTRAINT df_clinical_patient_Suffix         DEFAULT('')
        , MaidenName          NVARCHAR(100)       MASKED WITH (FUNCTION = 'partial(1,"xxxx",0)')  NOT NULL     CONSTRAINT df_clinical_patient_MaidenName     DEFAULT('')
        , MaritalStatus       NVARCHAR(10)        NOT NULL     CONSTRAINT df_clinical_patient_MaritalStatus  DEFAULT('')
        , Race                NVARCHAR(50)        NOT NULL     CONSTRAINT df_clinical_patient_Race           DEFAULT('')
        , Ethnicity           NVARCHAR(50)        NOT NULL     CONSTRAINT df_clinical_patient_Ethnicity      DEFAULT('')
        , Gender              NVARCHAR(10)        NOT NULL     CONSTRAINT df_clinical_patient_Gender         DEFAULT('')
        , BirthPlace          NVARCHAR(255)       NOT NULL     CONSTRAINT df_clinical_patient_BirthPlace     DEFAULT('')
        , Address             NVARCHAR(255)       MASKED WITH (FUNCTION = 'default()')            NOT NULL     CONSTRAINT df_clinical_patient_Address        DEFAULT('')
        , Zip                 NVARCHAR(10)        MASKED WITH (FUNCTION = 'partial(3,"xx",0)')    NOT NULL     CONSTRAINT df_clinical_patient_Zip            DEFAULT('')
        , Latitude            DECIMAL(9, 6)       MASKED WITH (FUNCTION = 'default()')            NOT NULL     CONSTRAINT df_clinical_patient_Latitude       DEFAULT(0)
        , Longitude           DECIMAL(9, 6)       MASKED WITH (FUNCTION = 'default()')            NOT NULL     CONSTRAINT df_clinical_patient_Longitude      DEFAULT(0)
        , BirthDate           DATE                MASKED WITH (FUNCTION = 'default()')            NOT NULL     CONSTRAINT df_clinical_patient_BirthDate      DEFAULT('1900-01-01')
        , DeathDate           DATE                NULL
        , Income              DECIMAL(12, 2)      NOT NULL     CONSTRAINT df_clinical_patient_Income         DEFAULT(0)

        --------------------------------------------------------------------------------
        -- Standard Fields
        --------------------------------------------------------------------------------
        , Deleted             BIT                 NOT NULL     CONSTRAINT df_clinical_patient_Deleted        DEFAULT(0)
        , ID_CreatedBy        INT                 NOT NULL     CONSTRAINT df_clinical_patient_ID_CreatedBy   DEFAULT(1)
        , CreatedDate         DATETIME2           NOT NULL     CONSTRAINT df_clinical_patient_CreatedDate    DEFAULT(SYSUTCDATETIME())
        , ID_UpdatedBy        INT                 NOT NULL     CONSTRAINT df_clinical_patient_ID_UpdatedBy   DEFAULT(0)
        , UpdatedDate         DATETIME2           NULL

        , CONSTRAINT pk_clinical_patient_ID PRIMARY KEY CLUSTERED (ID)
    );

    SET IDENTITY_INSERT clinical.Patient ON;
    INSERT INTO clinical.Patient (ID, FirstName, LastName) VALUES (0, N'', N'(None)');
    SET IDENTITY_INSERT clinical.Patient OFF;

    CREATE UNIQUE NONCLUSTERED INDEX UX_Patient_SourceKey ON clinical.Patient (SourceKey) WHERE ID > 0;
    CREATE NONCLUSTERED INDEX IX_Patient_ID_Location ON clinical.Patient (ID_Location);

    ALTER TABLE clinical.Patient ADD CONSTRAINT fk_clinical_patient_ID_Location  FOREIGN KEY (ID_Location)  REFERENCES ref.Location(ID);
    ALTER TABLE clinical.Patient ADD CONSTRAINT fk_clinical_patient_ID_CreatedBy FOREIGN KEY (ID_CreatedBy) REFERENCES security.[User](ID);
    ALTER TABLE clinical.Patient ADD CONSTRAINT fk_clinical_patient_ID_UpdatedBy FOREIGN KEY (ID_UpdatedBy) REFERENCES security.[User](ID);
END
GO

PRINT N'clinical.Patient - Script Done';
GO