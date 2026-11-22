--=====================================================================================================
--                          stage.spMerge_Location Stored Procedure
--=====================================================================================================
-- Purpose:  Builds State > County > City in ref.Location from every stage source.
--           - Patients give state name, county and city (the only file with counties).
--           - Organizations and providers give a state code; ref.UsState maps it to the name.
--           - Cities with no known county go under "(Unknown County)"; if a later batch reveals
--             the county, the city is moved under it.
--           Inserts only missing rows, then rebuilds Path/Level/HasChildren.
--=====================================================================================================
PRINT N'stage.spMerge_Location - Creating';
GO

CREATE OR ALTER PROCEDURE stage.spMerge_Location
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @UnknownCounty NVARCHAR(255) = N'(Unknown County)';

    --------------------------------------------------------------------------------
    -- Step 1: City -> county map (from patients)
    --------------------------------------------------------------------------------
    CREATE TABLE #CityCounty (
          StateName   NVARCHAR(100)   NOT NULL
        , CityName    NVARCHAR(255)   NOT NULL
        , CountyName  NVARCHAR(255)   NOT NULL
        , CountyCode  NVARCHAR(20)    NOT NULL
    );

    INSERT INTO #CityCounty (StateName, CityName, CountyName, CountyCode)
    SELECT
          TRIM(patient.[STATE])
        , TRIM(patient.CITY)
        , MIN(TRIM(patient.COUNTY))
        , MIN(ISNULL(TRIM(patient.FIPS), N''))
    FROM
        stage.Patient patient
    WHERE
        NULLIF(TRIM(patient.[STATE]), N'') IS NOT NULL
        AND NULLIF(TRIM(patient.CITY), N'') IS NOT NULL
        AND NULLIF(TRIM(patient.COUNTY), N'') IS NOT NULL
    GROUP BY
          TRIM(patient.[STATE])
        , TRIM(patient.CITY);

    --------------------------------------------------------------------------------
    -- Step 2: Every city from every source, with the state as a full name
    --------------------------------------------------------------------------------
    CREATE TABLE #City (
          StateName   NVARCHAR(100)   NOT NULL
        , CityName    NVARCHAR(255)   NOT NULL
    );

    INSERT INTO #City (StateName, CityName)
    SELECT TRIM(patient.[STATE]), TRIM(patient.CITY)
    FROM stage.Patient patient
    WHERE NULLIF(TRIM(patient.[STATE]), N'') IS NOT NULL AND NULLIF(TRIM(patient.CITY), N'') IS NOT NULL

    UNION

    SELECT usState.Name, TRIM(organization.CITY)
    FROM stage.Organization organization
        INNER JOIN ref.UsState usState ON usState.Code = TRIM(organization.[STATE])
    WHERE NULLIF(TRIM(organization.CITY), N'') IS NOT NULL

    UNION

    SELECT usState.Name, TRIM(provider.CITY)
    FROM stage.Provider provider
        INNER JOIN ref.UsState usState ON usState.Code = TRIM(provider.[STATE])
    WHERE NULLIF(TRIM(provider.CITY), N'') IS NOT NULL

    UNION

    SELECT usState.Name, TRIM(payer.CITY)
    FROM stage.Payer payer
        INNER JOIN ref.UsState usState
            ON usState.Code = TRIM(payer.STATE_HEADQUARTERED)
            OR usState.Name = TRIM(payer.STATE_HEADQUARTERED)
    WHERE NULLIF(TRIM(payer.CITY), N'') IS NOT NULL;

    BEGIN TRANSACTION;

    --------------------------------------------------------------------------------
    -- Step 3: States
    --------------------------------------------------------------------------------
    INSERT INTO ref.Location (ID_Parent, Name, LocationType, Code)
    SELECT DISTINCT
          0
        , city.StateName
        , N'State'
        , ISNULL(usState.Code, N'')
    FROM
        #City city
        LEFT JOIN ref.UsState usState
            ON usState.Name = city.StateName
    WHERE
        NOT EXISTS (
            SELECT 1
            FROM ref.Location existing
            WHERE existing.ID_Parent = 0
              AND existing.LocationType = N'State'
              AND existing.Name = city.StateName
              AND existing.Deleted = 0
        );

    --------------------------------------------------------------------------------
    -- Step 4: Counties (known ones plus "(Unknown County)" where needed)
    --------------------------------------------------------------------------------
    INSERT INTO ref.Location (ID_Parent, Name, LocationType, Code)
    SELECT
          state.ID
        , county.CountyName
        , N'County'
        , MIN(county.CountyCode)
    FROM (
        SELECT
              city.StateName
            , ISNULL(cityCounty.CountyName, @UnknownCounty) AS CountyName
            , ISNULL(cityCounty.CountyCode, N'')            AS CountyCode
        FROM
            #City city
            LEFT JOIN #CityCounty cityCounty
                ON cityCounty.StateName = city.StateName
                AND cityCounty.CityName = city.CityName
    ) county
        INNER JOIN ref.Location state
            ON state.ID_Parent = 0
            AND state.LocationType = N'State'
            AND state.Name = county.StateName
            AND state.Deleted = 0
    WHERE
        NOT EXISTS (
            SELECT 1
            FROM ref.Location existing
            WHERE existing.ID_Parent = state.ID
              AND existing.LocationType = N'County'
              AND existing.Name = county.CountyName
              AND existing.Deleted = 0
        )
    GROUP BY
          state.ID
        , county.CountyName;

    --------------------------------------------------------------------------------
    -- Step 5: Move cities out of "(Unknown County)" once their county is known
    --------------------------------------------------------------------------------
    UPDATE city
    SET
          city.ID_Parent    = county.ID
        , city.ID_UpdatedBy = 1
        , city.UpdatedDate  = SYSUTCDATETIME()
    FROM
        ref.Location city
        INNER JOIN ref.Location unknownCounty
            ON unknownCounty.ID = city.ID_Parent
            AND unknownCounty.LocationType = N'County'
            AND unknownCounty.Name = @UnknownCounty
        INNER JOIN ref.Location state
            ON state.ID = unknownCounty.ID_Parent
        INNER JOIN #CityCounty cityCounty
            ON cityCounty.StateName = state.Name
            AND cityCounty.CityName = city.Name
        INNER JOIN ref.Location county
            ON county.ID_Parent = state.ID
            AND county.LocationType = N'County'
            AND county.Name = cityCounty.CountyName
            AND county.Deleted = 0
    WHERE
        city.LocationType = N'City'
        AND city.Deleted = 0;

    --------------------------------------------------------------------------------
    -- Step 6: Cities
    --------------------------------------------------------------------------------
    INSERT INTO ref.Location (ID_Parent, Name, LocationType)
    SELECT DISTINCT
          county.ID
        , city.CityName
        , N'City'
    FROM
        #City city
        LEFT JOIN #CityCounty cityCounty
            ON cityCounty.StateName = city.StateName
            AND cityCounty.CityName = city.CityName
        INNER JOIN ref.Location state
            ON state.ID_Parent = 0
            AND state.LocationType = N'State'
            AND state.Name = city.StateName
            AND state.Deleted = 0
        INNER JOIN ref.Location county
            ON county.ID_Parent = state.ID
            AND county.LocationType = N'County'
            AND county.Name = ISNULL(cityCounty.CountyName, @UnknownCounty)
            AND county.Deleted = 0
    WHERE
        NOT EXISTS (
            SELECT 1
            FROM ref.Location existing
            WHERE existing.ID_Parent = county.ID
              AND existing.LocationType = N'City'
              AND existing.Name = city.CityName
              AND existing.Deleted = 0
        );

    --------------------------------------------------------------------------------
    -- Step 7: Path, Level, HasChildren
    --------------------------------------------------------------------------------
    EXEC ref.spLocation_RebuildHierarchy;

    COMMIT TRANSACTION;
END
GO

PRINT N'stage.spMerge_Location - Script Done';
GO