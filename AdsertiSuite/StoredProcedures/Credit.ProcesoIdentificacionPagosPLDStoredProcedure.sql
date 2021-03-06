USE [AdsertiSuite]
GO
/****** Object:  StoredProcedure [Credit].[ProcesoIdentificacionPagosPLDStoredProcedure]    Script Date: 08/05/2017 16:18:53 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


ALTER PROCEDURE [Credit].[ProcesoIdentificacionPagosPLDStoredProcedure]
AS
BEGIN TRY
   SET NOCOUNT ON
   SET XACT_ABORT ON

	BEGIN TRAN
		DECLARE @Fecha DATE
		DECLARE @TipoCambioDolar DECIMAL(20,4)
		DECLARE @MultiEmpresaId INT
		DECLARE @NumeroMultiEmpresas INT
		DECLARE @ConteoMultiEmpresas INT
		DECLARE @DescripcionOperacion NVARCHAR(250)
		DECLARE @ObservacionesRevisionFinal NVARCHAR(250)
		DECLARE @UsuarioAltaId INT
		DECLARE @LavadoDineroStoredProcedureBitacoraId INT


		SET @Fecha = DATEADD(DAY,-1,GETDATE()) --Ayer
		--SET @Fecha = CONVERT(DATE, '31/08/2015', 103)

		SET @UsuarioAltaId = 0
		SET @DescripcionOperacion = 'ESTA ALERTA NO REQUIERE REVISIÓN MANUAL, YA QUE DEBE REPORTARSE DE FORMA AUTOMÁTICA.'
		SET @ObservacionesRevisionFinal = @DescripcionOperacion

		DECLARE @FechaUltimaRevisionProceso AS DATE

		SET @FechaUltimaRevisionProceso = ISNULL((SELECT MAX(FechaUltimaRevisionProceso) FROM Credit.LavadoDineroStoredProcedureBitacora),DATEADD(DAY,-1,@Fecha))

		INSERT INTO Credit.LavadoDineroStoredProcedureBitacora (
			FechaUltimaRevisionProceso,
			UsuarioAltaId)
		VALUES (
			@Fecha,
			@UsuarioAltaId
		)

		--RECUPERA EL IDENTITY CREADO
		SET @LavadoDineroStoredProcedureBitacoraId  = SCOPE_IDENTITY()

		-------------------------
		--SECCION MULTIEMPRESAS--
		-------------------------

		--Declara la tabla temporal para recorrer todas las multiempresas
		DECLARE @MultiEmpresasTemporal TABLE (
			NumeroFila INT IDENTITY(1, 1),
			MultiEmpresaId INT
		)


		--TABLAS INTERNAS EMPRESA x EMPRESA--

		--Créditos con cortes pasados pero con pagos nuevos
		DECLARE @CreditosRevisarNuevamente TABLE(
			Id INT IDENTITY(1,1),
			CreditoId INT,
			Periodo INT
		)
		--Créditos con corte a la fecha
		DECLARE @CreditosCorteEnFecha TABLE(
			Id INT IDENTITY(1,1),
			CreditoId INT,
			Periodo INT
		)

		--Obtiene todas las multiempresas que tengan un cliente de AdsertiCredit y lo guarda en una tabla temporal
		INSERT INTO @MultiEmpresasTemporal(MultiEmpresaId) 
			--SELECT 1 --Adserti
			SELECT 
				MultiEmpresaId 
			FROM 
				Credit.Clientes 
			GROUP BY MultiEmpresaId

		--Inicializar variables LOOP MULTIEMPRESAS
		SELECT 
			@ConteoMultiEmpresas = MIN(NumeroFila),
			@NumeroMultiEmpresas = MAX(NumeroFila)
		FROM 
			@MultiEmpresasTemporal

		PRINT 'Numero multiempresas ' + CONVERT(NVARCHAR(2),@NumeroMultiEmpresas)

		--LOOP MULTIEMPRESAS--
		WHILE @ConteoMultiEmpresas <= @NumeroMultiEmpresas
			BEGIN
		
					SELECT 
						@MultiEmpresaId = MultiEmpresaId 
					FROM 
						@MultiEmpresasTemporal 
					WHERE 
						NumeroFila = @ConteoMultiEmpresas

					PRINT  'MultiEmpresaId: ' + CONVERT(NVARCHAR(2),@MultiEmpresaId)

					--Obtiene el tipo de cambio de la multiempresa en cuestion
					SELECT 
						@TipoCambioDolar = CONVERT(DECIMAL(10,5),ISNULL(Parametro,0)) 
					FROM 
						Global.Parametros 
					WHERE 
						ParametroId = 'AdsertiCredit.TipoCambioDolar' AND MultiEmpresaId = @MultiEmpresaId

					PRINT  'TipoCambioDolar: ' + CONVERT(NVARCHAR(10),@TipoCambioDolar)

					----------------------------------
					--INICIO: PROCESO x MULTIEMPRESA--
					----------------------------------


					--*************************************************************--
					--* 4)	PAGO POR UN MONTO SUPERIOR AL MONTO ESPERADO EN UN 50%*--
					--*************************************************************--

					-------------------------------------------------------
					----Créditos con cortes pasados pero con pagos nuevos--
					-------------------------------------------------------
					INSERT INTO @CreditosRevisarNuevamente(CreditoId, Periodo)
						SELECT  
							CreditosCalculos.CreditoId,
							CreditosCalculos.Periodo
						FROM 
							Credit.Clientes INNER JOIN Credit.Solicitudes
								ON Clientes.ClienteId = Solicitudes.ClienteId
							INNER JOIN Credit.Creditos
								ON Solicitudes.SolicitudId = Creditos.SolicitudId
							INNER JOIN Credit.CreditosCalculos 
								ON Creditos.CreditoId = CreditosCalculos.CreditoId
							INNER JOIN Credit.Pagos
								ON CreditosCalculos.PagoId = Pagos.PagoId
						WHERE 
							Clientes.MultiEmpresaId = @MultiEmpresaId
							AND CreditosCalculos.FechaEsperadaPago < @Fecha
							AND CAST(Pagos.FechaAlta AS DATE) > @FechaUltimaRevisionProceso-->(Fecha de la Ultima vez que se ejecuto el proceso)
							AND CAST(Pagos.FechaAlta AS DATE) <= @Fecha

					---------------------------------
					--Créditos con corte a la fecha--
					---------------------------------
					INSERT INTO @CreditosCorteEnFecha (CreditoId,Periodo) 
						SELECT
							Creditos.CreditoId,
							CreditosCalculos.Periodo
						FROM 
							Credit.Clientes INNER JOIN Credit.Solicitudes
								ON Clientes.ClienteId = Solicitudes.ClienteId
							INNER JOIN Credit.Creditos 
								ON Solicitudes.SolicitudId = Creditos.SolicitudId
							INNER JOIN Credit.CreditosCalculos
								ON Creditos.CreditoId = CreditosCalculos.CreditoId
						WHERE
							Clientes.MultiEmpresaId = @MultiEmpresaId
							AND CreditosCalculos.FechaEsperadaPago > @FechaUltimaRevisionProceso-->(Fecha de la Ultima vez que se ejecuto el proceso)
							AND CreditosCalculos.FechaEsperadaPago <= @Fecha


					----------------------
					--REVISION COMBINADA--
					----------------------

					DECLARE @RevisionCombinada TABLE(
						Id INT IDENTITY(1,1),
						CreditoId INT,
						Periodo INT
					)

					--ELIMINAR LOS QUE YA ESTEN INCLUIDOS A LA FECHA
					DELETE
						A
					FROM 
						@CreditosRevisarNuevamente A INNER JOIN @CreditosCorteEnFecha B
							ON 	
								A.CreditoId = B.CreditoId 
								AND A.Periodo = B.Periodo


					--INSERTAR ELEMENTOS PARA REVISAR NUEVAMENTE
					INSERT INTO @RevisionCombinada (CreditoId, Periodo)
						SELECT CreditoId,Periodo FROM @CreditosRevisarNuevamente

					--INSERTAR ELEMENTOS A LA FECHA PARA REVISION 
					INSERT INTO @RevisionCombinada (CreditoId, Periodo)
						SELECT CreditoId,Periodo FROM @CreditosCorteEnFecha

					SELECT * FROM @RevisionCombinada

					DECLARE 
						@i INT,
						@iMax INT,
						@CreditoId INT,
						@Periodo INT

					SELECT @i = MIN(Id), @iMax = MAX(Id) FROM @RevisionCombinada

					WHILE(@i <= @iMax)
					BEGIN
	
						SELECT 
							@CreditoId = CreditoId, 
							@Periodo = Periodo 
						FROM 
							@RevisionCombinada WHERE Id = @i
	
						EXEC Credit.RevisionAlertasPLDMontoSuperior50PorcientoStoredProcedure @MultiEmpresaId, @LavadoDineroStoredProcedureBitacoraId, @CreditoId, @Periodo, @UsuarioAltaId

						SET @i = @i + 1
					END

					DELETE FROM @RevisionCombinada
					--Eliminar tablas internas
					DELETE FROM @CreditosRevisarNuevamente
					DELETE FROM @CreditosCorteEnFecha


				--****************************************************************************************--
				--* 5) PAGO POR UN MONTO IGUAL O SUPERIOR AL EQUIVALENTE A USD$10,000 EN MONEDA NACIONAL *--
				--****************************************************************************************--

				--DECLARE @ClienteId INT

				--SET @ClienteId = 27

				--SELECT 
				--	SUM(CreditosCalculos.MontoPago)
				--FROM 
				--	Credit.CreditosCalculos INNER JOIN Credit.Creditos 
				--		ON CreditosCalculos.CreditoId = Creditos.CreditoId
				--	INNER JOIN Credit.Pagos 
				--		ON CreditosCalculos.PagoId = Pagos.PagoId
				--	INNER JOIN Credit.Solicitudes 
				--		ON Creditos.SolicitudId = Solicitudes.SolicitudId
				--WHERE 
				--	Solicitudes.ClienteId = @ClienteId
				--	AND CreditosCalculos.Procesado = 1
				--	AND Pagos.EstatusPagoId != 8 -->CANCELADO
				--	AND Pagos.TipoPagoId != 5 --> REESTRUCTURA
				--	AND Pagos.FechaPago > @FechaInicio
				--	AND Pagos.FechaPago <= @FechaFin




					-------------------------------
					--FIN: PROCESO x MULTIEMPRESA--
					-------------------------------

				--Incrementa el contador de multiEmpresas
				SET @ConteoMultiEmpresas = @ConteoMultiEmpresas + 1	
			END
	COMMIT TRAN
END TRY       
BEGIN CATCH
   IF @@trancount > 0 ROLLBACK TRANSACTION                        
   EXEC Credit.ErrorHandlerStoredProcedure                                         
   RETURN 55555                                                   
END CATCH                

