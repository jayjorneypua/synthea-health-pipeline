--=====================================================================================================
--                                        security.User Table
--=====================================================================================================
-- Purpose:  Users referenced by ID_CreatedBy / ID_UpdatedBy. ID 0 = (None), ID 1 = system.
--=====================================================================================================
IF OBJECT_ID(N'security.[User]', N'U') IS NULL BEGIN
    PRINT N'security.User - Creating';

    CREATE TABLE security.[User] (
          ID                  INT                 NOT NULL     IDENTITY(0, 1)
        , Username            NVARCHAR(100)       NOT NULL     CONSTRAINT df_security_user_Username     DEFAULT('')
        , FullName            NVARCHAR(255)       NOT NULL     CONSTRAINT df_security_user_FullName     DEFAULT('')
        , Active              BIT                 NOT NULL     CONSTRAINT df_security_user_Active       DEFAULT(1)

        --------------------------------------------------------------------------------
        -- Standard Fields
        --------------------------------------------------------------------------------
        , Deleted             BIT                 NOT NULL     CONSTRAINT df_security_user_Deleted      DEFAULT(0)
        , ID_CreatedBy        INT                 NOT NULL     CONSTRAINT df_security_user_ID_CreatedBy DEFAULT(1)
        , CreatedDate         DATETIME2           NOT NULL     CONSTRAINT df_security_user_CreatedDate  DEFAULT(SYSUTCDATETIME())
        , ID_UpdatedBy        INT                 NOT NULL     CONSTRAINT df_security_user_ID_UpdatedBy DEFAULT(0)
        , UpdatedDate         DATETIME2           NULL

        , CONSTRAINT pk_security_user_ID PRIMARY KEY CLUSTERED (ID)
    );

    SET IDENTITY_INSERT security.[User] ON;
    INSERT INTO security.[User] (ID, Username, FullName) VALUES (0, N'', N'(None)');
    INSERT INTO security.[User] (ID, Username, FullName) VALUES (1, N'system', N'System');
    SET IDENTITY_INSERT security.[User] OFF;

    CREATE UNIQUE NONCLUSTERED INDEX UX_User_Username ON security.[User] (Username) WHERE Username <> N'';
END
GO

PRINT N'security.User - Script Done';
GO