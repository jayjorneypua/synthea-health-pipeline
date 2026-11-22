--=====================================================================================================
--                                        ref.UsState Table
--=====================================================================================================
-- Purpose:  Static lookup of US state codes and names. Synthea patients use full names
--           ("Massachusetts") while organizations and providers use codes ("MA").
--=====================================================================================================
IF OBJECT_ID(N'ref.UsState', N'U') IS NULL BEGIN
    PRINT N'ref.UsState - Creating';

    CREATE TABLE ref.UsState (
          Code                NCHAR(2)            NOT NULL
        , Name                NVARCHAR(50)        NOT NULL
        , CONSTRAINT pk_ref_usstate_Code PRIMARY KEY CLUSTERED (Code)
    );

    CREATE UNIQUE NONCLUSTERED INDEX UX_UsState_Name ON ref.UsState (Name);
END
GO

-- Seed (idempotent)
INSERT INTO ref.UsState (Code, Name)
SELECT v.Code, v.Name
FROM (VALUES
      (N'AL', N'Alabama'), (N'AK', N'Alaska'), (N'AZ', N'Arizona'), (N'AR', N'Arkansas'), (N'CA', N'California')
    , (N'CO', N'Colorado'), (N'CT', N'Connecticut'), (N'DE', N'Delaware'), (N'DC', N'District of Columbia'), (N'FL', N'Florida')
    , (N'GA', N'Georgia'), (N'HI', N'Hawaii'), (N'ID', N'Idaho'), (N'IL', N'Illinois'), (N'IN', N'Indiana')
    , (N'IA', N'Iowa'), (N'KS', N'Kansas'), (N'KY', N'Kentucky'), (N'LA', N'Louisiana'), (N'ME', N'Maine')
    , (N'MD', N'Maryland'), (N'MA', N'Massachusetts'), (N'MI', N'Michigan'), (N'MN', N'Minnesota'), (N'MS', N'Mississippi')
    , (N'MO', N'Missouri'), (N'MT', N'Montana'), (N'NE', N'Nebraska'), (N'NV', N'Nevada'), (N'NH', N'New Hampshire')
    , (N'NJ', N'New Jersey'), (N'NM', N'New Mexico'), (N'NY', N'New York'), (N'NC', N'North Carolina'), (N'ND', N'North Dakota')
    , (N'OH', N'Ohio'), (N'OK', N'Oklahoma'), (N'OR', N'Oregon'), (N'PA', N'Pennsylvania'), (N'RI', N'Rhode Island')
    , (N'SC', N'South Carolina'), (N'SD', N'South Dakota'), (N'TN', N'Tennessee'), (N'TX', N'Texas'), (N'UT', N'Utah')
    , (N'VT', N'Vermont'), (N'VA', N'Virginia'), (N'WA', N'Washington'), (N'WV', N'West Virginia'), (N'WI', N'Wisconsin')
    , (N'WY', N'Wyoming')
) v (Code, Name)
WHERE NOT EXISTS (SELECT 1 FROM ref.UsState s WHERE s.Code = v.Code);
GO

PRINT N'ref.UsState - Script Done';
GO