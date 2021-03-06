USE [AdsertiSuite]
GO
/****** Object:  StoredProcedure [Credit].[ReportesBCStoredProcedure]    Script Date: 08/05/2017 16:19:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [Credit].[ReportesBCStoredProcedure]
	@TipoReporte int, 
	@MultiempresaId int, 
	@ClaveUsuario nvarchar(10), 
	@NombreUsuario nvarchar(16), 
	@Version int = null, 
	@Fecha date, 
	@NombreArchivo nvarchar(50), 
	@UsuarioDevolucion nvarchar(15) = null, 
	@DireccionUsuarioDevolucion nvarchar(160) = null, 
	@UsuarioAltaId int
WITH EXEC AS CALLER
AS
BEGIN TRY

   SET NOCOUNT ON                                                
   SET XACT_ABORT ON                                            

	BEGIN TRAN

	IF @TipoReporte = 1 OR @TipoReporte = 2
	BEGIN
		DECLARE 
			@ReporteBCId INT, --Retorna el Identificador del Reporte Generado
			@FechaGeneracion DATETIME,
			@SegmentosTL INT,
			@TotalSaldosActuales INT,
			@TotalSaldosVencidos INT

		--------------------------------------------
		-->>INICIO: EXTRAE INFORMACION DE CREDITOS--
		--------------------------------------------

		DECLARE @InformacionCartera TABLE(
			[NumeroCuentaTL] [nvarchar](25) NULL,
			[TipoResponsabilidadTL] [nvarchar](1) NULL,
			[TipoCuentaTL] [nvarchar](1) NULL,
			[TipoContratoTL] [nvarchar](2) NULL,
			[MonedaTL] [nvarchar](2) NULL,
			[ImporteAvaluoTL] [int] NULL,
			[NumeroPagosTL] [int] NULL,
			[FrecuenciaPagosTL] [nvarchar](1) NULL,
			[MontoPagarTL] [int] NULL,
			[FechaAperturaTL] [nvarchar](8) NULL,
			[FechaUltimoPagoTL] [nvarchar](8) NULL,
			[FechaUltimaCompraTL] [nvarchar](8) NULL,
			[FechaCierreTL] [nvarchar](8) NULL,
			[FechaReporteTL] [nvarchar](8) NULL,
			[GarantiaTL] [nvarchar](40) NULL,
			[CreditoMaximoTL] [int] NULL,
			[SaldoActualTL] [int] NULL,
			[SaldoVencidoTL] [int] NULL,
			[PagosVencidosTL] [int] NULL,
			[MopTL] [nvarchar](2) NULL,
			[ClaveObservacionTL] [nvarchar](2) NULL,
			[ClaveUsuarioAnteriorTL] [nvarchar](10) NULL,
			[NombreUsuarioAnteriorTL] [nvarchar](16) NULL,
			[NumeroCuentaAnteriorTL] [nvarchar](25) NULL,
			[FechaPrimerInclumplimientoTL] [nvarchar](8) NULL,
			[SaldoInsolutoPrincipalTL] [int] NULL,
			[MontoUltimoPagoTL] [int] NULL,
			[PlazoMesesTL] [decimal](10,2) NULL,
			[MontoCreditoTL][int]NULL,
			--Version 14: Nuevas columnas
			[FechaIngresoCarteraVencidaTL] [nvarchar](8) NULL,
			[MontoInteresesTL] [int] NULL,
			[MopInteresesTL] [nvarchar](2) NULL,
			[DiasVencimientoTL] [int] NULL,
			[CorreoElectronicoConsumidorTL] [nvarchar](100) NULL
		)


		INSERT INTO @InformacionCartera (
			NumeroCuentaTL,
			TipoResponsabilidadTL,
			TipoCuentaTL,
			TipoContratoTL,
			MonedaTL,
			ImporteAvaluoTL,
			NumeroPagosTL,
			FrecuenciaPagosTL,
			MontoPagarTL,
			FechaAperturaTL,
			FechaUltimoPagoTL,
			FechaUltimaCompraTL,
			FechaCierreTL,
			FechaReporteTL,
			GarantiaTL,
			CreditoMaximoTL,
			SaldoActualTL,
			SaldoVencidoTL,
			PagosVencidosTL,
			MopTL,
			ClaveObservacionTL,
			ClaveUsuarioAnteriorTL,
			NombreUsuarioAnteriorTL,
			NumeroCuentaAnteriorTL,
			FechaPrimerInclumplimientoTL,
			SaldoInsolutoPrincipalTL,
			MontoUltimoPagoTL,
			PlazoMesesTL,
			MontoCreditoTL,
			--Inicio: Version 14
			FechaIngresoCarteraVencidaTL,
			MontoInteresesTL,
			MopInteresesTL,
			DiasVencimientoTL,
			CorreoElectronicoConsumidorTL
			--Fin: Version 14
		) 
			SELECT 
				TL.NumeroCuenta, --Numero de Solicitud
				TL.TipoResponsabilidadCuenta, --I=Individual
				TL.TipoCuenta,--I=Pagos Fijos
				TL.TipoContratoProducto,--CL=Línea de Crédito
				TL.MonedaCredito,-- MX
				TL.ImporteAvaluo,-- No se reporta
				TL.NumeroPagos, --Total de Periodos
				TL.FrecuenciaPagos, -- Frecuencia de los Pagos
				ISNULL(CONVERT(INT,ROUND(TL.MontoAPagar,0,1)),0) AS MontoAPagar, -- Mientras el crédito este activo se debe reportar el MontoPago de Credit.CreditosCalculos (Mensualizado) en caso contario deberá ir cero 
				REPLACE(CONVERT(NVARCHAR(10),TL.FechaAperturaCredito,103),'/','') AS FechaAperturaCredito, -- Fecha Pago del Crédito
				ISNULL(REPLACE(CONVERT(NVARCHAR(10),TL.FechaUltimoPago,103),'/',''),'') AS FechaUltimoPago, ---Fecha del Ultimo Pago

				-->>CAMBIO [ini]: Segun correo de observaciones [jueves 04/06/2015 05:38 p. m.], si no tiene fecha de ultimo pago se reporte de reporta la fecha de apertura
				CASE WHEN TL.FechaUltimoPago IS NULL THEN 
					REPLACE(CONVERT(NVARCHAR(10),TL.FechaAperturaCredito,103),'/','') 
				ELSE 
					ISNULL(REPLACE(CONVERT(NVARCHAR(10),TL.FechaUltimoPago,103),'/',''),'')
				END  AS FechaUltimoCompraDisposicion, -- Se reporta la Fecha del Ultimo Pago
				-->>CAMBIO [fin]: Segun correo de observaciones [jueves 04/06/2015 05:38 p. m.], si no tiene fecha de ultimo pago se reporte de reporta la fecha de apertura
				
				CASE WHEN TL.EstatusCreditoId = 2 THEN REPLACE(CONVERT(NVARCHAR(10),TL.FechaUltimoPago,103),'/','') ELSE '' END AS FechaCierre, --Si el crédito esta en estatus de Liquidado se reporta la Fecha del Ultimo Pago
				TL.FechaReporteInformacion, 
				TL.Garantia, 
				CONVERT(INT,ROUND(TL.CreditoMaximoAutorizado,0,1)) AS CreditoMaximoAutorizado, -- Se reporta el MontoCredito de la Solicitud
				CONVERT(INT,ROUND(TL.SaldoActual+TL.Moratorios,0,1)) AS SaldoActual,-- Es el saldo actual del crédito incluyendo intereses, comisiones, etc. (Se debe incluir los moratorios si es que hay)
				--TL.LimiteCredito, -- No aplica porque son puros pagos fijos
				CONVERT(INT,ROUND(TL.SaldoVencido + TL.Moratorios,0,1))  AS SaldoVencido, --Checar con Flavio
				TL.NumeroPagosVencidos, --Se reportan todos los pagos que presentan incumplimiento dando como margen 5 días mas en la fecha esperada de pago de cada periodo
				CASE 
					--WHEN (TL.FechaUltimoPago IS NULL AND DATEDIFF(MONTH,TL.FechaAperturaCredito, @Fecha) <= 3)  THEN '00'
					WHEN (TL.FechaUltimoPago IS NULL AND TL.FechaAperturaCredito < DATEDIFF(MONTH,-3,@Fecha))  THEN '00'
					WHEN CEILING(CONVERT(DECIMAL(10,2),NumeroPagosVencidos)/NumeroPeriodosMensuales)=0 THEN '01'
					WHEN CEILING(CONVERT(DECIMAL(10,2),NumeroPagosVencidos)/NumeroPeriodosMensuales)=1 THEN '02'
					WHEN CEILING(CONVERT(DECIMAL(10,2),NumeroPagosVencidos)/NumeroPeriodosMensuales)=2 THEN '03'
					WHEN CEILING(CONVERT(DECIMAL(10,2),NumeroPagosVencidos)/NumeroPeriodosMensuales)=3 THEN '04'
					WHEN CEILING(CONVERT(DECIMAL(10,2),NumeroPagosVencidos)/NumeroPeriodosMensuales)=4 THEN '05'
					WHEN CEILING(CONVERT(DECIMAL(10,2),NumeroPagosVencidos)/NumeroPeriodosMensuales)=5 THEN '06'
					WHEN CEILING(CONVERT(DECIMAL(10,2),NumeroPagosVencidos)/NumeroPeriodosMensuales) BETWEEN 6 AND 12 THEN '07'
					WHEN CEILING(CONVERT(DECIMAL(10,2),NumeroPagosVencidos)/NumeroPeriodosMensuales) > 12 THEN '96'  
				END AS FormaPago,
				CASE 
					WHEN TL.EstatusCreditoId=2 AND TL.SaldoActual<=0 AND TL.SaldoVencido<=0 AND TL.MontoAPagar<=0 AND TL.FechaUltimoPago IS NOT NULL 
						THEN 'CC' 
						ELSE '' 
				END AS ClaveObservacion,
				TL.ClaveUsuarioAnteriorTL, 
				TL.NombreUsuarioAnteriorTL, 
				TL.NumeroCuentaAnteriorTL, 
				REPLACE(CONVERT(NVARCHAR(10),TL.FechaPrimerIncumplimiento,103),'/','') AS FechaPrimerIncumplimiento,
				CONVERT(INT,ROUND(TL.SaldoInsolutoPrincipal,0,1)) AS SaldoInsolutoPrincipal,
				CONVERT(INT,ROUND(ISNULL(TL.MontoUltimoPago,0),0,1)) AS MontoUltimoPago,
				CAST(TL.PlazoMeses AS INT) PlazoMesesTL,
				CONVERT(INT,ROUND(TL.MontoCredito,0,1)) AS MontoCreditoTL,
				ISNULL(REPLACE(CONVERT(NVARCHAR(10),TL.FechaIngresoCarteraVencida,103),'/',''),'') AS FechaIngresoCarteraVencida,
				ISNULL(CONVERT(INT,ROUND(TL.MontoIntereses,0,1)),0) AS MontoIntereses,
				CASE 
					--WHEN (TL.FechaUltimoPago IS NULL AND DATEDIFF(MONTH,TL.FechaAperturaCredito, @Fecha) <= 3)  THEN '00'
					WHEN (TL.FechaUltimoPago IS NULL AND TL.FechaAperturaCredito < DATEDIFF(MONTH,-3,@Fecha))  THEN '00'
					WHEN CEILING(CONVERT(DECIMAL(10,2),NumeroPagosVencidos)/NumeroPeriodosMensuales)=0 THEN '01'
					WHEN CEILING(CONVERT(DECIMAL(10,2),NumeroPagosVencidos)/NumeroPeriodosMensuales)=1 THEN '02'
					WHEN CEILING(CONVERT(DECIMAL(10,2),NumeroPagosVencidos)/NumeroPeriodosMensuales)=2 THEN '03'
					WHEN CEILING(CONVERT(DECIMAL(10,2),NumeroPagosVencidos)/NumeroPeriodosMensuales)=3 THEN '04'
					WHEN CEILING(CONVERT(DECIMAL(10,2),NumeroPagosVencidos)/NumeroPeriodosMensuales)=4 THEN '05'
					WHEN CEILING(CONVERT(DECIMAL(10,2),NumeroPagosVencidos)/NumeroPeriodosMensuales)=5 THEN '06'
					WHEN CEILING(CONVERT(DECIMAL(10,2),NumeroPagosVencidos)/NumeroPeriodosMensuales) BETWEEN 6 AND 12 THEN '07'
					WHEN CEILING(CONVERT(DECIMAL(10,2),NumeroPagosVencidos)/NumeroPeriodosMensuales) > 12 THEN '96'  
				END AS MopIntereses, --Se calcula de la misma manera que el mop anterior
				'' DiasVencimiento,
				TL.CorreoElectronicoConsumidor
			FROM 
				(SELECT 
						Creditos.EstatusCreditoId,
						Creditos.CreditoId,
						Solicitudes.PeriodicidadDescuentoId,
						Productos.DescuentoNomina,
						CASE WHEN Solicitudes.PeriodicidadDescuentoId = 1 THEN 4 --Semanal
							 WHEN Solicitudes.PeriodicidadDescuentoId = 2 THEN 2 -- Catorcenal
							 WHEN Solicitudes.PeriodicidadDescuentoId = 3 THEN 2 -- Quincenal
							 WHEN Solicitudes.PeriodicidadDescuentoId = 4 THEN 1 -- Mensual
						END AS NumeroPeriodosMensuales,
						Solicitudes.NumeroSolicitud AS NumeroCuenta,
						'I' TipoResponsabilidadCuenta,
						'I' TipoCuenta,
						'PL' TipoContratoProducto, -->>CAMBIO: Segun correo de observaciones [jueves 04/06/2015 05:38 p. m.] se cambio de CL a PL
						'MX' MonedaCredito,
						'' ImporteAvaluo,
						(SELECT 
								COUNT(0) 
							FROM 
								Credit.CreditosCalculos WHERE CreditosCalculos.CreditoId=Creditos.CreditoId
						) AS NumeroPagos,
						CASE 
							WHEN Solicitudes.PeriodicidadDescuentoId = 1 THEN 'W' --Semanal
							WHEN Solicitudes.PeriodicidadDescuentoId = 2 THEN 'K' -- Catorcenal
							WHEN Solicitudes.PeriodicidadDescuentoId = 3 THEN 'S' -- Quincenal
							WHEN Solicitudes.PeriodicidadDescuentoId = 4 THEN 'M' -- Mensual
						END AS FrecuenciaPagos,
						PeriodicidadDescuentos.PeriodicidadDescuento,
							--ISNULL((SELECT TOP 1 CreditosCalculos.MontoPago FROM Credit.CreditosCalculos WHERE CreditosCalculos.CreditoId=Creditos.CreditoId AND Creditos.EstatusCreditoId=1),0) *
							--CASE 
							--	WHEN Solicitudes.PeriodicidadDescuentoId = 1 THEN 4 --Semanal
							--	WHEN Solicitudes.PeriodicidadDescuentoId = 2 THEN 2 -- Catorcenal
							--	WHEN Solicitudes.PeriodicidadDescuentoId = 3 THEN 2 -- Quincenal
							--	WHEN Solicitudes.PeriodicidadDescuentoId = 4 THEN 1 -- Mensual
							--END AS MontoAPagar,  --Mientras el Credito este activo se debe reportar el monto mensualizado
						CASE WHEN
								(ISNULL((SELECT 
											SUM(CreditosCalculos.MontoPago) 
										FROM 
											Credit.CreditosCalculos 
										WHERE 
											CreditosCalculos.CreditoId = Creditos.CreditoId 
											AND Creditos.EstatusCreditoId IN(1,8)
											AND DATEPART(MONTH,DATEADD(MONTH,1,@Fecha)) = DATEPART(MONTH,FechaEsperadaPago)
											AND DATEPART(YEAR,DATEADD(MONTH,1,@Fecha)) = DATEPART(YEAR,FechaEsperadaPago)
										),0) = 0 AND Creditos.Saldo > 0) THEN 
																				ISNULL((SELECT 
																					SUM(CreditosCalculos.MontoPago) 
																				FROM 
																					Credit.CreditosCalculos 
																				WHERE 
																					CreditosCalculos.CreditoId=Creditos.CreditoId 
																					AND Creditos.EstatusCreditoId IN(1,8)
																					AND CreditosCalculos.PagoId IS NULL),0)
								ELSE
									ISNULL((SELECT 
											SUM(CreditosCalculos.MontoPago) 
										FROM 
											Credit.CreditosCalculos 
										WHERE 
											CreditosCalculos.CreditoId = Creditos.CreditoId 
											AND Creditos.EstatusCreditoId IN(1,8)
											AND DATEPART(MONTH,DATEADD(MONTH,1,@Fecha)) = DATEPART(MONTH,FechaEsperadaPago)
											AND DATEPART(YEAR,DATEADD(MONTH,1,@Fecha)) = DATEPART(YEAR,FechaEsperadaPago)
										),0)
							END AS MontoAPagar,  --Mientras el Credito este activo se debe reportar el monto mensualizado
							Creditos.FechaPago AS FechaAperturaCredito,
							(SELECT TOP 1 
								Pagos.FechaPago  
							FROM 
								Credit.CreditosCalculos INNER JOIN Credit.Pagos ON Pagos.PagoId=CreditosCalculos.PagoId 
							WHERE 
								CreditosCalculos.PagoId IS NOT NULL 
								AND CreditosCalculos.Procesado=1 
								AND CreditosCalculos.CreditoId=Creditos.CreditoId 
							ORDER BY Pagos.FechaPago DESC) AS FechaUltimoPago,
						'' FechaReporteInformacion,
						'' Garantia,
						Solicitudes.MontoCredito AS CreditoMaximoAutorizado,

						ISNULL((
							SELECT 
								SUM(CreditosCalculos.MontoPago) 
							FROM 
								Credit.CreditosCalculos 
							WHERE 
								CreditosCalculos.CreditoId=Creditos.CreditoId 
								AND CreditosCalculos.PagoId IS NULL 
								AND CreditosCalculos.Procesado=0),0) AS SaldoActual, 
						--'' LimiteCredito,

						(CASE 
								WHEN Productos.DescuentoNomina = 1 THEN 0 
								ELSE
									ISNULL((
										SELECT 
											SUM(CreditosCalculos.MontoPago) 
										FROM 
											Credit.CreditosCalculos 
										WHERE 
											CreditosCalculos.CreditoId = Creditos.CreditoId 
											AND @Fecha > CAST(CreditosCalculos.FechaEsperadaPago AS DATE) --Cambio de GETDATE a @Fecha
											AND CreditosCalculos.PagoId IS NULL 
											AND CreditosCalculos.Procesado = 0),0) 
						END) AS SaldoVencido,

						(CASE 
							WHEN Productos.DescuentoNomina=1 THEN 0 
							ELSE  
							
								CASE WHEN 
									(Creditos.EstatusCreditoId = 1 OR  Creditos.EstatusCreditoId = 8) THEN Credit.CalculaMoraFunction(Creditos.CreditoId,@Fecha)  --Calcula moratorios para Creditos Activos --Cambio de GETDATE a @Fecha
								ELSE
									0
								END
						END) AS Moratorios, 
						(CASE 
							WHEN Productos.DescuentoNomina = 1 THEN 0 
						ELSE
							(SELECT 
								COUNT(0) 
							FROM 
								Credit.CreditosCalculos 
							WHERE 
								CreditosCalculos.CreditoId=Creditos.CreditoId 
								AND @Fecha > CAST(CreditosCalculos.FechaEsperadaPago AS DATE) --Cambio de GETDATE a @Fecha
								AND CreditosCalculos.PagoId IS NULL 
								AND CreditosCalculos.Procesado=0) 
						END) AS NumeroPagosVencidos,
						'' ClaveObservacion,
						'' ClaveUsuarioAnteriorTL,
						'' NombreUsuarioAnteriorTL,
						'' NumeroCuentaAnteriorTL,
						(CASE 
							WHEN Productos.DescuentoNomina=1 THEN CONVERT(DATE,'01/01/1900',103) 
							ELSE
								ISNULL((SELECT TOP 1 
											CreditosCalculos.FechaEsperadaPago 
										FROM 
											Credit.CreditosCalculos LEFT JOIN Credit.Pagos 
												ON Pagos.PagoId=CreditosCalculos.PagoId  
										WHERE 
											CreditosCalculos.CreditoId=Creditos.CreditoId 
											AND (Pagos.FechaPago>CreditosCalculos.FechaEsperadaPago -- Que la Fecha de Pago sea mayor a la FechaEsperada de pago dando una tolerancia de 5 días
												OR  (@Fecha > CAST(CreditosCalculos.FechaEsperadaPago AS DATE) --Cambio de GETDATE a @Fecha
												AND CreditosCalculos.PagoId IS NULL 
												AND CreditosCalculos.Procesado=0)) --Que la fecha actual sea mayor a la FechaEsperada de pago dando una tolerancia de 5 días
										ORDER BY CreditosCalculos.FechaEsperadaPago ASC),CONVERT(DATE,'01/01/1900',103)) 
						END) AS FechaPrimerIncumplimiento,
						Creditos.Saldo AS SaldoInsolutoPrincipal,
						(SELECT TOP 1 
							CASE 
								WHEN Pagos.EmpresaId IS NOT NULL THEN CreditosCalculos.MontoPago  
								ELSE Pagos.MontoPago 
							END  
						FROM 
							Credit.CreditosCalculos INNER JOIN Credit.Pagos 
								ON Pagos.PagoId=CreditosCalculos.PagoId 
						WHERE 
							CreditosCalculos.Procesado=1 AND 
							CreditosCalculos.CreditoId=Creditos.CreditoId 
						ORDER BY Pagos.FechaPago DESC) AS MontoUltimoPago,
						(SELECT TOP 1 
							CreditosCalculos.FechaEsperadaPago 
						FROM 
							Credit.CreditosCalculos 
						WHERE 
							CreditosCalculos.CreditoId = Creditos.CreditoId 
							AND CreditosCalculos.Periodo=1
						) AS FechaEsperadaPrimerPago,
						Plazos.Meses PlazoMeses,
						Solicitudes.MontoCredito,
						--Inicio: Version 14:
						'' AS FechaIngresoCarteraVencida,
						ISNULL((SELECT 
										SUM(CreditosCalculos.MontoInteresOrdinario) 
									FROM 
										Credit.CreditosCalculos 
									WHERE 
										CreditosCalculos.CreditoId=Creditos.CreditoId 
										AND Creditos.EstatusCreditoId IN(1,8)
										AND DATEPART(MONTH,DATEADD(MONTH,1,@Fecha)) = DATEPART(MONTH,FechaEsperadaPago)
										AND DATEPART(YEAR,DATEADD(MONTH,1,@Fecha)) = DATEPART(YEAR,FechaEsperadaPago)
									),0) AS MontoIntereses,  
						'' AS DiasVencimiento,
						CorreosElectronicos.CorreoElectronico AS CorreoElectronicoConsumidor
						--Fin: Version 14:
					FROM 
						Credit.Creditos INNER JOIN Credit.Solicitudes 
							ON Solicitudes.SolicitudId=Creditos.SolicitudId
						INNER JOIN Global.Plazos
							ON Solicitudes.PlazoId = Plazos.PlazoId
						INNER JOIN Credit.Clientes 
							ON Clientes.ClienteId=Solicitudes.ClienteId
						INNER JOIN Global.PeriodicidadDescuentos 
							ON PeriodicidadDescuentos.PeriodicidadDescuentoId=Solicitudes.PeriodicidadDescuentoId
						INNER JOIN Credit.Productos 
							ON Productos.ProductoId=Solicitudes.ProductoId
						--Correo Electronico Acreditado--
						INNER JOIN Credit.PersonasCorreosElectronicos
							ON Clientes.PersonaId = PersonasCorreosElectronicos.PersonaId
						INNER JOIN (SELECT 
									PersonaId,
									MIN(CorreoElectronicoId) CorreoElectronicoId
								FROM
									Credit.PersonasCorreosElectronicos
								GROUP BY PersonaId) PrimerCorreoElectronico
							ON PersonasCorreosElectronicos.CorreoElectronicoId = PrimerCorreoElectronico.CorreoElectronicoId
						INNER JOIN Credit.CorreosElectronicos
							ON PrimerCorreoElectronico.CorreoElectronicoId = CorreosElectronicos.CorreoElectronicoId


					WHERE 
						Clientes.MultiEmpresaId=@MultiEmpresaId
						AND CAST(Creditos.FechaPago AS DATE) <= @Fecha
				) TL

		-----------------------------------------
		-->>FIN: EXTRAE INFORMACION DE CREDITOS--
		-----------------------------------------


		IF @TipoReporte = 1 --REPORTE INTEGRAL
		BEGIN
				DECLARE 
					@ReporteIntegralBCId INT,
					@SegmentosPN INT,
					@SegmentosPE INT
					

				SELECT
					@ReporteIntegralBCId = ReporteIntegralBCId
				FROM 
					[Credit].[ReportesIntegralesBC]
				WHERE
					MultiEmpresaId = @MultiempresaId AND
					CONVERT(DATE,Fecha) = @Fecha AND
					Estatus = 1

				--Si el reporte no existe se crea
				IF @ReporteIntegralBCId IS NULL
					BEGIN
						--INSERTAR INFORMACIÓN GENERAL DEL REPORTE
							INSERT INTO Credit.ReportesIntegralesBC(
								[MultiEmpresaId],
								[Version],
								[ClaveUsuario],
								[NombreUsuario],
								[Fecha],
								[NombreArchivo],
								[TotalSaldosActuales],
								[TotalSaldosVencidos],
								[SegmentosINTF],
								[SegmentosPN],
								[SegmentosPA],
								[SegmentosPE],
								[SegmentosTL],
								[Bloques],
								[UsuarioDevolucion],
								[DireccionUsuarioDevolucion],
								[UsuarioAltaId]
							)VALUES(
								@MultiEmpresaId,
								@Version,
								@ClaveUsuario,
								@NombreUsuario,
								@Fecha,
								@NombreArchivo,
								0,--[TotalSaldosActuales]
								0,--[TotalSaldosVencidos]
								0,--[SegmentosINTF]
								0,--[SegmentosPN]
								0,--[SegmentosPA]
								0,--[SegmentosPE]
								0,--[SegmentosTL]
								0,--[Bloques]
								@UsuarioDevolucion,
								@DireccionUsuarioDevolucion,
								@UsuarioAltaId
							)

							--RECUPERA EL IDENTITY CREADO
							SET @ReporteIntegralBCId = SCOPE_IDENTITY()

							----------------------------------------
							----------------------------------------
							----------------------------------------

							--INSERTAR INFORMACIÓN DE CREDITOS A LA TABLA DETALLE DE REPORTE
							INSERT INTO [Credit].[ReportesIntegralesBCDetalle] (
								[ReporteIntegralBCId],
								[NumeroCuentaTL],
								[TipoResponsabilidadTL],
								[TipoCuentaTL],
								[TipoContratoTL],
								[MonedaTL],
								[ImporteAvaluoTL],
								[NumeroPagosTL],
								[FrecuenciaPagosTL],
								[MontoPagarTL],
								[FechaAperturaTL],
								[FechaUltimoPagoTL],
								[FechaUltimaCompraTL],
								[FechaCierreTL],
								[FechaReporteTL],
								[GarantiaTL],
								[CreditoMaximoTL],
								[SaldoActualTL],
								[SaldoVencidoTL],
								[PagosVencidosTL],
								[MopTL],
								[ClaveObservacionTL],
								[ClaveUsuarioAnteriorTL],
								[NombreUsuarioAnteriorTL],
								[NumeroCuentaAnteriorTL],
								[FechaPrimerInclumplimientoTL],
								[SaldoInsolutoPrincipalTL],
								[MontoUltimoPagoTL],
								[PlazoMesesTL],
								[MontoCreditoTL],
								--Inicio: Version 14
								[FechaIngresoCarteraVencidaTL],
								[MontoInteresesTL],
								[MopInteresesTL],
								[DiasVencimientoTL],
								[CorreoElectronicoConsumidorTL],
								--Fin: Version 14
								[UsuarioAltaId])
							SELECT
								@ReporteIntegralBCId,
								[NumeroCuentaTL],
								[TipoResponsabilidadTL],
								[TipoCuentaTL],
								[TipoContratoTL],
								[MonedaTL],
								[ImporteAvaluoTL],
								[NumeroPagosTL],
								[FrecuenciaPagosTL],
								[MontoPagarTL],
								[FechaAperturaTL],
								[FechaUltimoPagoTL],
								[FechaUltimaCompraTL],
								[FechaCierreTL],
								[FechaReporteTL],
								[GarantiaTL],
								[CreditoMaximoTL],
								[SaldoActualTL],
								[SaldoVencidoTL],
								[PagosVencidosTL],
								[MopTL],
								[ClaveObservacionTL],
								[ClaveUsuarioAnteriorTL],
								[NombreUsuarioAnteriorTL],
								[NumeroCuentaAnteriorTL],
								[FechaPrimerInclumplimientoTL],
								[SaldoInsolutoPrincipalTL],
								[MontoUltimoPagoTL],
								[PlazoMesesTL],
								[MontoCreditoTL],
								--Inicio: Version 14
								[FechaIngresoCarteraVencidaTL],
								[MontoInteresesTL],
								[MopInteresesTL],
								[DiasVencimientoTL],
								[CorreoElectronicoConsumidorTL],
								--Fin: Version 14
								@UsuarioAltaId
							FROM 
								@InformacionCartera
							ORDER BY [NumeroCuentaTL]


							--TABLA EN DONDE SE UNEN IDENTIFICADORES DE TABLAS: SOLICITUDES Y CLIENTES 
							DECLARE @LinkTable TABLE(
								SolicitudId INT NOT NULL,
								NumeroSolicitud NVARCHAR(15) NOT NULL,
								ClienteId  INT NOT NULL,
								PersonaId  INT NOT NULL
							)

							INSERT INTO @LinkTable
							SELECT
								[Solicitudes].[SolicitudId],
								[Solicitudes].[NumeroSolicitud],
								[Clientes].[ClienteId],
								[Clientes].[PersonaId]
							FROM 
								[Credit].[Solicitudes] INNER JOIN [Credit].[Clientes]
									ON [Solicitudes].[ClienteId] = [Clientes].[ClienteId]
							WHERE
								Solicitudes.NumeroSolicitud IN(
																	SELECT 
																		NumeroCuentaTL 
																	FROM 
																		@InformacionCartera
																)

							--------------------------------------------
							--* INICIO: SEGMENTO PE, DATOS LABORALES *--
							--------------------------------------------
							IF OBJECT_ID('tempdb..#DatosLaboralesCompletos') IS NOT NULL
								DROP TABLE #DatosLaboralesCompletos

							SELECT
								[DatoLaboralUnico].[DatoLaboralId],
								[DatoLaboralUnico].[SolicitudId],
								[DatoLaboralUnico].[EmpresaId],
								[Trabajos].[Empresa],
								[Trabajos].[NumeroEmpleado],
								[Trabajos].[Puesto],
								[Trabajos].[Area],
								[Trabajos].[SueldoBruto],
								[Trabajos].[TotalDeducciones],
								[Trabajos].[SueldoNeto],
								[Trabajos].[GastosMensuales],
								[Trabajos].[FechaIngreso],
								[Trabajos].[NombreJefeInmediato],
								[Trabajos].[PuestoJefeInmediato],
								[Direcciones].[Calle],
								[Direcciones].[NumeroExterior],
								[Direcciones].[NumeroInterior],
								LTRIM(RTRIM([Direcciones].Calle)) + ' ' + 	
								LTRIM(RTRIM([Direcciones].NumeroExterior)) + ' ' + 
								CASE 
									WHEN (LTRIM(RTRIM([Direcciones].NumeroInterior)) = '' OR  [Direcciones].NumeroInterior IS NULL) THEN '' 
									ELSE 'INT ' + [Direcciones].NumeroInterior 
								END Direccion,
								[ColoniasLaboral].[ColoniaId],
								[ColoniasLaboral].[Colonia],
								[Direcciones].[CodigoPostal],
								[MunicipiosLaboral].[MunicipioId],
								[MunicipiosLaboral].[Municipio],
								[EstadosLaboral].[EstadoId],
								[EstadosLaboral].[Estado],
								[EstadosLaboral].[ClaveBuroCredito] EstadoClaveBuroCredito,
								Telefonos.Telefono,
								Telefonos.Extension
							INTO 
								#DatosLaboralesCompletos
							FROM
								--SELECCIONAR EL PRIMER DATO LABORAL CAPTURADO "MIN(DatoLaboralId)" DE LA SOLICITUD
								(SELECT 
										DatosLaborales.*
									FROM
										Credit.DatosLaborales INNER JOIN (SELECT 
												DatosLaborales.SolicitudId,
												MIN(DatoLaboralId) DatoLaboralId
											FROM
												Credit.DatosLaborales INNER JOIN @LinkTable LinkTable --Solo información de las solicitudes reportadas
													ON(DatosLaborales.SolicitudId = LinkTable.SolicitudId)
											GROUP BY DatosLaborales.SolicitudId) AS DatoLaboralMasAntiguo
										ON DatosLaborales.DatoLaboralId = DatoLaboralMasAntiguo.DatoLaboralId
								) DatoLaboralUnico
								INNER JOIN Credit.Trabajos
									ON DatoLaboralUnico.TrabajoId = Trabajos.TrabajoId
								--TOMAR EL PRIMER NUMERO TELEFÓNICO DEL DATO LABORAL
								INNER JOIN Credit.TrabajosTelefonos 
									ON Trabajos.TrabajoId = TrabajosTelefonos.TrabajoId
								INNER JOIN (SELECT 
												TrabajoId, 
												MIN(TelefonoId) DatoLaboralTelefonoId 
											FROM 
												Credit.TrabajosTelefonos 
											GROUP BY TrabajoId
											) PrimerTelefonoLaborales
									ON TrabajosTelefonos.TelefonoId = PrimerTelefonoLaborales.DatoLaboralTelefonoId
								INNER JOIN Credit.Telefonos
									ON TrabajosTelefonos.TelefonoId = Telefonos.TelefonoId
								--DEMAS TABLAS
								LEFT JOIN Credit.Direcciones
									ON Trabajos.DireccionId = Direcciones.DireccionId
								LEFT JOIN Global.Colonias ColoniasLaboral 
									ON Direcciones.ColoniaId = ColoniasLaboral.ColoniaId
								LEFT JOIN Global.Municipios MunicipiosLaboral
									ON ColoniasLaboral.MunicipioId = MunicipiosLaboral.MunicipioId
								LEFT JOIN Global.Estados EstadosLaboral
									ON MunicipiosLaboral.EstadoId = EstadosLaboral.EstadoId
	
							--------------------------------------------
							--* INICIO: SEGMENTO PE, DATOS LABORALES *--
							--------------------------------------------

							--------------------------------------------------
							--* INICIO: CONSTRUCCION SEGMENTOS ORIGINACION *--
							--------------------------------------------------

							IF OBJECT_ID('tempdb..#InformacionOriginacion') IS NOT NULL
								DROP TABLE #InformacionOriginacion


							SELECT 
								Solicitudes.NumeroSolicitud,
								-->INICIO DEL SEGMENTO [PN]<--
								LTRIM(RTRIM(ApellidoPaterno)) AS ApellidoPaterno,
								LTRIM(RTRIM(ApellidoMaterno)) AS ApellidoMaterno,
								CASE WHEN CHARINDEX(' ',LTRIM(RTRIM(Nombre)))>0 
									THEN  
										LTRIM(RTRIM(LEFT(LTRIM(RTRIM(Nombre)),CHARINDEX(' ', LTRIM(RTRIM(Nombre))))))
									ELSE 
										LTRIM(RTRIM(Nombre))
								END PrimerNombre,
								CASE WHEN CHARINDEX(' ',LTRIM(RTRIM(Nombre)))>0 
									THEN 
										LTRIM(RTRIM(SUBSTRING(LTRIM(RTRIM(Nombre)),CHARINDEX(' ',LTRIM(RTRIM(Nombre))),LEN(LTRIM(RTRIM(Nombre)))-CHARINDEX(' ',LTRIM(RTRIM(Nombre))) + 1)))
									ELSE 
										NULL
								END SegundoNombre,
								REPLACE(CONVERT(VARCHAR(10), FechaNacimiento, 103), '/', '') AS FechaNacimiento,
								LTRIM(RTRIM(Rfc)) AS Rfc,
								Nacionalidades.ClaveBuroCredito Nacionalidad,
								CASE 
									WHEN 
										Domicilios.TipoDomicilioId = 4 THEN 1
									ELSE 
										Domicilios.TipoDomicilioId 
								END TipoResidencia,
								CASE SolicitudesPersonaFisica.EstadoCivilId 
									WHEN 1 THEN 'S' --SOLTERO
									WHEN 2 THEN 'M' --CASADO
									WHEN 3 THEN 'D' --DIVORCIADO
									WHEN 4 THEN 'F' --UNIÓN LIBRE
									--FALTA VIUDO 'W'
								END EstadoCivil, 
								CASE PersonasFisicas.GeneroId WHEN 1 THEN 'F' ELSE 'M' END Sexo,
								PersonasFisicas.NumeroSeguridadSocial,
								Curp,
								PaisesNacimiento.ClaveBuroCredito AS ClavePais,
								RIGHT ('00'+ CAST (SolicitudesPersonaFisica.DependientesEconomicos AS varchar), 2) NumeroDependientes,
								-->FIN DEL SEGMENTO [PN]<--
								---------------------------
								-->INICIO DEL SEGMENTO [PA]<--
								CASE 
									WHEN (LEN(LTRIM(RTRIM(Direcciones.Calle)) + ' ' + 	
										LTRIM(RTRIM(Direcciones.NumeroExterior)) + ' ' + 
											CASE 
												WHEN (LTRIM(RTRIM(Direcciones.NumeroInterior)) = '' OR  Direcciones.NumeroInterior IS NULL) 
													THEN '' 
												ELSE 
													'INT ' + Direcciones.NumeroInterior 
											END)>40) THEN LEFT(LTRIM(RTRIM(Direcciones.Calle)) + ' ' + 	
																LTRIM(RTRIM(Direcciones.NumeroExterior)) + ' ' + 
																	CASE 
																		WHEN (LTRIM(RTRIM(Direcciones.NumeroInterior)) = '' OR  Direcciones.NumeroInterior IS NULL) THEN '' 
																		ELSE 'INT ' + Direcciones.NumeroInterior 
																	END,40)
									ELSE
										LTRIM(RTRIM(Direcciones.Calle)) + ' ' + 	
										LTRIM(RTRIM(Direcciones.NumeroExterior)) + ' ' + 
											CASE 
												WHEN (LTRIM(RTRIM(Direcciones.NumeroInterior)) = '' OR  Direcciones.NumeroInterior IS NULL) THEN '' 
												ELSE 'INT ' + Direcciones.NumeroInterior 
											END
								END Direccion1,
								CASE 
									WHEN (LEN(LTRIM(RTRIM(Direcciones.Calle)) + ' ' + 	
										LTRIM(RTRIM(Direcciones.NumeroExterior)) + ' ' + 
											CASE 
												WHEN (LTRIM(RTRIM(Direcciones.NumeroInterior)) = '' OR  Direcciones.NumeroInterior IS NULL) 
													THEN '' 
												ELSE 
													'INT ' + Direcciones.NumeroInterior 
											END)>40) THEN RIGHT(LTRIM(RTRIM(Direcciones.Calle)) + ' ' + 	
																LTRIM(RTRIM(Direcciones.NumeroExterior)) + ' ' + 
																	CASE 
																		WHEN (LTRIM(RTRIM(Direcciones.NumeroInterior)) = '' OR  Direcciones.NumeroInterior IS NULL) THEN ''
																		ELSE 'INT ' + Direcciones.NumeroInterior 
																	END,LEN(LTRIM(RTRIM(Direcciones.Calle)) + ' ' + 	
																		LTRIM(RTRIM(Direcciones.NumeroExterior)) + ' ' + 
																			CASE 
																				WHEN (LTRIM(RTRIM(Direcciones.NumeroInterior)) = '' OR  Direcciones.NumeroInterior IS NULL) THEN ''
																				ELSE 'INT ' + Direcciones.NumeroInterior 
																			END)-40)
									ELSE
										NULL
								END Direccion2,
								Colonias.Colonia,
								Municipios.Municipio,
								Estados.ClaveBuroCredito Estado,
								Direcciones.CodigoPostal,
								Telefonos.Telefono,
								Telefonos.Extension,
								'MX' OrigenDomicilioPA,
								-->FIN DEL SEGMENTO [PA]<--
								---------------------------
								-->INICIO DEL SEGMENTO [PE]<--
								LTRIM(RTRIM(DatosLaboralesCompletos.Empresa)) NombreEmpresa,
								CASE 
									WHEN (LEN(DatosLaboralesCompletos.Direccion)>40) THEN LEFT(DatosLaboralesCompletos.Direccion,40)
									ELSE DatosLaboralesCompletos.Direccion
								END DireccionEmpresa1,
								CASE 
									WHEN (LEN(DatosLaboralesCompletos.Direccion)>40) THEN RIGHT(DatosLaboralesCompletos.Direccion,LEN(DatosLaboralesCompletos.Direccion)-40)
									ELSE
										NULL
								END DireccionEmpresa2,
								DatosLaboralesCompletos.Colonia ColoniaEmpresa,
								DatosLaboralesCompletos.Municipio MunicipioEmpresa,
								DatosLaboralesCompletos.EstadoClaveBuroCredito EstadoEmpresa,
								DatosLaboralesCompletos.CodigoPostal CodigoPostalEmpresa,
								DatosLaboralesCompletos.Telefono TelefonoLaboral,
								DatosLaboralesCompletos.Extension ExtensionLaboral,
								DatosLaboralesCompletos.Puesto,
								REPLACE(CONVERT(VARCHAR(10), DatosLaboralesCompletos.FechaIngreso, 103), '/', '') AS FechaContratacion,
								DatosLaboralesCompletos.NumeroEmpleado,
								'MX' OrigenDomicilioPE
								-->FIN DEL SEGMENTO [PE]<--
							INTO
								#InformacionOriginacion
							FROM
								@LinkTable LinkTable --INNER JOIN Credit.Clientes  
									--ON(LinkTable.ClienteId = Clientes.ClienteId) -->Solo Información de Clientes Reportados
								INNER JOIN Credit.PersonasFisicas
									ON LinkTable.PersonaId = PersonasFisicas.PersonaId

								INNER JOIN	Global.Nacionalidades 
									ON PersonasFisicas.NacionalidadId = Nacionalidades.NacionalidadId
	
								INNER JOIN Credit.Solicitudes 
									ON 
										LinkTable.ClienteId = Solicitudes.ClienteId			---/>Solo Información de Solicitudes Reportadas
										AND LinkTable.SolicitudId = Solicitudes.SolicitudId	--/

								--SOLICITUDES PERSONA FISICA
								INNER JOIN Credit.SolicitudesPersonaFisica
									ON SolicitudesPersonaFisica.SolicitudId = Solicitudes.SolicitudId


								INNER JOIN Credit.Domicilios
									ON Solicitudes.SolicitudId = Domicilios.SolicitudId

								INNER JOIN Credit.Direcciones
									ON Domicilios.DireccionId =  Direcciones.DireccionId

								INNER JOIN Global.Nacionalidades PaisesNacimiento
									ON PaisesNacimiento.NacionalidadId = PersonasFisicas.PaisNacimientoId
								INNER JOIN Global.Colonias
									ON Direcciones.ColoniaId = Colonias.ColoniaId
								INNER JOIN	Global.Municipios
									ON Colonias.MunicipioId = Municipios.MunicipioId
								INNER JOIN	Global.Estados
									ON Municipios.EstadoId = Estados.EstadoId
								LEFT JOIN #DatosLaboralesCompletos DatosLaboralesCompletos --DATOS LABORALES
									ON Solicitudes.SolicitudId = DatosLaboralesCompletos.SolicitudId
								--TELÉFONOS CASA CLIENTE
								LEFT JOIN 
									(SELECT
										PersonaId,
										MAX(Telefono) Telefono,
										MAX(Extension) Extension
									FROM 
										Credit.PersonasTelefonos INNER JOIN Credit.Telefonos
											ON PersonasTelefonos.TelefonoId = Telefonos.TelefonoId
									WHERE
										TipoTelefonoId = 1 --CASA
									GROUP BY PersonaId) Telefonos --Solo un teléfono de casa
										ON LinkTable.PersonaId = Telefonos.PersonaId

							-----------------------------------------------
							--* FIN: CONSTRUCCION SEGMENTOS ORIGINACION *--
							-----------------------------------------------

							UPDATE 
								A
							SET
								A.ApellidoPaternoPN = SUBSTRING(B.ApellidoPaterno,1,26),
								A.ApellidoMaternoPN = SUBSTRING(B.ApellidoMaterno,1,26),
								A.PrimerNombrePN = SUBSTRING(B.PrimerNombre,1,26),
								A.SegundoNombrePN = SUBSTRING(B.SegundoNombre,1,26),
								A.FechaNacimientoPN = B.FechaNacimiento,
								A.RfcPN = B.Rfc,
								A.NacionalidadPN = B.Nacionalidad,
								A.TipoResidenciaPN = B.TipoResidencia,
								A.EstadoCivilPN = B.EstadoCivil,
								A.SexoPN = B.Sexo,
								A.NumeroSeguridadSocialPN = SUBSTRING(B.NumeroSeguridadSocial,1,20),
								A.CurpPN = B.Curp,
								A.ClavePaisPN = B.ClavePais,
								A.NumeroDependientesPN = B.NumeroDependientes,
								A.Direccion1PA = SUBSTRING(B.Direccion1,1,40),
								A.Direccion2PA = SUBSTRING(B.Direccion2,1,40),
								A.ColoniaPA = SUBSTRING(B.Colonia,1,40),
								A.MunicipioPA = SUBSTRING(B.Municipio,1,40),
								A.EstadoPA = B.Estado,
								A.CodigoPostalPA = B.CodigoPostal,
								A.TelefonoPA = B.Telefono,
								A.ExtensionPA = B.Extension,
								A.OrigenDomicilioPA = B.OrigenDomicilioPA,
								A.RazonSocialPE = SUBSTRING(B.NombreEmpresa,1,99),----1
								A.Direccion1PE = SUBSTRING(B.DireccionEmpresa1,1,40),
								A.Direccion2PE = SUBSTRING(B.DireccionEmpresa2,1,40),
								A.ColoniaPE = SUBSTRING(B.ColoniaEmpresa,1,40),
								A.MunicipioPE = SUBSTRING(B.MunicipioEmpresa,1,40),
								A.EstadoPE = B.EstadoEmpresa,
								A.CodigoPostalPE = B.CodigoPostalEmpresa,
								A.CargoPE = SUBSTRING(B.Puesto,1,30), ----2
								A.FechaContratacionPE = B.FechaContratacion,
								A.NumeroEmpleadoPE = SUBSTRING(B.NumeroEmpleado,1,15),
								A.TelefonoPE = SUBSTRING(B.TelefonoLaboral,1,11),
								A.ExtensionPE = SUBSTRING(B.ExtensionLaboral,1,8),
								A.OrigenDomicilioPE =  B.OrigenDomicilioPE
							FROM 
								[Credit].[ReportesIntegralesBCDetalle] A INNER JOIN #InformacionOriginacion B
									ON(LTRIM(RTRIM(A.NumeroCuentaTL)) = LTRIM(RTRIM(B.NumeroSolicitud)))

							WHERE 
								A.[ReporteIntegralBCId] = @ReporteIntegralBCId

							--ACTUALIZA RESUMEN DE SEGMENTOS

							SELECT @SegmentosTL = COUNT(1) FROM @InformacionCartera
							SELECT @SegmentosPE = COUNT(1) FROM #DatosLaboralesCompletos
							SELECT @SegmentosPN = COUNT(1) FROM #InformacionOriginacion

							SELECT  
								@TotalSaldosActuales = SUM(CAST(ISNULL(SaldoActualTL,0) AS INT)),
								@TotalSaldosVencidos = SUM(CAST(ISNULL(SaldoVencidoTL,0) AS INT))
							FROM 
								[Credit].[ReportesIntegralesBCDetalle]
							WHERE
								[ReporteIntegralBCId] = @ReporteIntegralBCId


							UPDATE 
								[Credit].[ReportesIntegralesBC]
							SET 
								[TotalSaldosActuales] = @TotalSaldosActuales,
								[TotalSaldosVencidos] = @TotalSaldosVencidos,
								[SegmentosINTF] = 1, --Siempre se reporta un segmento INTF
								[SegmentosPN] =	@SegmentosPN,
								[SegmentosPA] = @SegmentosPN,
								[SegmentosPE] = @SegmentosPE,
								[SegmentosTL] = @SegmentosTL
							WHERE
								[ReporteIntegralBCId] = @ReporteIntegralBCId

	

							--Elimina tablas temporales
							DROP TABLE #DatosLaboralesCompletos
							DROP TABLE #InformacionOriginacion
					END

				--Si el reporte existe se crea se selecciona la información
				IF @ReporteIntegralBCId IS NOT NULL
				BEGIN
					SET @ReporteBCId = @ReporteIntegralBCId 
				END
			END --IF @TipoReporte = 1 
			---------------------------------------------------------------------------------
			IF @TipoReporte = 2 --REPORTE PARCIAL
			BEGIN

				DECLARE @ReporteParcialBCId INT

				SELECT
					@ReporteParcialBCId = ReporteParcialBCId
				FROM 
					[Credit].[ReportesParcialesBC]
				WHERE
					MultiEmpresaId = @MultiempresaId AND
					CONVERT(DATE,Fecha) = @Fecha AND
					Estatus = 1

				--Si el reporte no existe se crea
				IF @ReporteParcialBCId IS NULL
					BEGIN
						--INSERTAR INFORMACIÓN GENERAL DEL REPORTE
							INSERT INTO Credit.ReportesParcialesBC(
								[MultiEmpresaId],
								[ClaveUsuario],
								[NombreUsuario],
								[Fecha],
								[NombreArchivo],
								[RegistrosReportados],
								[SaldosActuales],
								[SaldosVencidos],
								[UsuarioAltaId]
							)VALUES(
								@MultiEmpresaId,
								@ClaveUsuario,
								@NombreUsuario,
								@Fecha,
								@NombreArchivo,
								0,--[RegistrosReportados]
								0,--[SaldosActuales]
								0,--[SaldosVencidos]
								@UsuarioAltaId
							)

							--RECUPERA EL IDENTITY CREADO
							SET @ReporteParcialBCId = SCOPE_IDENTITY()

							----------------------------------------
							----------------------------------------
							----------------------------------------

							--INSERTAR INFORMACIÓN DE CRÉDITOS A LA TABLA DETALLE DE REPORTE
							INSERT INTO [Credit].[ReportesParcialesBCDetalle] (
								[ReporteParcialBCId],
								[NumeroCuenta],
								[TipoResponsabilidad],
								[TipoCuenta],
								[TipoContrato],
								[Moneda],
								[NumeroPagos],
								[FrecuenciaPagos],
								[MontoPagar],
								[FechaApertura],
								[FechaUltimoPago],
								[FechaUltimaCompra],
								[FechaCierre],
								[FechaReporte],
								[CreditoMaximo],
								[SaldoActual],
								[SaldoVencido],
								[PagosVencidos],
								[Mop],
								[ClaveObservacion],
								[SaldoInsolutoPrincipal],
								[MontoUltimoPago],
								[UsuarioAltaId])
							SELECT
								@ReporteParcialBCId,
								[NumeroCuentaTL],
								[TipoResponsabilidadTL],
								[TipoCuentaTL],
								[TipoContratoTL],
								[MonedaTL],
								[NumeroPagosTL],
								[FrecuenciaPagosTL],
								[MontoPagarTL],
								[FechaAperturaTL],
								[FechaUltimoPagoTL],
								[FechaUltimaCompraTL],
								[FechaCierreTL],
								[FechaReporteTL],
								[CreditoMaximoTL],
								[SaldoActualTL],
								[SaldoVencidoTL],
								[PagosVencidosTL],
								[MopTL],
								[ClaveObservacionTL],
								[SaldoInsolutoPrincipalTL],
								[MontoUltimoPagoTL],
								@UsuarioAltaId
							FROM 
								@InformacionCartera
							ORDER BY [NumeroCuentaTL]

							---------------------------------------------------------------------------------------------
							--Eliminar Registros Parciales que no hayan sido reportados en el Reporte Integral Anterior--
							---------------------------------------------------------------------------------------------


							---SELECCIONAR REPORTE INTEGRAL INMEDIATO ANTERIOR
							DECLARE @ReporteIntegralBCIdAnt INT


							SELECT 
								@ReporteIntegralBCIdAnt = ReporteIntegralBCId
							FROM 
								[Credit].[ReportesIntegralesBC] 
							WHERE
								Fecha = (SELECT 
											MAX(Fecha) 
										FROM 
											[Credit].[ReportesIntegralesBC] 
										WHERE 
											MultiEmpresaId = @MultiEmpresaId
											AND Fecha < @Fecha
											AND Estatus = 1
											)
								AND Estatus = 1

							---ELIMINAR DEL REGISTRO PARCIAL LOS QUE NO HAYAN SIDO REPORTADOS EN EL INTEGRAL ANTERIOR
							DELETE
								Parcial
							FROM 
								[Credit].[ReportesParcialesBCDetalle] Parcial LEFT JOIN [Credit].[ReportesIntegralesBCDetalle] Integral
									ON  
										(Parcial.NumeroCuenta = Integral.NumeroCuentaTL
										AND Integral.ReporteIntegralBCId = @ReporteIntegralBCIdAnt)
							WHERE
								Parcial.ReporteParcialBCID  = @ReporteParcialBCId
								AND Integral.NumeroCuentaTL IS NULL



							--ACTUALIZA RESUMEN DE CONCEPTOS
							SELECT 
								@SegmentosTL = COUNT(1),
								@TotalSaldosActuales = SUM(CAST(ISNULL(SaldoActual,0) AS INT)),
								@TotalSaldosVencidos = SUM(CAST(ISNULL(SaldoVencido,0) AS INT))
							FROM 
								[Credit].[ReportesParcialesBCDetalle]
							WHERE
								ReporteParcialBCId = @ReporteParcialBCId

							UPDATE 
								[Credit].[ReportesParcialesBC]
							SET 
								[RegistrosReportados] = @SegmentosTL,
								[SaldosActuales] = @TotalSaldosActuales,
								[SaldosVencidos] = @TotalSaldosVencidos
							WHERE
								ReporteParcialBCId = @ReporteParcialBCId
					END

				--Si el reporte existe se crea se selecciona la información
				IF @ReporteParcialBCId IS NOT NULL
				BEGIN
					SET @ReporteBCId = @ReporteParcialBCId 
				END
			END --IF @TipoReporte = 2

			--Se Devuelve el identificador del reporte generado o consultado segun sea el caso
			IF @ReporteBCId IS NOT NULL
				BEGIN
					SELECT 
						@ReporteBCId AS ReporteBCId
				END

	END --IF @TipoReporte = 1 OR @TipoReporte = 2

	COMMIT TRAN
END TRY       
BEGIN CATCH
   IF @@trancount > 0 ROLLBACK TRANSACTION                        
   EXEC Credit.ErrorHandlerStoredProcedure                                         
   RETURN 55555                                                   
END CATCH
