--=====================================================================================================
--                          stage.spMerge_Provider Stored Procedure
--=====================================================================================================
-- Purpose:  stage.Provider -> ref.Provider. Run after spMerge_Organization (looks up ID_Organization).
--           Updates only changed rows, inserts new rows.
--=====================================================================================================
PRINT N'stage.spMerge_Provider - Creating';
GO

CREATE OR ALTER PROCEDURE stage.spMerge_Provider
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Updated INT;
    DECLARE @Inserted INT;

    --------------------------------------------------------------------------------
    -- Step 1: Typed source, last row per Id
    --------------------------------------------------------------------------------
    SELECT
          TRY_CONVERT(UNIQUEIDENTIFIER, TRIM(provider.[Id]))          AS SourceKey
        , ISNULL(organization.ID, 0)                                   AS ID_Organization
        , ISNULL(cityLookup.ID_City, 0)                                AS ID_Location
        , LEFT(ISNULL(TRIM(provider.[NAME]), N''), 255)                AS Name
        , LEFT(ISNULL(TRIM(provider.GENDER), N''), 10)                 AS Gender
        , LEFT(ISNULL(TRIM(provider.SPECIALITY), N''), 100)            AS Speciality
        , LEFT(ISNULL(TRIM(provider.[ADDRESS]), N''), 255)             AS Address
        , LEFT(ISNULL(TRIM(provider.ZIP), N''), 10)                    AS Zip
        , ISNULL(TRY_CONVERT(DECIMAL(9, 6), provider.LAT), 0)          AS Latitude
        , ISNULL(TRY_CONVERT(DECIMAL(9, 6), provider.LON), 0)          AS Longitude
        , LEFT(ISNULL(TRIM(provider.NPI), N''), 20)                    AS NPI
        , ROW_NUMBER() OVER (PARTITION BY TRIM(provider.[Id]) ORDER BY provider.StageID DESC) AS RowNumber
    INTO
        #Source
    FROM
        stage.Provider provider
        LEFT JOIN ref.Organization organization
            ON organization.SourceKey = TRY_CONVERT(UNIQUEIDENTIFIER, TRIM(provider.ORGANIZATION))
            AND organization.ID > 0
        LEFT JOIN stage.vwCityLookup cityLookup
            ON cityLookup.CityName = TRIM(provider.CITY)
            AND cityLookup.StateCode = TRIM(provider.[STATE]);

    DELETE FROM #Source WHERE RowNumber > 1 OR SourceKey IS NULL;

    BEGIN TRANSACTION;

    --------------------------------------------------------------------------------
    -- Step 2: Update changed rows
    --------------------------------------------------------------------------------
    UPDATE target
    SET
          target.ID_Organization = source.ID_Organization
        , target.ID_Location     = source.ID_Location
        , target.Name            = source.Name
        , target.Gender          = source.Gender
        , target.Speciality      = source.Speciality
        , target.Address         = source.Address
        , target.Zip             = source.Zip
        , target.Latitude        = source.Latitude
        , target.Longitude       = source.Longitude
        , target.NPI             = source.NPI
        , target.Deleted         = 0
        , target.ID_UpdatedBy    = 1
        , target.UpdatedDate     = SYSUTCDATETIME()
    FROM
        ref.Provider target
        INNER JOIN #Source source
            ON source.SourceKey = target.SourceKey
    WHERE
        target.ID > 0
        AND EXISTS (
            SELECT target.ID_Organization, target.ID_Location, target.Name, target.Gender, target.Speciality, target.Address, target.Zip, target.Latitude, target.Longitude, target.NPI, target.Deleted
            EXCEPT
            SELECT source.ID_Organization, source.ID_Location, source.Name, source.Gender, source.Speciality, source.Address, source.Zip, source.Latitude, source.Longitude, source.NPI, CAST(0 AS BIT)
        );
    SET @Updated = @@ROWCOUNT;

    --------------------------------------------------------------------------------
    -- Step 3: Insert new rows
    --------------------------------------------------------------------------------
    INSERT INTO ref.Provider (SourceKey, ID_Organization, ID_Location, Name, Gender, Speciality, Address, Zip, Latitude, Longitude, NPI)
    SELECT
          source.SourceKey
        , source.ID_Organization
        , source.ID_Location
        , source.Name
        , source.Gender
        , source.Speciality
        , source.Address
        , source.Zip
        , source.Latitude
        , source.Longitude
        , source.NPI
    FROM
        #Source source
    WHERE
        NOT EXISTS (SELECT 1 FROM ref.Provider target WHERE target.SourceKey = source.SourceKey AND target.ID > 0);
    SET @Inserted = @@ROWCOUNT;

    COMMIT TRANSACTION;

    PRINT CONCAT(N'stage.spMerge_Provider: inserted ', @Inserted, N', updated ', @Updated);
END
GO

PRINT N'stage.spMerge_Provider - Script Done';
GO