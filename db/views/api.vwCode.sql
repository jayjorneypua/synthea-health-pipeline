--=====================================================================================================
--                                        api.vwCode View
--=====================================================================================================
-- Purpose:  Consumer view of ref.Code. Hides Deleted = 1, keeps row 0.
--=====================================================================================================
CREATE OR ALTER VIEW api.vwCode
AS
SELECT
      ID
    , CodeSystem
    , Code
    , Description
    , DisplayOrder
    , CreatedDate
    , UpdatedDate
FROM
    ref.Code
WHERE
    Deleted = 0;
GO

PRINT N'api.vwCode - Script Done';
GO
