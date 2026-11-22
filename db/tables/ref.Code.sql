--=====================================================================================================
--                                        ref.Code Table
--=====================================================================================================
-- Purpose:  Clinical terminology lookup (SNOMED-CT, LOINC, RxNorm, CVX). One row per
--           CodeSystem + Code. Clinical tables reference ID_Code instead of repeating text.
--=====================================================================================================
IF OBJECT_ID(N'ref.Code', N'U') IS NULL BEGIN
    PRINT N'ref.Code - Creating';

    CREATE TABLE ref.Code (
          ID                  INT                 NOT NULL     IDENTITY(0, 1)

        --------------------------------------------------------------------------------
        , CodeSystem          NVARCHAR(20)        NOT NULL     CONSTRAINT df_ref_code_CodeSystem    DEFAULT('')  --SNOMED-CT, LOINC, RxNorm, CVX
        , Code                NVARCHAR(50)        NOT NULL     CONSTRAINT df_ref_code_Code          DEFAULT('')
        , Description         NVARCHAR(1000)      NOT NULL     CONSTRAINT df_ref_code_Description   DEFAULT('')
        , DisplayOrder        INT                 NOT NULL     CONSTRAINT df_ref_code_DisplayOrder  DEFAULT(100)

        --------------------------------------------------------------------------------
        -- Standard Fields
        --------------------------------------------------------------------------------
        , Deleted             BIT                 NOT NULL     CONSTRAINT df_ref_code_Deleted       DEFAULT(0)
        , ID_CreatedBy        INT                 NOT NULL     CONSTRAINT df_ref_code_ID_CreatedBy  DEFAULT(1)
        , CreatedDate         DATETIME2           NOT NULL     CONSTRAINT df_ref_code_CreatedDate   DEFAULT(SYSUTCDATETIME())
        , ID_UpdatedBy        INT                 NOT NULL     CONSTRAINT df_ref_code_ID_UpdatedBy  DEFAULT(0)
        , UpdatedDate         DATETIME2           NULL

        , CONSTRAINT pk_ref_code_ID PRIMARY KEY CLUSTERED (ID)
    );

    -- Placeholder row
    SET IDENTITY_INSERT ref.Code ON;
    INSERT INTO ref.Code (ID, CodeSystem, Code, Description) VALUES (0, N'', N'', N'(None)');
    SET IDENTITY_INSERT ref.Code OFF;

    -- Indexes
    CREATE UNIQUE NONCLUSTERED INDEX UX_Code_CodeSystem_Code ON ref.Code (CodeSystem, Code) WHERE ID > 0;

    -- Foreign keys
    ALTER TABLE ref.Code ADD CONSTRAINT fk_ref_code_ID_CreatedBy FOREIGN KEY (ID_CreatedBy) REFERENCES security.[User](ID);
    ALTER TABLE ref.Code ADD CONSTRAINT fk_ref_code_ID_UpdatedBy FOREIGN KEY (ID_UpdatedBy) REFERENCES security.[User](ID);
END
GO

PRINT N'ref.Code - Script Done';
GO