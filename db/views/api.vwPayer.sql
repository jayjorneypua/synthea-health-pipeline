--=====================================================================================================
--                                        api.vwPayer View
--=====================================================================================================
-- Purpose:  Consumer view of ref.Payer. Hides Deleted = 1, keeps row 0.
--=====================================================================================================
CREATE OR ALTER VIEW api.vwPayer
AS
SELECT
      ID
    , ID_Location
    , SourceKey
    , Name
    , Ownership
    , Address
    , Zip
    , Phone
    , DisplayOrder
    , CreatedDate
    , UpdatedDate
FROM
    ref.Payer
WHERE
    Deleted = 0;
GO

PRINT N'api.vwPayer - Script Done';
GO
