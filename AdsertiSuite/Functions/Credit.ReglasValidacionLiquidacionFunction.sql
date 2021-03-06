USE [AdsertiSuite]
GO
/****** Object:  UserDefinedFunction [Credit].[ReglasValidacionLiquidacionFunction]    Script Date: 08/05/2017 15:42:58 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER FUNCTION [Credit].[ReglasValidacionLiquidacionFunction](@CreditoId INT, @EstatudCreditoIdVigente INT)
RETURNS @ReglasValidacionLiquidacion TABLE
(
	ReglaId INT NOT NULL IDENTITY(1,1),
	Regla VARCHAR(250) NOT NULL,
	Requerido VARCHAR(150),
	Actual VARCHAR(150),
	EsSaldo BIT NOT NULL,
	EsTotal BIT NOT NULL,
	EsTexto BIT NOT NULL,
	Correcto BIT NOT NULL
)
AS
BEGIN

	DECLARE @tmpValidaSaldo TABLE(
		Regla VARCHAR(250) NOT NULL,
		Saldo1 DECIMAL(10,2) NULL,
		Saldo2 DECIMAL(10,2) NULL,
		Correcto BIT
	)

	--VALIDACION DE SALDOS
	INSERT INTO @tmpValidaSaldo (Regla,Saldo1,Saldo2)
	SELECT
		'[C1] SALDO CRÉDITO / [C2] MONTO P/PAGAR' AS Regla,
		Creditos.Saldo AS Saldo1,
		MontosCredito.MontoPorPagar AS Saldo2
	FROM
		Credit.Solicitudes INNER JOIN Credit.Creditos 
			ON Solicitudes.SolicitudId = Creditos.SolicitudId 
		INNER JOIN 
					(SELECT 
						CreditosCalculos.CreditoId,
						SUM(CASE WHEN CreditosCalculos.PagoId IS NULL THEN CreditosCalculos.MontoCapital ELSE 0 END) MontoPorPagar,
						SUM(CASE WHEN CreditosCalculos.PagoId IS NOT NULL THEN CreditosCalculos.MontoCapital  ELSE 0 END) MontoPagado
					FROM
						Credit.CreditosCalculos
					WHERE
						CreditosCalculos.CreditoId = @CreditoId
					GROUP BY CreditosCalculos.CreditoId) AS MontosCredito
			ON Creditos.CreditoId = MontosCredito.CreditoId
	UNION ALL
	SELECT
		'[C1] SALDO CRÉDITO - [C2] SALDO FINAL ÚLTIMO PAGO' AS Regla,
		Creditos.Saldo AS Saldo1,
		ISNULL(SaldoFinalUltimoPago.SaldoFinal,Creditos.Saldo) AS Saldo2 --No hay pago
	FROM
		Credit.Creditos LEFT JOIN 
				(SELECT TOP 1
					CreditosCalculos.CreditoId,
					CreditosCalculos.SaldoFinal
				FROM 
					Credit.CreditosCalculos 
				WHERE 
					CreditoId = @CreditoId AND PagoId IS NOT NULL
				ORDER BY CreditosCalculos.Periodo DESC) AS SaldoFinalUltimoPago
			ON Creditos.CreditoId = SaldoFinalUltimoPago.CreditoId
	WHERE
		Creditos.CreditoId = @CreditoId
			

	UPDATE @tmpValidaSaldo SET Correcto = CASE WHEN (Saldo1 = Saldo2) THEN 1 ELSE 0 END


	--VALIDACION DE CONDICIONES TOTALES
	DECLARE @tmpValidaTotales TABLE(
		Regla VARCHAR(250) NOT NULL,
		Total1 INT NULL,
		Total2 INT NULL,
		Correcto BIT NULL
	)

	INSERT INTO @tmpValidaTotales(Regla,Total1,Total2)
		SELECT
			'EXCEPCIONES PAGO: [C1] Requeridas / [C2] Actuales' AS Regla,
			0 Total1,
			ISNULL(SUM(CASE WHEN CreditosCalculos.CreditoPagoExcepcionId IS NULL THEN 0 ELSE 1 END),0) Total2
		FROM 
			Credit.CreditosCalculos
		WHERE
			CreditosCalculos.CreditoId = @CreditoId
			AND CreditosCalculos.PagoId IS NULL

	UPDATE @tmpValidaTotales SET Correcto = CASE WHEN (Total1 = Total2) THEN 1 ELSE 0 END


	--VALIDACION DE CONDICIONES TEXTO
	DECLARE @tmpValidaTexto TABLE(
	Regla VARCHAR(250) NOT NULL,
	Condicion1 VARCHAR(200) NULL,
	Condicion2 VARCHAR(200) NULL,
	Correcto BIT NULL
	)

	INSERT INTO @tmpValidaTexto (Regla,Condicion1,Condicion2)
	SELECT
		'ESTATUS: [C1] Requerido / [C2] Actual' AS Regla,
		(SELECT TOP 1 EC.EstatusCredito FROM Credit.EstatusCredito EC WHERE EC.EstatusCreditoId = @EstatudCreditoIdVigente),
		EstatusCredito.EstatusCredito
	FROM 
		Credit.Creditos INNER JOIN Credit.EstatusCredito
			ON Creditos.EstatusCreditoId = EstatusCredito.EstatusCreditoId	
	WHERE
		Creditos.CreditoId = @CreditoId

	UPDATE @tmpValidaTexto SET Correcto = CASE WHEN (ISNULL(Condicion1,'') = ISNULL(Condicion2,'')) THEN 1 ELSE 0 END


	INSERT INTO @ReglasValidacionLiquidacion 
		SELECT 
			Regla,
			'$ ' + CONVERT(varchar, CAST(Saldo1 AS money), 1),
			'$ ' + CONVERT(varchar, CAST(Saldo2 AS money), 1),
			--CAST(Saldo1 AS VARCHAR),
			--CAST(Saldo2 AS VARCHAR),
			1 EsSaldo,
			0 EsTotal,
			0 EsTexto,
			Correcto
		FROM
			@tmpValidaSaldo

		UNION ALL

		SELECT 
			Regla,
			CAST(Total1 AS VARCHAR),
			CAST(Total2 AS VARCHAR),
			0 EsSaldo,
			1 EsTotal,
			0 EsTexto,
			Correcto
		FROM
			@tmpValidaTotales

		UNION ALL

		SELECT 
			Regla,
			Condicion1,
			Condicion2,
			0 EsSaldo,
			0 EsTotal,
			1 EsTexto,
			Correcto
		FROM
			@tmpValidaTexto


	RETURN
END