CREATE TABLE [dbo].[order_detail] (
    [id_order_detail] BIGINT        IDENTITY (1, 1) NOT NULL,
    [id_order]        BIGINT        NOT NULL,
    [id_sustenance]   BIGINT        NOT NULL,
    [quantity]        BIGINT        NOT NULL,
    [is_active]       BIT           CONSTRAINT [dv_order_detail_is_active] DEFAULT ((1)) NOT NULL,
    [date_created]    DATETIME2 (7) CONSTRAINT [dv_order_detail_date_created] DEFAULT (getdate()) NOT NULL,
    CONSTRAINT [pk_order_detail] PRIMARY KEY CLUSTERED ([id_order_detail] ASC),
    CONSTRAINT [fk_order_detail_to_order] FOREIGN KEY ([id_order]) REFERENCES [dbo].[order] ([id_order]),
    CONSTRAINT [fk_order_detail_to_sustenance] FOREIGN KEY ([id_sustenance]) REFERENCES [dbo].[sustenance] ([id_sustenance])
);


GO
CREATE NONCLUSTERED INDEX [IX_order_detail_report]
    ON [dbo].[order_detail]([id_order] ASC, [id_sustenance] ASC, [quantity] ASC) WITH (FILLFACTOR = 90);

