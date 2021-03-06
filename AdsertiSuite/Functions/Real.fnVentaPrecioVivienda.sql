USE [AdsertiSuite]
GO
/****** Object:  UserDefinedFunction [Real].[fnVentaPrecioVivienda]    Script Date: 08/05/2017 15:45:24 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER FUNCTION [Real].[fnVentaPrecioVivienda](@VentaId INT)
RETURNS DECIMAL(10,2)
BEGIN
	DECLARE @ValorVivienda DECIMAL(10,2)

	SELECT 
		@ValorVivienda = CAST(
			ISNULL(Viviendas.Precio,0.0) + -->Precio Vivienda
			CASE WHEN Viviendas.EsEsquina = 1 
				THEN ISNULL(Viviendas.PrecioEsquina,0.0) 
				ELSE 0.0 
			END + -->Precio Esquina
			CASE WHEN Viviendas.TieneAreaExcedente = 1 
				THEN ISNULL(Ventas.PrecioTerrenoExcedente,0.0) 
				ELSE 0.0 
			END + -->Precio Terreno Excedente
			ISNULL((SELECT SUM(Precio) FROM Real.VentasAcabados WHERE VentaId = @VentaId),0.0) -->Costo Acabados
		AS DECIMAL(10,2))
	FROM 
		Real.Ventas	INNER JOIN Real.Viviendas 
			ON Viviendas.ViviendaId = Ventas.ViviendaId
	WHERE
		Ventas.VentaId = @VentaId

	RETURN ISNULL(@ValorVivienda,0.0)
END


