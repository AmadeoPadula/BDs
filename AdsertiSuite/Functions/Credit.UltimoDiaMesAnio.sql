USE [AdsertiSuite]
GO
/****** Object:  UserDefinedFunction [Credit].[UltimoDiaMesAnio]    Script Date: 08/05/2017 15:44:22 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER FUNCTION [Credit].[UltimoDiaMesAnio](
    @Anio int,
    @Mes int
)
RETURNS DATE
AS
BEGIN
    DECLARE @UltimoDia DATETIME
	
	SELECT @UltimoDia = DATEADD(MONTH, ((@Anio - 1900) * 12) + @Mes, -1)
    
    RETURN @UltimoDia
END
