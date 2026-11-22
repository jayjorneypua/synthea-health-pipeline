--=====================================================================================================
--                          stage.spMerge_Organization Stored Procedure
--=====================================================================================================
-- Purpose:  stage.Organization -> ref.Organization. Updates only changed rows, inserts new rows.
--=====================================================================================================
PRINT N'stage.spMerge_Organization - Creating';
GO

CREATE OR ALTER PROCEDURE stage.spMerge_Organization
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
          TRY_CONVERT(UNIQUEIDENTIFIER, TRIM(organization.[Id]))          AS SourceKey
        , ISNULL(cityLookup.ID_City, 0)                                    AS ID_Location
        , LEFT(ISNULL(TRIM(organization.[NAME]), N''), 255)                AS Name
        , LEFT(ISNULL(TRIM(organization.[ADDRESS]), N''), 255)             AS Address
        , LEFT(ISNULL(TRIM(organization.ZIP), N''), 10)                    AS Zip
        , ISNULL(TRY_CONVERT(DECIMAL(9, 6), organization.LAT), 0)          AS Latitude
        , ISNULL(TRY_CONVERT(DECIMAL(9, 6), organization.LON), 0)          AS Longitude
        , LEFT(ISNULL(TRIM(organization.PHONE), N''), 30)                  AS Phone
        , LEFT(ISNULL(TRIM(organization.NPI), N''), 20)                    AS NPI
        , ROW_NUMBER() OVER (PARTITION BY TRIM(organization.[Id]) ORDER BY organization.StageID DESC) AS RowNumber
    INTO
        #Source
    FROM
        stage.Organization organization
        LEFT JOIN stage.vwCityLookup cityLookup
            ON cityLookup.CityName = TRIM(organization.CITY)
            AND cityLookup.StateCode = TRIM(organization.[STATE]);

    DELETE FROM #Source WHERE RowNumber > 1 OR SourceKey IS NULL;

    BEGIN TRANSACTION;

    --------------------------------------------------------------------------------
    -- Step 2: Update changed rows
    --------------------------------------------------------------------------------
    UPDATE target
    SET
          target.ID_Location  = source.ID_Location
        , target.Name         = source.Name
        , target.Address      = source.Address
        , target.Zip          = source.Zip
        , target.Latitude     = source.Latitude
        , target.Longitude    = source.Longitude
        , target.Phone        = source.Phone
        , target.NPI          = source.NPI
        , target.Deleted      = 0
        , target.ID_UpdatedBy = 1
        , target.UpdatedDate  = SYSUTCDATETIME()
    FROM
        ref.Organization target
        INNER JOIN #Source source
            ON source.SourceKey = target.SourceKey
    WHERE
        target.ID > 0
        AND EXISTS (
            SELECT target.ID_Location, target.Name, target.Address, target.Zip, target.Latitude, target.Longitude, target.Phone, target.NPI, target.Deleted
            EXCEPT
            SELECT source.ID_Location, source.Name, source.Address, source.Zip, source.Latitude, source.Longitude, source.Phone, source.NPI, CAST(0 AS BIT)
        );
    SET @Updated = @@ROWCOUNT;

    --------------------------------------------------------------------------------
    -- Step 3: Insert new rows
    --------------------------------------------------------------------------------
    INSERT INTO ref.Organization (SourceKey, ID_Location, Name, Address, Zip, Latitude, Longitude, Phone, NPI)
    SELECT
          source.SourceKey
        , source.ID_Location
        , source.Name
        , source.Address
        , source.Zip
        , source.Latitude
        , source.Longitude
        , source.Phone
        , source.NPI
    FROM
        #Source source
    WHERE
        NOT EXISTS (SELECT 1 FROM ref.Organization target WHERE target.SourceKey = source.SourceKey AND target.ID > 0);
    SET @Inserted = @@ROWCOUNT;

    COMMIT TRANSACTION;

    PRINT CONCAT(N'stage.spMerge_Organization: inserted ', @Inserted, N', updated ', @Updated);
END
GO

PRINT N'stage.spMerge_Organization - Script Done';
GO