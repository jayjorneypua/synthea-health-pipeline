--=====================================================================================================
--                          stage.spMerge_Medication Stored Procedure
--=====================================================================================================
-- Purpose:  stage.Medication -> clinical.Medication. Codes are RxNorm, reasons SNOMED-CT.
--           Natural key: encounter + code + start date + Occurrence.
--=====================================================================================================
PRINT N'stage.spMerge_Medication - Creating';
GO

CREATE OR ALTER PROCEDURE stage.spMerge_Medication
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Updated INT;
    DECLARE @Inserted INT;
    DECLARE @Skipped INT;

    SELECT
          ISNULL(patient.ID, 0)                                                                          AS ID_Patient
        , ISNULL(encounter.ID, 0)                                                                        AS ID_Encounter
        , ISNULL(payer.ID, 0)                                                                            AS ID_Payer
        , ISNULL(code.ID, 0)                                                                             AS ID_Code
        , ISNULL(reasonCode.ID, 0)                                                                       AS ID_ReasonCode
        , ISNULL(TRY_CONVERT(DATETIME2(0), medication.[START], 127), CAST('1900-01-01' AS DATETIME2(0))) AS StartDate
        , TRY_CONVERT(DATETIME2(0), medication.[STOP], 127)                                              AS StopDate
        , CAST(ROW_NUMBER() OVER (
              PARTITION BY TRIM(medication.ENCOUNTER), TRIM(medication.CODE), medication.[START]
              ORDER BY medication.StageID) AS INT)                                                       AS Occurrence
        , ISNULL(TRY_CONVERT(DECIMAL(14, 2), medication.BASE_COST), 0)                                   AS BaseCost
        , ISNULL(TRY_CONVERT(DECIMAL(14, 2), medication.PAYER_COVERAGE), 0)                              AS PayerCoverage
        , ISNULL(TRY_CONVERT(INT, medication.DISPENSES), 0)                                              AS Dispenses
        , ISNULL(TRY_CONVERT(DECIMAL(14, 2), medication.TOTALCOST), 0)                                   AS TotalCost
    INTO
        #Source
    FROM
        stage.Medication medication
        LEFT JOIN clinical.Patient patient
            ON patient.SourceKey = TRY_CONVERT(UNIQUEIDENTIFIER, TRIM(medication.PATIENT)) AND patient.ID > 0
        LEFT JOIN clinical.Encounter encounter
            ON encounter.SourceKey = TRY_CONVERT(UNIQUEIDENTIFIER, TRIM(medication.ENCOUNTER)) AND encounter.ID > 0
        LEFT JOIN ref.Payer payer
            ON payer.SourceKey = TRY_CONVERT(UNIQUEIDENTIFIER, TRIM(medication.PAYER)) AND payer.ID > 0
        LEFT JOIN ref.Code code
            ON code.CodeSystem = N'RxNorm' AND code.Code = TRIM(medication.CODE) AND code.ID > 0
        LEFT JOIN ref.Code reasonCode
            ON reasonCode.CodeSystem = N'SNOMED-CT' AND reasonCode.Code = TRIM(medication.REASONCODE) AND reasonCode.ID > 0;

    SELECT @Skipped = COUNT(*) FROM #Source WHERE ID_Encounter = 0 OR ID_Code = 0;
    DELETE FROM #Source WHERE ID_Encounter = 0 OR ID_Code = 0;

    BEGIN TRANSACTION;

    UPDATE target
    SET
          target.ID_Patient    = source.ID_Patient
        , target.ID_Payer      = source.ID_Payer
        , target.ID_ReasonCode = source.ID_ReasonCode
        , target.StopDate      = source.StopDate
        , target.BaseCost      = source.BaseCost
        , target.PayerCoverage = source.PayerCoverage
        , target.Dispenses     = source.Dispenses
        , target.TotalCost     = source.TotalCost
        , target.Deleted       = 0
        , target.ID_UpdatedBy  = 1
        , target.UpdatedDate   = SYSUTCDATETIME()
    FROM
        clinical.Medication target
        INNER JOIN #Source source
            ON source.ID_Encounter = target.ID_Encounter
            AND source.ID_Code = target.ID_Code
            AND source.StartDate = target.StartDate
            AND source.Occurrence = target.Occurrence
    WHERE
        target.ID > 0
        AND EXISTS (
            SELECT target.ID_Patient, target.ID_Payer, target.ID_ReasonCode, target.StopDate, target.BaseCost, target.PayerCoverage, target.Dispenses, target.TotalCost, target.Deleted
            EXCEPT
            SELECT source.ID_Patient, source.ID_Payer, source.ID_ReasonCode, source.StopDate, source.BaseCost, source.PayerCoverage, source.Dispenses, source.TotalCost, CAST(0 AS BIT)
        );
    SET @Updated = @@ROWCOUNT;

    INSERT INTO clinical.Medication (
          ID_Patient, ID_Encounter, ID_Payer, ID_Code, ID_ReasonCode, StartDate, StopDate, Occurrence
        , BaseCost, PayerCoverage, Dispenses, TotalCost
    )
    SELECT
          source.ID_Patient, source.ID_Encounter, source.ID_Payer, source.ID_Code, source.ID_ReasonCode, source.StartDate, source.StopDate, source.Occurrence
        , source.BaseCost, source.PayerCoverage, source.Dispenses, source.TotalCost
    FROM
        #Source source
    WHERE
        NOT EXISTS (
            SELECT 1 FROM clinical.Medication target
            WHERE target.ID_Encounter = source.ID_Encounter AND target.ID_Code = source.ID_Code
              AND target.StartDate = source.StartDate AND target.Occurrence = source.Occurrence AND target.ID > 0
        );
    SET @Inserted = @@ROWCOUNT;

    COMMIT TRANSACTION;

    PRINT CONCAT(N'stage.spMerge_Medication: inserted ', @Inserted, N', updated ', @Updated, N', skipped ', @Skipped);
END
GO

PRINT N'stage.spMerge_Medication - Script Done';
GO