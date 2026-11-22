-- every patient in dim_patient has at most one current version
SELECT
    patient_id
  , COUNT(*)    AS current_versions
FROM
    {{ ref('dim_patient') }}
WHERE
    is_current
GROUP BY
    patient_id
HAVING
    COUNT(*) > 1