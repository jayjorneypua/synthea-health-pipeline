-- one row per claim transaction: CHARGE, PAYMENT, ADJUSTMENT, TRANSFERIN, TRANSFEROUT.
-- charge_id groups a charge with the payments and adjustments applied to it.-- one row per claim transaction: CHARGE, PAYMENT, ADJUSTMENT, TRANSFERIN, TRANSFEROUT.
-- charge_id groups a charge with the payments and adjustments applied to it.
WITH claim_lines AS (
    SELECT
        *
    FROM
        {{ source('silver', 'clinical_claimline') }}
    WHERE
        ID > 0
        AND Deleted = false
)
SELECT
    claim_lines.ID                                                      AS claim_line_id
  , claim_lines.ID_Claim                                                AS claim_id
  , claim_lines.ChargeID                                                AS charge_id
  , claim_lines.ID_Provider                                             AS provider_id
  , claim_lines.ID_Organization                                         AS organization_id
  , claim_lines.ID_ProcedureCode                                        AS procedure_code_id
  , claim_lines.TransactionType                                         AS transaction_type
  , claim_lines.PaymentMethod                                           AS payment_method
  , claim_lines.TransferType                                            AS transfer_type
  , CAST(date_format(claim_lines.FromDate, 'yyyyMMdd') AS INT)          AS from_date_key
  , claim_lines.FromDate                                                AS from_at
  , claim_lines.ToDate                                                  AS to_at
  , claim_lines.Units                                                   AS units
  , claim_lines.UnitAmount                                              AS unit_amount
  , claim_lines.Amount                                                  AS amount
  , claim_lines.Payments                                                AS payments
  , claim_lines.Adjustments                                             AS adjustments
  , claim_lines.Transfers                                               AS transfers
  , claim_lines.Outstanding                                             AS outstanding
FROM
    claim_lines