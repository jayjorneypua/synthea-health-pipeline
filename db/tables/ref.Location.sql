--=====================================================================================================
--                                        ref.Location Table
--=====================================================================================================
-- Purpose:  Location hierarchy: State > County > City. ID 0 is the root.
--           Path = comma list of IDs from the root (e.g. 0,5,12,40). Maintained by
--           ref.spLocation_UpdateHierarchy.
--=====================================================================================================
IF OBJECT_ID(N'ref.Location', N'U') IS NULL BEGIN
    PRINT N'ref.Location - Creating';

    CREATE TABLE ref.Location (
          ID                  INT                 NOT NULL     IDENTITY(0, 1)
        , ID_Parent           INT                 NOT NULL     CONSTRAINT df_ref_location_ID_Parent     DEFAULT(0)  --from ref.Location (self reference)

        --------------------------------------------------------------------------------
        , Name                NVARCHAR(255)       NOT NULL     CONSTRAINT df_ref_location_Name          DEFAULT('')
        , LocationType        NVARCHAR(20)        NOT NULL     CONSTRAINT df_ref_location_LocationType  DEFAULT('')  --Root, State, County, City
        , Code                NVARCHAR(20)        NOT NULL     CONSTRAINT df_ref_location_Code          DEFAULT('')  --e.g. county FIPS
        , Path                NVARCHAR(255)       NOT NULL     CONSTRAINT df_ref_location_Path          DEFAULT('0')
        , Level               INT                 NOT NULL     CONSTRAINT df_ref_location_Level         DEFAULT(0)
        , HasChildren         BIT                 NOT NULL     CONSTRAINT df_ref_location_HasChildren   DEFAULT(0)
        , DisplayOrder        INT                 NOT NULL     CONSTRAINT df_ref_location_DisplayOrder  DEFAULT(100)

        --------------------------------------------------------------------------------
        -- Standard Fields
        --------------------------------------------------------------------------------
        , Deleted             BIT                 NOT NULL     CONSTRAINT df_ref_location_Deleted       DEFAULT(0)
        , ID_CreatedBy        INT                 NOT NULL     CONSTRAINT df_ref_location_ID_CreatedBy  DEFAULT(1)
        , CreatedDate         DATETIME2           NOT NULL     CONSTRAINT df_ref_location_CreatedDate   DEFAULT(SYSUTCDATETIME())
        , ID_UpdatedBy        INT                 NOT NULL     CONSTRAINT df_ref_location_ID_UpdatedBy  DEFAULT(0)
        , UpdatedDate         DATETIME2           NULL

        , CONSTRAINT pk_ref_location_ID PRIMARY KEY CLUSTERED (ID)
    );

    -- Root row
    SET IDENTITY_INSERT ref.Location ON;
    INSERT INTO ref.Location (ID, ID_Parent, Name, LocationType, Path, Level) VALUES (0, 0, N'(Location Collection)', N'Root', N'0', 0);
    SET IDENTITY_INSERT ref.Location OFF;

    -- Indexes
    CREATE NONCLUSTERED INDEX IX_Location_ID_Parent ON ref.Location (ID_Parent);
    CREATE UNIQUE NONCLUSTERED INDEX UX_Location_Parent_Type_Name ON ref.Location (ID_Parent, LocationType, Name) WHERE Deleted = 0;

    -- Foreign keys
    ALTER TABLE ref.Location ADD CONSTRAINT fk_ref_location_ID_Parent    FOREIGN KEY (ID_Parent)    REFERENCES ref.Location(ID);
    ALTER TABLE ref.Location ADD CONSTRAINT fk_ref_location_ID_CreatedBy FOREIGN KEY (ID_CreatedBy) REFERENCES security.[User](ID);
    ALTER TABLE ref.Location ADD CONSTRAINT fk_ref_location_ID_UpdatedBy FOREIGN KEY (ID_UpdatedBy) REFERENCES security.[User](ID);
END
GO

PRINT N'ref.Location - Script Done';
GO