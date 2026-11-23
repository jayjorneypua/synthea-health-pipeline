--=====================================================================================================
--                                        api.vwClaimLine View
--=====================================================================================================
-- Purpose:  Consumer view of clinical.ClaimLine. Hides Deleted = 1, keeps row 0.
--=====================================================================================================
CREATE OR ALTER VIEW api.vwClaimLine
AS
SELECT
      ID
    , ID_Claim
    , ID_Provider
    , ID_Organization
    , ID_ProcedureCode
    , SourceKey
    , ChargeID
    , TransactionType
    , PaymentMethod
    , TransferType
    , FromDate
    , ToDate
    , Units
    , UnitAmount
    , Amount
    , Payments
    , Adjustments
    , Transfers
    , Outstanding
    , CreatedDate
    , UpdatedDate
FROM
    clinical.ClaimLine
WHERE
    Deleted = 0;
GO

PRINT N'api.vwClaimLine - Script Done';
GO