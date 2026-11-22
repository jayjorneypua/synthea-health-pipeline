SELECT
    provider.ID                 AS provider_id
  , provider.ID_Organization    AS organization_id
  , provider.Name               AS name
  , provider.Gender             AS gender
  , provider.Speciality         AS speciality
FROM
    {{ source('silver', 'ref_provider') }} provider
WHERE
    provider.Deleted = false