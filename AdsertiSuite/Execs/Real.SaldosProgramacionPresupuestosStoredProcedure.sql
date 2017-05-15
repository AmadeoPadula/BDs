DECLARE 
     @AreaId INT,
	@EtapaDesarrolloId INT,
	@Fecha DATE,
	@Maestro BIT--DEFINICION DE LA VISTA QUE SE QUIERE MOSTAR (MAESTRO/DETALLE)

SET @AreaId = 13
SET @EtapaDesarrolloId = 2
SET @Fecha = GETDATE()
SET @Maestro = 0
--SET @Maestro = 1
					
EXEC Real.SaldosProgramacionPresupuestosStoredProcedure @AreaId, @EtapaDesarrolloId, @Fecha, @Maestro


--SELECT EtapaDesarrolloId,* FROM Real.Presupuestos WHERE EtapaDesarrolloId IS NOT NULL--PresupuestoId = 1152
--SELECT EtapaDesarrolloId,* FROM Real.Presupuestos WHERE PresupuestoId = 1201