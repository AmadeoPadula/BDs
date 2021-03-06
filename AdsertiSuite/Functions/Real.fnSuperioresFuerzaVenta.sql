USE [AdsertiSuite]
GO
/****** Object:  UserDefinedFunction [Real].[fnSuperioresFuerzaVenta]    Script Date: 08/05/2017 15:43:20 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER FUNCTION [Real].[fnSuperioresFuerzaVenta](@FuerzaVentaId INT)
RETURNS TABLE
AS
RETURN(WITH ListadoFuerzaVentas AS
		(SELECT 
			FuerzaVentaId,
			PersonaId,
			TipoFuerzaVentaId,
			FuerzaVentaIdSuperior
		FROM
			Real.FuerzaVentas
		WHERE
			FuerzaVentaId = @FuerzaVentaId
	
		UNION ALL

		SELECT 
			FzVta.FuerzaVentaId,
			FzVta.PersonaId,
			FzVta.TipoFuerzaVentaId,
			FzVta.FuerzaVentaIdSuperior
		FROM
			Real.FuerzaVentas AS FzVta INNER JOIN ListadoFuerzaVentas CteFzaVta
				ON FzVta.FuerzaVentaId = CteFzaVta.FuerzaVentaIdSuperior
		WHERE
			FzVta.FuerzaVentaId <> FzVta.FuerzaVentaIdSuperior 
			OR FzVta.FuerzaVentaIdSuperior IS NULL
			)
	SELECT 
		FuerzaVentaId,
		TipoFuerzaVentaId, 
		PersonaId 
	FROM 
		ListadoFuerzaVentas 
)  
