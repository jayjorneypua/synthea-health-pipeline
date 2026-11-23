-- one row per claim. patient_version_key comes from the claim's encounter (fct_encounters),
-- so the SCD2 version lookup lives in one place. line totals are rolled up from fct_claim_lines.
WITH claims AS (
    SELECT
        *
    FROM
        {{ source('silver', 'clinical_claim') }}
    WHERE
        ID > 0
        AND Deleted = false
)
, line_totals AS (
    SELECT
        claim_id
      , SUM(CASE WHEN transaction_type = 'CHARGE' THEN amount ELSE 0 END)       AS total_charges
      , SUM(CASE WHEN transaction_type = 'PAYMENT' THEN amount ELSE 0 END)      AS total_payments
      , SUM(CASE WHEN transaction_type = 'ADJUSTMENT' THEN amount ELSE 0 END)   AS total_adjustments
      , COUNT(*)                                                                AS line_count
    FROM
        {{ ref('fct_claim_lines') }}
    GROUP BY
        claim_id
)
SELECT
    claims.ID                                                           AS claim_id
  , claims.ID_Encounter                                                 AS encounter_id
  , claims.ID_Patient                                                   AS patient_id
  , encounters.patient_version_key
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
  , COALESCE(line_totals.total_adjustments, 0)                          AS total_adjustments
  , COALESCE(line_totals.line_count, 0)                                 AS line_count
FROM
    claims
LEFT JOIN
    {{ ref('fct_encounters') }} encounters
    ON encounters.encounter_id = claims.ID_Encounter
LEFT JOIN
    line_totals
    ON line_totals.claim_id = claims.ID