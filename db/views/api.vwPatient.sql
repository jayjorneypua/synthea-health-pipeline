--=====================================================================================================
--                                        api.vwPatient View
--=====================================================================================================
-- Purpose:  Consumer view of clinical.Patient. Hides Deleted = 1, keeps row 0.
--=====================================================================================================
CREATE OR ALTER VIEW api.vwPatient
AS
SELECT
      ID
    , ID_Location
    , SourceKey
    , Prefix
    , FirstName
    , MiddleName
    , LastName
    , Suffix
    , MaidenName
    , MaritalStatus
    , Race
    , Ethnicity
    , Gender
    , BirthPlace
    , Address
    , Zip
    , Latitude
    , Longitude
    , BirthDate
    , DeathDate
    , Income
    , CreatedDate
    , UpdatedDate
FROM
    clinical.Patient
WHERE
    Deleted = 0;
GO

PRINT N'api.vwPatient - Script Done';
GO
