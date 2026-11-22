-- SNOMED-CT and RxNorm codes. code_id 0 = (None)
SELECT
    code.ID             AS code_id
  , code.CodeSystem     AS code_system
  , code.Code           AS code
  , code.Description    AS description
FROM
    {{ source('silver', 'ref_code') }} code
WHERE
    code.Deleted = false