CREATE DATABASE Primitiva
GO
USE Primitiva
GO
CREATE TABLE Sorteos(
	ID int IDENTITY(1,1)
	,[Fecha/Hora] SMALLDATETIME
	,Num1 TINYINT
	,Num2 TINYINT
	,Num3 TINYINT
	,Num4 TINYINT
	,Num5 TINYINT
	,Num6 TINYINT
	,Premio MONEY
	,Abierto BIT NOT NULL
	,CONSTRAINT PK_Sorteos PRIMARY KEY(ID)
)
GO
CREATE TABLE Boletos(
	ID UNIQUEIDENTIFIER
	,[Fecha/Hora] SMALLDATETIME
	,ID_Sorteo int
	,Importe SMALLMONEY
	,Reintegro TINYINT
	,CONSTRAINT PK_Boletos PRIMARY KEY(ID)
	,CONSTRAINT FK_Boletos_Sorteos FOREIGN KEY(ID_Sorteo) REFERENCES Sorteos(ID) ON UPDATE NO ACTION /*CASCADE NO PORQUE SI NO NO PUEDO HACER EL INSTEAD OF*/ ON DELETE NO ACTION
)
GO
CREATE TABLE Combinaciones(
	ID_Boleto UNIQUEIDENTIFIER
	,Columna TINYINT NOT NULL
	,Numero TINYINT NOT NULL
	,CONSTRAINT PK_Combinaciones PRIMARY KEY(ID_Boleto, Columna, Numero)
	,CONSTRAINT FK_Combinaciones_Sorteos FOREIGN KEY(ID_Boleto) REFERENCES Boletos(ID) ON UPDATE NO ACTION ON DELETE NO ACTION
)
GO

--Borramos la columna ID y la PK
ALTER TABLE Combinaciones DROP CONSTRAINT PK_Combinaciones
GO
--ALTER TABLE Combinaciones DROP COLUMN ID

--Creamos de nuevo la PK
ALTER TABLE Combinaciones ALTER COLUMN ID_Boleto UNIQUEIDENTIFIER NOT NULL
ALTER TABLE Combinaciones ALTER COLUMN Columna TINYINT NOT NULL
ALTER TABLE Combinaciones ALTER COLUMN Numero TINYINT NOT NULL
ALTER TABLE Combinaciones ADD CONSTRAINT PK_Combinaciones PRIMARY KEY(ID_Boleto,Columna,Numero)

--A�adimos la columna Tipo_Apuesta
ALTER TABLE Combinaciones ADD Tipo_Apuesta VARCHAR(8) DEFAULT 'Simple' NOT NULL
--ALTER TABLE Combinaciones DROP COLUMN Tipo_Apuesta


--Todas las combinaciones del mismo boleto tienen que ser simples o m�ltiples
GO
CREATE TRIGGER CompruebaSencilla on Combinaciones
after insert as
BEGIN
	DECLARE @IDBoleto UNIQUEIDENTIFIER
	DECLARE @CantColumna int
	DECLARE @Cont int=1
	SET @CantColumna=0

	--Consulta para conseguir el �ltimo boleto insertado
	SELECT @IDBoleto=B.ID from inserted as I inner join
	Boletos as B on I.ID_Boleto=B.ID

	--Consulta para conseguir la cantidad de columnas insertadas en ese boleto
	SELECT @CantColumna=COUNT(DISTINCT Columna) FROM Combinaciones WHERE ID_Boleto=@IDBoleto

	WHILE(@Cont<=@CantColumna)
	BEGIN
		IF('Simple'=ANY(SELECT Tipo_Apuesta FROM Combinaciones WHERE ID_Boleto=@IDBoleto and Columna=@Cont))--Si cualquiera de las Columnas es simple pasamos a la siguiente comprobaci�n
		BEGIN
			IF((SELECT COUNT(Numero) FROM Combinaciones WHERE ID_Boleto=@IDBoleto and Columna=@Cont)!=6) OR--Si la cantidad de numeros que contiene la columna
				('Multiple'=ANY(SELECT Tipo_Apuesta FROM Combinaciones WHERE ID_Boleto=@IDBoleto and Columna=@Cont))--es distinto de 6 o cualquier columna es Multiple
			BEGIN																						    
				ROLLBACK
				DELETE FROM Boletos WHERE ID=@IDBoleto
			END
		END
		SET @Cont+=1
	END
END

-- A�adimos el reintegro porque a Leo se le olvid�
GO
ALTER TABLE Sorteos ADD Reintegro TINYINT
--ALTER TABLE Boletos ADD Reintegro TINYINT

GO

ALTER TABLE Sorteos ADD CONSTRAINT CK_ReintegroSorteos CHECK (Reintegro BETWEEN 1 AND 9)
ALTER TABLE Boletos ADD CONSTRAINT CK_ReintegroBoletos CHECK (Reintegro BETWEEN 1 AND 9)
GO

--POR HACER: COMPROBAR SI EL BOLETO EST� COMPLETADO O NO, CON ATRIBUTO COMPLETADO EN BOLETOS. MIRAMOS TIPO_APUESTA EN COMBINACIONES PA SABER SI HAY QUE COMPROBAR 6 O 5/11
--ALTER TABLE Boletos DROP COLUMN Completado BIT DEFAULT 0 --1 completado, 0 incompleto

--Restricciones check
--Los n�meros comprendidos entre 1 y 49
BEGIN TRANSACTION
ALTER TABLE Sorteos ADD CONSTRAINT CK_Numeros1y49 CHECK (Num1 BETWEEN 1 AND 49 AND Num2 BETWEEN 1 AND 49 AND Num3 BETWEEN 1 AND 49 AND Num4 BETWEEN 1 AND 49 AND Num5 BETWEEN 1 AND 49 AND Num6 BETWEEN 1 AND 49)
ALTER TABLE Combinaciones ADD CONSTRAINT CK_Combinaciones1y49 CHECK (Numero BETWEEN 1 AND 49)
--ROLLBACK
COMMIT

GO
--AntelacionBoleto2
CREATE TRIGGER AntelacionBoleto ON Boletos
	AFTER INSERT AS
	BEGIN
		DECLARE @FechaSorteo SMALLDATETIME
		DECLARE @FechaBoleto SMALLDATETIME
		DECLARE @IDSorteoBoleto int
		DECLARE @Abierto TINYINT

		IF EXISTS(
			SELECT Abierto,I.[Fecha/Hora],S.[Fecha/Hora]
			FROM inserted AS I
			INNER JOIN Sorteos AS S ON I.ID_Sorteo=S.ID
			WHERE (Abierto=0) OR (Abierto=1 AND DATEDIFF(MINUTE,I.[Fecha/Hora],S.[Fecha/Hora])<60)
		)
		BEGIN
			ROLLBACK
		END
	END
GO
--No se pueden cambiar los n�meros una vez insertado el boleto
CREATE TRIGGER NumerosNoModificables ON Combinaciones
	INSTEAD OF UPDATE AS
	BEGIN
		PRINT 'ERROR'
	END
GO

--Trigger para comprobar que las apuestas sencillas tienen seis n�meros
ALTER trigger compruebaSencilla on Combinaciones
after insert as
BEGIN
	declare @idBoleto UNIQUEIDENTIFIER
	declare @cantColumna int
	declare @cont int=1
	set @cantColumna=0

	--consulta para conseguir el �ltimo boleto insertado
	select @idBoleto=B.ID from inserted as I inner join
	Boletos as B on I.ID_Boleto=B.ID

	--consulta para conseguir la cantidad de columnas insertadas en ese boleto
	select @cantColumna=count(distinct Columna) from Combinaciones where ID_Boleto=@idBoleto

	while(@cont<=@cantColumna)
	BEGIN
		if('Simple'=ANY(select Tipo_Apuesta from Combinaciones where ID_Boleto=@idBoleto and Columna=@cont))--Si cualquier de las Columnas es simple pasamos a la siguiente comprobaci�n
		BEGIN
			if(((select count(numero) from Combinaciones where ID_Boleto=@idBoleto and Columna=@cont)!=6) OR--Si la cantidad de numeros que contiene la columna
				('Multiple'=ANY(select Tipo_Apuesta from Combinaciones where ID_Boleto=@idBoleto and Columna=@cont)))--es distinto de 6 o cualquier columna es Multiple
				
			BEGIN																						    
				ROLLBACK
				delete from Boletos where ID=@idBoleto
			END
		END
		ELSE IF(((select count(numero) from Combinaciones where ID_Boleto=@idBoleto and Columna=@cont)=6) AND 
				('Multiple'=ALL(select Tipo_Apuesta from Combinaciones where ID_Boleto=@idBoleto and Columna=@cont)))
		BEGIN 
			BEGIN																						    
				ROLLBACK
				delete from Boletos where ID=@idBoleto
			END
		END
		set @cont+=1
	END
END

--Procedimientos almacenados
--GenerarNumerosAleatorios
GO
CREATE PROCEDURE GenerarNumerosAleatorios
	@Aleatorio TINYINT OUTPUT
	,@Minimo TINYINT
	,@Tope TINYINT
AS
	BEGIN
		--DECLARE @Tope TINYINT
		--DECLARE @Minimo TINYINT

		--Otra opci�n ser�a controlar el rango desde el procedure donde se llama, preguntar qu� es mejor
		--SET @Minimo = 1
		--SET @Tope = 49
		SELECT @Aleatorio = ROUND(((@Tope - @Minimo -1) * RAND() + @Minimo), 0)
		--SELECT @Aleatorio
		RETURN
	END
GO

--GrabaSencilla.
/*Implementa un procedimiento almacenado GrabaSencilla que grabe un
boleto con una sola apuesta simple. Datos de entrada: El sorteo y los seis
n�meros.*/
GO
CREATE PROCEDURE GrabaSencilla
	@IDSorteo int
	,@Num1 TINYINT
	,@Num2 TINYINT
	,@Num3 TINYINT
	,@Num4 TINYINT
	,@Num5 TINYINT
	,@Num6 TINYINT
AS
BEGIN
	DECLARE @IDBoleto UNIQUEIDENTIFIER
	DECLARE @Reintegro TINYINT = 0
	BEGIN TRANSACTION
		EXECUTE dbo.GenerarNumerosAleatorios @Reintegro OUTPUT, 1,9
		SELECT @IDBoleto = NEWID()
		INSERT INTO Boletos
			VALUES(@IDBoleto,CURRENT_TIMESTAMP,@IDSorteo,1,@Reintegro)
		
		--SELECT @IDBoleto = @@IDENTITY
		

		INSERT INTO Combinaciones
			VALUES(@IDBoleto,1,@Num1,'Simple')
			,(@IDBoleto,1,@Num2,'Simple')
			,(@IDBoleto,1,@Num3,'Simple')
			,(@IDBoleto,1,@Num4,'Simple')
			,(@IDBoleto,1,@Num5,'Simple')
			,(@IDBoleto,1,@Num6,'Simple')
			--VALUES(@IDSorteo,@Num1,@Num2,@Num3,@Num4,@Num4,@Num5,@Num6)
	--@@TRANCOUNT >0
	COMMIT
	--select * from Combinaciones
END

--GrabaSencillas: Lo mismo que el GrabaSencilla pero con n�mero variable de columnas
GO
CREATE PROCEDURE GrabaSencillas
	@IDBoleto UNIQUEIDENTIFIER
	,@IDSorteo int
	,@Num1 TINYINT
	,@Num2 TINYINT
	,@Num3 TINYINT
	,@Num4 TINYINT
	,@Num5 TINYINT
	,@Num6 TINYINT
	,@NumeroColumnas TINYINT
AS
BEGIN
	--DECLARE @IDBoleto UNIQUEIDENTIFIER
	DECLARE @Reintegro TINYINT = 0
	BEGIN TRANSACTION
		EXECUTE dbo.GenerarNumerosAleatorios @Reintegro OUTPUT, 1,9
		INSERT INTO Combinaciones
			VALUES(@IDBoleto,@NumeroColumnas,@Num1,'Simple')
			,(@IDBoleto,@NumeroColumnas,@Num2,'Simple')
			,(@IDBoleto,@NumeroColumnas,@Num3,'Simple')
			,(@IDBoleto,@NumeroColumnas,@Num4,'Simple')
			,(@IDBoleto,@NumeroColumnas,@Num5,'Simple')
			,(@IDBoleto,@NumeroColumnas,@Num6,'Simple')
			
	COMMIT
END

--GrabaSencillaAleatoria: Genera un boleto con n apuestas sencillas, n�meros aleatorios
GO
CREATE PROCEDURE GrabaSencillaAleatoria
	@NumeroColumnas TINYINT
	,@IDSorteo int
AS
BEGIN
	DECLARE @Num1 TINYINT = 0
	DECLARE @Num2 TINYINT = 0
	DECLARE @Num3 TINYINT = 0
	DECLARE @Num4 TINYINT = 0
	DECLARE @Num5 TINYINT = 0
	DECLARE @Num6 TINYINT = 0
	--DECLARE @IDSorteo int
	DECLARE @Reintegro TINYINT
	DECLARE @RellenaColumna TINYINT
	BEGIN TRANSACTION
		DECLARE @Seguir TINYINT = 0
		DECLARE @IDBoleto UNIQUEIDENTIFIER
		--SET @IDSorteo = (SELECT TOP(1)ID FROM Sorteos ORDER BY [Fecha/Hora] DESC /*O ASC? COMPROBAR*/)
		SET @RellenaColumna = 0
		--Hacemos el insert en Boletos
		SET @IDBoleto = NEWID()
		EXECUTE dbo.GenerarNumerosAleatorios @Reintegro OUTPUT, 1,9
		INSERT INTO Boletos
				([ID]
			   ,[Fecha/Hora]
			   ,[ID_Sorteo]
			   ,[Importe]
			   ,[Reintegro])
		   VALUES(@IDBoleto,CURRENT_TIMESTAMP,@IDSorteo,(1 * @NumeroColumnas),@Reintegro /*Tratar tema del importe*/)

		--Hacemos el insert de los n�meros
		WHILE @RellenaColumna<@NumeroColumnas --Para que vaya desde la columna 1 hasta la que haya que rellenar
			BEGIN
			/*No se c�mo devolver un par�metro de salida sin mandarle uno de entrada, le mando 0 porque
			igualmente luego le hago set a lo que me interesa, no afecta al generador de n�meros
			aleatorios.
			A�n as� preguntar a Leo si es posible declarar una variable OUTPUT en el procedure sin que
			tengas que mandarle ninguna entrada al procedure luego.*/
				--@Num1 = a lo que devuelva el generador de aleatorios
				
				EXECUTE dbo.GenerarNumerosAleatorios @Num1 OUTPUT,1,49
				
				--�C�mo carajo hago para recoger la salida del procedure?
				--Intent� hacer el generador como una funci�n pero no se puede
				--Lo �nico que se me ocurre si no es hacerlo a lo guarro y meter en este procedure
				--el generador, pero ser�a un solapamiento importante creo yo. Preguntar.
				--EXECUTE dbo.GenerarNumerosAleatorios @Num2 OUTPUT,1,49
				 -- (@Num2=@Num1)
				 WHILE (@Seguir=0)
					BEGIN
						--Llamamos de nuevo al procedimiento que genera los n�meros
						EXECUTE dbo.GenerarNumerosAleatorios @Num2 OUTPUT,1,49
						IF(@Num2!=@Num1)
							BEGIN
								SET @Seguir=1
							END
					END
				SET @Seguir=0
				WHILE (@Seguir=0)
					BEGIN
						--Llamamos de nuevo al procedimiento que genera los n�meros
						EXECUTE dbo.GenerarNumerosAleatorios @Num3 OUTPUT,1,49
						IF(@Num3!=@Num1 AND @Num3!=@Num2)
							BEGIN
								SET @Seguir=1
							END
					END
				SET @Seguir=0
				WHILE (@Seguir=0)
					BEGIN
						--Llamamos de nuevo al procedimiento que genera los n�meros
						EXECUTE dbo.GenerarNumerosAleatorios @Num4 OUTPUT,1,49
						IF(@Num4!=@Num3 AND @Num4!=@Num2 AND @Num4!=@Num1)
							BEGIN
								SET @Seguir=1
							END
					END
				SET @Seguir=0
				WHILE (@Seguir=0)
					BEGIN
						--Llamamos de nuevo al procedimiento que genera los n�meros
						EXECUTE dbo.GenerarNumerosAleatorios @Num5 OUTPUT,1,49
						IF(@Num5!=@Num4 AND @Num5!=@Num3 AND @Num5!=@Num2)
							BEGIN
								SET @Seguir=1
							END
					END
				SET @Seguir=0
				WHILE (@Seguir=0)
					BEGIN
						--Llamamos de nuevo al procedimiento que genera los n�meros
						EXECUTE dbo.GenerarNumerosAleatorios @Num6 OUTPUT,1,49
						IF(@Num6!=@Num5 AND @Num6!=@Num4 AND @Num6!=@Num3 AND @Num6!=@Num2 AND @Num6!=@Num1)
							BEGIN
								SET @Seguir=1
							END
					END
				SET @Seguir = 0
					SET @RellenaColumna+=1 --La forma abreviada de incrementarlo de uno en uno
				EXECUTE dbo.GrabaSencillas @IDBoleto,@IDSorteo,@Num1,@Num2,@Num3,@Num4,@Num5,@Num6, @RellenaColumna
				
			END
			--EXECUTE dbo.GrabaSencillas @IDSorteo,@Num1,@Num2,@Num3,@Num4,@Num5,@Num6, @NumeroColumnas
	COMMIT
END

 --Implementa un procedimiento GrabaMuchasSencillas que genere n boletos con una sola apuesta sencilla utilizando
 --el procedimiento GrabaSencillaAleatoria. Datos de entrada: El sorteo y el valor de n
GO
CREAte PROCEDURE GrabaMuchasSencillas
	@IDSorteo int
	,@NumerodeBoletos INT
AS
BEGIN
	DECLARE @Seguir int = 0 
	WHILE @Seguir < @NumerodeBoletos
		BEGIN
			EXECUTE dbo.GrabaSencillaAleatoria 1, @IDSorteo
			SET @Seguir+=1
		END
END

SELECT * FROM Sorteos
SELECT * FROM Boletos
SELECT * FROM Combinaciones

BEGIN TRANSACTION
EXECUTE dbo.GrabaMuchasSencillas 2,10000
ROLLBACK
COMMIT

SET DATEFORMAT ymd --formato de la fecha
INSERT INTO [dbo].[Sorteos]
           ([Fecha/Hora]
           ,[Num1]
           ,[Num2]
           ,[Num3]
           ,[Num4]
           ,[Num5]
           ,[Num6]
           ,[Premio]
           ,[Abierto]
           ,[Reintegro])
     VALUES
           ('2017-12-20 20:00:00'
           ,1
           ,2
           ,3
           ,4
           ,5
           ,6
           ,2
           ,1
           ,1)
GO


