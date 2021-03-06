USE [AdsertiSuite]
GO
/****** Object:  UserDefinedFunction [Credit].[LiborFaltantesPeriodo]    Script Date: 08/05/2017 15:44:00 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER FUNCTION [Credit].[LiborFaltantesPeriodo](@FechaInicio DATE, @FechaFin DATE, @TipoTasaInteresVariableId INT)
RETURNS INT
AS
BEGIN
	DECLARE 
		@Faltantes INT,
		@FechaTmp DATE

	SET @FechaTmp = @FechaInicio

	SET @Faltantes = -1

	IF(@FechaInicio <= @FechaFin)
		BEGIN
			DECLARE @Calendario TABLE(
				Id INT IDENTITY(1,1) PRIMARY KEY,
				Fecha DATE
			)

			WHILE (@FechaTmp <= @FechaFin)
			BEGIN
				IF(DATEPART(DW,@FechaTmp) < 6) --Lunes a Viernes
					INSERT INTO @Calendario(Fecha) VALUES (@FechaTmp)

				SET @FechaTmp = DATEADD(DAY,1,@FechaTmp)
			END

			SELECT 
				@Faltantes = COUNT(1)
			FROM
				(
				SELECT
					Calendario.Fecha,
					COUNT(Libor.Fecha) Libor
				FROM 
					@Calendario Calendario LEFT JOIN Credit.Libor 
						ON 
							Calendario.Fecha = Libor.Fecha
							AND Libor.TipoTasaInteresVariableId = @TipoTasaInteresVariableId
		
				GROUP BY Calendario.Fecha
				) AS CalendarioLiborPeriodo
			WHERE 
				CalendarioLiborPeriodo.Libor = 0
		END

RETURN @Faltantes;
END