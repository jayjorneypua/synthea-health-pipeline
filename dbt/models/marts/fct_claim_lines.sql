-- one row per claim transaction: CHARGE, PAYMENT, TRANSFERIN, TRANSFEROUT.
-- charge_id groups a charge with the payments and transfers applied to it.
-- Synthea puts the value in a different column per type, so line_amount picks the right one:
-- CHARGE -> Amount, PAYMENT -> Payments, TRANSFERIN / TRANSFEROUT -> Transfers.
-- outstanding is the running balance after the transaction, not an amount to sum.
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
  , CASE claim_lines.TransactionType
        WHEN 'CHARGE' THEN claim_lines.Amount
        WHEN 'PAYMENT' THEN claim_lines.Payments
        WHEN 'TRANSFERIN' THEN claim_lines.Transfers
        WHEN 'TRANSFEROUT' THEN claim_lines.Transfers
        ELSE 0
    END                                                                 AS line_amount
  , claim_lines.Outstanding                                             AS outstanding_after
FROM
    claim_lines