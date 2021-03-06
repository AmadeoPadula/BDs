USE [AdsertiSuite]
GO
/****** Object:  StoredProcedure [Real].[CalcularComisionTitulacionDetalleStoredProcedure]    Script Date: 08/05/2017 16:20:13 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [Real].[CalcularComisionTitulacionDetalleStoredProcedure]
	@MultiEmpresaId INT,
	@ParamDesarrolloId INT
AS
BEGIN TRY
	SET NOCOUNT ON                                                
	SET XACT_ABORT ON          

	BEGIN TRAN
		DECLARE 
			@EtapaVentaIdComisionLimite INT,
			@EtapaVentaIdComision INT,
			@MontoComision DECIMAL(10,2)

		SET @EtapaVentaIdComision = 6 --FONDEO DE RECURSOS ENTIDAD FINANCIERA
		SET @EtapaVentaIdComisionLimite = 8 --ENTREGA DE VIVIENDA


		SELECT 
			@MontoComision = Parametro 
		FROM 
			Global.Parametros 
		WHERE 
			ParametroId = 'AdsertiReal.MontoComisionTitulacion' 
			AND MultiEmpresaId = @MultiEmpresaId


		--Variable tabla Información Ventas Maestro
		DECLARE @SeleccionVentas TABLE(
			SeleccionVentaId INT NOT NULL IDENTITY(1,1) PRIMARY KEY,
			VentaId INT NOT NULL,
			TipoCreditoId INT NOT NULL,
			ClienteId INT NOT NULL,
			EstatusVentaId INT NOT NULL,
			ViviendaId INT NOT NULL,
			EtapaVentaId INT NOT NULL,
			ActividadVentaId INT NOT NULL,
			DesarrolloId INT NOT NULL
		)

		DECLARE @ComisionesTitulacionDetalle TABLE(
			ComisionTitulacionDetalleId INT NOT NULL IDENTITY(1,1) PRIMARY KEY,
			VentaId INT NOT NULL,
			TipoCreditoId INT NOT NULL,
			ClienteId INT NOT NULL,
			EstatusVentaId INT NOT NULL,
			ViviendaId INT NOT NULL,
			EtapaVentaId INT NOT NULL,
			ActividadVentaId INT NOT NULL,
			DesarrolloId INT NOT NULL,

			PersonaId INT NOT NULL,
			--Detalle Comision 
			--ComisionId INT,
			MontoComision DECIMAL(10,2)--,
			--PorcentajeComision DECIMAL(10,2),
			--EstatusComisionId INT,

			--DiferenciaComision DECIMAL(10,2)
		)

		INSERT INTO @SeleccionVentas(
				VentaId,
				TipoCreditoId,
				EstatusVentaId,
				ClienteId,
				ViviendaId,
				EtapaVentaId,
				ActividadVentaId,
				DesarrolloId
			)
		SELECT 
			Ventas.VentaId,
			Ventas.TipoCreditoId,
			Ventas.EstatusVentaId,
			Ventas.ClienteId,
			Ventas.ViviendaId,
			EtapasVenta.EtapaVentaId,
			ActividadesVenta.ActividadVentaId,
			Desarrollos.DesarrolloId
		FROM
				Real.Ventas INNER JOIN Real.ActividadesVenta 
					ON ActividadesVenta.ActividadVentaId = Ventas.ActividadVentaId
				INNER JOIN Real.EtapasVenta
					ON ActividadesVenta.EtapaVentaId = EtapasVenta.EtapaVentaId
				INNER JOIN Real.Viviendas
					ON Viviendas.ViviendaId = Ventas.ViviendaId
				INNER JOIN Real.EtapasDesarrollo
					ON Viviendas.EtapaDesarrolloId = EtapasDesarrollo.EtapaDesarrolloId
				INNER JOIN Real.Desarrollos
					ON EtapasDesarrollo.DesarrolloId = Desarrollos.DesarrolloId
		
			WHERE
				Desarrollos.DesarrolloId = @ParamDesarrolloId
				AND EtapasVenta.EtapaVentaId >= @EtapaVentaIdComision
				--AND EtapasVenta.EtapaVentaId <= @EtapaVentaIdComisionLimite --> Este filtro se sustituye mas adelante
				AND Ventas.EstatusVentaId = 1 --Activa


		-------------------------------------
		--SELECCIÓN VENTAS MAESTRO AMPLIADA--
		-------------------------------------

		DECLARE 
			@i INT,
			@iMax INT

		DECLARE
			@SeleccionVentaId INT,
			@VentaId INT,
			@TipoCreditoId INT,
			@EstatusVentaId INT,
			@ClienteId INT,
			@ViviendaId INT,
			@EtapaVentaId INT,
			@ActividadVentaId INT,
			@DesarrolloId INT

		SELECT @i = MIN(SeleccionVentaId), @iMax = MAX(SeleccionVentaId) FROM @SeleccionVentas

		WHILE @i <= @iMax
		BEGIN
			SELECT
				@SeleccionVentaId = SeleccionVentaId,
				@VentaId = VentaId,
				@TipoCreditoId = TipoCreditoId,
				@EstatusVentaId = EstatusVentaId,
				@ClienteId = ClienteId,
				@ViviendaId = ViviendaId,
				@EtapaVentaId = EtapaVentaId,
				@ActividadVentaId = ActividadVentaId,
				@DesarrolloId = DesarrolloId
			FROM
				@SeleccionVentas
			WHERE
				SeleccionVentaId = @i
			----------------------------------------------------------------------
			--Para cada Integrante de Titulación agregar un registro

			INSERT INTO @ComisionesTitulacionDetalle(
				VentaId,
				TipoCreditoId,
				EstatusVentaId,
				ClienteId,
				ViviendaId,
				EtapaVentaId,
				ActividadVentaId,
				DesarrolloId,
				PersonaId,
				--ComisionId,
				MontoComision--,
				--PorcentajeComision,
				--EstatusComisionId
			)
			SELECT
				@VentaId,
				@TipoCreditoId,
				@EstatusVentaId,
				@ClienteId,
				@ViviendaId,
				@EtapaVentaId,
				@ActividadVentaId,
				@DesarrolloId,
				Personas.PersonaId,
				@MontoComision
			FROM 
				Real.PersonasComisionTitulacion INNER JOIN Seguridad.Personas
					ON PersonasComisionTitulacion.PersonaId = Personas.PersonaId
			WHERE
				Personas.MultiEmpresaId = @MultiEmpresaId
				AND PersonasComisionTitulacion.Estatus = 1 

			SET @i = @i + 1
		END 


		--Consultar las ventas que ya fueron comisionadas y eliminarlas de la tabla actual
		DECLARE @TipoComisionIdTitulacion INT

		SET @TipoComisionIdTitulacion = 3 --3	COMISIÓN TITULACIÓN

		DELETE FROM @ComisionesTitulacionDetalle WHERE VentaId IN(
			SELECT DISTINCT
				Comisiones.VentaId
			FROM 
				Real.Comisiones 
			WHERE
				Comisiones.TipoComisionId = @TipoComisionIdTitulacion 
		)


		SELECT
			ComisionesTitulacionDetalle.ComisionTitulacionDetalleId,
			ComisionesTitulacionDetalle.VentaId,
			TiposCredito.TipoCreditoId,
			TiposCredito.TipoCredito,
			EstatusVenta.EstatusVentaId,
			EstatusVenta.EstatusVenta,
			Clientes.ClienteId,
			Clientes.Nombre + ' ' + Clientes.ApellidoPaterno + ' ' + ISNULL(Clientes.ApellidoMaterno,'') AS Cliente ,
			--Ubicación
			Desarrollos.DesarrolloId,
			Desarrollos.Desarrollo,
			EtapasDesarrollo.EtapaDesarrolloId,
			EtapasDesarrollo.EtapaDesarrollo,
			Condominios.CondominioId,
			Condominios.Condominio,

			Viviendas.ViviendaId,
			Real.fnVentaPrecioVivienda(VentaId) PrecioVivienda,
			Viviendas.Ubicacion,
			ComisionesTitulacionDetalle.EtapaVentaId,
			ComisionesTitulacionDetalle.ActividadVentaId,
			ComisionesTitulacionDetalle.PersonaId,
			Personas.Nombre + ' ' + Personas.ApellidoPaterno + ' ' + ISNULL(Personas.ApellidoMaterno,'') AS Nombre,
			ComisionesTitulacionDetalle.MontoComision
		FROM 
			@ComisionesTitulacionDetalle ComisionesTitulacionDetalle INNER JOIN Seguridad.Personas
				ON ComisionesTitulacionDetalle.PersonaId = Personas.PersonaId
			INNER JOIN Real.Clientes
				ON ComisionesTitulacionDetalle.ClienteId = Clientes.ClienteId
			INNER JOIN Real.Viviendas
				ON ComisionesTitulacionDetalle.ViviendaId = Viviendas.ViviendaId
			INNER JOIN Real.Condominios
				ON Viviendas.CondominioId  = Condominios.CondominioId
			INNER JOIN Real.EtapasDesarrollo
				ON Condominios.EtapaDesarrolloId = EtapasDesarrollo.EtapaDesarrolloId
			INNER JOIN Real.Desarrollos
				ON EtapasDesarrollo.DesarrolloId = Desarrollos.DesarrolloId
			INNER JOIN Real.TiposCredito
				ON ComisionesTitulacionDetalle.TipoCreditoId = TiposCredito.TipoCreditoId
			INNER JOIN Real.EstatusVenta
				ON ComisionesTitulacionDetalle.EstatusVentaId = EstatusVenta.EstatusVentaId

	COMMIT TRAN
END TRY       
BEGIN CATCH
   IF @@trancount > 0 ROLLBACK TRANSACTION                        
   EXEC Real.ErrorHandlerStoredProcedure                                         
   RETURN 55555                                                   
END CATCH                      