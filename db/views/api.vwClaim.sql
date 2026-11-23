--=====================================================================================================
--                                        api.vwClaim View
--=====================================================================================================
-- Purpose:  Consumer view of clinical.Claim. Hides Deleted = 1, keeps row 0.
--=====================================================================================================
CREATE OR ALTER VIEW api.vwClaim
AS
SELECT
      ID
    , ID_Patient
    , ID_Provider
    , ID_Encounter
    , ID_DiagnosisCode
    , SourceKey
    , ServiceDate
    , CurrentIllnessDate
    , PrimaryStatus
    , SecondaryStatus
    , PatientStatus
    , PrimaryOutstanding
    , SecondaryOutstanding
    , PatientOutstanding
    , PrimaryLastBilledDate
    , SecondaryLastBilledDate
    , PatientLastBilledDate
    , PrimaryClaimType
    , SecondaryClaimType
    , CreatedDate
    , UpdatedDate
FROM
    clinical.Claim
WHERE
    Deleted = 0;
GO

PRINT N'api.vwClaim - Script Done';
GO