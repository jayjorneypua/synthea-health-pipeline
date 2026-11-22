--=====================================================================================================
--                          stage.spMerge_Payer Stored Procedure
--=====================================================================================================
-- Purpose:  stage.Payer -> ref.Payer. Updates only rows whose values changed, inserts new rows.
--=====================================================================================================
PRINT N'stage.spMerge_Payer - Creating';
GO

CREATE OR ALTER PROCEDURE stage.spMerge_Payer
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Updated INT;
    DECLARE @Inserted INT;

    --------------------------------------------------------------------------------
    -- Step 1: Typed source, last row per Id
    --------------------------------------------------------------------------------
    SELECT
          TRY_CONVERT(UNIQUEIDENTIFIER, TRIM(payer.[Id]))     AS SourceKey
        , ISNULL(cityLookup.ID_City, 0)                        AS ID_Location
        , LEFT(ISNULL(TRIM(payer.[NAME]), N''), 255)           AS Name
        , LEFT(ISNULL(TRIM(payer.OWNERSHIP), N''), 50)         AS Ownership
        , LEFT(ISNULL(TRIM(payer.[ADDRESS]), N''), 255)        AS Address
        , LEFT(ISNULL(TRIM(payer.ZIP), N''), 10)               AS Zip
        , LEFT(ISNULL(TRIM(payer.PHONE), N''), 30)             AS Phone
        , ROW_NUMBER() OVER (PARTITION BY TRIM(payer.[Id]) ORDER BY payer.StageID DESC) AS RowNumber
    INTO
        #Source
    FROM
        stage.Payer payer
        LEFT JOIN stage.vwCityLookup cityLookup
            ON cityLookup.CityName = TRIM(payer.CITY)
            AND (cityLookup.StateCode = TRIM(payer.STATE_HEADQUARTERED)
                 OR cityLookup.StateName = TRIM(payer.STATE_HEADQUARTERED));

    DELETE FROM #Source WHERE RowNumber > 1 OR SourceKey IS NULL;

    BEGIN TRANSACTION;

    --------------------------------------------------------------------------------
    -- Step 2: Update changed rows
    --------------------------------------------------------------------------------
    UPDATE target
    SET
          target.ID_Location  = source.ID_Location
        , target.Name         = source.Name
        , target.Ownership    = source.Ownership
        , target.Address      = source.Address
        , target.Zip          = source.Zip
        , target.Phone        = source.Phone
        , target.Deleted      = 0
        , target.ID_UpdatedBy = 1
        , target.UpdatedDate  = SYSUTCDATETIME()
    FROM
        ref.Payer target
        INNER JOIN #Source source
            ON source.SourceKey = target.SourceKey
    WHERE
        target.ID > 0
        AND EXISTS (
            SELECT target.ID_Location, target.Name, target.Ownership, target.Address, target.Zip, target.Phone, target.Deleted
            EXCEPT
            SELECT source.ID_Location, source.Name, source.Ownership, source.Address, source.Zip, source.Phone, CAST(0 AS BIT)
        );
    SET @Updated = @@ROWCOUNT;

    --------------------------------------------------------------------------------
    -- Step 3: Insert new rows
    --------------------------------------------------------------------------------
    INSERT INTO ref.Payer (SourceKey, ID_Location, Name, Ownership, Address, Zip, Phone)
    SELECT
          source.SourceKey
        , source.ID_Location
        , source.Name
        , source.Ownership
        , source.Address
        , source.Zip
        , source.Phone
    FROM
        #Source source
    WHERE
        NOT EXISTS (SELECT 1 FROM ref.Payer target WHERE target.SourceKey = source.SourceKey AND target.ID > 0);
    SET @Inserted = @@ROWCOUNT;

    COMMIT TRANSACTION;

    PRINT CONCAT(N'stage.spMerge_Payer: inserted ', @Inserted, N', updated ', @Updated);
END
GO

PRINT N'stage.spMerge_Payer - Script Done';
GO