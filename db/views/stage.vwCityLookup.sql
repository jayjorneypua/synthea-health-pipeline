--=====================================================================================================
--                                        stage.vwCityLookup View
--=====================================================================================================
-- Purpose:  City + state (code or name) -> ref.Location city ID, for the merge procs.
--=====================================================================================================
CREATE OR ALTER VIEW stage.vwCityLookup
AS
SELECT
      city.ID         AS ID_City
    , city.Name       AS CityName
    , state.Code      AS StateCode
    , state.Name      AS StateName
FROM
    ref.Location city
    INNER JOIN ref.Location county
        ON county.ID = city.ID_Parent
    INNER JOIN ref.Location state
        ON state.ID = county.ID_Parent
WHERE
    city.LocationType = N'City'
    AND city.Deleted = 0
    AND state.LocationType = N'State';
GO

PRINT N'stage.vwCityLookup - Script Done';
GO