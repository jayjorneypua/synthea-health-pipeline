--=====================================================================================================
--                                        Stage Tables
--=====================================================================================================
-- Purpose:  Landing tables for the Synthea CSV files. All columns are raw text named exactly like
--           the CSV headers; the merge procs convert types. SSN, driver's license and passport have
--           no column here, so they never enter the database. Safe to drop: no permanent data.
--=====================================================================================================

------------------------------------------------------------------------------------
-- stage.Payer
------------------------------------------------------------------------------------
IF OBJECT_ID(N'stage.Payer', N'U') IS NOT NULL BEGIN
    PRINT N'stage.Payer - Dropping';
    DROP TABLE stage.Payer;
END
GO

PRINT N'stage.Payer - Creating';
CREATE TABLE stage.Payer (
      StageID                 INT                 NOT NULL     IDENTITY(1, 1)
    , [Id]                    NVARCHAR(100)       NULL
    , [NAME]                  NVARCHAR(255)       NULL
    , [OWNERSHIP]             NVARCHAR(50)        NULL
    , [ADDRESS]               NVARCHAR(255)       NULL
    , [CITY]                  NVARCHAR(255)       NULL
    , [STATE_HEADQUARTERED]   NVARCHAR(100)       NULL
    , [ZIP]                   NVARCHAR(20)        NULL
    , [PHONE]                 NVARCHAR(50)        NULL
    , CONSTRAINT pk_stage_payer_StageID PRIMARY KEY CLUSTERED (StageID)
);
GO

------------------------------------------------------------------------------------
-- stage.Organization
------------------------------------------------------------------------------------
IF OBJECT_ID(N'stage.Organization', N'U') IS NOT NULL BEGIN
    PRINT N'stage.Organization - Dropping';
    DROP TABLE stage.Organization;
END
GO

PRINT N'stage.Organization - Creating';
CREATE TABLE stage.Organization (
      StageID                 INT                 NOT NULL     IDENTITY(1, 1)
    , [Id]                    NVARCHAR(100)       NULL
    , [NAME]                  NVARCHAR(255)       NULL
    , [ADDRESS]               NVARCHAR(255)       NULL
    , [CITY]                  NVARCHAR(255)       NULL
    , [STATE]                 NVARCHAR(100)       NULL
    , [ZIP]                   NVARCHAR(20)        NULL
    , [LAT]                   NVARCHAR(50)        NULL
    , [LON]                   NVARCHAR(50)        NULL
    , [PHONE]                 NVARCHAR(50)        NULL
    , [NPI]                   NVARCHAR(50)        NULL
    , CONSTRAINT pk_stage_organization_StageID PRIMARY KEY CLUSTERED (StageID)
);
GO

------------------------------------------------------------------------------------
-- stage.Provider
------------------------------------------------------------------------------------
IF OBJECT_ID(N'stage.Provider', N'U') IS NOT NULL BEGIN
    PRINT N'stage.Provider - Dropping';
    DROP TABLE stage.Provider;
END
GO

PRINT N'stage.Provider - Creating';
CREATE TABLE stage.Provider (
      StageID                 INT                 NOT NULL     IDENTITY(1, 1)
    , [Id]                    NVARCHAR(100)       NULL
    , [ORGANIZATION]          NVARCHAR(100)       NULL
    , [NAME]                  NVARCHAR(255)       NULL
    , [GENDER]                NVARCHAR(20)        NULL
    , [SPECIALITY]            NVARCHAR(100)       NULL
    , [ADDRESS]               NVARCHAR(255)       NULL
    , [CITY]                  NVARCHAR(255)       NULL
    , [STATE]                 NVARCHAR(100)       NULL
    , [ZIP]                   NVARCHAR(20)        NULL
    , [LAT]                   NVARCHAR(50)        NULL
    , [LON]                   NVARCHAR(50)        NULL
    , [NPI]                   NVARCHAR(50)        NULL
    , CONSTRAINT pk_stage_provider_StageID PRIMARY KEY CLUSTERED (StageID)
);
GO

------------------------------------------------------------------------------------
-- stage.Patient
------------------------------------------------------------------------------------
IF OBJECT_ID(N'stage.Patient', N'U') IS NOT NULL BEGIN
    PRINT N'stage.Patient - Dropping';
    DROP TABLE stage.Patient;
END
GO

PRINT N'stage.Patient - Creating';
CREATE TABLE stage.Patient (
      StageID                 INT                 NOT NULL     IDENTITY(1, 1)
    , [Id]                    NVARCHAR(100)       NULL
    , [BIRTHDATE]             NVARCHAR(50)        NULL
    , [DEATHDATE]             NVARCHAR(50)        NULL
    , [PREFIX]                NVARCHAR(20)        NULL
    , [FIRST]                 NVARCHAR(100)       NULL
    , [MIDDLE]                NVARCHAR(100)       NULL
    , [LAST]                  NVARCHAR(100)       NULL
    , [SUFFIX]                NVARCHAR(20)        NULL
    , [MAIDEN]                NVARCHAR(100)       NULL
    , [MARITAL]               NVARCHAR(20)        NULL
    , [RACE]                  NVARCHAR(50)        NULL
    , [ETHNICITY]             NVARCHAR(50)        NULL
    , [GENDER]                NVARCHAR(20)        NULL
    , [BIRTHPLACE]            NVARCHAR(255)       NULL
    , [ADDRESS]               NVARCHAR(255)       NULL
    , [CITY]                  NVARCHAR(255)       NULL
    , [STATE]                 NVARCHAR(100)       NULL
    , [COUNTY]                NVARCHAR(255)       NULL
    , [FIPS]                  NVARCHAR(20)        NULL
    , [ZIP]                   NVARCHAR(20)        NULL
    , [LAT]                   NVARCHAR(50)        NULL
    , [LON]                   NVARCHAR(50)        NULL
    , [INCOME]                NVARCHAR(50)        NULL
    , CONSTRAINT pk_stage_patient_StageID PRIMARY KEY CLUSTERED (StageID)
);
GO

------------------------------------------------------------------------------------
-- stage.Encounter
------------------------------------------------------------------------------------
IF OBJECT_ID(N'stage.Encounter', N'U') IS NOT NULL BEGIN
    PRINT N'stage.Encounter - Dropping';
    DROP TABLE stage.Encounter;
END
GO

PRINT N'stage.Encounter - Creating';
CREATE TABLE stage.Encounter (
      StageID                 INT                 NOT NULL     IDENTITY(1, 1)
    , [Id]                    NVARCHAR(100)       NULL
    , [START]                 NVARCHAR(50)        NULL
    , [STOP]                  NVARCHAR(50)        NULL
    , [PATIENT]               NVARCHAR(100)       NULL
    , [ORGANIZATION]          NVARCHAR(100)       NULL
    , [PROVIDER]              NVARCHAR(100)       NULL
    , [PAYER]                 NVARCHAR(100)       NULL
    , [ENCOUNTERCLASS]        NVARCHAR(50)        NULL
    , [CODE]                  NVARCHAR(50)        NULL
    , [DESCRIPTION]           NVARCHAR(1000)      NULL
    , [BASE_ENCOUNTER_COST]   NVARCHAR(50)        NULL
    , [TOTAL_CLAIM_COST]      NVARCHAR(50)        NULL
    , [PAYER_COVERAGE]        NVARCHAR(50)        NULL
    , [REASONCODE]            NVARCHAR(50)        NULL
    , [REASONDESCRIPTION]     NVARCHAR(1000)      NULL
    , CONSTRAINT pk_stage_encounter_StageID PRIMARY KEY CLUSTERED (StageID)
);
GO

------------------------------------------------------------------------------------
-- stage.Condition
------------------------------------------------------------------------------------
IF OBJECT_ID(N'stage.Condition', N'U') IS NOT NULL BEGIN
    PRINT N'stage.Condition - Dropping';
    DROP TABLE stage.Condition;
END
GO

PRINT N'stage.Condition - Creating';
CREATE TABLE stage.Condition (
      StageID                 INT                 NOT NULL     IDENTITY(1, 1)
    , [START]                 NVARCHAR(50)        NULL
    , [STOP]                  NVARCHAR(50)        NULL
    , [PATIENT]               NVARCHAR(100)       NULL
    , [ENCOUNTER]             NVARCHAR(100)       NULL
    , [SYSTEM]                NVARCHAR(100)       NULL
    , [CODE]                  NVARCHAR(50)        NULL
    , [DESCRIPTION]           NVARCHAR(1000)      NULL
    , CONSTRAINT pk_stage_condition_StageID PRIMARY KEY CLUSTERED (StageID)
);
GO

------------------------------------------------------------------------------------
-- stage.Medication
------------------------------------------------------------------------------------
IF OBJECT_ID(N'stage.Medication', N'U') IS NOT NULL BEGIN
    PRINT N'stage.Medication - Dropping';
    DROP TABLE stage.Medication;
END
GO

PRINT N'stage.Medication - Creating';
CREATE TABLE stage.Medication (
      StageID                 INT                 NOT NULL     IDENTITY(1, 1)
    , [START]                 NVARCHAR(50)        NULL
    , [STOP]                  NVARCHAR(50)        NULL
    , [PATIENT]               NVARCHAR(100)       NULL
    , [PAYER]                 NVARCHAR(100)       NULL
    , [ENCOUNTER]             NVARCHAR(100)       NULL
    , [CODE]                  NVARCHAR(50)        NULL
    , [DESCRIPTION]           NVARCHAR(1000)      NULL
    , [BASE_COST]             NVARCHAR(50)        NULL
    , [PAYER_COVERAGE]        NVARCHAR(50)        NULL
    , [DISPENSES]             NVARCHAR(50)        NULL
    , [TOTALCOST]             NVARCHAR(50)        NULL
    , [REASONCODE]            NVARCHAR(50)        NULL
    , [REASONDESCRIPTION]     NVARCHAR(1000)      NULL
    , CONSTRAINT pk_stage_medication_StageID PRIMARY KEY CLUSTERED (StageID)
);
GO

------------------------------------------------------------------------------------
-- stage.Procedure
------------------------------------------------------------------------------------
IF OBJECT_ID(N'stage.[Procedure]', N'U') IS NOT NULL BEGIN
    PRINT N'stage.Procedure - Dropping';
    DROP TABLE stage.[Procedure];
END
GO

PRINT N'stage.Procedure - Creating';
CREATE TABLE stage.[Procedure] (
      StageID                 INT                 NOT NULL     IDENTITY(1, 1)
    , [START]                 NVARCHAR(50)        NULL
    , [STOP]                  NVARCHAR(50)        NULL
    , [PATIENT]               NVARCHAR(100)       NULL
    , [ENCOUNTER]             NVARCHAR(100)       NULL
    , [SYSTEM]                NVARCHAR(100)       NULL
    , [CODE]                  NVARCHAR(50)        NULL
    , [DESCRIPTION]           NVARCHAR(1000)      NULL
    , [BASE_COST]             NVARCHAR(50)        NULL
    , [REASONCODE]            NVARCHAR(50)        NULL
    , [REASONDESCRIPTION]     NVARCHAR(1000)      NULL
    , CONSTRAINT pk_stage_procedure_StageID PRIMARY KEY CLUSTERED (StageID)
);
GO

PRINT N'Stage Tables - Script Done';
GO