--=====================================================================================================
--                                        etl.CdcWatermark Table
--=====================================================================================================
-- Purpose:  Last CDC LSN read per capture instance. Written by the extractor only after the
--           Parquet file is confirmed in Databricks. NULL LastLsn = needs an initial snapshot.
--=====================================================================================================
IF OBJECT_ID(N'etl.CdcWatermark', N'U') IS NULL BEGIN
    PRINT N'etl.CdcWatermark - Creating';

    CREATE TABLE etl.CdcWatermark (
          ID                  INT                 NOT NULL     IDENTITY(0, 1)

        --------------------------------------------------------------------------------
        , CaptureInstance     NVARCHAR(128)       NOT NULL     CONSTRAINT df_etl_cdcwatermark_CaptureInstance  DEFAULT('')
        , LastLsn             BINARY(10)          NULL
        , LastRunDate         DATETIME2           NULL
        , LastRowCount        INT                 NOT NULL     CONSTRAINT df_etl_cdcwatermark_LastRowCount     DEFAULT(0)

        --------------------------------------------------------------------------------
        -- Standard Fields
        --------------------------------------------------------------------------------
        , Deleted             BIT                 NOT NULL     CONSTRAINT df_etl_cdcwatermark_Deleted          DEFAULT(0)
        , ID_CreatedBy        INT                 NOT NULL     CONSTRAINT df_etl_cdcwatermark_ID_CreatedBy     DEFAULT(1)
        , CreatedDate         DATETIME2           NOT NULL     CONSTRAINT df_etl_cdcwatermark_CreatedDate      DEFAULT(SYSUTCDATETIME())
        , ID_UpdatedBy        INT                 NOT NULL     CONSTRAINT df_etl_cdcwatermark_ID_UpdatedBy     DEFAULT(0)
        , UpdatedDate         DATETIME2           NULL

        , CONSTRAINT pk_etl_cdcwatermark_ID PRIMARY KEY CLUSTERED (ID)
    );

    SET IDENTITY_INSERT etl.CdcWatermark ON;
    INSERT INTO etl.CdcWatermark (ID, CaptureInstance) VALUES (0, N'(None)');
    SET IDENTITY_INSERT etl.CdcWatermark OFF;

    CREATE UNIQUE NONCLUSTERED INDEX UX_CdcWatermark_CaptureInstance ON etl.CdcWatermark (CaptureInstance) WHERE ID > 0;

    ALTER TABLE etl.CdcWatermark ADD CONSTRAINT fk_etl_cdcwatermark_ID_CreatedBy FOREIGN KEY (ID_CreatedBy) REFERENCES security.[User](ID);
    ALTER TABLE etl.CdcWatermark ADD CONSTRAINT fk_etl_cdcwatermark_ID_UpdatedBy FOREIGN KEY (ID_UpdatedBy) REFERENCES security.[User](ID);
END
GO

PRINT N'etl.CdcWatermark - Script Done';
GO