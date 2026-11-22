SELECT
    organization.ID             AS organization_id
  , organization.Name           AS name
  , organization.ID_Location    AS location_id
FROM
    {{ source('silver', 'ref_organization') }} organization
WHERE
    organization.Deleted = false