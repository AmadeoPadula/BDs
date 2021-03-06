USE [AdsertiSuite]
GO
/****** Object:  UserDefinedFunction [Credit].[VencimientoDisposicionLineaCredito]    Script Date: 08/05/2017 15:44:42 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER FUNCTION [Credit].[VencimientoDisposicionLineaCredito](@CreditoId INT)
RETURNS DATE
AS
BEGIN
	DECLARE 
		@FechaVencimiento DATE,
		@FechaPago DATE,
		@PlazoDias INT
	IF EXISTS(SELECT 1 FROM	Credit.Creditos WHERE CreditoId = @CreditoId)
		BEGIN
			SELECT 
				@FechaPago = CAST(ISNULL(Creditos.FechaPago,GETDATE()) AS DATE),
				@PlazoDias = Plazos.Dias
			FROM 
				Credit.Solicitudes INNER JOIN Global.Plazos
					ON Solicitudes.PlazoId = Plazos.PlazoId
				INNER JOIN Credit.Creditos
					ON Solicitudes.SolicitudId = Creditos.SolicitudId
			WHERE 
				Creditos.CreditoId = @CreditoId


			SET @FechaVencimiento = DATEADD(DAY,@PlazoDias,@FechaPago)
	
			IF(DATEPART(DW,@FechaVencimiento) = 7) --Domingo
				SET @FechaVencimiento = DATEADD(DAY,-2,@FechaVencimiento)
			ELSE IF(DATEPART(DW,@FechaVencimiento) = 6) --Sabado
				SET @FechaVencimiento = DATEADD(DAY,-1,@FechaVencimiento)
		END
	--ELSE
	--	SET @FechaVencimiento = CAST(GETDATE() AS DATE)

RETURN @FechaVencimiento;

END

--SELECT DATEPART(DW,DATEADD(DAY,-4, GETDATE())),DATEADD(DAY,-4, GETDATE())
--SELECT DATEPART(DW,DATEADD(DAY,-3, GETDATE())),DATEADD(DAY,-3, GETDATE())
--SELECT DATEPART(DW,DATEADD(DAY,-2, GETDATE())),DATEADD(DAY,-2, GETDATE())
--SELECT DATEPART(DW,DATEADD(DAY,-1, GETDATE())),DATEADD(DAY,-1, GETDATE())
