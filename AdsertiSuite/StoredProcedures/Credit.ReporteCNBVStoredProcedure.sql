USE [AdsertiSuite]
GO
/****** Object:  StoredProcedure [Credit].[ReporteCNBVStoredProcedure]    Script Date: 08/05/2017 16:19:18 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


ALTER PROCEDURE [Credit].[ReporteCNBVStoredProcedure]
	@MultiempresaId INTEGER,
	@TipoReporteId INTEGER,
	@Fecha DATE,
	@NombreArchivo VARCHAR(50),
	@Reportable24Horas BIT,
	@UsuarioAltaId INTEGER
AS
BEGIN TRY

   SET NOCOUNT ON                                                
   SET XACT_ABORT ON                                            

   BEGIN TRAN
		DECLARE 
			@Periodo INTEGER,
			@Mes INTEGER,
			@ReporteCNBVId INTEGER,
			@Separador CHAR,
			@ClasificacionAlertaLavadoDineroId INT,
			@FechaGeneracion DATETIME

		SET @Separador = ';'
		SET @Mes = MONTH(@Fecha)
		SET @FechaGeneracion = GETDATE()

		--INICIO: SECCIÓN VARIABLE POR MULTIEMPRESA
		DECLARE 
			@OrganoSupervisor VARCHAR(6),
			@ClaveSujetoObligado VARCHAR(7),
			@Localidad VARCHAR(8),
			@CodigoPostalSucursal VARCHAR(5)

		SELECT @OrganoSupervisor = Parametro FROM Global.Parametros WHERE MultiEmpresaId = @MultiEmpresaId AND ParametroId = 'AdsertiCredit.PLDReportesOperacionesOrganoSupervisor'
		SELECT @ClaveSujetoObligado = Parametro FROM Global.Parametros WHERE MultiEmpresaId = @MultiEmpresaId AND ParametroId = 'AdsertiCredit.PLDReportesOperacionesClaveSujetoObligado'
		SELECT @Localidad = Parametro FROM Global.Parametros WHERE MultiEmpresaId = @MultiEmpresaId AND ParametroId = 'AdsertiCredit.PLDReportesOperacionesLocalidad'
		SELECT @CodigoPostalSucursal = Parametro FROM Global.Parametros WHERE MultiEmpresaId = @MultiEmpresaId AND ParametroId = 'AdsertiCredit.PLDReportesOperacionesCodigoPostalSucursal'


		IF(@OrganoSupervisor IS NULL OR @ClaveSujetoObligado IS NULL OR @Localidad IS NULL OR @CodigoPostalSucursal IS NULL)
			BEGIN
				RAISERROR ('Los Parametros del Reporte no pueden ser leidos o no existen.',16,1) -- Mensaje de texto,Severidad,Estado
			END
		--FIN: SECCIÓN VARIABLE POR MULTIEMPRESA

		--Mapeo claves TiposReporteCNBV - ClasificacionAlertaLavadoDinero
		IF @TipoReporteId = 1
			SET @ClasificacionAlertaLavadoDineroId = 2
		ELSE IF @TipoReporteId = 2
			SET @ClasificacionAlertaLavadoDineroId = 1
		ELSE IF @TipoReporteId = 3
			SET @ClasificacionAlertaLavadoDineroId = 3

		--CALCULAR EL PERIODO
		IF @TipoReporteId = 1 --RELEVANTES (Trimestral)
			BEGIN 
				SET @Periodo = @Mes/3
			END
		ELSE IF (@TipoReporteId = 2 OR @TipoReporteId = 3) --[2] INUSUALES (Mensual) O  [3] INTERNAS PREOCUPANTES (Mensual)
			BEGIN 
				SET @Periodo = MONTH(@Fecha)
			END

		--TODO: Tomando como base el periodo, el año, multiempresa y el tipo de reporte; validar si el archivo fue anteriormente generado
		DECLARE @EsInusual BIT

		SET @EsInusual = 0

		IF(@TipoReporteId = 2) SET @EsInusual = 1

		IF(@EsInusual = 1)-->ES INUSUAL 
			BEGIN 
				SELECT
					@ReporteCNBVId = ReporteCNBVId
				FROM 
					Credit.ReportesCNBV
				WHERE
					TipoReporteCNBVId = @TipoReporteId
					AND MultiEmpresaId = @MultiempresaId
					AND CAST(Fecha AS DATE) = CAST(@Fecha AS DATE)
					AND Reportable24Horas = @Reportable24Horas --REPORTABLE EN 24 HORAS
					AND Estatus = 1 --Reporte ACTIVO
			END
		ELSE
			BEGIN
				SELECT
					@ReporteCNBVId = ReporteCNBVId
				FROM 
					Credit.ReportesCNBV
				WHERE
					TipoReporteCNBVId = @TipoReporteId
					AND MultiEmpresaId = @MultiempresaId
					AND Anio = YEAR(@Fecha)
					AND Periodo = @Periodo
					AND Estatus = 1 --Reporte ACTIVO
			END

		--------------------------------------------------
		--SI EL REPORTE AUN NO HA SIDO GENERADO, SE CREA--
		--------------------------------------------------
		IF @ReporteCNBVId IS NULL
			BEGIN 

				IF(@EsInusual = 1)-->ES INUSUAL 
					BEGIN
												--INSERTAR INFORMACIÓN GENERAL DEL REPORTE
						INSERT INTO Credit.ReportesCNBV(
							MultiEmpresaId,
							TipoReporteCNBVId,
							Anio,
							Periodo,
							NombreArchivo,
							Reportable24Horas,
							Fecha,
							UsuarioAltaId
						)VALUES(
							@MultiempresaId,
							@TipoReporteId,
							YEAR(@Fecha),
							@Periodo,
							@NombreArchivo,
							@Reportable24Horas, --Reportable 24 Hrs
							@Fecha,
							@UsuarioAltaId
						)
					END
				ELSE
					BEGIN

						--INSERTAR INFORMACIÓN GENERAL DEL REPORTE
						INSERT INTO Credit.ReportesCNBV(
							MultiEmpresaId,
							TipoReporteCNBVId,
							Anio,
							Periodo,
							NombreArchivo,
							Reportable24Horas,
							UsuarioAltaId
						)VALUES(
							@MultiempresaId,
							@TipoReporteId,
							YEAR(@Fecha),
							@Periodo,
							@NombreArchivo,
							0,
							@UsuarioAltaId
						)
					END

				--RECUPERA EL IDENTITY CREADO
				SET @ReporteCNBVId = SCOPE_IDENTITY()

				----------------------------------------
				----------------------------------------
				----------------------------------------

				DECLARE @AlertasReportables TABLE(
					AlertaLavadoDineroId INT,
					TipoAlertaLavadoDineroId INT,
					TipoProductoId INT,
					SolicitudLineaCreditoId INT,
					SolicitudId INT,
					FechaAlta DATETIME,
					MontoOperacion DECIMAL(10,2),
					DescripcionOperacion NVARCHAR(4000),
					RazonesAlerta NVARCHAR(400)
				)


				---->INSERTAR ALERTAS REPORTABLES EN TABLA TEMPORAL<--
				--IF OBJECT_ID('tempdb..#AlertasReportables') IS NOT NULL
				--	DROP TABLE #AlertasReportables

				IF(@EsInusual = 1)-->ES INUSUAL REPORTABLE EN 24 HORAS
					BEGIN
						-->INSERTAR ALERTAS REPORTABLES EN TABLA TEMPORAL<--
						--IF OBJECT_ID('tempdb..#AlertasReportables') IS NOT NULL
						--	DROP TABLE #AlertasReportables

						INSERT INTO @AlertasReportables(
								AlertaLavadoDineroId,
								TipoAlertaLavadoDineroId,
								TipoProductoId,
								SolicitudLineaCreditoId,
								SolicitudId,
								FechaAlta,
								MontoOperacion,
								DescripcionOperacion,
								RazonesAlerta
							)
							SELECT 
								Alertas.AlertaLavadoDineroId,
								TiposPLD.TipoAlertaLavadoDineroId,
								Alertas.TipoProductoId,
								Alertas.SolicitudLineaCreditoId,
								Alertas.SolicitudId,
								Alertas.FechaAlta,
								Alertas.MontoOperacion,
								Alertas.DescripcionOperacion DescripcionOperacion,
								Alertas.ObservacionesRevisionFinal RazonesAlerta
							--INTO
							--	#AlertasReportables
							FROM
								Credit.ClasificacionAlertaLavadoDinero ClasificacionPLD INNER JOIN Credit.TiposAlertaLavadoDinero TiposPLD
									ON ClasificacionPLD.ClasificacionAlertaLavadoDineroId = TiposPLD .ClasificacionAlertaLavadoDineroId
								INNER JOIN Credit.AlertasLavadoDinero Alertas
									ON Alertas.TipoAlertaLavadoDineroId = TiposPLD.TipoAlertaLavadoDineroId
							WHERE
								Alertas.MultiEmpresaId = @MultiempresaId
								AND ClasificacionPLD.ClasificacionAlertaLavadoDineroId = @ClasificacionAlertaLavadoDineroId
								AND CAST(Alertas.FechaAlta AS DATE)<= @Fecha
								AND Alertas.AlertaReportable = 1 --Tiene que reportarse
								AND Alertas.AlertaReportada = 0 --Aun no ha sido reportada
								AND TiposPLD.Reportable24Horas = @Reportable24Horas --Reportable en 24hrs
					END
				ELSE
					BEGIN
						-->INSERTAR ALERTAS REPORTABLES EN TABLA TEMPORAL<--
						--IF OBJECT_ID('tempdb..#AlertasReportables') IS NOT NULL
						--	DROP TABLE #AlertasReportables

						INSERT INTO @AlertasReportables(
								AlertaLavadoDineroId,
								TipoAlertaLavadoDineroId,
								TipoProductoId,
								SolicitudLineaCreditoId,
								SolicitudId,
								FechaAlta,
								MontoOperacion,
								DescripcionOperacion,
								RazonesAlerta
							)
							SELECT 
								Alertas.AlertaLavadoDineroId,
								TiposPLD.TipoAlertaLavadoDineroId,
								Alertas.TipoProductoId,
								Alertas.SolicitudLineaCreditoId,
								Alertas.SolicitudId,
								Alertas.FechaAlta,
								Alertas.MontoOperacion,
								Alertas.DescripcionOperacion DescripcionOperacion,
								Alertas.ObservacionesRevisionFinal RazonesAlerta
							--INTO
							--	#AlertasReportables
							FROM
								Credit.ClasificacionAlertaLavadoDinero ClasificacionPLD INNER JOIN Credit.TiposAlertaLavadoDinero TiposPLD
									ON ClasificacionPLD.ClasificacionAlertaLavadoDineroId = TiposPLD .ClasificacionAlertaLavadoDineroId
								INNER JOIN Credit.AlertasLavadoDinero Alertas
									ON Alertas.TipoAlertaLavadoDineroId = TiposPLD.TipoAlertaLavadoDineroId
							WHERE
								Alertas.MultiEmpresaId = @MultiempresaId
								AND ClasificacionPLD.ClasificacionAlertaLavadoDineroId = @ClasificacionAlertaLavadoDineroId
								AND CAST(Alertas.FechaAlta AS DATE)<= @Fecha
								AND Alertas.AlertaReportable = 1 --Tiene que reportarse
								AND Alertas.AlertaReportada = 0 --Aun no ha sido reportada
								AND TiposPLD.Reportable24Horas = 0 --No Reportable en 24hrs
					END



				DECLARE @ReportesCNBVDetalle TABLE(
					[AlertaLavadoDineroId] [bigint] NULL,
					[TipoAlertaLavadoDineroId] [int] NULL,
					[NumeroCuenta] [nvarchar](16) NULL,
					[Monto] [decimal](17, 2) NULL,
					[Moneda] [nvarchar](3) NULL,
					[FechaOperacion] [nvarchar](8) NULL,
					[FechaDeteccion] [nvarchar](8) NULL,
					[Nacionalidad] [char](1) NULL,
					[TipoPersona] [char](1) NULL,
					[RazonSocial] [nvarchar](125) NULL,
					[Nombre] [nvarchar](60) NULL,
					[ApellidoPaterno] [nvarchar](60) NULL,
					[ApelidoMaterno] [nvarchar](30) NULL,
					[Rfc] [nvarchar](13) NULL,
					[Curp] [nvarchar](18) NULL,
					[FechaNacimiento] [nvarchar](8) NULL,
					[Domicilio] [nvarchar](60) NULL,
					[Colonia] [nvarchar](30) NULL,
					[LocalidadId] [nvarchar](8) NULL,
					[Telefono] [nvarchar](40) NULL,
					[ActividadEconomica] [nvarchar](7) NULL,
					--INICIO:COLUMNAS ACIONALES ADAMANTINE [29-33]
					--[ApoderadoSegurosNombreRazonSocial] [nvarchar](60) NULL,
					--[ApoderadoSegurosApellidoPaterno] [nvarchar](60) NULL,
					--[ApoderadoSegurosApellidoMaterno] [nvarchar](60) NULL,
					--[ApoderadoSegurosRfc] [nvarchar](13) NULL,
					--[ApoderadoSegurosCurp] [nvarchar](18) NULL,
					--FIN:COLUMNAS ACIONALES ADAMANTINE [29-33]
					[ConsecutivoCuentasRelacionadas] [nvarchar](2) NULL,
					[NumeroCuentaRelacionadas] [nvarchar](16) NULL,
					[ClaveSujetoObligadoCuentasRelacionadas] [nvarchar](7) NULL,
					[NombreCuentasRelacionadas] [nvarchar](60) NULL,
					[ApellidoPaternoCuentasRelacionadas] [nvarchar](60) NULL,
					[ApellidoMaternoCuentasRelacionadas] [nvarchar](30) NULL,
					[DescipcionOperacion] [nvarchar](4000) NULL,
					[RazonesAlerta] [nvarchar](4000) NULL
				) --DECLARE @ReportesCNBVDetalle TABLE(



				DECLARE 
					@TipoCreditoNomina INT,
					@TipoCreditoIndividual INT,
					@TipoCreditoAlConsumo INT,
					@TipoCreditoLineaCredito INT
					
				-->VALIDAR LA INFORMACIÓN POR TIPO DE PRODUCTO
				SET @TipoCreditoNomina = 1 --1	CRÉDITO DE NÓMINA
				SET @TipoCreditoIndividual = 2 --2	CRÉDITO INDIVIDUAL
				SET @TipoCreditoAlConsumo = 3 --3	CRÉDITO AL CONSUMO
				SET @TipoCreditoLineaCredito = 4 --4	LÍNEA DE CRÉDITO

				DECLARE @HayCreditosNomina BIT
				DECLARE @HayCreditosIndividuales BIT
				DECLARE @HayCreditosAlConsumo BIT
				DECLARE @HayCreditosLineasCredito BIT
				
				
				SET @HayCreditosNomina = CASE WHEN EXISTS(SELECT 1 FROM @AlertasReportables WHERE TipoProductoId = @TipoCreditoNomina) THEN 1 ELSE 0 END
				SET @HayCreditosIndividuales = CASE WHEN EXISTS(SELECT 1 FROM @AlertasReportables WHERE TipoProductoId = @TipoCreditoIndividual) THEN 1 ELSE 0 END
				SET @HayCreditosAlConsumo = CASE WHEN EXISTS(SELECT 1 FROM @AlertasReportables WHERE TipoProductoId = @TipoCreditoAlConsumo) THEN 1 ELSE 0 END
				SET @HayCreditosLineasCredito = CASE WHEN EXISTS(SELECT 1 FROM @AlertasReportables WHERE TipoProductoId = @TipoCreditoLineaCredito) THEN 1 ELSE 0 END

				DECLARE @TotalAlertasReportables INT
				
				SELECT @TotalAlertasReportables = COUNT(1) FROM @AlertasReportables
				
				IF( @TotalAlertasReportables > 0)
------------------->
					BEGIN
						IF (@TipoReporteId = 1 OR @TipoReporteId = 2)--[1] RELEVANTES (Trimestral), [2] INUSUALES (Mensual)
--------------------------->
							BEGIN
								IF @HayCreditosNomina = 1 OR @HayCreditosIndividuales = 1 OR @HayCreditosAlConsumo = 1
----------------------------------->
									BEGIN
										--INSERTAR VALORES EN LA TABLA DE DETALLE
										INSERT INTO @ReportesCNBVDetalle
											SELECT
												AR.AlertaLavadoDineroId AlertaLavadoDineroId,
												AR.TipoAlertaLavadoDineroId TipoAlertaLavadoDineroId,
												ISNULL(Solicitudes.NumeroSolicitud,'') AS NumeroCuenta,
												CASE 
													WHEN AR.TipoAlertaLavadoDineroId IN(4,5) THEN --PAGO POR UN MONTO SUPERIOR AL MONTO ESPERADO EN UN 50% / PAGO POR UN MONTO IGUAL O SUPERIOR AL EQUIVALENTE A USD$10,000 EN MONEDA NACIONAL
														ISNULL(AR.MontoOperacion,0)
													ELSE
														ISNULL(Solicitudes.MontoCredito,0) 
												END AS Monto,
												CASE WHEN Solicitudes.MontoCredito IS NULL THEN '' ELSE 'MXN' END AS Moneda, --Si existe monto moneda es igual a pesos
												CONVERT(VARCHAR(8), AR.FechaAlta, 112) FechaOperacion,
												CASE 
													@TipoReporteId WHEN 1 THEN '' 
													ELSE
														CONVERT(VARCHAR(8), AR.FechaAlta, 112)
												END FechaDeteccionOperacion,--Fecha deteccion operación
												CASE WHEN Nacionalidades.NacionalidadId IS NOT NULL
													THEN 
														CASE Nacionalidades.NacionalidadId
															WHEN 150 THEN '1' --MÉXICO
															ELSE '2'
														END 
												ELSE
													''
												END Nacionalidad, --Nacionalidad
 												CASE WHEN Clientes.ClienteId IS NULL
													THEN ''
													ELSE '1' 
												END TipoPersona, --Persona Física
												'' RazonSocial, --Nula para personas Físicas
												PersonasFisicas.Nombre,
												PersonasFisicas.ApellidoPaterno, 
												PersonasFisicas.ApellidoMaterno, 
												CASE WHEN LEN(PersonasFisicas.Rfc) = 13 THEN PersonasFisicas.Rfc ELSE '' END Rfc,
												ISNULL(PersonasFisicas.Curp,'') AS Curp,
												ISNULL(CONVERT(VARCHAR(8), PersonasFisicas.FechaNacimiento, 112),'') FechaNacimiento,
												ISNULL(REPLACE(LTRIM(RTRIM(Direcciones.Calle)) + 
												(CASE WHEN Direcciones.NumeroInterior IS NULL THEN '' ELSE ' INTERIOR ' + Direcciones.NumeroInterior END) + 
												' EXTERIOR ' + Direcciones.NumeroExterior + ' CP ' + Direcciones.CodigoPostal,';',' '),'') AS Domicilio, --Domicilio
												ISNULL(REPLACE(Colonias.Colonia,';',' '),'') Colonia, --Colonia
												ISNULL(Localidades.LocalidadId,'') Poblacion, --Población
												LTRIM(RTRIM(TelefonosConcat.Telefonos)) AS Telefonos, --Telefonos
												ISNULL(Clientes.ActividadEconomicaId,'0000000')AS ActividadEconomicaId, --Actividad Economica
												'' ConsecutivoCuentasRelacionadas,
												'' NumeroCuentaRelacionadas,
												'' ClaveSujetoObligadoCuentasRelacionadas,
												'' NombreCuentasRelacionadas,
												'' ApellidoPaternoCuentasRelacionadas,
												'' ApellidoMaternoCuentasRelacionadas,
												AR.DescripcionOperacion DescipcionOperacion,
												AR.RazonesAlerta RazonesAlerta
											FROM 
												@AlertasReportables AR INNER JOIN Credit.Solicitudes
													ON	AR.SolicitudId = Solicitudes.SolicitudId
												LEFT JOIN Credit.Domicilios	
													ON AR.SolicitudId = Domicilios.SolicitudId
												LEFT JOIN Credit.Direcciones
													ON Domicilios.DireccionId = Direcciones.DireccionId
												LEFT JOIN Global.Monedas
													ON Solicitudes.MonedaId = Monedas.MonedaId
												LEFT JOIN Credit.Clientes
													ON Solicitudes.ClienteId = Clientes.ClienteId
												LEFT JOIN Credit.PersonasFisicas
													ON Clientes.PersonaId = PersonasFisicas.PersonaId
												LEFT JOIN	Global.Nacionalidades 
													ON PersonasFisicas.NacionalidadId =  Nacionalidades.NacionalidadId
												LEFT JOIN Global.Colonias
													ON Direcciones.ColoniaId = Colonias.ColoniaId
												LEFT JOIN Global.Localidades
													ON Localidades.LocalidadId = Direcciones.LocalidadId
												--Telefonos Concatenados por Cliente
												LEFT JOIN (
													SELECT 
														ClienteId,
														(
															SELECT 
																Telefono + ' ' + CASE WHEN TiposTelefono.TelefonoFijo = 1 THEN 'PARTICULAR' ELSE 'CELULAR' END
															FROM 
																Credit.Clientes INNER JOIN Credit.PersonasFisicas 
																	ON Clientes.PersonaId = PersonasFisicas.PersonaId
																INNER JOIN (SELECT PersonaId,MIN(TelefonoId) AS TelefonoId FROM Credit.PersonasTelefonos GROUP BY PersonaId) AS PrimerTelefonoPersona
																	ON PersonasFisicas.PersonaId = PrimerTelefonoPersona.PersonaId
																INNER JOIN Credit.Telefonos 
																	ON PrimerTelefonoPersona.TelefonoId = Telefonos.TelefonoId 
																INNER JOIN Global.TiposTelefono
																	ON Telefonos.TipoTelefonoId = TiposTelefono.TipoTelefonoId
															WHERE 
																ClienteId = TelefonosUnaLinea.ClienteId) AS Telefonos
													FROM (
														SELECT DISTINCT 
															ClienteId 
														FROM 
															Credit.Clientes)
													TelefonosUnaLinea
												) AS TelefonosConcat
													ON Clientes.ClienteId = TelefonosConcat.ClienteId
									END
----------------------------------->


								IF @HayCreditosLineasCredito = 1 
----------------------------------->
									BEGIN
											INSERT INTO @ReportesCNBVDetalle
												SELECT
													AR.AlertaLavadoDineroId AlertaLavadoDineroId,
													AR.TipoAlertaLavadoDineroId TipoAlertaLavadoDineroId,
													SolicitudesLineaCredito.NumeroSolicitud NumeroCuenta,
													--//TODO: Pendiente definir de donde sacar el monto del credito
													CASE 
														WHEN AR.TipoAlertaLavadoDineroId IN(4,5) THEN	--PAGO POR UN MONTO SUPERIOR AL MONTO ESPERADO EN UN 50% / PAGO POR UN MONTO IGUAL O SUPERIOR AL EQUIVALENTE A USD$10,000 EN MONEDA NACIONAL
															ISNULL(AR.MontoOperacion,0)
														--WHEN AR.TipoAlertaLavadoDineroId IN(1,2,3) THEN -->Segun tabla TipoAlertaLavadoDinero
														ELSE
															ISNULL(SolicitudesLineaCreditoTerminosCondiciones.MontoCredito,0) 
														
													END AS Monto,
													CASE Monedas.MonedaId
														WHEN 1 THEN 'MXN'
														WHEN 2 THEN 'USD'
														ELSE '' END AS Moneda,
													CONVERT(VARCHAR(8), AR.FechaAlta, 112) FechaOperacion,
													CONVERT(VARCHAR(8), AR.FechaAlta, 112) FechaDeteccionOperacion,
													'' Nacionalidad, --Nacionalidad
													'2' TipoPersona, --Persona Moral
													PersonasMorales.RazonSocial RazonSocial, --Nula para personas Físicas
													'' Nombre,
													'' ApellidoPaterno, 
													'' ApellidoMaterno, 
													CASE WHEN LEN(PersonasMorales.Rfc) = 12 THEN PersonasMorales.Rfc ELSE '' END Rfc,
													'' AS Curp,
													ISNULL(CONVERT(VARCHAR(8), ClientesPersonaMoral.FechaEscrituraPublica, 112),'') FechaNacimiento,--TODO: Validar si se tiene campo fecha de constitución para personas morales
													ISNULL(REPLACE(LTRIM(RTRIM(Direcciones.Calle)) + 
													(CASE WHEN Direcciones.NumeroInterior IS NULL THEN '' ELSE ' INTERIOR ' + Direcciones.NumeroInterior END) + 
													' EXTERIOR ' + Direcciones.NumeroExterior + ' CP ' + Direcciones.CodigoPostal,';',' '),'') AS Domicilio, --Domicilio
													ISNULL(REPLACE(Colonias.Colonia,';',' '),'') Colonia, --Colonia
													ISNULL(Localidades.LocalidadId,'') Poblacion, --Población
													--REPLACE(LTRIM(RTRIM(TelefonosConcat.Telefonos)),' ','/') AS Telefonos, --Telefonos
													REPLACE(LTRIM(RTRIM(ISNULL(STUFF((
															SELECT 
																' '+ Telefono 
															FROM 
																(SELECT SolicitudLineaCreditoId,MIN(PersonaId) PersonaId FROM Credit.SolicitudesLineaCreditoContactos GROUP BY SolicitudLineaCreditoId) PrimerContacto
																INNER JOIN Credit.PersonasTelefonos 
																	ON PrimerContacto.PersonaId = PersonasTelefonos.PersonaId
																INNER JOIN Credit.Telefonos 
																	ON PersonasTelefonos.TelefonoId =Telefonos.TelefonoId 
															WHERE 
																SolicitudLineaCreditoId = SolicitudesLineaCredito.SolicitudLineaCreditoId FOR XML PATH('')
														),1,1,''
													),''))),' ','/') AS Telefonos,
													ISNULL(Clientes.ActividadEconomicaId,'0000000')AS ActividadEconomicaId, --Actividad Economica
													--INICIO:COLUMNAS ACIONALES ADAMANTINE [29-33]
													--'' ApoderadoSegurosNombreRazonSocial,
													--'' ApoderadoSegurosApellidoPaterno,
													--'' ApoderadoSegurosApellidoMaterno,
													--'' ApoderadoSegurosRfc,
													--'' ApoderadoSegurosCurp,
													--FIN:COLUMNAS ACIONALES ADAMANTINE [29-33]
													'' ConsecutivoCuentasRelacionadas,
													'' NumeroCuentaRelacionadas,
													'' ClaveSujetoObligadoCuentasRelacionadas,
													'' NombreCuentasRelacionadas,
													'' ApellidoPaternoCuentasRelacionadas,
													'' ApellidoMaternoCuentasRelacionadas,
													AR.DescripcionOperacion DescripcionOperacion,
													AR.RazonesAlerta RazonesAlerta
												FROM
													@AlertasReportables AR INNER JOIN Credit.SolicitudesLineaCredito
														ON	AR.SolicitudLineaCreditoId = SolicitudesLineaCredito.SolicitudLineaCreditoId

													--TERMINOS Y CONDICIONES
													INNER JOIN Credit.SolicitudesLineaCreditoTerminosCondiciones
														ON SolicitudesLineaCredito.SolicitudLineaCreditoId = SolicitudesLineaCreditoTerminosCondiciones.SolicitudLineaCreditoId

													--MONEDAS
													INNER JOIN Credit.ProductosMonedas
														ON SolicitudesLineaCredito.ProductoId = ProductosMonedas.ProductoId
													INNER JOIN Global.Monedas
														ON ProductosMonedas.MonedaId = Monedas.MonedaId

													INNER JOIN Credit.Clientes
														ON Clientes.ClienteId = SolicitudesLineaCredito.ClienteId
													INNER JOIN Credit.ClientesPersonaMoral
														ON Clientes.ClienteId = ClientesPersonaMoral.ClienteId
													INNER JOIN Credit.Personas
														ON Clientes.PersonaId = Personas.PersonaId
													INNER JOIN Credit.PersonasMorales
														ON Personas.PersonaId = PersonasMorales.PersonaId
													LEFT JOIN Credit.Direcciones
														ON SolicitudesLineaCredito.DireccionId = Direcciones.DireccionId
													LEFT JOIN Global.Colonias
														ON Direcciones.ColoniaId = Colonias.ColoniaId
													LEFT JOIN Global.Localidades
														ON Localidades.LocalidadId = Direcciones.LocalidadId
									END
----------------------------------->
							END
--------------------------->
						IF @TipoReporteId = 3 --[3] INTERNAS PREOCUPANTES (Mensual)
							BEGIN 
								INSERT INTO @ReportesCNBVDetalle
									SELECT 
										AR.AlertaLavadoDineroId,
										AR.TipoAlertaLavadoDineroId TipoAlertaLavadoDineroId,
										'' AS NumeroCuenta,
										0 AS Monto,
										'' AS Moneda,
										CONVERT(VARCHAR(8), AR.FechaAlta, 112) FechaOperacion,
										CONVERT(VARCHAR(8), AR.FechaAlta, 112) FechaDeteccionOperacion,
										'' AS Nacionalidad,
										'' AS TipoPersona,
										'' AS RazonSocial,
										'' AS Nombre,
										'' AS ApellidoPaterno,
										'' AS ApelidoMaterno,
										'' AS Rfc,
										'' AS Curp,
										'' AS FechaNacimiento,
										'' AS Domicilio,
										'' AS Colonia,
										'' AS LocalidadId,
										'' AS Telefono,
										'' AS ActividadEconomica,
										--INICIO:COLUMNAS ACIONALES ADAMANTINE [29-33]
										--'' ApoderadoSegurosNombreRazonSocial,
										--'' ApoderadoSegurosApellidoPaterno,
										--'' ApoderadoSegurosApellidoMaterno,
										--'' ApoderadoSegurosRfc,
										--'' ApoderadoSegurosCurp,
										--FIN:COLUMNAS ACIONALES ADAMANTINE [29-33]
										'' AS ConsecutivoCuentasRelacionadas,
										'' AS NumeroCuentaRelacionadas,
										'' AS ClaveSujetoObligadoCuentasRelacionadas,
										'' AS NombreCuentasRelacionadas,
										'' AS ApellidoPaternoCuentasRelacionadas,
										'' AS ApellidoMaternoCuentasRelacionadas,
										AR.DescripcionOperacion,
										AR.RazonesAlerta
									FROM
										@AlertasReportables AR
							END
					END

					----------------------------------------
					----------------------------------------
					----------------------------------------
					--INSERTAR VALORES EN LA TABLA DE DETALLE
					INSERT INTO Credit.ReportesCNBVDetalle(
						ReporteCNBVId,
						AlertaLavadoDineroId,
						TipoReporte,
						PeriodoReporte,
						Folio,
						OrganoSupervisor,
						ClaveSujetoObligado,
						LocalidadSujetoObligadoId,
						CodigoPostalSucursal,
						TipoOperacion,
						InstrumentoMonetario,
						NumeroCuenta,
						Monto,
						Moneda,
						FechaOperacion,
						FechaDeteccion,
						Nacionalidad,
						TipoPersona,
						RazonSocial,
						Nombre,
						ApellidoPaterno,
						ApelidoMaterno,
						Rfc,
						Curp,
						FechaNacimiento,
						Domicilio,
						Colonia,
						LocalidadId,
						Telefono,
						ActividadEconomica,
						--INICIO:COLUMNAS ACIONALES ADAMANTINE [29-33]
						--ApoderadoSegurosNombreRazonSocial,
						--ApoderadoSegurosApellidoPaterno,
						--ApoderadoSegurosApellidoMaterno,
						--ApoderadoSegurosRfc,
						--ApoderadoSegurosCurp,
						--FIN:COLUMNAS ACIONALES ADAMANTINE [29-33]
						ConsecutivoCuentasRelacionadas,
						NumeroCuentaRelacionadas,
						ClaveSujetoObligadoCuentasRelacionadas,
						NombreCuentasRelacionadas,
						ApellidoPaternoCuentasRelacionadas,
						ApellidoMaternoCuentasRelacionadas,
						DescipcionOperacion,
						RazonesAlerta,
						FechaAlta,
						UsuarioAltaId
					)
					SELECT
						@ReporteCNBVId AS ReporteCNBVId,
						ReporteTemporal.AlertaLavadoDineroId,
						@TipoReporteId AS TipoReporte,
						CASE @TipoReporteId 
							WHEN 1 THEN REPLACE(CONVERT(VARCHAR(7), @Fecha, 120),'-','')	--Relevante
							WHEN 2 THEN CONVERT(VARCHAR(8), @Fecha, 112)	--Inusual
							WHEN 3 THEN CONVERT(VARCHAR(8), @Fecha, 112)	--Interna Preocupante
						END AS Periodo, 
						RIGHT(REPLICATE('0',6) + CAST(ROW_NUMBER() OVER(ORDER BY ReporteTemporal.AlertaLavadoDineroId) AS VARCHAR(6)),6) AS Folio,
						@OrganoSupervisor AS OrganoSupervisor,--Comisión Nacional Bancaria y de Valores (CNVB)
						@ClaveSujetoObligado ClaveSujetoObligado, -->Economizate segun CNBV
						@Localidad Localidad, -->, (01001002) Distrito Federal
						@CodigoPostalSucursal CodigoPostalSucursal,-->CP Economizate 06140 
						--'00' TipoOperacion,
						CASE ReporteTemporal.TipoAlertaLavadoDineroId -->Segun tabla TipoAlertaLavadoDinero
							WHEN 1 THEN '08'
							WHEN 2 THEN '08'
							WHEN 3 THEN '08'
							WHEN 4 THEN '09'
							WHEN 5 THEN '09'
							ELSE '' 
						END TipoOperacion, -->[PENDIENTE]
						'03' InstrumentoMonetario,-->Segun catalogo corresponde: 03	TRANSFERENCIAS	
						ReporteTemporal.NumeroCuenta,
						--//TODO: Pendiente definir de donde sacar el monto del credito
						ReporteTemporal.Monto,
						ReporteTemporal.Moneda, --Si existe monto moneda es igual a pesos
						ReporteTemporal.FechaOperacion,
						CASE 
							@TipoReporteId WHEN 1 THEN '' 
							ELSE
								ReporteTemporal.FechaDeteccion
						END FechaDeteccionOperacion,--Fecha deteccion operación
						ReporteTemporal.Nacionalidad, --Nacionalidad
 						ReporteTemporal.TipoPersona, --Persona Física
						ReporteTemporal.RazonSocial, --Nula para personas Físicas
						ReporteTemporal.Nombre,
						ReporteTemporal.ApellidoPaterno, 
						ReporteTemporal.ApelidoMaterno, 
						ReporteTemporal.Rfc,
						ReporteTemporal.Curp,
						ReporteTemporal.FechaNacimiento,
						ReporteTemporal.Domicilio, --Domicilio
						ReporteTemporal.Colonia, --Colonia
						ReporteTemporal.LocalidadId AS Poblacion, --Población
						ReporteTemporal.Telefono AS Telefonos, --Telefonos
						ReporteTemporal.ActividadEconomica, --Actividad Economica
						--INICIO:COLUMNAS ACIONALES ADAMANTINE [29-33]
						--ReporteTemporal.ApoderadoSegurosNombreRazonSocial,
						--ReporteTemporal.ApoderadoSegurosApellidoPaterno,
						--ReporteTemporal.ApoderadoSegurosApellidoMaterno,
						--ReporteTemporal.ApoderadoSegurosRfc,
						--ReporteTemporal.ApoderadoSegurosCurp,
						--FIN:COLUMNAS ACIONALES ADAMANTINE [29-33]
						ReporteTemporal.ConsecutivoCuentasRelacionadas,
						ReporteTemporal.NumeroCuentaRelacionadas,
						ReporteTemporal.ClaveSujetoObligadoCuentasRelacionadas,
						ReporteTemporal.NombreCuentasRelacionadas,
						ReporteTemporal.ApellidoPaternoCuentasRelacionadas,
						ReporteTemporal.ApellidoMaternoCuentasRelacionadas,
						ReporteTemporal.DescipcionOperacion,
						ReporteTemporal.RazonesAlerta,
						@FechaGeneracion,
						@UsuarioAltaId
					FROM 
						@ReportesCNBVDetalle ReporteTemporal	


					--Actualizar en la tabla de Alertas las que se estan reportando
					UPDATE 
						AlertasPLD		
					SET
						AlertaReportada = 1,
						FechaReporte = @FechaGeneracion,
						UsuarioReporteId = @UsuarioAltaId
					FROM 
						Credit.AlertasLavadoDinero AlertasPLD INNER JOIN Credit.ReportesCNBVDetalle DetalleReporte
						ON AlertasPLD.AlertaLavadoDineroId = DetalleReporte.AlertaLavadoDineroId

------------------->
			END --IF @ReporteCNBVId IS NULL
	
		--SI EXISTE EL IDENTIFICADOR @ReporteCNBVId
		PRINT @ReporteCNBVId 

		IF @ReporteCNBVId IS NOT NULL
			BEGIN
				DECLARE @TotalRegistrosReportados INTEGER
				SELECT 
					@TotalRegistrosReportados = COUNT(1) 
				FROM 	
					Credit.ReportesCNBVDetalle
				WHERE 
					ReporteCNBVId = @ReporteCNBVId

				IF @TotalRegistrosReportados > 0
					BEGIN
						SELECT 
							TipoReporte + @Separador +
							PeriodoReporte + @Separador +
							Folio + @Separador +
							OrganoSupervisor + @Separador +
							ClaveSujetoObligado + @Separador +
							LocalidadSujetoObligadoId + @Separador +
							CodigoPostalSucursal + @Separador +
							TipoOperacion + @Separador +
							InstrumentoMonetario + @Separador +
							NumeroCuenta + @Separador +
							CAST(Monto AS VARCHAR) + @Separador +
							Moneda + @Separador +
							FechaOperacion + @Separador +
							FechaDeteccion + @Separador +
							Nacionalidad + @Separador +
							TipoPersona + @Separador +
							RazonSocial + @Separador +
							ISNULL(Nombre,'') + @Separador +
							ISNULL(ApellidoPaterno,'') + @Separador +
							ISNULL(ApelidoMaterno,'') + @Separador +
							Rfc + @Separador +
							Curp + @Separador +
							FechaNacimiento + @Separador +
							REPLACE(Domicilio, @Separador,'') + @Separador +
							Colonia + @Separador +
							LocalidadId + @Separador +
							ISNULL(Telefono,'') + @Separador +
							ActividadEconomica + @Separador +
							ConsecutivoCuentasRelacionadas + @Separador +
							NumeroCuentaRelacionadas + @Separador +
							ClaveSujetoObligadoCuentasRelacionadas + @Separador +
							NombreCuentasRelacionadas + @Separador +
							ApellidoPaternoCuentasRelacionadas + @Separador +
							ApellidoMaternoCuentasRelacionadas + @Separador +
							REPLACE(DescipcionOperacion, @Separador,'')  + @Separador +
							REPLACE(RazonesAlerta, @Separador,'') + @Separador AS Renglon
						FROM 
							Credit.ReportesCNBVDetalle
						WHERE 
							ReporteCNBVId = @ReporteCNBVId
					END
				ELSE
					BEGIN
						--GENERA REPORTE VACIO
						SELECT
							CAST(@TipoReporteId AS VARCHAR) + @Separador +
							CASE @TipoReporteId 
								WHEN 1 THEN REPLACE(CONVERT(VARCHAR(7), @Fecha, 120),'-','')	--Relevante
								WHEN 2 THEN CONVERT(VARCHAR(8), @Fecha, 112)	--Inusual
								WHEN 3 THEN CONVERT(VARCHAR(8), @Fecha, 112)	--Interna Preocupante
							END + @Separador +
							+ @Separador + --FOLIO VACIO
							@OrganoSupervisor + @Separador + --Comisión Nacional Bancaria y de Valores (CNVB)
							@ClaveSujetoObligado + -->Clave sujeto obligado Economizate segun CNBV
							REPLICATE(@Separador,31) AS Renglon
					END
			END
	 COMMIT TRAN
END TRY       
BEGIN CATCH
   IF @@trancount > 0 ROLLBACK TRANSACTION                        
   EXEC Credit.ErrorHandlerStoredProcedure                                         
   RETURN 55555                                                   
END CATCH                                                         


