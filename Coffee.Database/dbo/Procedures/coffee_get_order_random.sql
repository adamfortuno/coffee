CREATE PROCEDURE [dbo].[coffee_get_order_random]
	@order_status AS tinyint
 AS
    --Return a random order
	WITH pool_orders_active AS (
	SELECT TOP 50 id_order
	  FROM dbo.[order] 
	 WHERE [status] = @order_status
	  AND is_active = 1
	ORDER BY id_order ASC
	)
	SELECT TOP 1 id_order 
	  FROM pool_orders_active
	 ORDER BY NEWID();
GO