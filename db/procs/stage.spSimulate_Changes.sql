--=====================================================================================================
--                          stage.spSimulate_Changes Stored Procedure
--=====================================================================================================
-- Purpose:  Makes small random OLTP changes so CDC has updates and deletes, and silver has SCD2
--           material. Runs after spLoad_All. The next spLoad_All reverts these (same Synthea seed),
--           which also shows up in CDC. In stage so role_Loader can run it without new grants.
--
--           Patient moves        UPDATE  new city + address (SCD2)
--           Encounter deletes    UPDATE  Deleted = 1 on encounter and its conditions, meds, procedures
--           Cost changes         UPDATE  TotalClaimCost -10% to +20% (never 0%), coverage capped
--           Condition deletes    DELETE  hard delete (CDC operation 1)
--=====================================================================================================
PRINT N'stage.spSimulate_Changes - Creating';
GO

CREATE OR ALTER PROCEDURE stage.spSimulate_Changes
      @PatientMoves       INT = 3
    , @EncounterDeletes   INT = 3
    , @CostChanges        INT = 10
    , @ConditionDeletes   INT = 2
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Moved INT;
    DECLARE @EncountersDeleted INT;
    DECLARE @ChildrenDeleted INT = 0;
    DECLARE @CostsChanged INT;
    DECLARE @ConditionsDeleted INT;

    --------------------------------------------------------------------------------
    -- Step 1: Pick rows (random)
    --------------------------------------------------------------------------------
    SELECT TOP (@PatientMoves) ID, ID_Location
    INTO #Moves
    FROM clinical.Patient
    WHERE ID > 0 AND Deleted = 0
    ORDER BY NEWID();

    SELECT TOP (@EncounterDeletes) ID
    INTO #DeletedEncounters
    FROM clinical.Encounter
    WHERE ID > 0 AND Deleted = 0
    ORDER BY NEWID();

    SELECT TOP (@CostChanges) encounter.ID, (ABS(CHECKSUM(NEWID())) % 30) - 10 AS Pct
    INTO #Costs
    FROM clinical.Encounter encounter
    WHERE encounter.ID > 0
        AND encounter.Deleted = 0
        AND encounter.TotalClaimCost >= 10
        AND NOT EXISTS (SELECT 1 FROM #DeletedEncounters deleted WHERE deleted.ID = encounter.ID)
    ORDER BY NEWID();

    UPDATE #Costs SET Pct = Pct + 1 WHERE Pct >= 0;  -- -10..-1 and 1..20, never 0 (no fake updates)

    BEGIN TRANSACTION;

    --------------------------------------------------------------------------------
    -- Step 2: Patient moves
    --------------------------------------------------------------------------------
    UPDATE target
    SET
          target.ID_Location  = newCity.ID
        , target.Address      = CONCAT(ABS(CHECKSUM(NEWID())) % 9000 + 100, N' Simulated St')
        , target.ID_UpdatedBy = 1
        , target.UpdatedDate  = SYSUTCDATETIME()
    FROM
        clinical.Patient target
        INNER JOIN #Moves moves
            ON moves.ID = target.ID
        CROSS APPLY (
            SELECT TOP 1 city.ID
            FROM ref.Location city
            WHERE city.LocationType = N'City'
                AND city.Deleted = 0
                AND city.ID <> moves.ID_Location
            ORDER BY NEWID()
        ) newCity;
    SET @Moved = @@ROWCOUNT;

    --------------------------------------------------------------------------------
    -- Step 3: Encounter soft deletes (cascade to children)
    --------------------------------------------------------------------------------
    UPDATE clinical.Encounter
    SET Deleted = 1, ID_UpdatedBy = 1, UpdatedDate = SYSUTCDATETIME()
    WHERE ID IN (SELECT ID FROM #DeletedEncounters);
    SET @EncountersDeleted = @@ROWCOUNT;

    UPDATE clinical.Condition
    SET Deleted = 1, ID_UpdatedBy = 1, UpdatedDate = SYSUTCDATETIME()
    WHERE ID_Encounter IN (SELECT ID FROM #DeletedEncounters) AND Deleted = 0;
    SET @ChildrenDeleted = @ChildrenDeleted + @@ROWCOUNT;

    UPDATE clinical.Medication
    SET Deleted = 1, ID_UpdatedBy = 1, UpdatedDate = SYSUTCDATETIME()
    WHERE ID_Encounter IN (SELECT ID FROM #DeletedEncounters) AND Deleted = 0;
    SET @ChildrenDeleted = @ChildrenDeleted + @@ROWCOUNT;

    UPDATE clinical.[Procedure]
    SET Deleted = 1, ID_UpdatedBy = 1, UpdatedDate = SYSUTCDATETIME()
    WHERE ID_Encounter IN (SELECT ID FROM #DeletedEncounters) AND Deleted = 0;
    SET @ChildrenDeleted = @ChildrenDeleted + @@ROWCOUNT;

    --------------------------------------------------------------------------------
    -- Step 4: Cost changes
    --------------------------------------------------------------------------------
    UPDATE target
    SET
          target.TotalClaimCost = adjusted.NewTotal
        , target.PayerCoverage  = CASE WHEN target.PayerCoverage > adjusted.NewTotal THEN adjusted.NewTotal ELSE target.PayerCoverage END
        , target.ID_UpdatedBy   = 1
        , target.UpdatedDate    = SYSUTCDATETIME()
    FROM
        clinical.Encounter target
        INNER JOIN #Costs costs
            ON costs.ID = target.ID
        CROSS APPLY (
            SELECT CAST(target.TotalClaimCost * (100 + costs.Pct) / 100.0 AS DECIMAL(14, 2)) AS NewTotal
        ) adjusted;
    SET @CostsChanged = @@ROWCOUNT;

    --------------------------------------------------------------------------------
    -- Step 5: Condition hard deletes
    --------------------------------------------------------------------------------
    DELETE FROM clinical.Condition
    WHERE ID IN (
        SELECT TOP (@ConditionDeletes) ID
        FROM clinical.Condition
        WHERE ID > 0 AND Deleted = 0
        ORDER BY NEWID()
    );
    SET @ConditionsDeleted = @@ROWCOUNT;

    COMMIT TRANSACTION;

    PRINT CONCAT(N'stage.spSimulate_Changes: moved ', @Moved
        , N', encounters soft-deleted ', @EncountersDeleted
        , N' (children ', @ChildrenDeleted, N')'
        , N', costs changed ', @CostsChanged
        , N', conditions hard-deleted ', @ConditionsDeleted);
END
GO

PRINT N'stage.spSimulate_Changes - Script Done';
GO