CREATE TABLE [dbo].[order] (
    [id_order]       BIGINT        IDENTITY (1, 1) NOT NULL,
    [id_customer]    BIGINT        NOT NULL,
    [status]         CHAR (1)      CONSTRAINT [dv_order_status] DEFAULT ('I') NOT NULL,
    [account_number] CHAR (19)     NULL,
    [cvv_code]       CHAR (3)      NULL,
    [is_active]      BIT           CONSTRAINT [dv_order_is_active] DEFAULT ((1)) NOT NULL,
    [date_created]   DATETIME2 (7) CONSTRAINT [dv_order_date_created] DEFAULT (getdate()) NOT NULL,
    CONSTRAINT [pk_order] PRIMARY KEY CLUSTERED ([id_order] ASC),
    CONSTRAINT [fk_order_to_customer] FOREIGN KEY ([id_customer]) REFERENCES [dbo].[customer] ([id_customer])
);


GO
CREATE NONCLUSTERED INDEX [IX_order_id_customer]
    ON [dbo].[order]([id_customer] ASC) WITH (FILLFACTOR = 90);


GO
CREATE NONCLUSTERED INDEX [IX_order_status]
    ON [dbo].[order]([status] ASC) WITH (FILLFACTOR = 90);

