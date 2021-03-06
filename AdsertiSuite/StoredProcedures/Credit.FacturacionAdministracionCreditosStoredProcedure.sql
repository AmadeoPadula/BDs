USE [AdsertiSuite]
GO
/****** Object:  StoredProcedure [Credit].[FacturacionAdministracionCreditosStoredProcedure]    Script Date: 08/05/2017 16:18:33 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [Credit].[FacturacionAdministracionCreditosStoredProcedure]
	@MultiEmpresaId INT
AS
BEGIN
    DECLARE
	   @FechaInicio DATE,
	   @FechaInicioTmp DATE,
	   @MultiEmpresa VARCHAR (100)


    --CONSULTAR FECHA MINIMA POR MULTIEMPRESA
    SELECT 
	   @FechaInicioTmp = CAST(MIN(Creditos.FechaPago) AS DATE)
    FROM
	   Credit.Creditos INNER JOIN Credit.Solicitudes 
		  ON Creditos.SolicitudId = Solicitudes.SolicitudId
	   INNER JOIN Credit.Clientes 
		  ON Solicitudes.ClienteId = Clientes.ClienteId
	   INNER JOIN Seguridad.MultiEmpresas 
		  ON Clientes.MultiEmpresaId = MultiEmpresas.MultiEmpresaId
    WHERE
	   MultiEmpresas.MultiEmpresaId = @MultiEmpresaId


    SET @FechaInicio = DATEFROMPARTS (YEAR(@FechaInicioTmp),MONTH(@FechaInicioTmp),1)  
    SELECT @MultiEmpresa = MultiEmpresa FROM Seguridad.MultiEmpresas WHERE  MultiEmpresaId = @MultiEmpresaId

    DECLARE @Peridos TABLE(
	   Id INT IDENTITY,
	   Anio INT,
	   Mes INT, 
	   Periodo VARCHAR(7)
    )

    WHILE (@FechaInicio <= CAST(DATEADD(MONTH,-1,GETDATE()) AS DATE))
    BEGIN
	   INSERT INTO @Peridos 
		  SELECT 
			 YEAR(@FechaInicio) AS Anio, 
			 MONTH(@FechaInicio) AS Mes, 
			 CONVERT(VARCHAR, YEAR(@FechaInicio)) + '.' + RIGHT('00'+CONVERT(VARCHAR, MONTH(@FechaInicio)), 2) AS Periodo


	   SET @FechaInicio = DATEADD(MONTH,1, @FechaInicio)
    END 

    DECLARE @MontoCreditoAdministrado DECIMAL(10,2)
    SET @MontoCreditoAdministrado = 20.00

    SELECT 
	   Periodos.Id,
	   @MultiEmpresa AS MultiEmpresa,
	   Periodos.Anio,
	   Periodos.Mes,
	   Periodos.Periodo,
	   (SELECT COUNT(1) FROM Credit.CreditosMultiEmpresaPeriodoFunction(@MultiEmpresaId, Periodos.Anio, Periodos.Mes)) AS TotalCreditos,
	   (SELECT COUNT(1) FROM Credit.CreditosMultiEmpresaPeriodoFunction(@MultiEmpresaId, Periodos.Anio, Periodos.Mes)) * @MontoCreditoAdministrado AS MontoTotalCreditos
    FROM
	   @Peridos Periodos
    ORDER BY Periodos.Id DESC

END

