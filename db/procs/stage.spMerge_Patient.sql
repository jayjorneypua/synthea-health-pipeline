--=====================================================================================================
--                          stage.spMerge_Patient Stored Procedure
--=====================================================================================================
-- Purpose:  stage.Patient -> clinical.Patient. Updates only changed rows, inserts new rows.
--           A changed address moves the patient to another ID_Location (SCD2 material for silver).
--=====================================================================================================
PRINT N'stage.spMerge_Patient - Creating';
GO

CREATE OR ALTER PROCEDURE stage.spMerge_Patient
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
          TRY_CONVERT(UNIQUEIDENTIFIER, TRIM(patient.[Id]))                          AS SourceKey
        , ISNULL(cityLookup.ID_City, 0)                                               AS ID_Location
        , LEFT(ISNULL(TRIM(patient.PREFIX), N''), 10)                                 AS Prefix
        , LEFT(ISNULL(TRIM(patient.[FIRST]), N''), 100)                               AS FirstName
        , LEFT(ISNULL(TRIM(patient.MIDDLE), N''), 100)                                AS MiddleName
        , LEFT(ISNULL(TRIM(patient.[LAST]), N''), 100)                                AS LastName
        , LEFT(ISNULL(TRIM(patient.SUFFIX), N''), 10)                                 AS Suffix
        , LEFT(ISNULL(TRIM(patient.MAIDEN), N''), 100)                                AS MaidenName
        , LEFT(ISNULL(TRIM(patient.MARITAL), N''), 10)                                AS MaritalStatus
        , LEFT(ISNULL(TRIM(patient.RACE), N''), 50)                                   AS Race
        , LEFT(ISNULL(TRIM(patient.ETHNICITY), N''), 50)                              AS Ethnicity
        , LEFT(ISNULL(TRIM(patient.GENDER), N''), 10)                                 AS Gender
        , LEFT(ISNULL(TRIM(patient.BIRTHPLACE), N''), 255)                            AS BirthPlace
        , LEFT(ISNULL(TRIM(patient.[ADDRESS]), N''), 255)                             AS Address
        , LEFT(ISNULL(TRIM(patient.ZIP), N''), 10)                                    AS Zip
        , ISNULL(TRY_CONVERT(DECIMAL(9, 6), patient.LAT), 0)                          AS Latitude
        , ISNULL(TRY_CONVERT(DECIMAL(9, 6), patient.LON), 0)                          AS Longitude
        , ISNULL(TRY_CONVERT(DATE, patient.BIRTHDATE, 23), CAST('1900-01-01' AS DATE)) AS BirthDate
        , TRY_CONVERT(DATE, patient.DEATHDATE, 23)                                    AS DeathDate
        , ISNULL(TRY_CONVERT(DECIMAL(12, 2), patient.INCOME), 0)                      AS Income
        , ROW_NUMBER() OVER (PARTITION BY TRIM(patient.[Id]) ORDER BY patient.StageID DESC) AS RowNumber
    INTO
        #Source
    FROM
        stage.Patient patient
        LEFT JOIN stage.vwCityLookup cityLookup
            ON cityLookup.CityName = TRIM(patient.CITY)
            AND cityLookup.StateName = TRIM(patient.[STATE]);

    DELETE FROM #Source WHERE RowNumber > 1 OR SourceKey IS NULL;

    BEGIN TRANSACTION;

    --------------------------------------------------------------------------------
    -- Step 2: Update changed rows
    --------------------------------------------------------------------------------
    UPDATE target
    SET
          target.ID_Location   = source.ID_Location
        , target.Prefix        = source.Prefix
        , target.FirstName     = source.FirstName
        , target.MiddleName    = source.MiddleName
        , target.LastName      = source.LastName
        , target.Suffix        = source.Suffix
        , target.MaidenName    = source.MaidenName
        , target.MaritalStatus = source.MaritalStatus
        , target.Race          = source.Race
        , target.Ethnicity     = source.Ethnicity
        , target.Gender        = source.Gender
        , target.BirthPlace    = source.BirthPlace
        , target.Address       = source.Address
        , target.Zip           = source.Zip
        , target.Latitude      = source.Latitude
        , target.Longitude     = source.Longitude
        , target.BirthDate     = source.BirthDate
        , target.DeathDate     = source.DeathDate
        , target.Income        = source.Income
        , target.Deleted       = 0
        , target.ID_UpdatedBy  = 1
        , target.UpdatedDate   = SYSUTCDATETIME()
    FROM
        clinical.Patient target
        INNER JOIN #Source source
            ON source.SourceKey = target.SourceKey
    WHERE
        target.ID > 0
        AND EXISTS (
            SELECT target.ID_Location, target.Prefix, target.FirstName, target.MiddleName, target.LastName, target.Suffix, target.MaidenName
                 , target.MaritalStatus, target.Race, target.Ethnicity, target.Gender, target.BirthPlace, target.Address, target.Zip
                 , target.Latitude, target.Longitude, target.BirthDate, target.DeathDate, target.Income, target.Deleted
            EXCEPT
            SELECT source.ID_Location, source.Prefix, source.FirstName, source.MiddleName, source.LastName, source.Suffix, source.MaidenName
                 , source.MaritalStatus, source.Race, source.Ethnicity, source.Gender, source.BirthPlace, source.Address, source.Zip
                 , source.Latitude, source.Longitude, source.BirthDate, source.DeathDate, source.Income, CAST(0 AS BIT)
        );
    SET @Updated = @@ROWCOUNT;

    --------------------------------------------------------------------------------
    -- Step 3: Insert new rows
    --------------------------------------------------------------------------------
    INSERT INTO clinical.Patient (
          SourceKey, ID_Location, Prefix, FirstName, MiddleName, LastName, Suffix, MaidenName, MaritalStatus
        , Race, Ethnicity, Gender, BirthPlace, Address, Zip, Latitude, Longitude, BirthDate, DeathDate, Income
    )
    SELECT
          source.SourceKey, source.ID_Location, source.Prefix, source.FirstName, source.MiddleName, source.LastName, source.Suffix, source.MaidenName, source.MaritalStatus
        , source.Race, source.Ethnicity, source.Gender, source.BirthPlace, source.Address, source.Zip, source.Latitude, source.Longitude, source.BirthDate, source.DeathDate, source.Income
    FROM
        #Source source
    WHERE
        NOT EXISTS (SELECT 1 FROM clinical.Patient target WHERE target.SourceKey = source.SourceKey AND target.ID > 0);
    SET @Inserted = @@ROWCOUNT;

    COMMIT TRANSACTION;

    PRINT CONCAT(N'stage.spMerge_Patient: inserted ', @Inserted, N', updated ', @Updated);
END
GO

PRINT N'stage.spMerge_Patient - Script Done';
GO