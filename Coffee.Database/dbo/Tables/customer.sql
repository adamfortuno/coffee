CREATE TABLE [dbo].[customer] (
    [id_customer]  BIGINT        IDENTITY (1, 1) NOT NULL,
    [first_name]   VARCHAR (30)  NOT NULL,
    [last_name]    VARCHAR (45)  NOT NULL,
    [is_active]    BIT           CONSTRAINT [dv_customer_is_active] DEFAULT ((1)) NOT NULL,
    [date_created] DATETIME2 (7) CONSTRAINT [dv_customer_date_created] DEFAULT (getdate()) NOT NULL,
    CONSTRAINT [pk_customer] PRIMARY KEY CLUSTERED ([id_customer] ASC)
);

