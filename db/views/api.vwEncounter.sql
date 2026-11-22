--=====================================================================================================
--                                        api.vwEncounter View
--=====================================================================================================
-- Purpose:  Consumer view of clinical.Encounter. Hides Deleted = 1, keeps row 0.
--=====================================================================================================
CREATE OR ALTER VIEW api.vwEncounter
AS
SELECT
      ID
    , ID_Patient
    , ID_Organization
    , ID_Provider
    , ID_Payer
    , ID_Code
    , ID_ReasonCode
    , SourceKey
    , EncounterClass
    , StartDate
    , StopDate
    , BaseEncounterCost
    , TotalClaimCost
    , PayerCoverage
    , CreatedDate
    , UpdatedDate
FROM
    clinical.Encounter
WHERE
    Deleted = 0;
GO

PRINT N'api.vwEncounter - Script Done';
GO
