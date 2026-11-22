--=====================================================================================================
--                                        api.vwOrganization View
--=====================================================================================================
-- Purpose:  Consumer view of ref.Organization. Hides Deleted = 1, keeps row 0.
--=====================================================================================================
CREATE OR ALTER VIEW api.vwOrganization
AS
SELECT
      ID
    , ID_Location
    , SourceKey
    , Name
    , Address
    , Zip
    , Latitude
    , Longitude
    , Phone
    , NPI
    , DisplayOrder
    , CreatedDate
    , UpdatedDate
FROM
    ref.Organization
WHERE
    Deleted = 0;
GO

PRINT N'api.vwOrganization - Script Done';
GO
