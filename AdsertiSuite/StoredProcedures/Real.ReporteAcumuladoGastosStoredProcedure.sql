USE [AdsertiSuite]
GO
/****** Object:  StoredProcedure [Real].[ReporteAcumuladoGastosStoredProcedure]    Script Date: 15/05/2017 14:24:14 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [Real].[ReporteAcumuladoGastosStoredProcedure]
	@MultiEmpresaId INT,
	@FechaInicio DATE,
	@FechaFin DATE
AS
BEGIN
	SELECT 
		Desarrollos.DesarrolloId,
		Desarrollos.Desarrollo,
		Empresas.EmpresaId,
		Empresas.Empresa,
		Partidas.PartidaId,
		Partidas.Partida,
		Rubros.RubroId,
		Rubros.Rubro,
		ClavesRequisicion.ClaveRequisicionId,
		ClavesRequisicion.ClaveRequisicion,
		ClavesRequisicion.DescripcionRequisicion,
		Requisiciones.Monto
	FROM 
		Real.Requisiciones INNER JOIN Real.ClavesRequisicion
			ON Requisiciones.ClaveRequisicionId = ClavesRequisicion.ClaveRequisicionId
		INNER JOIN Real.Rubros
			ON ClavesRequisicion.RubroId = Rubros.RubroId
		INNER JOIN Real.Partidas
			ON Rubros.PartidaId = Partidas.PartidaId
		INNER JOIN Real.Empresas
			ON Partidas.EmpresaId = Empresas.EmpresaId

		INNER JOIN Real.Presupuestos
		  ON Requisiciones.PresupuestoId = Presupuestos.PresupuestoId
		--LEFT JOIN Real.EtapasDesarrollo
		INNER JOIN Real.EtapasDesarrollo
			ON Presupuestos.EtapaDesarrolloId = EtapasDesarrollo.EtapaDesarrolloId
		--LEFT JOIN Real.Desarrollos
		INNER JOIN Real.Desarrollos
			ON EtapasDesarrollo.DesarrolloId = Desarrollos.DesarrolloId
	WHERE 
		Empresas.MultiEmpresaId = @MultiEmpresaId
		AND Requisiciones.EstatusRequisicionId = 5 --Pagada
		AND (Requisiciones.FechaPago >= @FechaInicio OR @FechaInicio IS NULL)
		AND (Requisiciones.FechaPago <= @FechaFin OR @FechaFin IS NULL)

END
