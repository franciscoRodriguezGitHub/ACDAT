
-- Creo la base de dato Prmitiva
CREATE DATABASE Primitiva
GO
-- Accedo a la base de datos previamente creada
USE Primitiva
GO

-- Creo las tablas correspondiente

-- Tabla Sorteos
CREATE TABLE Sorteos(
ID SMALLINT IDENTITY(1,1) UNIQUE,-- primer parametro por donde empieza y el segundo el incremento
FechaHora  SMALLDATETIME,--FECHA Y HORA FORMRATO
Abierto BIT NOT NULL, --BOOLENA PARECIDO 0 Y 1
Num1 TINYINT, -- ocupa menos memoria que el int
Num2 TINYINT,
Num3 TINYINT,
Num4 TINYINT,
Num5 TINYINT,
Num6 TINYINT,
Reintegro TINYINT,
Complementario TINYINT,
CONSTRAINT PK_Sorteos PRIMARY KEY(ID)
)
GO
-- Tabla Boletos
CREATE TABLE Boletos(
ID SMALLINT IDENTITY(1,1) UNIQUE, 
FechaHora  SMALLDATETIME,
Importe MONEY,
Reintegro TINYINT,
CONSTRAINT PK_Boletos PRIMARY KEY(ID),
ID_Sorteo SMALLINT CONSTRAINT FK_Boletos_Sorteos FOREIGN KEY REFERENCES Sorteos(ID) ON UPDATE NO ACTION /*CASCADE NO PORQUE SI NO NO PUEDO HACER EL INSTEAD OF*/ ON DELETE NO ACTION
)
GO
-- Tabla Combinaciones
CREATE TABLE Combinaciones(
Columna SMALLINT,
Numero  SMALLINT,
Tipo NVARCHAR(15) not null,
CONSTRAINT PK_Combinaciones PRIMARY KEY(Columna,Numero,ID_Boleto),
ID_Boleto SMALLINT CONSTRAINT FK_Combinaciones_Boletos FOREIGN KEY REFERENCES Boletos(ID) ON UPDATE NO ACTION ON DELETE NO ACTION
)
GO

SET DATEFORMAT ymd --formato de la fecha

												--Restricciones--

BEGIN TRANSACTION
--Números del 1 al 49
ALTER TABLE Sorteos add CONSTRAINT CK_Num1y49 CHECK(Num1 BETWEEN 1 AND 49 AND Num2 BETWEEN 1 AND 49 AND 
Num3 BETWEEN 1 AND 49 AND Num4 BETWEEN 1 AND 49 AND Num5 BETWEEN 1 AND 49 AND 
Num6 BETWEEN 1 AND 49 AND Complementario BETWEEN 1 AND 49 )
--Reintegro del 0 al 8
ALTER TABLE Sorteos ADD CONSTRAINT CK_Num0y8 CHECK (Reintegro BETWEEN 0 AND 8)
--Números del 1 al 49
ALTER TABLE Combinaciones ADD CONSTRAINT CK_NumCombinaciones1y49 CHECK (Numero BETWEEN 1 AND 49)
--Reintegro del 0 al 8
ALTER TABLE Boletos ADD CONSTRAINT CK_Num0y8Boletos CHECK (Reintegro BETWEEN 0 AND 8)
--Columna del 1 al 8
ALTER TABLE Combinaciones ADD CONSTRAINT CK_Columna_1a8 CHECK (Columna BETWEEN 1 AND 8)
--Columna tipo de la tabla combinación sólo admite los valores Simple o Múltiple
ALTER TABLE Combinaciones ADD CONSTRAINT CK_TipoCombinacion CHECK (Tipo in('Simple', 'Multiple'))

COMMIT

-- Pruebas
GO
INSERT INTO [dbo].[Sorteos]
          ([FechaHora]
           ,[Abierto]
           ,[Num1]
           ,[Num2]
           ,[Num3]
           ,[Num4]
           ,[Num5]
           ,[Num6]
           ,[Reintegro]
           ,[Complementario])
     VALUES
           ('2017-12-20 20:00:00',1,4,2,3,4,5,6,8,1)
GO
select*from Sorteos
Select * from Boletos
Select * from Combinaciones

DELETE FROM [dbo].[Sorteos]
DELETE FROM [dbo].[Boletos]
DELETE FROM [dbo].[Combinaciones]    
							--Restricciones--
--No se puede insertar un boleto si queda menos de una hora para el sorteo.
-- Tampoco para sorteos que ya hayan tenido lugar
GO
CREATE TRIGGER AntelacionBoleto ON Boletos
	AFTER INSERT AS
	BEGIN
	IF EXISTS(SELECT I.ID_Sorteo,I.FechaHora,S.FechaHora,S.Abierto
	FROM inserted AS I
			INNER JOIN Sorteos AS S ON I.ID_Sorteo=S.ID
	WHERE ( S.Abierto=0) OR (S.Abierto=1 AND DATEDIFF(MINUTE,I.FechaHora,S.FechaHora)<60))
		BEGIN
			ROLLBACK
			PRINT ' AntelacionBoleto TRIGGER'
		END
	END
GO
--Pruebas
INSERT INTO [dbo].[Boletos]
           ([FechaHora]
           ,[Importe]
           ,[Reintegro]
           ,[ID_Sorteo])
     VALUES
            ('2017-12-20 16:30:00'
           ,1
           ,8
           ,8)
GO
							--Restricciones--
--No se pueden cambiar los números una vez insertado el boleto
CREATE TRIGGER NumerosNoModificables ON Combinaciones
	INSTEAD OF UPDATE AS
	BEGIN
		PRINT 'ERROR NumerosNoModificables'
	END
GO

						--Procedimiento--
--	Implementa un procedimiento almacenado GrabaSencilla que grabe
-- un boleto con una sola apuesta simple. Datos de entrada: El sorteo y los seis números

CREATE PROCEDURE GrabaSencilla
	@IDSorteo SMALLINT
	,@Num1 TINYINT
	,@Num2 TINYINT
	,@Num3 TINYINT
	,@Num4 TINYINT
	,@Num5 TINYINT
	,@Num6 TINYINT
AS
BEGIN

	DECLARE @ReintregoAleatorio TINYINT =ROUND(((8 - 0) * RAND() + 1), 0)
	DECLARE @FechaHoraCreacion SMALLDATETIME=GETDATE()
	DECLARE @ID_Boleto SMALLINT
	BEGIN TRANSACTION	
		INSERT Boletos values(@FechaHoraCreacion,1,@ReintregoAleatorio,@IDSorteo)
		SELECT @ID_Boleto=MAX(ID) FROM Boletos WHERE ID_Sorteo=@IDSorteo

		INSERT Combinaciones values( 1,@Num1,'Simple', @ID_Boleto)
		INSERT Combinaciones values( 1,@Num2,'Simple', @ID_Boleto)
		INSERT Combinaciones values( 1,@Num3,'Simple', @ID_Boleto)
		INSERT Combinaciones values( 1,@Num4,'Simple', @ID_Boleto)
		INSERT Combinaciones values( 1,@Num5,'Simple', @ID_Boleto)
		INSERT Combinaciones values( 1,@Num6,'Simple', @ID_Boleto)
	
	COMMIT
END


GO
CREATE PROCEDURE GrabaSencilla2
	@IDSorteo SMALLINT
	,@Num1 TINYINT
	,@Num2 TINYINT
	,@Num3 TINYINT
	,@Num4 TINYINT
	,@Num5 TINYINT
	,@Num6 TINYINT
AS
BEGIN
	DECLARE @ReintregoAleatorio TINYINT =ROUND(((8 - 0) * RAND() + 1), 0)
	DECLARE @FechaHoraCreacion SMALLDATETIME=GETDATE()
	DECLARE @ID_Boleto SMALLINT
		
	INSERT Boletos values(@FechaHoraCreacion,1,@ReintregoAleatorio,@IDSorteo)
	SELECT @ID_Boleto=MAX(ID) FROM Boletos WHERE ID_Sorteo=@IDSorteo
	BEGIN TRANSACTION
		BEGIN TRY 
			INSERT Combinaciones values( 1,@Num1,'Simple', @ID_Boleto)
			INSERT Combinaciones values( 1,@Num2,'Simple', @ID_Boleto)
			INSERT Combinaciones values( 1,@Num3,'Simple', @ID_Boleto)
			INSERT Combinaciones values( 1,@Num4,'Simple', @ID_Boleto)
			INSERT Combinaciones values( 1,@Num5,'Simple', @ID_Boleto)
			INSERT Combinaciones values( 1,@Num6,'Simple', @ID_Boleto)
		END TRY
		BEGIN CATCH
			IF(@@TRANCOUNT>0)
			BEGIN
				COMMIT
			END
			ELSE
			BEGIN
				ROLLBACK
			END
		END CATCH
	END

END



EXEC dbo.GrabaSencilla 9, 14, 15, 28, 6, 42, 33
select*from Sorteos
select * from Boletos
select * from Combinaciones

	--Procedimiento--
--	Implementa un procedimiento GrabaSencillaAleatoria que genere 
-- un boleto con n apuestas sencillas, cuyos números se generarán de forma aleatoria.
-- Entradas: un entero que es el ID del sorteo y otro entero que es el Nº de apuestas a grabar
--AQUI
GO
--CREATE PROCEDURE GrabaSencillaAleatoria 
CREATE PROCEDURE GrabaSencillaAleatorias--Mecla de lo dos
	@IDSorteo SMALLINT
	,@NumApuesta TINYINT
AS
BEGIN
	DECLARE @Num1 TINYINT
	DECLARE @Num2 TINYINT
	DECLARE @Num3 TINYINT
	DECLARE @Num4 TINYINT
	DECLARE @Num5 TINYINT
	DECLARE @Num6 TINYINT
	DECLARE @Sigue BIT 
	
	WHILE(@NumApuesta>0)
	BEGIN
		SET @Sigue=0
		SET @Num1 =ROUND(((49 - 1) * RAND() + 1), 0)
		
		--SET @Num3 =ROUND(((49 - 1) * RAND() + 1), 0)
		--SET @Num4 =ROUND(((49 - 1) * RAND() + 1), 0)
		--SET @Num5 =ROUND(((49 - 1) * RAND() + 1), 0)
		--SET @Num6 =ROUND(((49 - 1) * RAND() + 1), 0)
		WHILE(@Sigue=0)
		BEGIN
			SET @Num2 =ROUND(((49 - 1) * RAND() + 1), 0)
			IF(@Num2 != @Num1)
			BEGIN 
				 SET @Sigue=1
			END
		END
		SET @Sigue=0

		WHILE(@Sigue=0)
		BEGIN
			SET @Num3 =ROUND(((49 - 1) * RAND() + 1), 0)
			IF(@Num3 != @Num1 AND @Num3 != @Num2 )
			BEGIN 
				 SET @Sigue=1
			END
		END
		SET @Sigue=0

		WHILE(@Sigue=0)
		BEGIN
			SET @Num4 =ROUND(((49 - 1) * RAND() + 1), 0)
			IF(@Num4 != @Num1 AND @Num4 != @Num2 AND @Num4 != @Num3 )
			BEGIN 
				 SET @Sigue=1
			END
		END
		SET @Sigue=0

		WHILE(@Sigue=0)
		BEGIN
			SET @Num5 =ROUND(((49 - 1) * RAND() + 1), 0)
			IF(@Num5 != @Num1 AND @Num5 != @Num2 AND @Num5 != @Num3  AND @Num5 != @Num4)
			BEGIN 
				 SET @Sigue=1
			END
		END
		SET @Sigue=0

		WHILE(@Sigue=0)
		BEGIN
			SET @Num6 =ROUND(((49 - 1) * RAND() + 1), 0)
			IF(@Num6 != @Num1 AND @Num6 != @Num2 AND @Num6 != @Num3  AND @Num6 != @Num4 AND @Num6 != @Num5)
			BEGIN 
				 SET @Sigue=1
			END
		END
		
		
		EXEC dbo.GrabaSencilla @IDSorteo, @Num1, @Num2, @Num3, @Num4, @Num5, @Num6
		SET @NumApuesta-=1
	END
END
GO
GO

--CREATE PROCEDURE GrabaSencillaAleatoria
CREATE PROCEDURE GrabaSencillaAleatoria
	@IDSorteo SMALLINT
	,@NumApuesta TINYINT
AS
BEGIN
	DECLARE @Num1 TINYINT
	DECLARE @Num2 TINYINT
	DECLARE @Num3 TINYINT
	DECLARE @Num4 TINYINT
	DECLARE @Num5 TINYINT
	DECLARE @Num6 TINYINT
	DECLARE @Sigue BIT 
	DECLARE @ReintregoAleatorio TINYINT =ROUND(((8 - 0) * RAND() + 1), 0)
	DECLARE @FechaHoraCreacion SMALLDATETIME=GETDATE()
	DECLARE @ID_Boleto SMALLINT
	DECLARE @Contador TINYINT =1
	--Comprobar el numero de columna
	BEGIN TRANSACTION	
		INSERT Boletos values(@FechaHoraCreacion,1,@ReintregoAleatorio,@IDSorteo)
		SELECT @ID_Boleto=MAX(ID) FROM Boletos WHERE ID_Sorteo=@IDSorteo

		WHILE(@NumApuesta>0)
		BEGIN
			SET @Sigue=0
			SET @Num1 =ROUND(((49 - 1) * RAND() + 1), 0)
			WHILE(@Sigue=0)
			BEGIN
				SET @Num2 =ROUND(((49 - 1) * RAND() + 1), 0)
				IF(@Num2 != @Num1)
				BEGIN 
					 SET @Sigue=1
				END
			END
			SET @Sigue=0

			WHILE(@Sigue=0)
			BEGIN
				SET @Num3 =ROUND(((49 - 1) * RAND() + 1), 0)
				IF(@Num3 != @Num1 AND @Num3 != @Num2 )
				BEGIN 
					 SET @Sigue=1
				END
			END
			SET @Sigue=0

			WHILE(@Sigue=0)
			BEGIN
				SET @Num4 =ROUND(((49 - 1) * RAND() + 1), 0)
				IF(@Num4 != @Num1 AND @Num4 != @Num2 AND @Num4 != @Num3 )
				BEGIN 
					 SET @Sigue=1
				END
			END
			SET @Sigue=0

			WHILE(@Sigue=0)
			BEGIN
				SET @Num5 =ROUND(((49 - 1) * RAND() + 1), 0)
				IF(@Num5 != @Num1 AND @Num5 != @Num2 AND @Num5 != @Num3  AND @Num5 != @Num4)
				BEGIN 
					 SET @Sigue=1
				END
			END
			SET @Sigue=0

			WHILE(@Sigue=0)
			BEGIN
				SET @Num6 =ROUND(((49 - 1) * RAND() + 1), 0)
				IF(@Num6 != @Num1 AND @Num6 != @Num2 AND @Num6 != @Num3  AND @Num6 != @Num4 AND @Num6 != @Num5)
				BEGIN 
					 SET @Sigue=1
				END
			END
			INSERT Combinaciones values( @Contador,@Num1,'Simple', @ID_Boleto)
			INSERT Combinaciones values( @Contador,@Num2,'Simple', @ID_Boleto)
			INSERT Combinaciones values( @Contador,@Num3,'Simple', @ID_Boleto)
			INSERT Combinaciones values( @Contador,@Num4,'Simple', @ID_Boleto)
			INSERT Combinaciones values( @Contador,@Num5,'Simple', @ID_Boleto)
			INSERT Combinaciones values( @Contador,@Num6,'Simple', @ID_Boleto)
		
			SET @Contador+=1
			SET @NumApuesta-=1
		END
	COMMIT
END
GO


EXEC dbo.GrabaSencillaAleatorias 3, 2
select * from Sorteos
select * from Boletos
select * from Combinaciones order by ID_Boleto
DELETE FROM [dbo].[Boletos]
DELETE FROM [dbo].[Combinaciones] 
EXEC dbo.GrabaSencillaAleatoria 3, 2  
                         --Procedimiento
--Implementa un procedimiento GrabaMuchasSencillas que genere n 
--boletos con una sola apuesta sencilla utilizando el procedimiento 
--GrabaSencillaAleatoria. Datos de entrada: El sorteo y el valor de n
GO
CREATE PROCEDURE GrabaMuchasSencillas
	@IDSorteo SMALLINT
	,@NumBoletos TINYINT
AS
BEGIN	
--me falta el commit
	WHILE(@NumBoletos>0)
		BEGIN
		EXEC dbo.GrabaSencillaAleatoria @IDSorteo, 1
		SET @NumBoletos-=1
	END
END
GO
EXEC dbo.GrabaMuchasSencillas 3, 2  
select * from Sorteos
select * from Boletos
select * from Combinaciones order by ID_Boleto
DELETE FROM [dbo].[Boletos]
DELETE FROM [dbo].[Combinaciones]

 