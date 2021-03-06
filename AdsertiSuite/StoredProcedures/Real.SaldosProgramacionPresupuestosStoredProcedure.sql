USE [AdsertiSuite]
GO
/****** Object:  StoredProcedure [Real].[ReporteAcumuladoGastosStoredProcedure]    Script Date: 09/05/2017 09:38:04 p. m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE Real.SaldosProgramacionPresupuestosStoredProcedure
    @AreaId INT,
    @EtapaDesarrolloId INT,
    @Fecha DATE,
    @Maestro BIT
AS
BEGIN
    DECLARE @ProgramacionGlobal TABLE(
	   ProgramacionPresupuestoId INT,
	   DesarrolloId INT,
	   Desarrollo VARCHAR(100),
	   EtapaDesarrolloId INT,
	   EtapaDesarrollo VARCHAR(50),
	   MultiEmpresaId INT,
	   AreaId INT,
	   Area VARCHAR(50),
	   Monto DECIMAL(10,2),
	   Gastado DECIMAL(10,2),
	   Saldo DECIMAL(10,2),
	   FechaInicio DATE,
	   FechaFin DATE
    )

    DECLARE @ProgramacionDetalle TABLE(
	   ProgramacionPresupuestoDetalleId INT,
	   ProgramacionPresupuestoId INT,
	   AreaId INT,
	   EtapaDesarrolloId INT,
	   Anio INT,
	   Mes INT,
	   Monto DECIMAL(10,2),
	   Gastado DECIMAL(10,2),
	   Saldo DECIMAL(10,2)
    )


    DECLARE @Presupuestos TABLE(
	   AreaId INT,
	   EtapaDesarrolloId INT,
	   Anio INT,
	   Mes INT,
	   Monto DECIMAL(10,2),
	   Saldo DECIMAL(10,2)
    )


    INSERT INTO  @ProgramacionGlobal
	   SELECT
		  ProgramacionPresupuestos.ProgramacionPresupuestoId,
		  Desarrollos.DesarrolloId,
		  Desarrollos.Desarrollo,
		  EtapasDesarrollo.EtapaDesarrolloId,
		  EtapasDesarrollo.EtapaDesarrollo,
		  Areas.MultiEmpresaId,
		  Areas.AreaId,
		  Areas.Area,
		  ProgramacionPresupuestos.Monto,
		  0 Gastado,
		  0 Saldo,
		  ProgramacionPresupuestos.FechaInicio,
		  ProgramacionPresupuestos.FechaFin
	   FROM 
		  Real.ProgramacionPresupuestos INNER JOIN Real.Areas
			 ON ProgramacionPresupuestos.AreaId = Areas.AreaId
		  INNER JOIN Real.EtapasDesarrollo
			 ON ProgramacionPresupuestos.EtapaDesarrolloId = EtapasDesarrollo.EtapaDesarrolloId
		  INNER JOIN Real.Desarrollos
			 ON EtapasDesarrollo.DesarrolloId = Desarrollos.DesarrolloId
	   WHERE 
		  CAST(@Fecha AS DATE) BETWEEN CAST(DATEADD(MONTH, DATEDIFF(MONTH, 0, FechaInicio), 0) AS DATE) AND CAST(DATEADD(SECOND,-1,DATEADD(MONTH, DATEDIFF(MONTH, 0, FechaFin) + 1,0)) AS DATE) 
		  AND ProgramacionPresupuestos.EtapaDesarrolloId = @EtapaDesarrolloId
		  AND ProgramacionPresupuestos.AreaId = @AreaId



    INSERT INTO @ProgramacionDetalle 
	   SELECT
		  ProgramacionPresupuestosDetalle.ProgramacionPresupuestoDetalleId,
		  ProgramacionPresupuestosDetalle.ProgramacionPresupuestoId,

		  ProgramacionPresupuestos.AreaId,
		  ProgramacionPresupuestos.EtapaDesarrolloId,

		  ProgramacionPresupuestosDetalle.Anio,
		  ProgramacionPresupuestosDetalle.Mes,
		  ProgramacionPresupuestosDetalle.Monto,
		  0 Gastado,
		  0 Saldo
	   FROM 
		  Real.ProgramacionPresupuestos INNER JOIN Real.ProgramacionPresupuestosDetalle
			 ON ProgramacionPresupuestos.ProgramacionPresupuestoId = ProgramacionPresupuestosDetalle.ProgramacionPresupuestoId
	   WHERE
		  ProgramacionPresupuestos.ProgramacionPresupuestoId IN (SELECT ProgramacionPresupuestoId FROM @ProgramacionGlobal)
    
    INSERT INTO @Presupuestos
	   SELECT 
		  Presupuestos.AreaId,
		  Presupuestos.EtapaDesarrolloId,
		  YEAR(Presupuestos.FechaAlta) AS Anio,
		  MONTH(Presupuestos.FechaAlta) AS Mes,
		  SUM(Presupuestos.Monto) AS Monto, 
		  SUM(Presupuestos.Saldo) AS Saldo
	   FROM 
		  Real.Presupuestos 
	   
	   WHERE 
		  Presupuestos.EstatusPresupuestoId = 2 --AUTORIZADO
		  AND Presupuestos.EtapaDesarrolloId = @EtapaDesarrolloId
		  AND Presupuestos.AreaId = @AreaId
	   GROUP BY 
		  Presupuestos.AreaId,
		  Presupuestos.EtapaDesarrolloId,
		  YEAR(Presupuestos.FechaAlta), 
		  MONTH(Presupuestos.FechaAlta) 

    --------------------------------
    --ACTUALIZAR DETALLE MES A MES--
    --------------------------------

    UPDATE
	   ProgramacionDetalle
    SET 
	   ProgramacionDetalle.Gastado = Presupuestos.Monto - Presupuestos.Saldo
    FROM 
	   @ProgramacionDetalle ProgramacionDetalle INNER JOIN @Presupuestos Presupuestos
		  ON 
			 ProgramacionDetalle.AreaId = Presupuestos.AreaId
			 AND ProgramacionDetalle.EtapaDesarrolloId = Presupuestos.EtapaDesarrolloId
			 AND ProgramacionDetalle.Anio = Presupuestos.Anio 
			 AND ProgramacionDetalle.Mes = Presupuestos.Mes

    UPDATE @ProgramacionDetalle SET Saldo = Monto - Gastado


    -----------------------------
    --ACTUALIZAR DETALLE GLOBAL--
    -----------------------------

    UPDATE 
	   PresupuestoGlobal
    SET
	   PresupuestoGlobal.Gastado = PresupuestoDetalleAgrupado.Gastado
    FROM 
	   @ProgramacionGlobal PresupuestoGlobal INNER JOIN 
		  (
			 SELECT
				ProgramacionPresupuestoId,
				SUM(Gastado) Gastado
			 FROM 
				@ProgramacionDetalle 
			 GROUP BY ProgramacionPresupuestoId
		  ) AS PresupuestoDetalleAgrupado
	   ON PresupuestoGlobal.ProgramacionPresupuestoId = PresupuestoDetalleAgrupado.ProgramacionPresupuestoId

    UPDATE @ProgramacionGlobal SET Saldo = Monto - Gastado

    -------------------
    --SELECCION FINAL--
    -------------------

    IF @Maestro = 1
	   BEGIN
		  SELECT * FROM @ProgramacionGlobal 
	   END
    ELSE
	   BEGIN
		  SELECT * FROM @ProgramacionDetalle 
	   END
END
