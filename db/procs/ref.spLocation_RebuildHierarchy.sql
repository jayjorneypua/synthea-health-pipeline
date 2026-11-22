--=====================================================================================================
--                          ref.spLocation_RebuildHierarchy Stored Procedure
--=====================================================================================================
-- Purpose:  Recalculates Path, Level and HasChildren for the whole location tree in one pass.
--           Used after bulk loads; spLocation_UpdateHierarchy stays for single-row moves.
--           Only rows whose values actually change are updated, so CDC does not log fake changes.
--=====================================================================================================
PRINT N'ref.spLocation_RebuildHierarchy - Creating';
GO

CREATE OR ALTER PROCEDURE ref.spLocation_RebuildHierarchy
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRANSACTION;

    --------------------------------------------------------------------------------
    -- Step 1: Path and Level, built from the root down
    --------------------------------------------------------------------------------
    ;WITH Tree AS (
        SELECT
              root.ID
            , CAST(N'0' AS NVARCHAR(255)) AS NewPath
            , 0                           AS NewLevel
        FROM
            ref.Location root
        WHERE
            root.ID = 0

        UNION ALL

        SELECT
              child.ID
            , CAST(tree.NewPath + N',' + CAST(child.ID AS NVARCHAR(20)) AS NVARCHAR(255))
            , tree.NewLevel + 1
        FROM
            ref.Location child
            INNER JOIN Tree tree
                ON child.ID_Parent = tree.ID
        WHERE
            child.ID <> 0
    )
    UPDATE location
    SET
          location.Path  = tree.NewPath
        , location.Level = tree.NewLevel
    FROM
        ref.Location location
        INNER JOIN Tree tree
            ON tree.ID = location.ID
    WHERE
        location.Path <> tree.NewPath
        OR location.Level <> tree.NewLevel;

    --------------------------------------------------------------------------------
    -- Step 2: HasChildren
    --------------------------------------------------------------------------------
    ;WITH Computed AS (
        SELECT
              parent.ID
            , CAST(CASE
                  WHEN EXISTS (
                      SELECT 1
                      FROM ref.Location child
                      WHERE child.ID_Parent = parent.ID
                        AND child.ID <> parent.ID
                        AND child.Deleted = 0
                  ) THEN 1
                  ELSE 0
              END AS BIT) AS NewHasChildren
        FROM
            ref.Location parent
    )
    UPDATE location
    SET
        location.HasChildren = computed.NewHasChildren
    FROM
        ref.Location location
        INNER JOIN Computed computed
            ON computed.ID = location.ID
    WHERE
        location.HasChildren <> computed.NewHasChildren;

    COMMIT TRANSACTION;
END
GO

PRINT N'ref.spLocation_RebuildHierarchy - Script Done';
GO