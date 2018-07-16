CREATE TABLE [dbo].[sustenance] (
    [id_sustenance] BIGINT        IDENTITY (1, 1) NOT NULL,
    [name]          VARCHAR (65)  NOT NULL,
    [is_active]     BIT           CONSTRAINT [dv_sustenance_is_active] DEFAULT ((1)) NOT NULL,
    [date_created]  DATETIME2 (7) CONSTRAINT [dv_sustenance_date_created] DEFAULT (getdate()) NOT NULL,
    CONSTRAINT [pk_sustenance] PRIMARY KEY CLUSTERED ([id_sustenance] ASC)
);

