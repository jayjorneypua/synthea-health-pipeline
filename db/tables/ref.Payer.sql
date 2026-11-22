--=====================================================================================================
--                                        ref.Payer Table
--=====================================================================================================
-- Purpose:  Insurance payers. Master data only; coverage and revenue totals are computed in gold.
--=====================================================================================================
IF OBJECT_ID(N'ref.Payer', N'U') IS NULL BEGIN
    PRINT N'ref.Payer - Creating';

    CREATE TABLE ref.Payer (
          ID                  INT                 NOT NULL     IDENTITY(0, 1)
        , ID_Location         INT                 NOT NULL     CONSTRAINT df_ref_payer_ID_Location   DEFAULT(0)  --from ref.Location (city)

        --------------------------------------------------------------------------------
        , SourceKey           UNIQUEIDENTIFIER    NOT NULL     CONSTRAINT df_ref_payer_SourceKey     DEFAULT('00000000-0000-0000-0000-000000000000')
        , Name                NVARCHAR(255)       NOT NULL     CONSTRAINT df_ref_payer_Name          DEFAULT('')
        , Ownership           NVARCHAR(50)        NOT NULL     CONSTRAINT df_ref_payer_Ownership     DEFAULT('')
        , Address             NVARCHAR(255)       NOT NULL     CONSTRAINT df_ref_payer_Address       DEFAULT('')
        , Zip                 NVARCHAR(10)        NOT NULL     CONSTRAINT df_ref_payer_Zip           DEFAULT('')
        , Phone               NVARCHAR(30)        NOT NULL     CONSTRAINT df_ref_payer_Phone         DEFAULT('')
        , DisplayOrder        INT                 NOT NULL     CONSTRAINT df_ref_payer_DisplayOrder  DEFAULT(100)

        --------------------------------------------------------------------------------
        -- Standard Fields
        --------------------------------------------------------------------------------
        , Deleted             BIT                 NOT NULL     CONSTRAINT df_ref_payer_Deleted       DEFAULT(0)
        , ID_CreatedBy        INT                 NOT NULL     CONSTRAINT df_ref_payer_ID_CreatedBy  DEFAULT(1)
        , CreatedDate         DATETIME2           NOT NULL     CONSTRAINT df_ref_payer_CreatedDate   DEFAULT(SYSUTCDATETIME())
        , ID_UpdatedBy        INT                 NOT NULL     CONSTRAINT df_ref_payer_ID_UpdatedBy  DEFAULT(0)
        , UpdatedDate         DATETIME2           NULL

        , CONSTRAINT pk_ref_payer_ID PRIMARY KEY CLUSTERED (ID)
    );

    -- Placeholder row
    SET IDENTITY_INSERT ref.Payer ON;
    INSERT INTO ref.Payer (ID, Name) VALUES (0, N'(None)');
    SET IDENTITY_INSERT ref.Payer OFF;

    -- Indexes
    CREATE UNIQUE NONCLUSTERED INDEX UX_Payer_SourceKey ON ref.Payer (SourceKey) WHERE ID > 0;
    CREATE NONCLUSTERED INDEX IX_Payer_ID_Location ON ref.Payer (ID_Location);

    -- Foreign keys
    ALTER TABLE ref.Payer ADD CONSTRAINT fk_ref_payer_ID_Location  FOREIGN KEY (ID_Location)  REFERENCES ref.Location(ID);
    ALTER TABLE ref.Payer ADD CONSTRAINT fk_ref_payer_ID_CreatedBy FOREIGN KEY (ID_CreatedBy) REFERENCES security.[User](ID);
    ALTER TABLE ref.Payer ADD CONSTRAINT fk_ref_payer_ID_UpdatedBy FOREIGN KEY (ID_UpdatedBy) REFERENCES security.[User](ID);
END
GO

PRINT N'ref.Payer - Script Done';
GO