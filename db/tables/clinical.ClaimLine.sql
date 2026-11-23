--=====================================================================================================
--                                        clinical.ClaimLine Table
--=====================================================================================================
-- Purpose:  Claim transactions: charges, payments, adjustments and transfers per claim.
--           ChargeID groups a charge with the payments and adjustments applied to it. Dates are UTC.
--=====================================================================================================
IF OBJECT_ID(N'clinical.ClaimLine', N'U') IS NULL BEGIN
    PRINT N'clinical.ClaimLine - Creating';

    CREATE TABLE clinical.ClaimLine (
          ID                  INT                 NOT NULL     IDENTITY(0, 1)
        , ID_Claim            INT                 NOT NULL     CONSTRAINT df_clinical_claimline_ID_Claim          DEFAULT(0)  --from clinical.Claim
        , ID_Provider         INT                 NOT NULL     CONSTRAINT df_clinical_claimline_ID_Provider       DEFAULT(0)  --from ref.Provider
        , ID_Organization     INT                 NOT NULL     CONSTRAINT df_clinical_claimline_ID_Organization   DEFAULT(0)  --from ref.Organization (place of service)
        , ID_ProcedureCode    INT                 NOT NULL     CONSTRAINT df_clinical_claimline_ID_ProcedureCode  DEFAULT(0)  --from ref.Code

        --------------------------------------------------------------------------------
        , SourceKey           UNIQUEIDENTIFIER    NOT NULL     CONSTRAINT df_clinical_claimline_SourceKey         DEFAULT('00000000-0000-0000-0000-000000000000')
        , ChargeID            INT                 NOT NULL     CONSTRAINT df_clinical_claimline_ChargeID          DEFAULT(0)
        , TransactionType     NVARCHAR(20)        NOT NULL     CONSTRAINT df_clinical_claimline_TransactionType   DEFAULT('')  --CHARGE, PAYMENT, ADJUSTMENT, TRANSFERIN, TRANSFEROUT
        , PaymentMethod       NVARCHAR(20)        NOT NULL     CONSTRAINT df_clinical_claimline_PaymentMethod     DEFAULT('')
        , TransferType        NVARCHAR(10)        NOT NULL     CONSTRAINT df_clinical_claimline_TransferType      DEFAULT('')  --1 primary, 2 secondary, p patient
        , FromDate            DATETIME2(0)        NOT NULL     CONSTRAINT df_clinical_claimline_FromDate          DEFAULT('1900-01-01')
        , ToDate              DATETIME2(0)        NULL
        , Units               DECIMAL(10, 2)      NOT NULL     CONSTRAINT df_clinical_claimline_Units             DEFAULT(0)
        , UnitAmount          DECIMAL(14, 2)      NOT NULL     CONSTRAINT df_clinical_claimline_UnitAmount        DEFAULT(0)
        , Amount              DECIMAL(14, 2)      NOT NULL     CONSTRAINT df_clinical_claimline_Amount            DEFAULT(0)
        , Payments            DECIMAL(14, 2)      NOT NULL     CONSTRAINT df_clinical_claimline_Payments          DEFAULT(0)
        , Adjustments         DECIMAL(14, 2)      NOT NULL     CONSTRAINT df_clinical_claimline_Adjustments       DEFAULT(0)
        , Transfers           DECIMAL(14, 2)      NOT NULL     CONSTRAINT df_clinical_claimline_Transfers         DEFAULT(0)
        , Outstanding         DECIMAL(14, 2)      NOT NULL     CONSTRAINT df_clinical_claimline_Outstanding       DEFAULT(0)

        --------------------------------------------------------------------------------
        -- Standard Fields
        --------------------------------------------------------------------------------
        , Deleted             BIT                 NOT NULL     CONSTRAINT df_clinical_claimline_Deleted           DEFAULT(0)
        , ID_CreatedBy        INT                 NOT NULL     CONSTRAINT df_clinical_claimline_ID_CreatedBy      DEFAULT(1)
        , CreatedDate         DATETIME2           NOT NULL     CONSTRAINT df_clinical_claimline_CreatedDate       DEFAULT(SYSUTCDATETIME())
        , ID_UpdatedBy        INT                 NOT NULL     CONSTRAINT df_clinical_claimline_ID_UpdatedBy      DEFAULT(0)
        , UpdatedDate         DATETIME2           NULL

        , CONSTRAINT pk_clinical_claimline_ID PRIMARY KEY CLUSTERED (ID)
    );

    SET IDENTITY_INSERT clinical.ClaimLine ON;
    INSERT INTO clinical.ClaimLine (ID, TransactionType) VALUES (0, N'(None)');
    SET IDENTITY_INSERT clinical.ClaimLine OFF;

    CREATE UNIQUE NONCLUSTERED INDEX UX_ClaimLine_SourceKey ON clinical.ClaimLine (SourceKey) WHERE ID > 0;
    CREATE NONCLUSTERED INDEX IX_ClaimLine_ID_Claim ON clinical.ClaimLine (ID_Claim, ChargeID);
    CREATE NONCLUSTERED INDEX IX_ClaimLine_ID_Provider ON clinical.ClaimLine (ID_Provider);
    CREATE NONCLUSTERED INDEX IX_ClaimLine_ID_Organization ON clinical.ClaimLine (ID_Organization);

    ALTER TABLE clinical.ClaimLine ADD CONSTRAINT fk_clinical_claimline_ID_Claim         FOREIGN KEY (ID_Claim)         REFERENCES clinical.Claim(ID);
    ALTER TABLE clinical.ClaimLine ADD CONSTRAINT fk_clinical_claimline_ID_Provider      FOREIGN KEY (ID_Provider)      REFERENCES ref.Provider(ID);
    ALTER TABLE clinical.ClaimLine ADD CONSTRAINT fk_clinical_claimline_ID_Organization  FOREIGN KEY (ID_Organization)  REFERENCES ref.Organization(ID);
    ALTER TABLE clinical.ClaimLine ADD CONSTRAINT fk_clinical_claimline_ID_ProcedureCode FOREIGN KEY (ID_ProcedureCode) REFERENCES ref.Code(ID);
    ALTER TABLE clinical.ClaimLine ADD CONSTRAINT fk_clinical_claimline_ID_CreatedBy     FOREIGN KEY (ID_CreatedBy)     REFERENCES security.[User](ID);
    ALTER TABLE clinical.ClaimLine ADD CONSTRAINT fk_clinical_claimline_ID_UpdatedBy     FOREIGN KEY (ID_UpdatedBy)     REFERENCES security.[User](ID);
END
GO

PRINT N'clinical.ClaimLine - Script Done';
GO