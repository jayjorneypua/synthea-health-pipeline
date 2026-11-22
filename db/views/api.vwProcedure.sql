--=====================================================================================================
--                                        api.vwProcedure View
--=====================================================================================================
-- Purpose:  Consumer view of clinical.Procedure. Hides Deleted = 1, keeps row 0.
--=====================================================================================================
CREATE OR ALTER VIEW api.vwProcedure
AS
SELECT
      ID
    , ID_Patient
    , ID_Encounter
    , ID_Code
    , ID_ReasonCode
    , StartDate
    , StopDate
    , Occurrence
    , BaseCost
    , CreatedDate
    , UpdatedDate
FROM
    clinical.[Procedure]
WHERE
    Deleted = 0;
GO

PRINT N'api.vwProcedure - Script Done';
GO
