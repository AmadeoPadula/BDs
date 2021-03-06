USE [AdsertiSuite]
GO
/****** Object:  UserDefinedFunction [Real].[fnPrecioBaseVivienda]    Script Date: 08/05/2017 15:45:09 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER FUNCTION [Real].[fnPrecioBaseVivienda](@ViviendaId INT)
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
				THEN ISNULL(Desarrollos.CostoMetroCuadradoExcedente,0.0) * ISNULL(Viviendas.AreaExcedente,0.0)
				ELSE 0.0 
			END 
		AS DECIMAL(10,2))
	FROM 
		Real.Viviendas INNER JOIN Real.Condominios
			ON Viviendas.CondominioId = Condominios.CondominioId
		INNER JOIN Real.EtapasDesarrollo
			ON Condominios.EtapaDesarrolloId = EtapasDesarrollo.EtapaDesarrolloId
		INNER JOIN Real.Desarrollos
			ON EtapasDesarrollo.DesarrolloId = Desarrollos.DesarrolloId
	WHERE
		Viviendas.ViviendaId = @ViviendaId

	RETURN ISNULL(@ValorVivienda,0.0)
END


