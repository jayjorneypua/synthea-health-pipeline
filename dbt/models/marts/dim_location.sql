-- city level, with county and state flattened from the hierarchy. location_id 0 = unknown
SELECT
    city.ID                 AS location_id
  , city.Name               AS city
  , county.Name             AS county
  , state.Name              AS state
  , state.Code              AS state_code
FROM
    {{ source('silver', 'ref_location') }} city
INNER JOIN
    {{ source('silver', 'ref_location') }} county
    ON county.ID = city.ID_Parent
INNER JOIN
    {{ source('silver', 'ref_location') }} state
    ON state.ID = county.ID_Parent
WHERE
    city.LocationType = 'City'
    AND city.Deleted = false
UNION ALL
SELECT
    0                       AS location_id
  , '(None)'                AS city
  , '(None)'                AS county
  , '(None)'                AS state
  , ''                      AS state_code