--=====================================================================================================
--                          stage.spMerge_Code Stored Procedure
--=====================================================================================================
-- Purpose:  Collects every code used in the clinical stage tables into ref.Code.
--           Encounter and reason codes are SNOMED-CT, medication codes are RxNorm, conditions and
--           procedures carry their own SYSTEM. When one code has several descriptions, the
--           alphabetically first is kept. Inserts only missing codes.
--=====================================================================================================
PRINT N'stage.spMerge_Code - Creating';
GO

CREATE OR ALTER PROCEDURE stage.spMerge_Code
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    ;WITH Source AS (
        SELECT N'SNOMED-CT' AS CodeSystem, TRIM(CODE) AS Code, TRIM([DESCRIPTION]) AS Description FROM stage.Encounter
        UNION ALL SELECT N'SNOMED-CT', TRIM(REASONCODE), TRIM(REASONDESCRIPTION) FROM stage.Encounter
        UNION ALL SELECT TRIM([SYSTEM]), TRIM(CODE), TRIM([DESCRIPTION]) FROM stage.Condition
        UNION ALL SELECT TRIM([SYSTEM]), TRIM(CODE), TRIM([DESCRIPTION]) FROM stage.[Procedure]
        UNION ALL SELECT N'SNOMED-CT', TRIM(REASONCODE), TRIM(REASONDESCRIPTION) FROM stage.[Procedure]
        UNION ALL SELECT N'RxNorm', TRIM(CODE), TRIM([DESCRIPTION]) FROM stage.Medication
        UNION ALL SELECT N'SNOMED-CT', TRIM(REASONCODE), TRIM(REASONDESCRIPTION) FROM stage.Medication
    ), CodeList AS (
        SELECT
              LEFT(source.CodeSystem, 20)            AS CodeSystem
            , source.Code
            , MIN(ISNULL(source.Description, N''))   AS Description
        FROM
            Source source
        WHERE
            NULLIF(source.Code, N'') IS NOT NULL
            AND NULLIF(source.CodeSystem, N'') IS NOT NULL
        GROUP BY
              LEFT(source.CodeSystem, 20)
            , source.Code
    )
    INSERT INTO ref.Code (CodeSystem, Code, Description)
    SELECT
          codeList.CodeSystem
        , codeList.Code
        , LEFT(codeList.Description, 1000)
    FROM
        CodeList codeList
    WHERE
        NOT EXISTS (
            SELECT 1
            FROM ref.Code existing
            WHERE existing.CodeSystem = codeList.CodeSystem
              AND existing.Code = codeList.Code
              AND existing.ID > 0
        );
END
GO

PRINT N'stage.spMerge_Code - Script Done';
GO