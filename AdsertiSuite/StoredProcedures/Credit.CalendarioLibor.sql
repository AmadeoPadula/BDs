USE [AdsertiSuite]
GO
/****** Object:  StoredProcedure [Credit].[CalendarioLibor]    Script Date: 08/05/2017 15:47:11 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [Credit].[CalendarioLibor]
	@Anio INT,
	@Mes INT
WITH EXEC AS CALLER
AS
BEGIN TRY

   SET NOCOUNT ON                                                
   SET XACT_ABORT ON                                            

	BEGIN TRAN
		
		DECLARE 
			@FechaInicio date,
			@FechaFin date

		SET @FechaInicio = CAST(CAST(@Anio as char(4)) + RIGHT('00' + LTRIM(@Mes),2) + '01' AS DATE) --PRIMER DIA DEL MES
		SET @FechaFin =  EOMONTH(@FechaInicio) --ULTIMO DIA DEL MES


		DECLARE @Calendario TABLE (
			Anio INT, 
			Semana INT, 
			Lunes DATE, 
			Martes DATE, 
			Miercoles DATE, 
			Jueves DATE, 
			Viernes DATE, 
			Sabado DATE, 
			Domingo DATE
		)


		DECLARE @RangoDias int
		DECLARE @TmpCalendario TABLE(FechaMes date, DiaSemana INT, NumAnio INT , NumSemana int)
		SET @RangoDias = DATEDIFF(day, @FechaInicio, @FechaFin)

		;WITH TablaNumerada AS (
			SELECT 0 AS numero
			UNION ALL
			SELECT numero + 1 FROM TablaNumerada WHERE numero <@RangoDias
			),
		NumerosMes (FechaBase,Indice, FechaMes)
		AS
		( 
			SELECT 
				@FechaInicio, 
				numero, 
				DATEADD(d, numero, @FechaInicio)
			FROM 
				TablaNumerada
		)
		INSERT INTO @TmpCalendario
			SELECT 
				FechaMes, 
				DATEPART(weekday, FechaMes), 
				DATEPART(year, FechaMes), 
				DATEPART(week, FechaMes)
			FROM
				NumerosMes 


		INSERT INTO @Calendario
			SELECT * FROM @TmpCalendario
			PIVOT (MAX(FechaMes) FOR DiaSemana IN ([1],[2],[3],[4],[5],[6],[7]))AS F ORDER BY 1,2,3


		DECLARE @LiborDiaria TABLE(Fecha DATE, Total INT)
		
		INSERT INTO @LiborDiaria (Fecha,Total)
			SELECT 
				CAST(Fecha AS DATE),
				COUNT(1) Total
			FROM 
				Credit.Libor 
			WHERE 
				DATEPART(year,Fecha) = @Anio 
				AND DATEPART(month,Fecha) = @Mes
			GROUP BY CAST(Fecha AS DATE)


		SELECT 
			Anio,
			Semana,
			DATEPART(DAY,Lunes) AS Lunes,
		  	ISNULL((SELECT Total FROM @LiborDiaria WHERE Fecha = CAST(Lunes AS DATE)),0) LunesTotal,
			DATEPART(DAY,Martes) AS Martes,
			ISNULL((SELECT Total FROM @LiborDiaria WHERE Fecha = CAST(Martes AS DATE)),0) MartesTotal,
			DATEPART(DAY,Miercoles) AS Miercoles,
			ISNULL((SELECT Total FROM @LiborDiaria WHERE Fecha = CAST(Miercoles AS DATE)),0) MiercolesTotal,
			DATEPART(DAY,Jueves) AS Jueves,
			ISNULL((SELECT Total FROM @LiborDiaria WHERE Fecha = CAST(Jueves AS DATE)),0) JuevesTotal,
			DATEPART(DAY,Viernes) AS Viernes,
			ISNULL((SELECT Total FROM @LiborDiaria WHERE Fecha = CAST(Viernes AS DATE)),0) ViernesTotal,
			DATEPART(DAY,Sabado) AS Sabado,
			DATEPART(DAY,Domingo) AS Domingo
		FROM 
			@Calendario 
		



	COMMIT TRAN
END TRY       
BEGIN CATCH
   IF @@trancount > 0 ROLLBACK TRANSACTION                        
   EXEC Credit.ErrorHandlerStoredProcedure                                         
   RETURN 55555                                                   
END CATCH