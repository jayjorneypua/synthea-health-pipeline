--=====================================================================================================
--                          stage.spMerge_Claim Stored Procedure
--=====================================================================================================
-- Purpose:  stage.Claim -> clinical.Claim. Run after patients, providers, encounters and codes.
--           APPOINTMENTID is the encounter. Updates only changed rows, inserts new rows.
--=====================================================================================================
PRINT N'stage.spMerge_Claim - Creating';
GO

CREATE OR ALTER PROCEDURE stage.spMerge_Claim
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Updated INT;
    DECLARE @Inserted INT;

    SELECT
          TRY_CONVERT(UNIQUEIDENTIFIER, TRIM(claim.[Id]))                                                AS SourceKey
        , ISNULL(patient.ID, 0)                                                                           AS ID_Patient
        , ISNULL(provider.ID, 0)                                                                          AS ID_Provider
        , ISNULL(encounter.ID, 0)                                                                         AS ID_Encounter
        , ISNULL(diagnosisCode.ID, 0)                                                                     AS ID_DiagnosisCode
        , ISNULL(TRY_CONVERT(DATETIME2(0), claim.SERVICEDATE, 127), CAST('1900-01-01' AS DATETIME2(0)))   AS ServiceDate
        , TRY_CONVERT(DATETIME2(0), claim.CURRENTILLNESSDATE, 127)                                        AS CurrentIllnessDate
        , LEFT(ISNULL(TRIM(claim.STATUS1), N''), 20)                                                      AS PrimaryStatus
        , LEFT(ISNULL(TRIM(claim.STATUS2), N''), 20)                                                      AS SecondaryStatus
        , LEFT(ISNULL(TRIM(claim.STATUSP), N''), 20)                                                      AS PatientStatus
        , ISNULL(TRY_CONVERT(DECIMAL(14, 2), claim.OUTSTANDING1), 0)                                      AS PrimaryOutstanding
        , ISNULL(TRY_CONVERT(DECIMAL(14, 2), claim.OUTSTANDING2), 0)                                      AS SecondaryOutstanding
        , ISNULL(TRY_CONVERT(DECIMAL(14, 2), claim.OUTSTANDINGP), 0)                                      AS PatientOutstanding
        , TRY_CONVERT(DATETIME2(0), claim.LASTBILLEDDATE1, 127)                                           AS PrimaryLastBilledDate
        , TRY_CONVERT(DATETIME2(0), claim.LASTBILLEDDATE2, 127)                                           AS SecondaryLastBilledDate
        , TRY_CONVERT(DATETIME2(0), claim.LASTBILLEDDATEP, 127)                                           AS PatientLastBilledDate
        , ISNULL(TRY_CONVERT(TINYINT, claim.HEALTHCARECLAIMTYPEID1), 0)                                   AS PrimaryClaimType
        , ISNULL(TRY_CONVERT(TINYINT, claim.HEALTHCARECLAIMTYPEID2), 0)                                   AS SecondaryClaimType
        , ROW_NUMBER() OVER (PARTITION BY TRIM(claim.[Id]) ORDER BY claim.StageID DESC)                  AS RowNumber
    INTO
        #Source
    FROM
        stage.Claim claim
        LEFT JOIN clinical.Patient patient
            ON patient.SourceKey = TRY_CONVERT(UNIQUEIDENTIFIER, TRIM(claim.PATIENTID)) AND patient.ID > 0
        LEFT JOIN ref.Provider provider
            ON provider.SourceKey = TRY_CONVERT(UNIQUEIDENTIFIER, TRIM(claim.PROVIDERID)) AND provider.ID > 0
        LEFT JOIN clinical.Encounter encounter
            ON encounter.SourceKey = TRY_CONVERT(UNIQUEIDENTIFIER, TRIM(claim.APPOINTMENTID)) AND encounter.ID > 0
        LEFT JOIN ref.Code diagnosisCode
            ON diagnosisCode.CodeSystem = N'SNOMED-CT' AND diagnosisCode.Code = TRIM(claim.DIAGNOSIS1) AND diagnosisCode.ID > 0;

    DELETE FROM #Source WHERE RowNumber > 1 OR SourceKey IS NULL;

    BEGIN TRANSACTION;

    UPDATE target
    SET
          target.ID_Patient              = source.ID_Patient
        , target.ID_Provider             = source.ID_Provider
        , target.ID_Encounter            = source.ID_Encounter
        , target.ID_DiagnosisCode        = source.ID_DiagnosisCode
        , target.ServiceDate             = source.ServiceDate
        , target.CurrentIllnessDate      = source.CurrentIllnessDate
        , target.PrimaryStatus           = source.PrimaryStatus
        , target.SecondaryStatus         = source.SecondaryStatus
        , target.PatientStatus           = source.PatientStatus
        , target.PrimaryOutstanding      = source.PrimaryOutstanding
        , target.SecondaryOutstanding    = source.SecondaryOutstanding
        , target.PatientOutstanding      = source.PatientOutstanding
        , target.PrimaryLastBilledDate   = source.PrimaryLastBilledDate
        , target.SecondaryLastBilledDate = source.SecondaryLastBilledDate
        , target.PatientLastBilledDate   = source.PatientLastBilledDate
        , target.PrimaryClaimType        = source.PrimaryClaimType
        , target.SecondaryClaimType      = source.SecondaryClaimType
        , target.Deleted                 = 0
        , target.ID_UpdatedBy            = 1
        , target.UpdatedDate             = SYSUTCDATETIME()
    FROM
        clinical.Claim target
        INNER JOIN #Source source
            ON source.SourceKey = target.SourceKey
    WHERE
        target.ID > 0
        AND EXISTS (
            SELECT target.ID_Patient, target.ID_Provider, target.ID_Encounter, target.ID_DiagnosisCode, target.ServiceDate, target.CurrentIllnessDate
                 , target.PrimaryStatus, target.SecondaryStatus, target.PatientStatus, target.PrimaryOutstanding, target.SecondaryOutstanding, target.PatientOutstanding
                 , target.PrimaryLastBilledDate, target.SecondaryLastBilledDate, target.PatientLastBilledDate, target.PrimaryClaimType, target.SecondaryClaimType, target.Deleted
            EXCEPT
            SELECT source.ID_Patient, source.ID_Provider, source.ID_Encounter, source.ID_DiagnosisCode, source.ServiceDate, source.CurrentIllnessDate
                 , source.PrimaryStatus, source.SecondaryStatus, source.PatientStatus, source.PrimaryOutstanding, source.SecondaryOutstanding, source.PatientOutstanding
                 , source.PrimaryLastBilledDate, source.SecondaryLastBilledDate, source.PatientLastBilledDate, source.PrimaryClaimType, source.SecondaryClaimType, CAST(0 AS BIT)
        );
    SET @Updated = @@ROWCOUNT;

    INSERT INTO clinical.Claim (
          SourceKey, ID_Patient, ID_Provider, ID_Encounter, ID_DiagnosisCode, ServiceDate, CurrentIllnessDate
        , PrimaryStatus, SecondaryStatus, PatientStatus, PrimaryOutstanding, SecondaryOutstanding, PatientOutstanding
        , PrimaryLastBilledDate, SecondaryLastBilledDate, PatientLastBilledDate, PrimaryClaimType, SecondaryClaimType
    )
    SELECT
          source.SourceKey, source.ID_Patient, source.ID_Provider, source.ID_Encounter, source.ID_DiagnosisCode, source.ServiceDate, source.CurrentIllnessDate
        , source.PrimaryStatus, source.SecondaryStatus, source.PatientStatus, source.PrimaryOutstanding, source.SecondaryOutstanding, source.PatientOutstanding
        , source.PrimaryLastBilledDate, source.SecondaryLastBilledDate, source.PatientLastBilledDate, source.PrimaryClaimType, source.SecondaryClaimType
    FROM
        #Source source
    WHERE
        NOT EXISTS (SELECT 1 FROM clinical.Claim target WHERE target.SourceKey = source.SourceKey AND target.ID > 0);
    SET @Inserted = @@ROWCOUNT;

    COMMIT TRANSACTION;

    PRINT CONCAT(N'stage.spMerge_Claim: inserted ', @Inserted, N', updated ', @Updated);
END
GO

PRINT N'stage.spMerge_Claim - Script Done';
GO