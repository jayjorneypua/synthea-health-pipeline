--=====================================================================================================
--                                        api.vwMedication View
--=====================================================================================================
-- Purpose:  Consumer view of clinical.Medication. Hides Deleted = 1, keeps row 0.
--=====================================================================================================
CREATE OR ALTER VIEW api.vwMedication
AS
SELECT
      ID
    , ID_Patient
    , ID_Encounter
    , ID_Payer
    , ID_Code
    , ID_ReasonCode
    , StartDate
    , StopDate
    , Occurrence
    , BaseCost
    , PayerCoverage
    , Dispenses
    , TotalCost
    , CreatedDate
    , UpdatedDate
FROM
    clinical.Medication
WHERE
    Deleted = 0;
GO

PRINT N'api.vwMedication - Script Done';
GO
