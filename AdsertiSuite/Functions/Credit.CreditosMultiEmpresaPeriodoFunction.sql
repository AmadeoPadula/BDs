USE [AdsertiSuite]
GO
/****** Object:  UserDefinedFunction [Credit].[CreditosMultiEmpresaPeriodoFunction]    Script Date: 08/05/2017 03:41:02 p. m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER FUNCTION [Credit].[CreditosMultiEmpresaPeriodoFunction](
    @MultiEmpresaId INT,
    @Anio INT,
    @Mes INT
)
RETURNS  @SeleccionCreditos TABLE 
(
    FilaId int NOT NULL,
    CreditoId int NOT NULL,
    EtapaCreditoId int NOT NULL,
    EstatusCreditoId int NOT NULL,
    EstatusCredito varchar(50),
    SolicitudId int NOT NULL,
    NumeroSolicitud varchar(15),
    ReferenciaPago nvarchar(15) NOT NULL,
    Saldo decimal(10, 2) NOT NULL,
    FechaCorte datetime NOT NULL,
    FechaPago datetime NOT NULL,
    FechaAlta datetime NOT NULL,
    UsuarioAltaId int NOT NULL,
    FechaCambio datetime NULL,
    UsuarioCambioId int NULL,
    FechaPagoReal datetime NOT NULL,
    FechaLiquidacion datetime NULL

)
AS
BEGIN
    DECLARE @TempTable TABLE (
	   FilaId int NOT NULL,
	   CreditoId int NOT NULL,
	   EtapaCreditoId int NOT NULL,
	   EstatusCreditoId int NOT NULL,
	   EstatusCredito varchar(50),
	   SolicitudId int NOT NULL,
	   NumeroSolicitud varchar(15),
	   ReferenciaPago nvarchar(15) NOT NULL,
	   Saldo decimal(10, 2) NOT NULL,
	   FechaCorte datetime NOT NULL,
	   FechaPago datetime NOT NULL,
	   FechaAlta datetime NOT NULL,
	   UsuarioAltaId int NOT NULL,
	   FechaCambio datetime NULL,
	   UsuarioCambioId int NULL,
	   FechaPagoReal datetime NOT NULL,
	   FechaLiquidacion datetime NULL)

    DECLARE @FormatoFecha VARCHAR(10)

    SET @FormatoFecha = 'dd/MM/yyyy'

    INSERT INTO @SeleccionCreditos 
	   SELECT 
		  ROW_NUMBER() OVER(ORDER BY Creditos.FechaPago) AS Fila,
		  Creditos.CreditoId,
		  Creditos.EtapaCreditoId,
		  EstatusCredito.EstatusCreditoId,
		  EstatusCredito.EstatusCredito,
		  Creditos.SolicitudId,
		  Solicitudes.NumeroSolicitud,
		  Creditos.ReferenciaPago,
		  Creditos.Saldo,
		  FORMAT(Creditos.FechaCorte, @FormatoFecha) AS FechaCorte,
		  FORMAT(Creditos.FechaPago, @FormatoFecha) AS FechaPago,
		  Creditos.FechaAlta,
		  Creditos.UsuarioAltaId,
		  Creditos.FechaCambio,
		  Creditos.UsuarioCambioId,
		  FORMAT(Creditos.FechaPagoReal, @FormatoFecha) AS FechaPagoReal,
		  FORMAT(Creditos.FechaLiquidacion, @FormatoFecha) AS FechaLiquidacion
	   FROM 
		  Credit.Creditos INNER JOIN Credit.Solicitudes 
			 ON Creditos.SolicitudId = Solicitudes.SolicitudId
		  INNER JOIN Credit.Clientes 
			 ON Solicitudes.ClienteId = Clientes.ClienteId
		  INNER JOIN Seguridad.MultiEmpresas 
			 ON Clientes.MultiEmpresaId = MultiEmpresas.MultiEmpresaId
		  INNER JOIN Credit.EstatusCredito
			 ON Creditos.EstatusCreditoId = EstatusCredito.EstatusCreditoId
	   WHERE
		  MultiEmpresas.MultiEmpresaId = @MultiEmpresaId
		  AND 
		  (
			 (
				Creditos.EstatusCreditoId = 1
				AND CAST(Creditos.FechaPago AS DATE) <= CAST(Credit.UltimoDiaMesAnio(@Anio,@Mes) AS DATE)
			 )
			 OR
			 (
			    Creditos.EstatusCreditoId != 1 AND (
				(CAST(Creditos.FechaPago AS DATE) <= CAST(Credit.UltimoDiaMesAnio(@Anio,@Mes) AS DATE))
				AND
				(CAST(Creditos.FechaLiquidacion AS DATE) >= CAST(DATEFROMPARTS(@Anio, @Mes, 1) AS DATE))
				)
			 )
		  )
	   ORDER BY Creditos.FechaPago
RETURN
END