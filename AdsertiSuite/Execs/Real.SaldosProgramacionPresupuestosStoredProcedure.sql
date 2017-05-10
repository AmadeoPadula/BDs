DECLARE 
     @AreaId INT,
	@EtapaDesarrolloId INT,
	@Fecha DATE,
	@Maestro BIT--DEFINICION DE LA VISTA QUE SE QUIERE MOSTAR (MAESTRO/DETALLE)

SET @AreaId = 19
SET @EtapaDesarrolloId = 1
SET @Fecha = GETDATE()
--SET @Maestro = 0
SET @Maestro = 1
					
EXEC Real.SaldosProgramacionPresupuestosStoredProcedure @AreaId, @EtapaDesarrolloId, @Fecha, @Maestro