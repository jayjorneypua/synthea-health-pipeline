SELECT
    payer.ID            AS payer_id
  , payer.Name          AS name
  , payer.Ownership     AS ownership
FROM
    {{ source('silver', 'ref_payer') }} payer
WHERE
    payer.Deleted = false