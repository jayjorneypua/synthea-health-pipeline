--=====================================================================================================
--                          stage.spLoad_All Stored Procedure
--=====================================================================================================
-- Purpose:  Runs every merge in dependency order as one transaction (all or nothing), then
--           clears the stage tables so the database stays small.
--=====================================================================================================
PRINT N'stage.spLoad_All - Creating';
GO

CREATE OR ALTER PROCEDURE stage.spLoad_All
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRANSACTION;

    EXEC stage.spMerge_Location;
    EXEC stage.spMerge_Code;
    EXEC stage.spMerge_Payer;
    EXEC stage.spMerge_Organization;
    EXEC stage.spMerge_Provider;
    EXEC stage.spMerge_Patient;
    EXEC stage.spMerge_Encounter;
    EXEC stage.spMerge_Condition;
    EXEC stage.spMerge_Medication;
    EXEC stage.spMerge_Procedure;

    DELETE FROM stage.Payer;
    DELETE FROM stage.Organization;
    DELETE FROM stage.Provider;
    DELETE FROM stage.Patient;
    DELETE FROM stage.Encounter;
    DELETE FROM stage.Condition;
    DELETE FROM stage.Medication;
    DELETE FROM stage.[Procedure];

    COMMIT TRANSACTION;

    PRINT N'stage.spLoad_All: done';
END
GO

PRINT N'stage.spLoad_All - Script Done';
GO