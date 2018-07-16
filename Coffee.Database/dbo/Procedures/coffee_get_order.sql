CREATE PROCEDURE [dbo].[coffee_get_order]
	@id_order int
AS
    -- Retrieve all data for a specified order
	SELECT cust.last_name
         , cust.first_name
         , ord.date_created
         , ord.account_number
         , ord.cvv_code
         , ord.[status]
      FROM dbo.[order] ord INNER JOIN dbo.customer cust
            ON ord.id_customer = cust.id_customer
     WHERE ord.id_order = @id_order;

    SELECT sus.name
      FROM dbo.[order] ord INNER JOIN dbo.[order_detail] odet
            ON ord.id_order = odet.id_order
           INNER JOIN dbo.sustenance sus
            ON odet.id_sustenance = sus.id_sustenance
     WHERE ord.id_order = @id_order;
GO