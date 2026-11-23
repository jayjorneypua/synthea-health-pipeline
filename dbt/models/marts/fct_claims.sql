-- one row per claim. line totals are rolled up from fct_claim_lines.
-- claims stay even when their encounter is soft-deleted (billing already happened), flagged by
-- is_encounter_deleted. patient_version_key uses the same rule as fct_encounters (version valid at
-- the service date, else the earliest version), so it does not depend on the encounter existing.
WITH claims AS (
    SELECT
        *
    FROM
        {{ source('silver', 'clinical_claim') }}
    WHERE
        ID > 0
        AND Deleted = false
)
, patient_versions AS (
    SELECT
        claims.ID                       AS claim_id
      , history.PatientVersionKey       AS patient_version_key
      , ROW_NUMBER() OVER (
            PARTITION BY
                claims.ID
            ORDER BY
                CASE
                    WHEN claims.ServiceDate >= history.ValidFrom
                         AND (history.ValidTo IS NULL OR claims.ServiceDate < history.ValidTo) THEN 0
                    ELSE 1
                END
              , history.ValidFrom
        )                               AS version_rank
    FROM
        claims
    INNER JOIN
        {{ source('silver', 'clinical_patient_history') }} history
        ON history.ID = claims.ID_Patient
)
, line_totals AS (
    SELECT
        claim_id
      , SUM(CASE WHEN transaction_type = 'CHARGE' THEN line_amount ELSE 0 END)      AS total_charges
      , SUM(CASE WHEN transaction_type = 'PAYMENT' THEN line_amount ELSE 0 END)     AS total_payments
      , SUM(CASE WHEN transaction_type = 'TRANSFERIN' THEN line_amount ELSE 0 END)  AS total_transferred
      , COUNT(*)                                                                    AS line_count
    FROM
        {{ ref('fct_claim_lines') }}
    GROUP BY
        claim_id
)
SELECT
    claims.ID                                                           AS claim_id
  , claims.ID_Encounter                                                 AS encounter_id
  , COALESCE(encounters.Deleted, false)                                 AS is_encounter_deleted
  , claims.ID_Patient                                                   AS patient_id
  , patient_versions.patient_version_key
  , claims.ID_Provider                                                  AS provider_id
  , claims.ID_DiagnosisCode                                             AS diagnosis_code_id
  , CAST(date_format(claims.ServiceDate, 'yyyyMMdd') AS INT)            AS service_date_key
  , claims.ServiceDate                                                  AS service_at
  , claims.PrimaryStatus                                                AS primary_status
  , claims.SecondaryStatus                                              AS secondary_status
  , claims.PatientStatus                                                AS patient_status
  , claims.PrimaryOutstanding                                           AS primary_outstanding
  , claims.SecondaryOutstanding                                         AS secondary_outstanding
  , claims.PatientOutstanding                                           AS patient_outstanding
  , claims.PrimaryOutstanding + claims.SecondaryOutstanding + claims.PatientOutstanding  AS total_outstanding
  , COALESCE(line_totals.total_charges, 0)                              AS total_charges
  , COALESCE(line_totals.total_payments, 0)                             AS total_payments
  , COALESCE(line_totals.total_transferred, 0)                          AS total_transferred
  , COALESCE(line_totals.line_count, 0)                                 AS line_count
FROM
    claims
LEFT JOIN
    {{ source('silver', 'clinical_encounter') }} encounters
    ON encounters.ID = claims.ID_Encounter
LEFT JOIN
    patient_versions
    ON patient_versions.claim_id = claims.ID
    AND patient_versions.version_rank = 1
LEFT JOIN
    line_totals
    ON line_totals.claim_id = claims.ID