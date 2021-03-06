USE [AdsertiSuite]
GO
/****** Object:  StoredProcedure [Credit].[ActualizarSaldoCredito]    Script Date: 08/05/2017 15:45:50 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:      ARTURO HERNANDEZ
-- Create date: 12/NOV/2015
-- Description: ACTUALIZAR SALDO CREDITO
-- =============================================
ALTER PROCEDURE [Credit].[ActualizarSaldoCredito]
	@CreditoId INT
AS
BEGIN
		DECLARE 
			@MontoCredito DECIMAL(10,2),
			@MontoPagos DECIMAL(10,2),
			@EstatusCredito INT,
			@CreditoLiquidado BIT,
			@ClienteId INT

		--CALCULAR EL MONTO DEL CREDITO 
		SELECT 
			@MontoCredito = Solicitudes.MontoCredito
		FROM 
			Credit.Creditos INNER JOIN Credit.Solicitudes
				ON Creditos.SolicitudId = Solicitudes.SolicitudId 
		WHERE 
			CreditoId = @CreditoId

		--CALCULAR EL MONTO DE LOS PAGOS A CAPITAL
		SELECT 
			@MontoPagos = ISNULL(SUM(MontoCapital),0)
		FROM 
			Credit.CreditosCalculos
		WHERE 
			CreditoId = @CreditoId
			AND PagoId IS NOT NULL
			AND Procesado = 1

		--ACTUALIZAR EL MONTO DEL CRÉDITO Y FECHA DE MODIFICACIÓN
		UPDATE
			Credit.Creditos 
		SET
			Saldo = @MontoCredito - @MontoPagos,
			FechaCambio = GETDATE()
		WHERE 
			CreditoId = @CreditoId


		--CONSULTA ESTATUS CREDITO
		SELECT 
			@EstatusCredito = Creditos.EstatusCreditoId, 
			@CreditoLiquidado = Credit.CreditoLiquidado(CreditoId),
			@ClienteId = Solicitudes.ClienteId 
		FROM 
			Credit.Creditos INNER JOIN Credit.Solicitudes
				ON Creditos.SolicitudId = Solicitudes.SolicitudId
		WHERE 
			CreditoId = @CreditoId

		
		IF(@CreditoLiquidado = 1 AND @EstatusCredito<>2)
		BEGIN
			--MARCAR COMO LIQUIDADO EL CRÉDITO
			UPDATE Credit.Creditos 
			SET 
				EstatusCreditoId = 2,
				FechaLiquidacion = GetDate(),
				FechaCambio = GetDate()
			WHERE 
				CreditoId = @CreditoId
			
			--ACTUALIZAR ESTATUS A CLIENTE CRÉDITO PAGADO
			--UPDATE  Credit.Clientes
			--SET
			--	EstatusClienteId = 5,
			--	FechaCambio = GetDate()
			--WHERE
			--	ClienteId = @ClienteId
		END

END