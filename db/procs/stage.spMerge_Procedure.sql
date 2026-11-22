--=====================================================================================================
--                          stage.spMerge_Procedure Stored Procedure
--=====================================================================================================
-- Purpose:  stage.Procedure -> clinical.Procedure. Natural key: encounter + code + start date +
--           Occurrence. Rows whose encounter or code is unknown are skipped and counted.
--=====================================================================================================
PRINT N'stage.spMerge_Procedure - Creating';
GO

CREATE OR ALTER PROCEDURE stage.spMerge_Procedure
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Updated INT;
    DECLARE @Inserted INT;
    DECLARE @Skipped INT;

    SELECT
          ISNULL(patient.ID, 0)                                                                         AS ID_Patient
        , ISNULL(encounter.ID, 0)                                                                       AS ID_Encounter
        , ISNULL(code.ID, 0)                                                                            AS ID_Code
        , ISNULL(reasonCode.ID, 0)                                                                      AS ID_ReasonCode
        , ISNULL(TRY_CONVERT(DATETIME2(0), proc_.[START], 127), CAST('1900-01-01' AS DATETIME2(0)))     AS StartDate
        , TRY_CONVERT(DATETIME2(0), proc_.[STOP], 127)                                                  AS StopDate
        , CAST(ROW_NUMBER() OVER (
              PARTITION BY TRIM(proc_.ENCOUNTER), TRIM(proc_.[SYSTEM]), TRIM(proc_.CODE), proc_.[START]
              ORDER BY proc_.StageID) AS INT)                                                           AS Occurrence
        , ISNULL(TRY_CONVERT(DECIMAL(14, 2), proc_.BASE_COST), 0)                                       AS BaseCost
    INTO
        #Source
    FROM
        stage.[Procedure] proc_
        LEFT JOIN clinical.Patient patient
            ON patient.SourceKey = TRY_CONVERT(UNIQUEIDENTIFIER, TRIM(proc_.PATIENT)) AND patient.ID > 0
        LEFT JOIN clinical.Encounter encounter
            ON encounter.SourceKey = TRY_CONVERT(UNIQUEIDENTIFIER, TRIM(proc_.ENCOUNTER)) AND encounter.ID > 0
        LEFT JOIN ref.Code code
            ON code.CodeSystem = LEFT(TRIM(proc_.[SYSTEM]), 20) AND code.Code = TRIM(proc_.CODE) AND code.ID > 0
        LEFT JOIN ref.Code reasonCode
            ON reasonCode.CodeSystem = N'SNOMED-CT' AND reasonCode.Code = TRIM(proc_.REASONCODE) AND reasonCode.ID > 0;

    SELECT @Skipped = COUNT(*) FROM #Source WHERE ID_Encounter = 0 OR ID_Code = 0;
    DELETE FROM #Source WHERE ID_Encounter = 0 OR ID_Code = 0;

    BEGIN TRANSACTION;

    UPDATE target
    SET
          target.ID_Patient    = source.ID_Patient
        , target.ID_ReasonCode = source.ID_ReasonCode
        , target.StopDate      = source.StopDate
        , target.BaseCost      = source.BaseCost
        , target.Deleted       = 0
        , target.ID_UpdatedBy  = 1
        , target.UpdatedDate   = SYSUTCDATETIME()
    FROM
        clinical.[Procedure] target
        INNER JOIN #Source source
            ON source.ID_Encounter = target.ID_Encounter
            AND source.ID_Code = target.ID_Code
            AND source.StartDate = target.StartDate
            AND source.Occurrence = target.Occurrence
    WHERE
        target.ID > 0
        AND EXISTS (
            SELECT target.ID_Patient, target.ID_ReasonCode, target.StopDate, target.BaseCost, target.Deleted
            EXCEPT
            SELECT source.ID_Patient, source.ID_ReasonCode, source.StopDate, source.BaseCost, CAST(0 AS BIT)
        );
    SET @Updated = @@ROWCOUNT;

    INSERT INTO clinical.[Procedure] (ID_Patient, ID_Encounter, ID_Code, ID_ReasonCode, StartDate, StopDate, Occurrence, BaseCost)
    SELECT
          source.ID_Patient, source.ID_Encounter, source.ID_Code, source.ID_ReasonCode, source.StartDate, source.StopDate, source.Occurrence, source.BaseCost
    FROM
        #Source source
    WHERE
        NOT EXISTS (
            SELECT 1 FROM clinical.[Procedure] target
            WHERE target.ID_Encounter = source.ID_Encounter AND target.ID_Code = source.ID_Code
              AND target.StartDate = source.StartDate AND target.Occurrence = source.Occurrence AND target.ID > 0
        );
    SET @Inserted = @@ROWCOUNT;

    COMMIT TRANSACTION;

    PRINT CONCAT(N'stage.spMerge_Procedure: inserted ', @Inserted, N', updated ', @Updated, N', skipped ', @Skipped);
END
GO

PRINT N'stage.spMerge_Procedure - Script Done';
GO