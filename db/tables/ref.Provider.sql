--=====================================================================================================
--                                        ref.Provider Table
--=====================================================================================================
-- Purpose:  Clinicians, each belonging to an organization. Encounter and procedure counts are
--           computed in gold.
--=====================================================================================================
IF OBJECT_ID(N'ref.Provider', N'U') IS NULL BEGIN
    PRINT N'ref.Provider - Creating';

    CREATE TABLE ref.Provider (
          ID                  INT                 NOT NULL     IDENTITY(0, 1)
        , ID_Organization     INT                 NOT NULL     CONSTRAINT df_ref_provider_ID_Organization  DEFAULT(0)  --from ref.Organization
        , ID_Location         INT                 NOT NULL     CONSTRAINT df_ref_provider_ID_Location      DEFAULT(0)  --from ref.Location (city)

        --------------------------------------------------------------------------------
        , SourceKey           UNIQUEIDENTIFIER    NOT NULL     CONSTRAINT df_ref_provider_SourceKey        DEFAULT('00000000-0000-0000-0000-000000000000')
        , Name                NVARCHAR(255)       NOT NULL     CONSTRAINT df_ref_provider_Name             DEFAULT('')
        , Gender              NVARCHAR(10)        NOT NULL     CONSTRAINT df_ref_provider_Gender           DEFAULT('')
        , Speciality          NVARCHAR(100)       NOT NULL     CONSTRAINT df_ref_provider_Speciality       DEFAULT('')
        , Address             NVARCHAR(255)       NOT NULL     CONSTRAINT df_ref_provider_Address          DEFAULT('')
        , Zip                 NVARCHAR(10)        NOT NULL     CONSTRAINT df_ref_provider_Zip              DEFAULT('')
        , Latitude            DECIMAL(9, 6)       NOT NULL     CONSTRAINT df_ref_provider_Latitude         DEFAULT(0)
        , Longitude           DECIMAL(9, 6)       NOT NULL     CONSTRAINT df_ref_provider_Longitude        DEFAULT(0)
        , NPI                 NVARCHAR(20)        NOT NULL     CONSTRAINT df_ref_provider_NPI              DEFAULT('')
        , DisplayOrder        INT                 NOT NULL     CONSTRAINT df_ref_provider_DisplayOrder     DEFAULT(100)

        --------------------------------------------------------------------------------
        -- Standard Fields
        --------------------------------------------------------------------------------
        , Deleted             BIT                 NOT NULL     CONSTRAINT df_ref_provider_Deleted          DEFAULT(0)
        , ID_CreatedBy        INT                 NOT NULL     CONSTRAINT df_ref_provider_ID_CreatedBy     DEFAULT(1)
        , CreatedDate         DATETIME2           NOT NULL     CONSTRAINT df_ref_provider_CreatedDate      DEFAULT(SYSUTCDATETIME())
        , ID_UpdatedBy        INT                 NOT NULL     CONSTRAINT df_ref_provider_ID_UpdatedBy     DEFAULT(0)
        , UpdatedDate         DATETIME2           NULL

        , CONSTRAINT pk_ref_provider_ID PRIMARY KEY CLUSTERED (ID)
    );

    SET IDENTITY_INSERT ref.Provider ON;
    INSERT INTO ref.Provider (ID, Name) VALUES (0, N'(None)');
    SET IDENTITY_INSERT ref.Provider OFF;

    CREATE UNIQUE NONCLUSTERED INDEX UX_Provider_SourceKey ON ref.Provider (SourceKey) WHERE ID > 0;
    CREATE NONCLUSTERED INDEX IX_Provider_ID_Organization ON ref.Provider (ID_Organization);
    CREATE NONCLUSTERED INDEX IX_Provider_ID_Location ON ref.Provider (ID_Location);

    ALTER TABLE ref.Provider ADD CONSTRAINT fk_ref_provider_ID_Organization FOREIGN KEY (ID_Organization) REFERENCES ref.Organization(ID);
    ALTER TABLE ref.Provider ADD CONSTRAINT fk_ref_provider_ID_Location     FOREIGN KEY (ID_Location)     REFERENCES ref.Location(ID);
    ALTER TABLE ref.Provider ADD CONSTRAINT fk_ref_provider_ID_CreatedBy    FOREIGN KEY (ID_CreatedBy)    REFERENCES security.[User](ID);
    ALTER TABLE ref.Provider ADD CONSTRAINT fk_ref_provider_ID_UpdatedBy    FOREIGN KEY (ID_UpdatedBy)    REFERENCES security.[User](ID);
END
GO

PRINT N'ref.Provider - Script Done';
GO