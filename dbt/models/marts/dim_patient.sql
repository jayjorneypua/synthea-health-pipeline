-- one row per patient version (SCD2). names stay out: they are masked upstream and not needed for analytics
SELECT
    history.PatientVersionKey   AS patient_version_key
  , history.ID                  AS patient_id
  , history.ID_Location         AS location_id
  , history.Gender              AS gender
  , history.Race                AS race
  , history.Ethnicity           AS ethnicity
  , history.MaritalStatus       AS marital_status
  , history.BirthDate           AS birth_date
  , history.DeathDate           AS death_date
  , history.Income              AS income
  , history.Zip                 AS zip
  , history.ValidFrom           AS valid_from
  , history.ValidTo             AS valid_to
  , history.IsCurrent           AS is_current
FROM
    {{ source('silver', 'clinical_patient_history') }} history
WHERE
    history.ID > 0