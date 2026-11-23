--=====================================================================================================
--                          stage.spMerge_ClaimLine Stored Procedure
--=====================================================================================================
-- Purpose:  stage.ClaimLine -> clinical.ClaimLine. Run after claims, providers, organizations and codes.
--           PROCEDURECODE has no code system in the CSV, so it is looked up by value, SNOMED-CT first,
--           then RxNorm. Codes not in ref.Code (e.g. immunization CVX) map to 0.
--           Updates only changed rows, inserts new rows.
--=====================================================================================================
PRINT N'stage.spMerge_ClaimLine - Creating';
GO

CREATE OR ALTER PROCEDURE stage.spMerge_ClaimLine
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Updated INT;
    DECLARE @Inserted INT;

    -- one ID per code value: SNOMED-CT wins over RxNorm, anything else last
    SELECT
          code.Code
        , code.ID
    INTO
        #CodeLookup
    FROM (
        SELECT
              ref.Code
            , ref.ID
            , ROW_NUMBER() OVER (
                PARTITION BY ref.Code
                ORDER BY CASE ref.CodeSystem WHEN N'SNOMED-CT' THEN 1 WHEN N'RxNorm' THEN 2 ELSE 3 END, ref.ID
              ) AS RowNumber
        FROM
            ref.Code ref
        WHERE
            ref.ID > 0
    ) code
    WHERE
        code.RowNumber = 1;

    CREATE UNIQUE CLUSTERED INDEX UX_CodeLookup_Code ON #CodeLookup (Code);

    SELECT
          TRY_CONVERT(UNIQUEIDENTIFIER, TRIM(line.[ID]))                                                  AS SourceKey
        , ISNULL(claim.ID, 0)                                                                              AS ID_Claim
        , ISNULL(provider.ID, 0)                                                                           AS ID_Provider
        , ISNULL(organization.ID, 0)                                                                       AS ID_Organization
        , ISNULL(procedureCode.ID, 0)                                                                      AS ID_ProcedureCode
        , ISNULL(TRY_CONVERT(INT, line.CHARGEID), 0)                                                       AS ChargeID
        , LEFT(ISNULL(TRIM(line.[TYPE]), N''), 20)                                                         AS TransactionType
        , LEFT(ISNULL(TRIM(line.METHOD), N''), 20)                                                         AS PaymentMethod
        , LEFT(ISNULL(TRIM(line.TRANSFERTYPE), N''), 10)                                                   AS TransferType
        , ISNULL(TRY_CONVERT(DATETIME2(0), line.FROMDATE, 127), CAST('1900-01-01' AS DATETIME2(0)))        AS FromDate
        , TRY_CONVERT(DATETIME2(0), line.TODATE, 127)                                                      AS ToDate
        , ISNULL(TRY_CONVERT(DECIMAL(10, 2), line.UNITS), 0)                                               AS Units
        , ISNULL(TRY_CONVERT(DECIMAL(14, 2), line.UNITAMOUNT), 0)                                          AS UnitAmount
        , ISNULL(TRY_CONVERT(DECIMAL(14, 2), line.AMOUNT), 0)                                              AS Amount
        , ISNULL(TRY_CONVERT(DECIMAL(14, 2), line.PAYMENTS), 0)                                            AS Payments
        , ISNULL(TRY_CONVERT(DECIMAL(14, 2), line.ADJUSTMENTS), 0)                                         AS Adjustments
        , ISNULL(TRY_CONVERT(DECIMAL(14, 2), line.TRANSFERS), 0)                                           AS Transfers
        , ISNULL(TRY_CONVERT(DECIMAL(14, 2), line.OUTSTANDING), 0)                                         AS Outstanding
        , ROW_NUMBER() OVER (PARTITION BY TRIM(line.[ID]) ORDER BY line.StageID DESC)                     AS RowNumber
    INTO
        #Source
    FROM
        stage.ClaimLine line
        LEFT JOIN clinical.Claim claim
            ON claim.SourceKey = TRY_CONVERT(UNIQUEIDENTIFIER, TRIM(line.CLAIMID)) AND claim.ID > 0
        LEFT JOIN ref.Provider provider
            ON provider.SourceKey = TRY_CONVERT(UNIQUEIDENTIFIER, TRIM(line.PROVIDERID)) AND provider.ID > 0
        LEFT JOIN ref.Organization organization
            ON organization.SourceKey = TRY_CONVERT(UNIQUEIDENTIFIER, TRIM(line.PLACEOFSERVICE)) AND organization.ID > 0
        LEFT JOIN #CodeLookup procedureCode
            ON procedureCode.Code = TRIM(line.PROCEDURECODE);

    DELETE FROM #Source WHERE RowNumber > 1 OR SourceKey IS NULL;

    -- biggest table in the pipeline: index the temp table for the update and insert joins
    CREATE UNIQUE CLUSTERED INDEX UX_Source_SourceKey ON #Source (SourceKey);

    BEGIN TRANSACTION;

    UPDATE target
    SET
          target.ID_Claim         = source.ID_Claim
        , target.ID_Provider      = source.ID_Provider
        , target.ID_Organization  = source.ID_Organization
        , target.ID_ProcedureCode = source.ID_ProcedureCode
        , target.ChargeID         = source.ChargeID
        , target.TransactionType  = source.TransactionType
        , target.PaymentMethod    = source.PaymentMethod
        , target.TransferType     = source.TransferType
        , target.FromDate         = source.FromDate
        , target.ToDate           = source.ToDate
        , target.Units            = source.Units
        , target.UnitAmount       = source.UnitAmount
        , target.Amount           = source.Amount
        , target.Payments         = source.Payments
        , target.Adjustments      = source.Adjustments
        , target.Transfers        = source.Transfers
        , target.Outstanding      = source.Outstanding
        , target.Deleted          = 0
        , target.ID_UpdatedBy     = 1
        , target.UpdatedDate      = SYSUTCDATETIME()
    FROM
        clinical.ClaimLine target
        INNER JOIN #Source source
            ON source.SourceKey = target.SourceKey
    WHERE
        target.ID > 0
        AND EXISTS (
            SELECT target.ID_Claim, target.ID_Provider, target.ID_Organization, target.ID_ProcedureCode, target.ChargeID, target.TransactionType
                 , target.PaymentMethod, target.TransferType, target.FromDate, target.ToDate, target.Units, target.UnitAmount, target.Amount
                 , target.Payments, target.Adjustments, target.Transfers, target.Outstanding, target.Deleted
            EXCEPT
            SELECT source.ID_Claim, source.ID_Provider, source.ID_Organization, source.ID_ProcedureCode, source.ChargeID, source.TransactionType
                 , source.PaymentMethod, source.TransferType, source.FromDate, source.ToDate, source.Units, source.UnitAmount, source.Amount
                 , source.Payments, source.Adjustments, source.Transfers, source.Outstanding, CAST(0 AS BIT)
        );
    SET @Updated = @@ROWCOUNT;

    INSERT INTO clinical.ClaimLine (
          SourceKey, ID_Claim, ID_Provider, ID_Organization, ID_ProcedureCode, ChargeID, TransactionType
        , PaymentMethod, TransferType, FromDate, ToDate, Units, UnitAmount, Amount
        , Payments, Adjustments, Transfers, Outstanding
    )
    SELECT
          source.SourceKey, source.ID_Claim, source.ID_Provider, source.ID_Organization, source.ID_ProcedureCode, source.ChargeID, source.TransactionType
        , source.PaymentMethod, source.TransferType, source.FromDate, source.ToDate, source.Units, source.UnitAmount, source.Amount
        , source.Payments, source.Adjustments, source.Transfers, source.Outstanding
    FROM
        #Source source
    WHERE
        NOT EXISTS (SELECT 1 FROM clinical.ClaimLine target WHERE target.SourceKey = source.SourceKey AND target.ID > 0);
    SET @Inserted = @@ROWCOUNT;

    COMMIT TRANSACTION;

    PRINT CONCAT(N'stage.spMerge_ClaimLine: inserted ', @Inserted, N', updated ', @Updated);
END
GO

PRINT N'stage.spMerge_ClaimLine - Script Done';
GO