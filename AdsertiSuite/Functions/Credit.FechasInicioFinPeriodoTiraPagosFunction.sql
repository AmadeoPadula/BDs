USE [AdsertiSuite]
GO
/****** Object:  UserDefinedFunction [Credit].[FechasInicioFinPeriodoTiraPagosFunction]    Script Date: 08/05/2017 15:42:34 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER FUNCTION [Credit].[FechasInicioFinPeriodoTiraPagosFunction](@CreditoId AS INT,@Periodo AS INT)
RETURNS @fechasPeriodo TABLE 
(
    --Periodo INT,
    FechaInicio DATETIME,
	FechaFin DATETIME
)
AS
BEGIN

	INSERT INTO @fechasPeriodo (/*Periodo,*/ FechaInicio, FechaFin)
		SELECT
			--@Periodo,
			ISNULL(FechaEsperadaPagoAnterior.FechaEsperadaPagoAnterior,
					CASE Solicitudes.PeriodicidadDescuentoId 
					WHEN 1 THEN DATEADD(DAY,-7,CreditosCalculos.FechaEsperadaPago) -- 1	SEMANAL
					WHEN 2 THEN DATEADD(DAY,-14,CreditosCalculos.FechaEsperadaPago) --2	CATORCENAL
					WHEN 3 THEN DATEADD(DAY,-15,CreditosCalculos.FechaEsperadaPago) --3	QUINCENAL
					WHEN 4 THEN DATEADD(DAY,-30,CreditosCalculos.FechaEsperadaPago) --4	MENSUAL
				END) AS FechaInicio,
			CreditosCalculos.FechaEsperadaPago AS FechaFin
		FROM 
			Credit.Solicitudes INNER JOIN Credit.Creditos 
				ON Solicitudes.SolicitudId = Creditos.SolicitudId
			INNER JOIN Credit.CreditosCalculos 
				ON Creditos.CreditoId = CreditosCalculos.CreditoId
			LEFT JOIN 
				(
					SELECT 
						TiraPagosAnterior.CreditoId,
						MAX(TiraPagosAnterior.FechaEsperadaPago) FechaEsperadaPagoAnterior
					FROM
						Credit.CreditosCalculos TiraPagosAnterior
					WHERE
						TiraPagosAnterior.CreditoId = @CreditoId
						AND TiraPagosAnterior.Periodo < @Periodo
					GROUP BY TiraPagosAnterior.CreditoId
				) AS FechaEsperadaPagoAnterior
				ON Creditos.CreditoId = FechaEsperadaPagoAnterior.CreditoId
		
		WHERE
			CreditosCalculos.CreditoId = @CreditoId
			AND CreditosCalculos.Periodo = @Periodo

		RETURN
END