WITH encounters AS (
    SELECT
        *
    FROM
        {{ source('silver', 'clinical_encounter') }}
    WHERE
        ID > 0
        AND Deleted = false
)
-- patient version valid at the encounter start. history starts at the first extract, so older
-- encounters fall back to the patient's earliest version
, patient_versions AS (
    SELECT
        encounters.ID                   AS encounter_id
      , history.PatientVersionKey       AS patient_version_key
      , history.ID_Location             AS location_id
      , ROW_NUMBER() OVER (
            PARTITION BY
                encounters.ID
            ORDER BY
                CASE
                    WHEN encounters.StartDate >= history.ValidFrom
                         AND (history.ValidTo IS NULL OR encounters.StartDate < history.ValidTo) THEN 0
                    ELSE 1
                END
              , history.ValidFrom
        )                               AS version_rank
    FROM
        encounters
    INNER JOIN
        {{ source('silver', 'clinical_patient_history') }} history
        ON history.ID = encounters.ID_Patient
)
-- 30-day readmission: the next inpatient admission of the same patient starts within 30 days of discharge
, inpatient AS (
    SELECT
        ID
      , StopDate
      , LEAD(StartDate) OVER (PARTITION BY ID_Patient ORDER BY StartDate)  AS next_admission_at
    FROM
        encounters
    WHERE
        EncounterClass = 'inpatient'
)
SELECT
    encounters.ID                                                       AS encounter_id
  , encounters.ID_Patient                                               AS patient_id
  , patient_versions.patient_version_key
  , COALESCE(patient_versions.location_id, 0)                           AS location_id
  , encounters.ID_Organization                                          AS organization_id
  , encounters.ID_Provider                                              AS provider_id
  , encounters.ID_Payer                                                 AS payer_id
  , encounters.ID_Code                                                  AS code_id
  , encounters.ID_ReasonCode                                            AS reason_code_id
  , encounters.EncounterClass                                           AS encounter_class
  , CAST(date_format(encounters.StartDate, 'yyyyMMdd') AS INT)          AS start_date_key
  , encounters.StartDate                                                AS start_at
  , encounters.StopDate                                                 AS stop_at
  , (unix_timestamp(encounters.StopDate) - unix_timestamp(encounters.StartDate)) / 3600.0  AS duration_hours
  , encounters.BaseEncounterCost                                        AS base_cost
  , encounters.TotalClaimCost                                           AS total_claim_cost
  , encounters.PayerCoverage                                            AS payer_coverage
  , encounters.TotalClaimCost - encounters.PayerCoverage                AS patient_cost
  , encounters.EncounterClass = 'inpatient'                             AS is_inpatient
  , COALESCE(
        inpatient.next_admission_at <= inpatient.StopDate + INTERVAL 30 DAYS
      , false
    )                                                                   AS is_readmitted_30d
FROM
    encounters
LEFT JOIN
    patient_versions
    ON patient_versions.encounter_id = encounters.ID
    AND patient_versions.version_rank = 1
LEFT JOIN
    inpatient
    ON inpatient.ID = encounters.ID