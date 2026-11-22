--=====================================================================================================
--                          ref.spLocation_UpdateHierarchy Stored Procedure
--=====================================================================================================
-- Purpose:  After a location is inserted or its ID_Parent changes, recalculates Path and Level
--           for the location and all its descendants, and HasChildren for the new and old parent.
--           Paths are built top-down inside the recursive CTE, so grandchildren never read a
--           stale parent path.
-------------------------------------------------------------------------------------------------------
-- Parameters:
--   @ID            the inserted or moved location
--   @ID_OldParent  the previous parent when moved (-1 = not moved / new row)
--=====================================================================================================
PRINT N'ref.spLocation_UpdateHierarchy - Creating';
GO

CREATE OR ALTER PROCEDURE ref.spLocation_UpdateHierarchy
      @ID             INT
    , @ID_OldParent   INT = -1
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @ID_Parent    INT;
    DECLARE @ParentPath   NVARCHAR(255);
    DECLARE @ParentLevel  INT;

    IF @ID = 0 RETURN;  -- root never moves

    --------------------------------------------------------------------------------
    -- Step 1: Current parent and its path
    --------------------------------------------------------------------------------
    SELECT
        @ID_Parent = ID_Parent
    FROM
        ref.Location
    WHERE
        ID = @ID;

    IF @ID_Parent IS NULL BEGIN
        THROW 50001, N'Location not found.', 1;
    END

    SELECT
          @ParentPath  = Path
        , @ParentLevel = Level
    FROM
        ref.Location
    WHERE
        ID = @ID_Parent;

    --------------------------------------------------------------------------------
    -- Step 2: Block cycles (parent cannot be the node itself or one of its descendants)
    --------------------------------------------------------------------------------
    IF @ID_Parent = @ID
       OR (N',' + @ParentPath + N',') LIKE (N'%,' + CAST(@ID AS NVARCHAR(20)) + N',%') BEGIN
        THROW 50002, N'A location cannot be placed under itself or its descendant.', 1;
    END

    BEGIN TRANSACTION;

    --------------------------------------------------------------------------------
    -- Step 3: Node and all descendants, paths built from the top down
    --------------------------------------------------------------------------------
    ;WITH Tree AS (
        SELECT
              node.ID
            , CAST(@ParentPath + N',' + CAST(node.ID AS NVARCHAR(20)) AS NVARCHAR(255)) AS NewPath
            , @ParentLevel + 1                                                           AS NewLevel
        FROM
            ref.Location node
        WHERE
            node.ID = @ID

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
            ON tree.ID = location.ID;

    --------------------------------------------------------------------------------
    -- Step 4: HasChildren for the new parent, the old parent and the node itself
    --------------------------------------------------------------------------------
    UPDATE parent
    SET
        parent.HasChildren =
            CASE
                WHEN EXISTS (
                    SELECT 1
                    FROM ref.Location child
                    WHERE child.ID_Parent = parent.ID
                      AND child.ID <> parent.ID
                      AND child.Deleted = 0
                ) THEN 1
                ELSE 0
            END
    FROM
        ref.Location parent
    WHERE
        parent.ID IN (@ID_Parent, @ID_OldParent, @ID);

    COMMIT TRANSACTION;
END
GO

PRINT N'ref.spLocation_UpdateHierarchy - Script Done';
GO