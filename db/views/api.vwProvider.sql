--=====================================================================================================
--                                        api.vwProvider View
--=====================================================================================================
-- Purpose:  Consumer view of ref.Provider. Hides Deleted = 1, keeps row 0.
--=====================================================================================================
CREATE OR ALTER VIEW api.vwProvider
AS
SELECT
      ID
    , ID_Organization
    , ID_Location
    , SourceKey
    , Name
    , Gender
    , Speciality
    , Address
    , Zip
    , Latitude
    , Longitude
    , NPI
    , DisplayOrder
    , CreatedDate
    , UpdatedDate
FROM
    ref.Provider
WHERE
    Deleted = 0;
GO

PRINT N'api.vwProvider - Script Done';
GO
