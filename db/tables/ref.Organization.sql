--=====================================================================================================
--                                        ref.Organization Table
--=====================================================================================================
-- Purpose:  Healthcare organizations (hospitals, clinics). Master data only; revenue and
--           utilization totals are computed in gold.
--=====================================================================================================
IF OBJECT_ID(N'ref.Organization', N'U') IS NULL BEGIN
    PRINT N'ref.Organization - Creating';

    CREATE TABLE ref.Organization (
          ID                  INT                 NOT NULL     IDENTITY(0, 1)
        , ID_Location         INT                 NOT NULL     CONSTRAINT df_ref_organization_ID_Location   DEFAULT(0)  --from ref.Location (city)

        --------------------------------------------------------------------------------
        , SourceKey           UNIQUEIDENTIFIER    NOT NULL     CONSTRAINT df_ref_organization_SourceKey     DEFAULT('00000000-0000-0000-0000-000000000000')
        , Name                NVARCHAR(255)       NOT NULL     CONSTRAINT df_ref_organization_Name          DEFAULT('')
        , Address             NVARCHAR(255)       NOT NULL     CONSTRAINT df_ref_organization_Address       DEFAULT('')
        , Zip                 NVARCHAR(10)        NOT NULL     CONSTRAINT df_ref_organization_Zip           DEFAULT('')
        , Latitude            DECIMAL(9, 6)       NOT NULL     CONSTRAINT df_ref_organization_Latitude      DEFAULT(0)
        , Longitude           DECIMAL(9, 6)       NOT NULL     CONSTRAINT df_ref_organization_Longitude     DEFAULT(0)
        , Phone               NVARCHAR(30)        NOT NULL     CONSTRAINT df_ref_organization_Phone         DEFAULT('')
        , NPI                 NVARCHAR(20)        NOT NULL     CONSTRAINT df_ref_organization_NPI           DEFAULT('')
        , DisplayOrder        INT                 NOT NULL     CONSTRAINT df_ref_organization_DisplayOrder  DEFAULT(100)

        --------------------------------------------------------------------------------
        -- Standard Fields
        --------------------------------------------------------------------------------
        , Deleted             BIT                 NOT NULL     CONSTRAINT df_ref_organization_Deleted       DEFAULT(0)
        , ID_CreatedBy        INT                 NOT NULL     CONSTRAINT df_ref_organization_ID_CreatedBy  DEFAULT(1)
        , CreatedDate         DATETIME2           NOT NULL     CONSTRAINT df_ref_organization_CreatedDate   DEFAULT(SYSUTCDATETIME())
        , ID_UpdatedBy        INT                 NOT NULL     CONSTRAINT df_ref_organization_ID_UpdatedBy  DEFAULT(0)
        , UpdatedDate         DATETIME2           NULL

        , CONSTRAINT pk_ref_organization_ID PRIMARY KEY CLUSTERED (ID)
    );

    -- Placeholder row
    SET IDENTITY_INSERT ref.Organization ON;
    INSERT INTO ref.Organization (ID, Name) VALUES (0, N'(None)');
    SET IDENTITY_INSERT ref.Organization OFF;

    -- Indexes
    CREATE UNIQUE NONCLUSTERED INDEX UX_Organization_SourceKey ON ref.Organization (SourceKey) WHERE ID > 0;
    CREATE NONCLUSTERED INDEX IX_Organization_ID_Location ON ref.Organization (ID_Location);

    -- Foreign keys
    ALTER TABLE ref.Organization ADD CONSTRAINT fk_ref_organization_ID_Location  FOREIGN KEY (ID_Location)  REFERENCES ref.Location(ID);
    ALTER TABLE ref.Organization ADD CONSTRAINT fk_ref_organization_ID_CreatedBy FOREIGN KEY (ID_CreatedBy) REFERENCES security.[User](ID);
    ALTER TABLE ref.Organization ADD CONSTRAINT fk_ref_organization_ID_UpdatedBy FOREIGN KEY (ID_UpdatedBy) REFERENCES security.[User](ID);
END
GO

PRINT N'ref.Organization - Script Done';
GO