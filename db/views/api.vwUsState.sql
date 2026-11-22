--=====================================================================================================
--                                        api.vwUsState View
--=====================================================================================================
-- Purpose:  Consumer view of ref.UsState;. Hides Deleted = 1, keeps row 0.
--=====================================================================================================
CREATE OR ALTER VIEW api.vwUsState
AS
SELECT
      Code
    , Name
FROM
    ref.UsState;
GO

PRINT N'api.vwUsState - Script Done';
GO
