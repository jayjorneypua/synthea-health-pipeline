--=====================================================================================================
--                          stage.spMerge_Encounter Stored Procedure
--=====================================================================================================
-- Purpose:  stage.Encounter -> clinical.Encounter. Run after patients, organizations, providers,
--           payers and codes. Updates only changed rows, inserts new rows.
--=====================================================================================================
PRINT N'stage.spMerge_Encounter - Creating';
GO

CREATE OR ALTER PROCEDURE stage.spMerge_Encounter
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Updated INT;
    DECLARE @Inserted INT;

    SELECT
          TRY_CONVERT(UNIQUEIDENTIFIER, TRIM(encounter.[Id]))                                         AS SourceKey
        , ISNULL(patient.ID, 0)                                                                        AS ID_Patient
        , ISNULL(organization.ID, 0)                                                                   AS ID_Organization
        , ISNULL(provider.ID, 0)                                                                       AS ID_Provider
        , ISNULL(payer.ID, 0)                                                                          AS ID_Payer
        , ISNULL(code.ID, 0)                                                                           AS ID_Code
        , ISNULL(reasonCode.ID, 0)                                                                     AS ID_ReasonCode
        , LEFT(ISNULL(TRIM(encounter.ENCOUNTERCLASS), N''), 20)                                        AS EncounterClass
        , ISNULL(TRY_CONVERT(DATETIME2(0), encounter.[START], 127), CAST('1900-01-01' AS DATETIME2(0))) AS StartDate
        , TRY_CONVERT(DATETIME2(0), encounter.[STOP], 127)                                             AS StopDate
        , ISNULL(TRY_CONVERT(DECIMAL(14, 2), encounter.BASE_ENCOUNTER_COST), 0)                        AS BaseEncounterCost
        , ISNULL(TRY_CONVERT(DECIMAL(14, 2), encounter.TOTAL_CLAIM_COST), 0)                           AS TotalClaimCost
        , ISNULL(TRY_CONVERT(DECIMAL(14, 2), encounter.PAYER_COVERAGE), 0)                             AS PayerCoverage
        , ROW_NUMBER() OVER (PARTITION BY TRIM(encounter.[Id]) ORDER BY encounter.StageID DESC)       AS RowNumber
    INTO
        #Source
    FROM
        stage.Encounter encounter
        LEFT JOIN clinical.Patient patient
            ON patient.SourceKey = TRY_CONVERT(UNIQUEIDENTIFIER, TRIM(encounter.PATIENT)) AND patient.ID > 0
        LEFT JOIN ref.Organization organization
            ON organization.SourceKey = TRY_CONVERT(UNIQUEIDENTIFIER, TRIM(encounter.ORGANIZATION)) AND organization.ID > 0
        LEFT JOIN ref.Provider provider
            ON provider.SourceKey = TRY_CONVERT(UNIQUEIDENTIFIER, TRIM(encounter.PROVIDER)) AND provider.ID > 0
        LEFT JOIN ref.Payer payer
            ON payer.SourceKey = TRY_CONVERT(UNIQUEIDENTIFIER, TRIM(encounter.PAYER)) AND payer.ID > 0
        LEFT JOIN ref.Code code
            ON code.CodeSystem = N'SNOMED-CT' AND code.Code = TRIM(encounter.CODE) AND code.ID > 0
        LEFT JOIN ref.Code reasonCode
            ON reasonCode.CodeSystem = N'SNOMED-CT' AND reasonCode.Code = TRIM(encounter.REASONCODE) AND reasonCode.ID > 0;

    DELETE FROM #Source WHERE RowNumber > 1 OR SourceKey IS NULL;

    BEGIN TRANSACTION;

    UPDATE target
    SET
          target.ID_Patient        = source.ID_Patient
        , target.ID_Organization   = source.ID_Organization
        , target.ID_Provider       = source.ID_Provider
        , target.ID_Payer          = source.ID_Payer
        , target.ID_Code           = source.ID_Code
        , target.ID_ReasonCode     = source.ID_ReasonCode
        , target.EncounterClass    = source.EncounterClass
        , target.StartDate         = source.StartDate
        , target.StopDate          = source.StopDate
        , target.BaseEncounterCost = source.BaseEncounterCost
        , target.TotalClaimCost    = source.TotalClaimCost
        , target.PayerCoverage     = source.PayerCoverage
        , target.Deleted           = 0
        , target.ID_UpdatedBy      = 1
        , target.UpdatedDate       = SYSUTCDATETIME()
    FROM
        clinical.Encounter target
        INNER JOIN #Source source
            ON source.SourceKey = target.SourceKey
    WHERE
        target.ID > 0
        AND EXISTS (
            SELECT target.ID_Patient, target.ID_Organization, target.ID_Provider, target.ID_Payer, target.ID_Code, target.ID_ReasonCode
                 , target.EncounterClass, target.StartDate, target.StopDate, target.BaseEncounterCost, target.TotalClaimCost, target.PayerCoverage, target.Deleted
            EXCEPT
            SELECT source.ID_Patient, source.ID_Organization, source.ID_Provider, source.ID_Payer, source.ID_Code, source.ID_ReasonCode
                 , source.EncounterClass, source.StartDate, source.StopDate, source.BaseEncounterCost, source.TotalClaimCost, source.PayerCoverage, CAST(0 AS BIT)
        );
    SET @Updated = @@ROWCOUNT;

    INSERT INTO clinical.Encounter (
          SourceKey, ID_Patient, ID_Organization, ID_Provider, ID_Payer, ID_Code, ID_ReasonCode
        , EncounterClass, StartDate, StopDate, BaseEncounterCost, TotalClaimCost, PayerCoverage
    )
    SELECT
          source.SourceKey, source.ID_Patient, source.ID_Organization, source.ID_Provider, source.ID_Payer, source.ID_Code, source.ID_ReasonCode
        , source.EncounterClass, source.StartDate, source.StopDate, source.BaseEncounterCost, source.TotalClaimCost, source.PayerCoverage
    FROM
        #Source source
    WHERE
        NOT EXISTS (SELECT 1 FROM clinical.Encounter target WHERE target.SourceKey = source.SourceKey AND target.ID > 0);
    SET @Inserted = @@ROWCOUNT;

    COMMIT TRANSACTION;

    PRINT CONCAT(N'stage.spMerge_Encounter: inserted ', @Inserted, N', updated ', @Updated);
END
GO

PRINT N'stage.spMerge_Encounter - Script Done';
GO