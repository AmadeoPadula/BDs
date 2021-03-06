USE [AdsertiSuite]
GO
/****** Object:  StoredProcedure [Credit].[RevisionAlertasPLDMontoSuperior50PorcientoStoredProcedure]    Script Date: 08/05/2017 16:19:46 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [Credit].[RevisionAlertasPLDMontoSuperior50PorcientoStoredProcedure]
	@MultiEmpresaId INT,
	@LavadoDineroStoredProcedureBitacoraId INT,
	@CreditoId INT,
	@Periodo INT,
	@UsuarioId INT
AS
BEGIN
		
	DECLARE 
		@FechaInicio DATETIME,
		@FechaFin DATETIME

	----------------------------------------------
	--CALCULAR FECHA DE INICIO Y FIN DEL PERIODO--
	----------------------------------------------
	SELECT 
		@FechaInicio = FechaInicio, 
		@FechaFin = FechaFin 
	FROM 
		Credit.FechasInicioFinPeriodoTiraPagosFunction(@CreditoId, @Periodo)

	-------------------------------------
	--CALCULAR MONTOS [ESPERADO/PAGADO]--
	-------------------------------------
	DECLARE 
		@MontoEsperadoPago DECIMAL(12,2),
		@MontoPagado DECIMAL(12,2)
	
	SELECT
		@MontoEsperadoPago = SUM(CASE 
				WHEN 
					(
						CreditosCalculos.FechaEsperadaPago <= @FechaInicio 
						AND (CreditosCalculos.PagoId IS NULL OR CreditosCalculos.Procesado = 0)
					) THEN CreditosCalculos.MontoPago -->Pagos Atrasados
				WHEN 
					(
						CreditosCalculos.FechaEsperadaPago > @FechaInicio 
						AND CreditosCalculos.FechaEsperadaPago <= @FechaFin 
						AND (CreditosCalculos.PagoId IS NULL OR CreditosCalculos.Procesado = 0)
					) THEN CreditosCalculos.MontoPago -->Pagos Periodo no pagados
				WHEN
					(
						CreditosCalculos.FechaEsperadaPago > @FechaInicio 
						AND CreditosCalculos.FechaEsperadaPago <= @FechaFin 
						AND Pagos.FechaPago > @FechaInicio 
						--AND Pagos.FechaPago <= @FechaFin 
						AND CreditosCalculos.PagoId IS NOT NULL -- Agregado JTT
						AND CreditosCalculos.Procesado = 1
					) THEN CreditosCalculos.MontoPago-->Pago Periodo Pagados en el Periodo
				ELSE 0
			END),--> MontoEsperadoPago
		@MontoPagado = SUM(CASE 
				WHEN 
					(
						CreditosCalculos.Procesado = 1 
						AND Pagos.EstatusPagoId != 8 -->CANCELADO
						AND Pagos.TipoPagoId != 5 --> REESTRUCTURA
						AND Pagos.FechaPago > @FechaInicio 
						AND Pagos.FechaPago <= @FechaFin
					) THEN CreditosCalculos.MontoPago
				ELSE 0
			END) --> MontoPagado
	FROM 
		Credit.Creditos INNER JOIN Credit.CreditosCalculos 
			ON CreditosCalculos.CreditoId = Creditos.CreditoId
		LEFT JOIN Credit.Pagos 
			ON CreditosCalculos.PagoId = Pagos.PagoId
	WHERE
		Creditos.CreditoId = @CreditoId

	--SI EXISTEN PAGOS POR UN MONTO SUPERIOR AL MONTO ESPERADO EN UN 50% - Generar Alerta
	IF (@MontoPagado > 0 AND @MontoPagado >= (@MontoEsperadoPago + (@MontoEsperadoPago * 0.50)))
		BEGIN
			DECLARE 
				@SolicitudId INT,
				@TipoProductoId INT,
				@AlertaLavadoDineroId INT

			SELECT @CreditoId AS CreditoId, @Periodo AS Periodo, @MontoPagado AS MontoPagado, @MontoEsperadoPago MontoEsperadoPago

			SELECT 
				@SolicitudId = Solicitudes.SolicitudId,
				@TipoProductoId = Productos.TipoProductoId
			FROM 
				Credit.Creditos INNER JOIN Credit.Solicitudes 
					ON Solicitudes.SolicitudId = Creditos.SolicitudId   
				INNER JOIN Credit.Productos
					ON Solicitudes.ProductoId = Productos.ProductoId
			WHERE 
				CreditoId = @CreditoId

			--Inserta las alertas de Lavado de Dinero
			INSERT INTO Credit.AlertasLavadoDinero
				(
					TipoAlertaLavadoDineroId,
					MultiEmpresaId,
					SolicitudId,
					TipoProductoId,
					LavadoDineroId,
					MontoOperacion,
					Alerta,
					LavadoDineroStoredProcedureBitacoraId,
					UsuarioAltaId
				)
				VALUES(
					4,
					@MultiEmpresaId,
					@SolicitudId,
					@TipoProductoId,
					NULL,
					@MontoPagado,
					NULL,
					@LavadoDineroStoredProcedureBitacoraId,
					@UsuarioId
				)

			--RECUPERA EL IDENTITY CREADO
			SET @AlertaLavadoDineroId = SCOPE_IDENTITY()
				
			INSERT INTO Credit.AlertasLavadoDineroPagos (
				AlertaLavadoDineroId,
				PagoId,
				UsuarioAltaId
			) 
			SELECT 
				@AlertaLavadoDineroId,
				Pagos.PagoId,
				@UsuarioId
			FROM 
				Credit.Creditos INNER JOIN Credit.CreditosCalculos 
					ON CreditosCalculos.CreditoId = Creditos.CreditoId
				INNER JOIN Credit.Pagos 
					ON CreditosCalculos.PagoId = Pagos.PagoId
			WHERE
				Creditos.CreditoId = @CreditoId
				AND CreditosCalculos.Procesado = 1 
				AND Pagos.EstatusPagoId != 8 -->CANCELADO
				AND Pagos.TipoPagoId != 5 --> REESTRUCTURA
				AND Pagos.FechaPago > @FechaInicio 
				AND Pagos.FechaPago <= @FechaFin
		END
END


