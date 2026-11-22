--=====================================================================================================
--                                        api.vwLocation View
--=====================================================================================================
-- Purpose:  Consumer view of ref.Location. Hides Deleted = 1, keeps row 0.
--=====================================================================================================
CREATE OR ALTER VIEW api.vwLocation
AS
SELECT
      ID
    , ID_Parent
    , Name
    , LocationType
    , Code
    , Path
    , Level
    , HasChildren
    , DisplayOrder
    , CreatedDate
    , UpdatedDate
FROM
    ref.Location
WHERE
    Deleted = 0;
GO

PRINT N'api.vwLocation - Script Done';
GO
