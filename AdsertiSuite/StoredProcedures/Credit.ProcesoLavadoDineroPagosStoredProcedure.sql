USE [AdsertiSuite]
GO
/****** Object:  StoredProcedure [Credit].[ProcesoLavadoDineroPagosStoredProcedure]    Script Date: 08/05/2017 16:19:06 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
ALTER PROCEDURE [Credit].[ProcesoLavadoDineroPagosStoredProcedure]
	
AS
BEGIN

DECLARE @FechaActual DATE
DECLARE @TipoCambioDolar DECIMAL(20,4)
DECLARE @PeriodoInicio DATE
DECLARE @PeriodoFin DATE
DECLARE @MultiEmpresaId INT
DECLARE @NumeroMultiEmpresas INT
DECLARE @ConteoMultiEmpresas INT
DECLARE @DescripcionOperacion NVARCHAR(250)
DECLARE @ObservacionesRevisionFinal NVARCHAR(250)
DECLARE @UsuarioAltaId INT
DECLARE @ProcesoLavadoDineroPagoId BIGINT
DECLARE @EstatusPagoCancelado INT;

--Inicializa el estatus del pago Cancelado
SET @EstatusPagoCancelado = 8;

SET @FechaActual=DATEADD(DAY,-1,GETDATE())
--SET @FechaActual=CONVERT(DATE,'15/10/2014',103)
SET @UsuarioAltaId=0
SET @DescripcionOperacion='ESTA ALERTA NO REQUIERE REVISIÓN MANUAL, YA QUE DEBE REPORTARSE DE FORMA AUTOMÁTICA.'
SET @ObservacionesRevisionFinal = @DescripcionOperacion

--Valida si es quince o fin de mes

IF DATEPART(DAY,@FechaActual) != 15 AND DATEPART(MONTH,@FechaActual) = DATEPART(MONTH,DATEADD(DAY,1,@FechaActual)) --- SI NO ES 15 Y NO ES FINAL DE MES
	BEGIN 
		PRINT 'No se ejecuta el proceso en este día'
		RETURN
	END
ELSE
	BEGIN 
		IF DATEPART(DAY,@FechaActual)= 15 
			BEGIN
				SET @PeriodoInicio=CONVERT(DATE,'01/' + CONVERT(NVARCHAR(2),DATEPART(MONTH,@FechaActual)) + '/' + CONVERT(NVARCHAR(4),DATEPART(YEAR,@FechaActual)),103)
				SET @PeriodoFin = @FechaActual
			END
		ELSE
			BEGIN
				SET @PeriodoInicio= CONVERT(DATE,'16/' + CONVERT(NVARCHAR(2),DATEPART(MONTH,@FechaActual)) + '/' + CONVERT(NVARCHAR(4),DATEPART(YEAR,@FechaActual)),103)
				SET @PeriodoFin=@FechaActual
			END				 
	END


PRINT CONVERT(NVARCHAR(10),@PeriodoInicio)
PRINT CONVERT(NVARCHAR(10),@PeriodoFin)


--Declara la tabla temporal para recorrer todas las multiempresas

DECLARE @MultiEmpresasTemporal TABLE (
	NumeroFila INT IDENTITY(1, 1),
	MultiEmpresaId INT
)

-- Declara la Tabla temporal para obtener los creditos con pagos a procesar

DECLARE @CreditosPLDTemporal TABLE (
	MultiEmpresaId INT, 
	SolicitudId INT,
	TipoProductoId INT, 
	CreditoId INT, 
	TotalPagado MONEY,
	NumeroPagos INT, 
	ClienteId INT,
	FechaEsperadaPagoAnterior DATE,
	FechaEsperadaPago DATE,
	TieneAlertaLavadoDinero4 INT, 
	TieneAlertaLavadoDinero5 INT
)


--Obtiene todas las multiempresas que tengan un cliente de AdsertiCredit y lo guarda en una tabla temporal
INSERT INTO @MultiEmpresasTemporal(MultiEmpresaId) SELECT MultiEmpresaId FROM Credit.Clientes GROUP BY MultiEmpresaId

--Obtiene el número de multiempresas 
SET @NumeroMultiEmpresas = (SELECT COUNT(*) FROM @MultiEmpresasTemporal)

PRINT 'Numero multiempresas ' + CONVERT(NVARCHAR(2),@NumeroMultiEmpresas)

--Inicializa el conteo de multiempresas
SET @ConteoMultiEmpresas = 1



-- Recorre todas las multiempresas
WHILE @ConteoMultiEmpresas <= @NumeroMultiEmpresas
	BEGIN
		--Para cada multiempresa se ejecuta una transacción
	 BEGIN TRY
		BEGIN TRAN
			--Obtiene la multiempresa en cuestion
			SELECT @MultiEmpresaId=MultiEmpresaId FROM @MultiEmpresasTemporal WHERE NumeroFila = @ConteoMultiEmpresas

			PRINT  'MultiEmpresaId: ' + CONVERT(NVARCHAR(2),@MultiEmpresaId)

			--Obtiene el tipo de cambio de la multiempresa en cuestion
			SELECT @TipoCambioDolar = CONVERT(DECIMAL(10,5),ISNULL(Parametro,0)) FROM Global.Parametros WHERE ParametroId = 'AdsertiCredit.TipoCambioDolar' AND MultiEmpresaId=@MultiEmpresaId

			PRINT  'TipoCambioDolar: ' + CONVERT(NVARCHAR(10),@TipoCambioDolar)

			-- Inserta un registro de la ejecución del proceso
			INSERT INTO Credit.ProcesoLavadoDineroPagos (
				 MultiEmpresaId,
				 PeriodoInicio,
				 PeriodoFin,
				 UsuarioAltaId
			)
			VALUES (
				 @MultiEmpresaId,
				 @PeriodoInicio,
				 @PeriodoFin,
				 @UsuarioAltaId
			)

			 -- Recupera el id del proceso registrado
			SET @ProcesoLavadoDineroPagoId= SCOPE_IDENTITY()

			PRINT 'ProcesoLavadoDineroPagoId: ' + CONVERT(NVARCHAR(10),@ProcesoLavadoDineroPagoId)


			--Registra en la tabla temporal todos aquellos pagos que no han sido procesados
			INSERT INTO @CreditosPLDTemporal (
				CreditosPLD.MultiEmpresaId,
				SolicitudId,
				TipoProductoId, 
				CreditoId,
				TotalPagado,
				NumeroPagos,
				ClienteId,
				FechaEsperadaPagoAnterior,
				FechaEsperadaPago,
				TieneAlertaLavadoDinero4,
				TieneAlertaLavadoDinero5)
			SELECT 
				CreditosPLD.MultiEmpresaId,
				CreditosPLD.SolicitudId,
				CreditosPLD.TipoProductoId,
				CreditosPLD.CreditoId, 
				CreditosPLD.TotalPagado,
				CreditosPLD.NumeroPagos,
				CreditosPLD.ClienteId,
				CreditosPLD.FechaEsperadaPagoAnterior,
				CreditosPLD.FechaEsperadaPago,
				CASE WHEN CreditosPLD.TotalPagado>=(CreditosPLD.MontoEsperado + (CreditosPLD.MontoEsperado * 0.50)) THEN 1 ELSE 0 END AS TieneAlertaLavadoDinero4,   --VERIFICA SI TIENE ALERTA DE LAVADO DE DINERO 4
				CASE WHEN CreditosPLD.TotalPagado>=((10000 * @TipoCambioDolar)-((10000 * @TipoCambioDolar)*.015)) THEN 1 ELSE 0 END AS TieneAlertaLavadoDinero5   -- --VERIFICA SI TIENE ALERTA DE LAVADO DE DINERO 5
			FROM ( 
				SELECT 
				 Creditos.MultiEmpresaId,
				 Creditos.CreditoId,
				 Creditos.SolicitudId,
				 Creditos.TipoProductoId,
				 Creditos.ClienteId,
				 Creditos.MontoEsperado,
				 Creditos.FechaEsperadaPagoAnterior,
				 Creditos.FechaEsperadaPago,
				 (SELECT 
					SUM(Pagos.MontoPago) 
				FROM 
					Credit.Pagos 
				WHERE 
					Pagos.ClienteId=Creditos.ClienteId 
					AND Pagos.FechaPago<=Creditos.FechaEsperadaPago 
                    AND Pagos.FechaPago>Creditos.FechaEsperadaPagoAnterior 
					AND Pagos.EstatusPagoId <> @EstatusPagoCancelado) AS TotalPagado, 
				 (SELECT 
					COUNT(0) 
				FROM 
					Credit.Pagos 
				WHERE 
					Pagos.ClienteId=Creditos.ClienteId    
					AND Pagos.FechaPago<=Creditos.FechaEsperadaPago 
					AND Pagos.FechaPago>Creditos.FechaEsperadaPagoAnterior 
					AND Pagos.EstatusPagoId <> @EstatusPagoCancelado) AS NumeroPagos    --QUE TENGAN MAS DE UN PAGO EN EL PERIODO
				FROM (
					SELECT 
						Clientes.MultiEmpresaId, 
						CreditosCalculos.CreditoId,
						Solicitudes.SolicitudId,
						Productos.TipoProductoId,
						Solicitudes.ClienteId,                			
						CreditosCalculos.FechaEsperadaPago,
						ISNULL((SELECT TOP 1
									CC.FechaEsperadaPago 
								FROM 
									Credit.CreditosCalculos CC 
								WHERE 
									CC.Creditoid=CreditosCalculos.CreditoId 
                                	AND CC.FechaEsperadaPago<CreditosCalculos.FechaEsperadaPago   
                                	ORDER BY CC.Periodo DESC),Creditos.FechaPago) AS FechaEsperadaPagoAnterior,   --OBTIENE LA FECHA ESPERADA DE PAGO ANTERIOR  
						 CreditosCalculos.MontoPago AS MontoEsperado,
						 Solicitudes.NumeroSolicitud   
					FROM 
						Credit.CreditosCalculos INNER JOIN Credit.Creditos 
							ON Creditos.CreditoId=CreditosCalculos.CreditoId   
						INNER JOIN Credit.Solicitudes 
							ON Solicitudes.SolicitudId=Creditos.SolicitudId   
						INNER JOIN Credit.Productos
							ON Solicitudes.ProductoId = Productos.ProductoId
						INNER JOIN Credit.Clientes 
							ON Clientes.ClienteId=Solicitudes.ClienteId   
					WHERE 
						Clientes.MultiEmpresaId=@MultiEmpresaId    -- --SOLO LOS CLIENTES DE LA MULTIEMPRESA
						AND (SELECT 
									COUNT(0) 
							FROM 
								Credit.Pagos 
							WHERE 
								Pagos.ClienteId=Clientes.ClienteId    
                				AND Pagos.FechaPago<=CreditosCalculos.FechaEsperadaPago 
								AND Pagos.FechaPago>ISNULL((SELECT TOP 1 
																CC.FechaEsperadaPago 
															FROM 
																Credit.CreditosCalculos CC 
															WHERE 
																CC.Creditoid=CreditosCalculos.CreditoId 
                                								AND CC.FechaEsperadaPago<CreditosCalculos.FechaEsperadaPago   
                                							ORDER BY CC.Periodo DESC),Creditos.FechaPago)
								AND Pagos.ProcesoLavadoDineroPagoId IS NULL
								AND Pagos.EstatusPagoId <> @EstatusPagoCancelado
							)>0  --VALIDA QUE EXISTA AL MENOS UN PAGO NO PROCESADO 
			) AS Creditos                   
		) CreditosPLD 

			PRINT 'Obtiene los creditos con algun pago sin procesar en algun periodo Correcto'

			-- Actualiza todos los pagos que no esten procesados que esten dentro de algun periodo
			UPDATE 
				Credit.Pagos 
			SET 
				ProcesoLavadoDineroPagoId = @ProcesoLavadoDineroPagoId 
			WHERE 
				PagoId IN (SELECT 
								Pagos.PagoId 
							FROM 
								Credit.Pagos 
										WHERE (SELECT 
													COUNT(0) 
												FROM 
													@CreditosPLDTemporal CPLD 
												WHERE 
													CPLD.ClienteId=Pagos.ClienteId
													AND Pagos.FechaPago<=CPLD.FechaEsperadaPago 
													AND Pagos.FechaPago>CPLD.FechaEsperadaPagoAnterior)>0
							)
			PRINT 'Actluaización de los Pagos correcto'

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
					UsuarioAltaId
				)
				SELECT 
					4,
					@MultiEmpresaId,
					SolicitudId,
					TipoProductoId,
					NULL,
					TotalPagado,
					NULL,
					@UsuarioAltaId
				FROM 
					@CreditosPLDTemporal
				WHERE 
					NumeroPagos>1
					AND TieneAlertaLavadoDinero4=1

				PRINT 'Registra las alertas de lavado de dinero tipo 4'

				--Para la alerta tipo 5 se registran mas valores

				INSERT INTO Credit.AlertasLavadoDinero
				(
					TipoAlertaLavadoDineroId,
					MultiEmpresaId,
					SolicitudId,
					TipoProductoId,
					LavadoDineroId,
					MontoOperacion,
					Alerta,
					UsuarioAltaId,
					FechaRevisionFinal,
					UsuarioRevisionFinalId,
					EstatusRevisionFinal,
					ObservacionesRevisionFinal,
					DescripcionOperacion,
					AlertaReportable,
					FechaCambio,
					UsuarioCambioId
				)
				SELECT 
					5,
					@MultiEmpresaId,
					SolicitudId,
					TipoProductoId,
					NULL,
					TotalPagado,
					NULL,
					@UsuarioAltaId,
					GetDate(), -- Fecha de revision final
					@UsuarioAltaId, -- UsuarioRevisionFinal
					1, --EstatusRevisionFinal
					@ObservacionesRevisionFinal,
					@DescripcionOperacion,
					1,--AlertaReportable
					GetDate(), --FechaCambio
					@UsuarioAltaId --UsuarioCambioId		  
				FROM 
					@CreditosPLDTemporal
				WHERE 
					NumeroPagos>1 
					AND TieneAlertaLavadoDinero5=1

				PRINT 'Registra las alertas de lavado de dinero tipo 5'

		 COMMIT
		END TRY

		BEGIN CATCH			
			PRINT ERROR_MESSAGE();
			-- Si ocurre un error hace el rollback de la transacción
			ROLLBACK
		END CATCH

		--Incrementa el contador de multiEmpresas
		SET @ConteoMultiEmpresas = @ConteoMultiEmpresas + 1	
		DELETE FROM @CreditosPLDTemporal

		PRINT '@ConteoMultiEmpresas:' + CONVERT(NVARCHAR(10),@ConteoMultiEmpresas)
					
	END
  
END
