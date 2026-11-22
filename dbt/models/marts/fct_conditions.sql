-- diagnoses; rows of soft-deleted encounters are excluded
SELECT
    condition.ID                                                AS condition_id
  , condition.ID_Patient                                        AS patient_id
  , condition.ID_Encounter                                      AS encounter_id
  , condition.ID_Code                                           AS code_id
  , CAST(date_format(condition.StartDate, 'yyyyMMdd') AS INT)   AS start_date_key
  , condition.StartDate                                         AS start_date
  , condition.StopDate                                          AS stop_date
  , condition.StopDate IS NULL                                  AS is_active
  , condition.Occurrence                                        AS occurrence
FROM
    {{ source('silver', 'clinical_condition') }} condition
INNER JOIN
    {{ source('silver', 'clinical_encounter') }} encounter
    ON encounter.ID = condition.ID_Encounter
    AND encounter.Deleted = false
WHERE
    condition.ID > 0
    AND condition.Deleted = false