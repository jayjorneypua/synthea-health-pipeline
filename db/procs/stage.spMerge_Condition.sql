--=====================================================================================================
--                          stage.spMerge_Condition Stored Procedure
--=====================================================================================================
-- Purpose:  stage.Condition -> clinical.Condition. Natural key: encounter + code + start date +
--           Occurrence. Rows whose encounter or code is unknown are skipped and counted.
--=====================================================================================================
PRINT N'stage.spMerge_Condition - Creating';
GO

CREATE OR ALTER PROCEDURE stage.spMerge_Condition
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Updated INT;
    DECLARE @Inserted INT;
    DECLARE @Skipped INT;

    SELECT
          ISNULL(patient.ID, 0)                                                         AS ID_Patient
        , ISNULL(encounter.ID, 0)                                                       AS ID_Encounter
        , ISNULL(code.ID, 0)                                                            AS ID_Code
        , ISNULL(TRY_CONVERT(DATE, condition.[START], 23), CAST('1900-01-01' AS DATE))  AS StartDate
        , TRY_CONVERT(DATE, condition.[STOP], 23)                                       AS StopDate
        , CAST(ROW_NUMBER() OVER (
              PARTITION BY TRIM(condition.ENCOUNTER), TRIM(condition.[SYSTEM]), TRIM(condition.CODE), condition.[START]
              ORDER BY condition.StageID) AS INT)                                       AS Occurrence
    INTO
        #Source
    FROM
        stage.Condition condition
        LEFT JOIN clinical.Patient patient
            ON patient.SourceKey = TRY_CONVERT(UNIQUEIDENTIFIER, TRIM(condition.PATIENT)) AND patient.ID > 0
        LEFT JOIN clinical.Encounter encounter
            ON encounter.SourceKey = TRY_CONVERT(UNIQUEIDENTIFIER, TRIM(condition.ENCOUNTER)) AND encounter.ID > 0
        LEFT JOIN ref.Code code
            ON code.CodeSystem = LEFT(TRIM(condition.[SYSTEM]), 20) AND code.Code = TRIM(condition.CODE) AND code.ID > 0;

    SELECT @Skipped = COUNT(*) FROM #Source WHERE ID_Encounter = 0 OR ID_Code = 0;
    DELETE FROM #Source WHERE ID_Encounter = 0 OR ID_Code = 0;

    BEGIN TRANSACTION;

    UPDATE target
    SET
          target.ID_Patient   = source.ID_Patient
        , target.StopDate     = source.StopDate
        , target.Deleted      = 0
        , target.ID_UpdatedBy = 1
        , target.UpdatedDate  = SYSUTCDATETIME()
    FROM
        clinical.Condition target
        INNER JOIN #Source source
            ON source.ID_Encounter = target.ID_Encounter
            AND source.ID_Code = target.ID_Code
            AND source.StartDate = target.StartDate
            AND source.Occurrence = target.Occurrence
    WHERE
        target.ID > 0
        AND EXISTS (
            SELECT target.ID_Patient, target.StopDate, target.Deleted
            EXCEPT
            SELECT source.ID_Patient, source.StopDate, CAST(0 AS BIT)
        );
    SET @Updated = @@ROWCOUNT;

    INSERT INTO clinical.Condition (ID_Patient, ID_Encounter, ID_Code, StartDate, StopDate, Occurrence)
    SELECT
          source.ID_Patient, source.ID_Encounter, source.ID_Code, source.StartDate, source.StopDate, source.Occurrence
    FROM
        #Source source
    WHERE
        NOT EXISTS (
            SELECT 1 FROM clinical.Condition target
            WHERE target.ID_Encounter = source.ID_Encounter AND target.ID_Code = source.ID_Code
              AND target.StartDate = source.StartDate AND target.Occurrence = source.Occurrence AND target.ID > 0
        );
    SET @Inserted = @@ROWCOUNT;

    COMMIT TRANSACTION;

    PRINT CONCAT(N'stage.spMerge_Condition: inserted ', @Inserted, N', updated ', @Updated, N', skipped ', @Skipped);
END
GO

PRINT N'stage.spMerge_Condition - Script Done';
GO