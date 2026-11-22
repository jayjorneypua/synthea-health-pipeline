--=====================================================================================================
--                          Test: ref.spLocation_UpdateHierarchy
--=====================================================================================================
-- Builds State A > County B > City C, moves County B under State D, checks City C's path and
-- level, and HasChildren on both states. Runs in a transaction and rolls back.
--=====================================================================================================
SET NOCOUNT ON;
BEGIN TRANSACTION;

DECLARE @StateA  INT;
DECLARE @StateD  INT;
DECLARE @CountyB INT;
DECLARE @CityC   INT;

INSERT INTO ref.Location (ID_Parent, Name, LocationType) VALUES (0, N'Test State A', N'State');
SET @StateA = SCOPE_IDENTITY();
EXEC ref.spLocation_UpdateHierarchy @ID = @StateA;

INSERT INTO ref.Location (ID_Parent, Name, LocationType) VALUES (@StateA, N'Test County B', N'County');
SET @CountyB = SCOPE_IDENTITY();
EXEC ref.spLocation_UpdateHierarchy @ID = @CountyB;

INSERT INTO ref.Location (ID_Parent, Name, LocationType) VALUES (@CountyB, N'Test City C', N'City');
SET @CityC = SCOPE_IDENTITY();
EXEC ref.spLocation_UpdateHierarchy @ID = @CityC;

INSERT INTO ref.Location (ID_Parent, Name, LocationType) VALUES (0, N'Test State D', N'State');
SET @StateD = SCOPE_IDENTITY();
EXEC ref.spLocation_UpdateHierarchy @ID = @StateD;

-- Move County B from State A to State D
UPDATE ref.Location SET ID_Parent = @StateD WHERE ID = @CountyB;
EXEC ref.spLocation_UpdateHierarchy @ID = @CountyB, @ID_OldParent = @StateA;

DECLARE @Expected NVARCHAR(255) = N'0,' + CAST(@StateD AS NVARCHAR(20)) + N',' + CAST(@CountyB AS NVARCHAR(20)) + N',' + CAST(@CityC AS NVARCHAR(20));
DECLARE @ActualPath  NVARCHAR(255) = (SELECT Path  FROM ref.Location WHERE ID = @CityC);
DECLARE @ActualLevel INT           = (SELECT Level FROM ref.Location WHERE ID = @CityC);
DECLARE @AHasChildren BIT          = (SELECT HasChildren FROM ref.Location WHERE ID = @StateA);
DECLARE @DHasChildren BIT          = (SELECT HasChildren FROM ref.Location WHERE ID = @StateD);

IF @ActualPath = @Expected AND @ActualLevel = 3 AND @AHasChildren = 0 AND @DHasChildren = 1 BEGIN
    PRINT N'PASS: hierarchy updated correctly';
END
ELSE BEGIN
    PRINT N'FAIL: expected ' + @Expected + N' level 3, got ' + ISNULL(@ActualPath, N'NULL') + N' level ' + ISNULL(CAST(@ActualLevel AS NVARCHAR(10)), N'NULL')
        + N'; A.HasChildren=' + CAST(@AHasChildren AS NVARCHAR(1)) + N', D.HasChildren=' + CAST(@DHasChildren AS NVARCHAR(1));
END

ROLLBACK TRANSACTION;