--=====================================================================================================
--                                        api.vwCondition View
--=====================================================================================================
-- Purpose:  Consumer view of clinical.Condition. Hides Deleted = 1, keeps row 0.
--=====================================================================================================
CREATE OR ALTER VIEW api.vwCondition
AS
SELECT
      ID
    , ID_Patient
    , ID_Encounter
    , ID_Code
    , StartDate
    , StopDate
    , Occurrence
    , CreatedDate
    , UpdatedDate
FROM
    clinical.Condition
WHERE
    Deleted = 0;
GO

PRINT N'api.vwCondition - Script Done';
GO
