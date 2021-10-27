--USE master
--CREATE DATABASE Votos
--USE Votos

SET DATEFORMAT dmy;
SET NOCOUNT OFF;

--ESTA CONSULTA DEMUESTRA QUE HAY DATOS DUPLICADOS. TENGO QUE DROPPEAR
--LAS TABLAS DE NUEVO Y EJECUTAR EL PROCEDIMIENTO DE POBLAR.
--ADEMÁS, HAY OTROS CONFLICTOS CON FK QUE SOLUCIONAS.

SELECT nombre, apellidos, COUNT(nombre + ' ' + apellidos) FROM Integrantes
GROUP BY nombre, apellidos

GO
CREATE TABLE tipos_eleccion(

	id int,
	tipo_eleccion nvarchar(20) NOT NULL

	CONSTRAINT PK_enum PRIMARY KEY(id),
	CONSTRAINT CK_Tipo_eleccion CHECK (tipo_eleccion IN (N'senado', N'nacional', N'autonomica'))
)
GO

INSERT INTO tipos_eleccion(id, tipo_eleccion) VALUES
(1, 'nacional'), (2, 'senado'), (3, 'autonomica')

GO
CREATE TABLE Votos_partido(

	id int IDENTITY(1,1),
	nombre nvarchar(50) NOT NULL,

	CONSTRAINT PK_Partidos PRIMARY KEY(id)
)
GO

CREATE TABLE Candidatos_senado(

	id int IDENTITY(1,1),
	nombre nvarchar(50) NOT NULL,
	apellidos nvarchar(100) NOT NULL,

	CONSTRAINT PK_CandidatoSenado PRIMARY KEY(id),

)
GO
CREATE TABLE Votos_senado(

--Los ciudadanos de las comunidades autónomas escogen tres candidatos
--al senado, mientras que en las ciudades autónomas sólo dos. Por ello,
-- el tercer campo de candidato es nullable.

	id int IDENTITY(1,1),
	id_senador_1 int NOT NULL,
	id_senador_2 int NOT NULL,
	id_senador_3 int NULL

	CONSTRAINT PK_Senado PRIMARY KEY(id),
	CONSTRAINT FK_SenadoCandidatoSenado1 FOREIGN KEY(id_senador_1) REFERENCES Candidatos_senado(id),
	CONSTRAINT FK_SenadoCandidatoSenado2 FOREIGN KEY(id_senador_2) REFERENCES Candidatos_senado(id),
	CONSTRAINT FK_SenadoCandidatoSenado3 FOREIGN KEY(id_senador_3) REFERENCES Candidatos_senado(id)
)
GO

CREATE TABLE Integrantes(
	
	id int IDENTITY(1,1),
	nombre nvarchar(50) NOT NULL,
	apellidos nvarchar(100) NOT NULL,
	cargo nvarchar(60) NOT NULL,
	id_partido int NOT NULL 

	CONSTRAINT PK_Integrantes PRIMARY KEY(id)
	CONSTRAINT FK_IntegrantesPartidos FOREIGN KEY(id_partido) REFERENCES Votos_partido(id)
	
)
GO

CREATE TABLE Elecciones(

	id int IDENTITY(1,1),
	provincia nvarchar(50) NOT NULL,
	instante_comienzo datetime NOT NULL,
	instante_final datetime NOT NULL,
	id_tipo_eleccion int NOT NULL

	CONSTRAINT PK_Elecciones PRIMARY KEY(id)
	CONSTRAINT FK_EleccionesTipoEleccion FOREIGN KEY(id_tipo_eleccion) REFERENCES tipos_eleccion(id)
)
GO
CREATE TABLE Votos(

	id int IDENTITY(1,1),
	id_eleccion int NOT NULL,
	id_partido int NULL,
	id_votos_senado int NULL,
	instante_creacion date NOT NULL DEFAULT GETDATE()

	CONSTRAINT PK_Votos PRIMARY KEY(id),
	CONSTRAINT FK_VotosElecciones FOREIGN KEY (id_eleccion) REFERENCES Elecciones(id),
	CONSTRAINT FK_VotosVotos_partido FOREIGN KEY (id_partido) REFERENCES Votos_partido(id),
	CONSTRAINT FK_VotosVotos_senado FOREIGN KEY (id_votos_senado) REFERENCES Votos_senado(id)

)
GO


--Creación de procedimientos y funciones
--
--FUNCIONES
--
-----------------------------------------
--Cabecera: FNExisteCandidato(@nombre_apellidos_candidato nvarchar(200))
--Input:
--		- @nombre_apellidos_candidato: El nombre y apellidos del candidato al senado que comprobaremos si existe
--									   en la tabla Candidatos_senado
--Output:
--		- @id_candidato: Si su valor es 0, significa que no existe un candidato con el mismo nombre y apellidos.
--						 Cualquier valor distinto representa la id del candidato, que ya existe en la base de datos.
--
--Función auxiliar que se encarga de comprobar si existe un candidato que tenga un nombre y apellidos
--exactamente iguales a los introducidos por parámetros.

--IMPORTANTE: NO SABE DEIFERENCIAR ENTRE VARIAS COMBINACIONES IGUALES DE NOMBRE Y APELLIDOS
-------------------------------------------
GO
CREATE OR ALTER FUNCTION FNExisteCandidato
(
	@nombre nvarchar(200),
	@apellidos nvarchar(200)
)
	RETURNS int AS
		BEGIN
			DECLARE @id_candidato int = 0
			DECLARE @loco int = 0
			
			--Si no existe, se almacena NULL
			SELECT @id_candidato = id
			FROM Candidatos_senado
			WHERE nombre = @nombre AND 
				  apellidos = @apellidos
			
	
		RETURN @id_candidato

		END;
GO

--PROCEDIMIENTOS

--
--Precondición: El nombre y apelidos suministrados por parámetro deben haber sido previamente
--filtrados para evitar la introducción de cadenas potencialmente peligrosas.
--
--   Input:
--		- @nombre: El nombre del candidato a comprobar
--		- @apellidos: Los apellidos del candidato a comprobar
--
--   Output:
--		- @id_candidato: Valor entero que representa la id del nuevo candidato introducido o, si ya se encontraba
--						 en la base de datos, la id existente.
--						 
--
--Este procedimiento auxiliar comprueba la existencia de un candidato al senado cuyo nombre y apellidos coincidan
--exactamente con los pasados por parámetros. De no existir, se crea un nuevo candidato.
--
CREATE OR ALTER PROCEDURE AnadirQuizaCandidatoSenado 
	@nombre nvarchar(200),
	@apellidos nvarchar(200),
	@id_candidato int OUTPUT
AS

--Si no existe el candidato, se crea.

	SET @id_candidato = 0

	--Comprobamos si existe el candidato cuyo nombres y apellidos se suministran por parametros
	DECLARE @posible_id_candidato int = dbo.FNExisteCandidato(@nombre, @apellidos)

	--Si la id que devuelve la función es igual a 0, significa que no existe aun el candidato
	IF(@posible_id_candidato = 0)
		BEGIN
			BEGIN TRANSACTION

				--Opening symmetric key in order to encrypt the data about to be inserted
				OPEN SYMMETRIC KEY Symmetric_Key
						DECRYPTION BY CERTIFICATE Certificate_test;

					INSERT INTO Candidatos_senado (nombre, apellidos)
					VALUES(EncryptByKey (Key_GUID('Symmetric_Key'), @nombre),
						   EncryptByKey (Key_GUID('Symmetric_Key'), @apellidos))

	
				CLOSE SYMMETRIC KEY SymKey_test;

				--scope_identity() devuelve el último valor de id insertado en ESTE ÁMBITO
				--@@IDENTITY tiene una scope global, puede dar lugar a errores
				SET @id_candidato = scope_identity()
			COMMIT
		END;
	--El candidato ya existía en la base de datos
	ELSE
		BEGIN
			SET @id_candidato = @posible_id_candidato
		END;

	RETURN @id_candidato
GO



-- Votar sólo se realiza a través de este procedimiento. Permite votar en elecciones autonómicas, nacionales y al senado.
--A través de la anulabilidad de los campos de id de senador e id de partido, tenemos todas las combinaciones de valores que necesitamos.
-----------------------------------------
--COMBINACIONES DE VALORES ACEPTADAS
--
--Voto nacional:
-- @id_elecciones -> 1
-- @id_partido -> 2
-- @id_senador_1 -> No introducido (NULL)
-- @id_senador_2 -> No introducido (NULL)
-- @id_senador_3 -> No introducido (NULL)
--
--Voto autonómico:
-- @id_elecciones -> 2
-- @id_partido -> 3
-- @id_senador_1 -> No introducido (NULL)
-- @id_senador_2 -> No introducido (NULL)
-- @id_senador_3 -> No introducido (NULL)
--
--Voto al senado (3 representantes):
-- @id_elecciones -> 3
-- @id_partido -> No introducido (NULL)
-- @id_senador_1 -> 2
-- @id_senador_2 -> 7
-- @id_senador_3 -> 1
--
--Voto al senado (2 representantes):
-- @id_elecciones -> 3
-- @id_partido -> No introducido (NULL)
-- @id_senador_1 -> 5
-- @id_senador_2 -> 7
-- @id_senador_3 -> No introducido (NULL)
------------------------------------------

-- Una de las tareas de este procedimiento es comprobar que las combinaciones de valores introducidas por parámetro sean alguna
--de las enteriores necesariamente. Por ejemplo, no se aceptarán entidades Voto con una id_partido no nula y alguna id de candidato
--al senado no nula (Voto al senado y nacional/autonómico al mismo tiempo; no se puede).
--


CREATE OR ALTER PROCEDURE Votar
	@id_elecciones int,
	@id_partido int,
	@nombre_1 nvarchar(200) = NULL,
	@nombre_2 nvarchar(200) = NULL,
	@nombre_3 nvarchar(200) = NULL,
	@apellido_1 nvarchar(200) = NULL,
	@apellido_2 nvarchar(200) = NULL,
	@apellido_3 nvarchar(200) = NULL,
	@exito bit OUTPUT
AS

	--Se filtran los valores pasados por parámetros

	--Se comprueba si en el momento de ejecución de este procedimiento el id de elección
	--se refiere a una elección activa

	IF(EXISTS
		(SELECT id
		 FROM Elecciones
		 WHERE CURRENT_TIMESTAMP BETWEEN instante_comienzo AND instante_final
		       AND id = @id_elecciones))
			BEGIN
				--Se escoge 1 partido y ningún senador
				IF(@id_partido IS NOT NULL AND COALESCE(@nombre_1, @apellido_1,
														@nombre_2, @apellido_2,
														@nombre_3, @apellido_3) IS NULL)
					BEGIN
		
						BEGIN TRANSACTION
							INSERT INTO Votos(id_eleccion, id_partido)
							VALUES(@id_elecciones, @id_partido)
						COMMIT

					END;
				--No se escoge ningún partido y al menos 2 candidatos al senado.
				ELSE IF(@id_partido IS NULL AND 
						@nombre_1 IS NOT NULL AND
						@nombre_2 IS NOT NULL AND
						@apellido_1 IS NOT NULL AND
						@apellido_2 IS NOT NULL)
			
						BEGIN
				
							DECLARE @id_votos_senado int = 0

							DECLARE @idInsertada1 int
							DECLARE @idInsertada2 int
							DECLARE @idInsertada3 int

							--Comprobamos que los candidatos introducidos por el usuario existen
							--Si no existen, se crean y almacenamos su id de vuelta.

							EXECUTE AnadirQuizaCandidatoSenado @nombre_1, @apellido_1, @idInsertada1 OUT
							EXECUTE AnadirQuizaCandidatoSenado @nombre_2, @apellido_2, @idInsertada2 OUT
							EXECUTE AnadirQuizaCandidatoSenado @nombre_3, @apellido_3, @idInsertada3 OUT

							--Solo se controla que siempre que haya voto al senado, existan al menos 2 candidatos elegidos por el usuario
							--Esta es la cantidad mínima (Sólo se da en ciudades autónomas). En el resto de CCAA se escogen 3 representantes.
							--Es decir, no se impide votar 2 candidatos a quien tiene que votar 3 y viceversa a nivel de base de datos.
			
								IF(@idInsertada1 <> 0 AND @idInsertada2 <> 0)
									BEGIN
										BEGIN TRANSACTION

											INSERT INTO Votos_senado(id_senador_1, id_senador_2, id_senador_3)
											VALUES(@idInsertada1,
												   @idInsertada2,
												   @idInsertada3)

											SET @id_votos_senado = scope_identity()

											INSERT INTO Votos(id_eleccion, id_votos_senado)
											VALUES (@id_elecciones, @id_votos_senado)

										COMMIT
									END;


						END;
			END;

GO


--Creación de login y usuarios
--
--Existen dos logins distintos: Uno para los electores y otro para los técnicos y administradores (Autenticación).
--Por otra parte se distinguen dos usuarios, Elector y Administrador, con niveles de privilegios diferentes, en función
--de su rol asignado (Autorización): ElectorRol, AdminRol.

--Usuario elector: Sólo podrá insertar datos en la tabla Votos, a la hora de votar.
--
--Usuario administrador: Es capaz de consultar, insertar, borrar y actualizar información de todas
--las tablas salvo en las de Voto y Candidatos_senador, pues ambas significan la decisión de voto del usuario
--y por ello debe permanecer inalterable.

USE master
CREATE LOGIN ElectorLogin 
	WITH PASSWORD = 'fW%qg8&g^PV2VnA43'

CREATE LOGIN AdminLogin
	WITH PASSWORD = 'G1ZqqpZKLCM#z4y$5NLX'

USE Votos

CREATE USER Administrador FROM LOGIN AdminLogin
CREATE USER Elector FROM LOGIN ElectorLogin

CREATE ROLE ElectorRol

--Se le revocan los permisos asignados por defecto al rol.
REVOKE SELECT, INSERT, UPDATE, DELETE, REFERENCES, ALTER ON Votos TO ElectorRol
REVOKE SELECT, INSERT, UPDATE, DELETE, REFERENCES, ALTER ON Integrantes TO ElectorRol
REVOKE SELECT, INSERT, UPDATE, DELETE, REFERENCES, ALTER ON Votos_partido TO ElectorRol
REVOKE SELECT, INSERT, UPDATE, DELETE, REFERENCES, ALTER ON Candidatos_senado TO ElectorRol
REVOKE SELECT, INSERT, UPDATE, DELETE, REFERENCES, ALTER ON Votos_senado TO ElectorRol
REVOKE SELECT, INSERT, UPDATE, DELETE, REFERENCES, ALTER ON Elecciones TO ElectorRol
REVOKE SELECT, INSERT, UPDATE, DELETE, REFERENCES, ALTER ON tipos_eleccion TO ElectorRol

--Se asignan los permisos adecuados al rol
GRANT EXECUTE ON Votar TO ElectorRol
GRANT SELECT ON Integrantes TO ElectorRol
GRANT SELECT ON Votos_partido TO ElectorRol
GRANT SELECT ON Integrantes TO ElectorRol
GRANT SELECT ON tipos_eleccion TO ElectorRol


CREATE ROLE AdminRol

--Se le revocan los permisos asignados por defecto al rol.
REVOKE SELECT, INSERT, UPDATE, DELETE, REFERENCES, ALTER ON Votos TO ElectorRol
REVOKE SELECT, INSERT, UPDATE, DELETE, REFERENCES, ALTER ON Integrantes TO ElectorRol
REVOKE SELECT, INSERT, UPDATE, DELETE, REFERENCES, ALTER ON Votos_partido TO ElectorRol
REVOKE SELECT, INSERT, UPDATE, DELETE, REFERENCES, ALTER ON Candidatos_senado TO ElectorRol
REVOKE SELECT, INSERT, UPDATE, DELETE, REFERENCES, ALTER ON Votos_senado TO ElectorRol
REVOKE SELECT, INSERT, UPDATE, DELETE, REFERENCES, ALTER ON Elecciones TO ElectorRol
REVOKE SELECT, INSERT, UPDATE, DELETE, REFERENCES, ALTER ON tipos_eleccion TO ElectorRol

--Se asignan los permisos adecuados al rol
GRANT SELECT, INSERT, UPDATE, DELETE ON Votos_partido TO Administrador
GRANT SELECT, INSERT, UPDATE, DELETE ON Integrantes TO Administrador
GRANT SELECT, INSERT, UPDATE, DELETE ON	Elecciones TO Administrador
GRANT SELECT, INSERT, UPDATE, DELETE ON tipos_eleccion TO Administrador

--Asignamos a los usuarios los permisos a través de los roles creados
EXECUTE sp_addrolemember 'AdminRol', 'Administrador';
EXECUTE sp_addrolemember 'ElectorRol', 'Elector'


GO

GO

CREATE OR ALTER PROCEDURE Poblar
AS

		--80 candidatos al senado
		insert into Candidatos_senado (nombre, apellidos) values ('Océanne', 'Consalve');
		insert into Candidatos_senado (nombre, apellidos) values ('Nélie', 'Karon');
		insert into Candidatos_senado (nombre, apellidos) values ('Bérénice', 'Trescha');
		insert into Candidatos_senado (nombre, apellidos) values ('Hélène', 'Crystie');
		insert into Candidatos_senado (nombre, apellidos) values ('Ráo', 'Celeste');
		insert into Candidatos_senado (nombre, apellidos) values ('Anaëlle', 'Randene');
		insert into Candidatos_senado (nombre, apellidos) values ('Judicaël', 'Eduard');
		insert into Candidatos_senado (nombre, apellidos) values ('Léone', 'Vanessa');
		insert into Candidatos_senado (nombre, apellidos) values ('Océane', 'Brande');
		insert into Candidatos_senado (nombre, apellidos) values ('Gisèle', 'Grantham');
		insert into Candidatos_senado (nombre, apellidos) values ('Bénédicte', 'Leyla');
		insert into Candidatos_senado (nombre, apellidos) values ('Anaïs', 'Anitra');
		insert into Candidatos_senado (nombre, apellidos) values ('Clémentine', 'Blinnie');
		insert into Candidatos_senado (nombre, apellidos) values ('Åsa', 'Selestina');
		insert into Candidatos_senado (nombre, apellidos) values ('Rébecca', 'Beckie');
		insert into Candidatos_senado (nombre, apellidos) values ('Véronique', 'Mariam');
		insert into Candidatos_senado (nombre, apellidos) values ('Bérénice', 'Sonnie');
		insert into Candidatos_senado (nombre, apellidos) values ('Océane', 'Shane');
		insert into Candidatos_senado (nombre, apellidos) values ('Maëlyss', 'Eustace');
		insert into Candidatos_senado (nombre, apellidos) values ('Crééz', 'Ricard');
		insert into Candidatos_senado (nombre, apellidos) values ('Dafnée', 'Tanner');
		insert into Candidatos_senado (nombre, apellidos) values ('Adélaïde', 'Marcia');
		insert into Candidatos_senado (nombre, apellidos) values ('Gaëlle', 'Leandra');
		insert into Candidatos_senado (nombre, apellidos) values ('Mélissandre', 'Fredek');
		insert into Candidatos_senado (nombre, apellidos) values ('Maïwenn', 'Jacquenette');
		insert into Candidatos_senado (nombre, apellidos) values ('Maïwenn', 'Zaccaria');
		insert into Candidatos_senado (nombre, apellidos) values ('Valérie', 'Morna');
		insert into Candidatos_senado (nombre, apellidos) values ('Mélinda', 'Chloette');
		insert into Candidatos_senado (nombre, apellidos) values ('Yénora', 'Dalia');
		insert into Candidatos_senado (nombre, apellidos) values ('Laurène', 'Naoma');
		insert into Candidatos_senado (nombre, apellidos) values ('Thérèse', 'Archy');
		insert into Candidatos_senado (nombre, apellidos) values ('Cécilia', 'Verine');
		insert into Candidatos_senado (nombre, apellidos) values ('Marie-osey', 'Ravi');
		insert into Candidatos_senado (nombre, apellidos) values ('Crééz', 'Tobi');
		insert into Candidatos_senado (nombre, apellidos) values ('Océanne', 'Kaleena');
		insert into Candidatos_senado (nombre, apellidos) values ('Mélodie', 'Dacie');
		insert into Candidatos_senado (nombre, apellidos) values ('Léonore', 'Barnabe');
		insert into Candidatos_senado (nombre, apellidos) values ('Léonie', 'Eward');
		insert into Candidatos_senado (nombre, apellidos) values ('Pål', 'Ilka');
		insert into Candidatos_senado (nombre, apellidos) values ('Faîtes', 'Bordy');
		insert into Candidatos_senado (nombre, apellidos) values ('Séréna', 'Manda');
		insert into Candidatos_senado (nombre, apellidos) values ('Maëlyss', 'Danella');
		insert into Candidatos_senado (nombre, apellidos) values ('Clélia', 'Nicol');
		insert into Candidatos_senado (nombre, apellidos) values ('Joséphine', 'Marilee');
		insert into Candidatos_senado (nombre, apellidos) values ('Maïlys', 'Auria');
		insert into Candidatos_senado (nombre, apellidos) values ('Léane', 'Hoyt');
		insert into Candidatos_senado (nombre, apellidos) values ('Cunégonde', 'Pernell');
		insert into Candidatos_senado (nombre, apellidos) values ('Sòng', 'Jayme');
		insert into Candidatos_senado (nombre, apellidos) values ('Erwéi', 'Rutledge');
		insert into Candidatos_senado (nombre, apellidos) values ('André', 'Lanette');
		insert into Candidatos_senado (nombre, apellidos) values ('Dù', 'Reinaldo');
		insert into Candidatos_senado (nombre, apellidos) values ('Uò', 'Sibylla');
		insert into Candidatos_senado (nombre, apellidos) values ('Mélissandre', 'Tripp');
		insert into Candidatos_senado (nombre, apellidos) values ('Kallisté', 'Ferd');
		insert into Candidatos_senado (nombre, apellidos) values ('Dafnée', 'Husein');
		insert into Candidatos_senado (nombre, apellidos) values ('Inès', 'Clerkclaude');
		insert into Candidatos_senado (nombre, apellidos) values ('Mélys', 'Ches');
		insert into Candidatos_senado (nombre, apellidos) values ('Loïc', 'Teriann');
		insert into Candidatos_senado (nombre, apellidos) values ('Esbjörn', 'Xylina');
		insert into Candidatos_senado (nombre, apellidos) values ('Valérie', 'Geno');
		insert into Candidatos_senado (nombre, apellidos) values ('Ruò', 'Reeba');
		insert into Candidatos_senado (nombre, apellidos) values ('Gwenaëlle', 'Miles');
		insert into Candidatos_senado (nombre, apellidos) values ('Céline', 'Sorcha');
		insert into Candidatos_senado (nombre, apellidos) values ('Pélagie', 'Gerrie');
		insert into Candidatos_senado (nombre, apellidos) values ('Maëlle', 'Desmund');
		insert into Candidatos_senado (nombre, apellidos) values ('Cinéma', 'Raffarty');
		insert into Candidatos_senado (nombre, apellidos) values ('Clémence', 'Gretchen');
		insert into Candidatos_senado (nombre, apellidos) values ('Josée', 'Elbert');
		insert into Candidatos_senado (nombre, apellidos) values ('Méryl', 'Shermy');
		insert into Candidatos_senado (nombre, apellidos) values ('Frédérique', 'Luis');
		insert into Candidatos_senado (nombre, apellidos) values ('Göran', 'Cindy');
		insert into Candidatos_senado (nombre, apellidos) values ('Kuí', 'Bunni');
		insert into Candidatos_senado (nombre, apellidos) values ('Örjan', 'Serge');

		
		--5 partidos
		INSERT INTO Votos_partido(nombre) VALUES
			('Podemos'),
			('Izquierda Unida'),
			('Vox'),
			('Partido Popular'),
			('PSOE')

		
							

		--99 integrantes de partido

		insert into Integrantes (nombre, apellidos, cargo, id_partido) values ('Aí', 'Stoffers', 'Food Chemist', 5);
		insert into Integrantes (nombre, apellidos, cargo, id_partido) values ('Mélys', 'Denisyuk', 'Professor', 5);
		insert into Integrantes (nombre, apellidos, cargo, id_partido) values ('Tán', 'Flint', 'Financial Analyst', 5);
		insert into Integrantes (nombre, apellidos, cargo, id_partido) values ('Adélaïde', 'Bradman', 'Technical Writer', 2);
		insert into Integrantes (nombre, apellidos, cargo, id_partido) values ('Mårten', 'Warmisham', 'Structural Engineer', 1);
		insert into Integrantes (nombre, apellidos, cargo, id_partido) values ('Pélagie', 'Winston', 'Cost Accountant', 5);
		insert into Integrantes (nombre, apellidos, cargo, id_partido) values ('Eléa', 'Sevier', 'Product Engineer', 1);
		insert into Integrantes (nombre, apellidos, cargo, id_partido) values ('Kù', 'Bibb', 'Product Engineer', 1);
		insert into Integrantes (nombre, apellidos, cargo, id_partido) values ('Audréanne', 'Stoffler', 'Chief Design Engineer', 2);
		insert into Integrantes (nombre, apellidos, cargo, id_partido) values ('Alizée', 'Pimblett', 'Administrative Officer', 3);
		insert into Integrantes (nombre, apellidos, cargo, id_partido) values ('Håkan', 'McGaughay', 'Sales Representative', 3);
		insert into Integrantes (nombre, apellidos, cargo, id_partido) values ('Maïlis', 'Cockayne', 'Legal Assistant', 2);
		insert into Integrantes (nombre, apellidos, cargo, id_partido) values ('Méryl', 'Yesinin', 'Business Systems Development Analyst', 5);
		insert into Integrantes (nombre, apellidos, cargo, id_partido) values ('Laurélie', 'Scallan', 'Geologist IV', 2);
		insert into Integrantes (nombre, apellidos, cargo, id_partido) values ('Gösta', 'Kastel', 'Senior Editor', 1);
		insert into Integrantes (nombre, apellidos, cargo, id_partido) values ('Kuí', 'Rodolico', 'Senior Financial Analyst', 5);
		insert into Integrantes (nombre, apellidos, cargo, id_partido) values ('Cinéma', 'Philott', 'Structural Analysis Engineer', 2);
		insert into Integrantes (nombre, apellidos, cargo, id_partido) values ('Adélaïde', 'Abreheart', 'Occupational Therapist', 2);
		insert into Integrantes (nombre, apellidos, cargo, id_partido) values ('Miléna', 'Addeycott', 'Marketing Manager', 2);
		insert into Integrantes (nombre, apellidos, cargo, id_partido) values ('Gérald', 'Mearing', 'Accountant I', 5);
		insert into Integrantes (nombre, apellidos, cargo, id_partido) values ('Salomé', 'Darycott', 'Social Worker', 2);
		insert into Integrantes (nombre, apellidos, cargo, id_partido) values ('Méryl', 'Hinz', 'Staff Accountant II', 1);
		insert into Integrantes (nombre, apellidos, cargo, id_partido) values ('Daphnée', 'Gilardone', 'Research Nurse', 2);
		insert into Integrantes (nombre, apellidos, cargo, id_partido) values ('André', 'Roser', 'Editor', 2);
		insert into Integrantes (nombre, apellidos, cargo, id_partido) values ('Nélie', 'Ferfulle', 'Quality Engineer', 2);
		insert into Integrantes (nombre, apellidos, cargo, id_partido) values ('Loïs', 'Breawood', 'Associate Professor', 1);
		insert into Integrantes (nombre, apellidos, cargo, id_partido) values ('Hélène', 'Clyne', 'Clinical Specialist', 1);
		insert into Integrantes (nombre, apellidos, cargo, id_partido) values ('Annotée', 'Cherrington', 'VP Product Management', 4);
		insert into Integrantes (nombre, apellidos, cargo, id_partido) values ('Marie', 'Drysdall', 'Design Engineer', 3);
		insert into Integrantes (nombre, apellidos, cargo, id_partido) values ('Magdalène', 'Poutress', 'Operator', 2);
		insert into Integrantes (nombre, apellidos, cargo, id_partido) values ('Gaïa', 'Franzetti', 'Legal Assistant', 3);
		insert into Integrantes (nombre, apellidos, cargo, id_partido) values ('Liè', 'OLeary', 'Paralegal', 5);
		insert into Integrantes (nombre, apellidos, cargo, id_partido) values ('Maëlann', 'Stampfer', 'Biostatistician II', 4);
		insert into Integrantes (nombre, apellidos, cargo, id_partido) values ('André', 'Duxbury', 'Help Desk Technician', 4);
		insert into Integrantes (nombre, apellidos, cargo, id_partido) values ('Börje', 'Wilsone', 'Help Desk Operator', 5);
		insert into Integrantes (nombre, apellidos, cargo, id_partido) values ('Gwenaëlle', 'Botten', 'Business Systems Development Analyst', 3);
		insert into Integrantes (nombre, apellidos, cargo, id_partido) values ('Béatrice', 'de avery', 'Product Engineer', 2);
		insert into Integrantes (nombre, apellidos, cargo, id_partido) values ('Pélagie', 'Meekins', 'Internal Auditor', 2);
		insert into Integrantes (nombre, apellidos, cargo, id_partido) values ('Simplifiés', 'Sarge', 'Nuclear Power Engineer', 1);
		insert into Integrantes (nombre, apellidos, cargo, id_partido) values ('Angélique', 'Oda', 'VP Quality Control', 3);
		insert into Integrantes (nombre, apellidos, cargo, id_partido) values ('Annotés', 'Birchwood', 'Quality Engineer', 2);
		insert into Integrantes (nombre, apellidos, cargo, id_partido) values ('Lucrèce', 'Dionisio', 'Community Outreach Specialist', 3);
		insert into Integrantes (nombre, apellidos, cargo, id_partido) values ('Naëlle', 'Sturmey', 'Structural Analysis Engineer', 4);
		insert into Integrantes (nombre, apellidos, cargo, id_partido) values ('Maïté', 'Morrowe', 'Assistant Media Planner', 1);
		insert into Integrantes (nombre, apellidos, cargo, id_partido) values ('Méthode', 'Ponte', 'Account Executive', 2);
		insert into Integrantes (nombre, apellidos, cargo, id_partido) values ('Lóng', 'Rosenberg', 'Biostatistician IV', 5);
		insert into Integrantes (nombre, apellidos, cargo, id_partido) values ('Alizée', 'Pantling', 'Help Desk Technician', 2);
		insert into Integrantes (nombre, apellidos, cargo, id_partido) values ('Lèi', 'Prendergrass', 'Senior Editor', 5);
		insert into Integrantes (nombre, apellidos, cargo, id_partido) values ('Aí', 'Archbell', 'Editor', 1);
		insert into Integrantes (nombre, apellidos, cargo, id_partido) values ('Marie-Antoinelle', 'Wasmer', 'Human Resources Assistant III', 3);
		insert into Integrantes (nombre, apellidos, cargo, id_partido) values ('Séréna', 'Barker', 'Electrical Engineer', 4);
		insert into Integrantes (nombre, apellidos, cargo, id_partido) values ('Camélia', 'Tayspell', 'Project Manager', 2);
		insert into Integrantes (nombre, apellidos, cargo, id_partido) values ('Amélie', 'Shawcross', 'Nurse', 1);
		insert into Integrantes (nombre, apellidos, cargo, id_partido) values ('Célestine', 'Pettman', 'Research Associate', 4);
		insert into Integrantes (nombre, apellidos, cargo, id_partido) values ('Mahélie', 'Glennon', 'Executive Secretary', 1);
		insert into Integrantes (nombre, apellidos, cargo, id_partido) values ('Aí', 'Lowde', 'Product Engineer', 2);
		insert into Integrantes (nombre, apellidos, cargo, id_partido) values ('Nadège', 'Onraet', 'Administrative Assistant IV', 2);
		insert into Integrantes (nombre, apellidos, cargo, id_partido) values ('Clémentine', 'Manon', 'Budget/Accounting Analyst II', 1);
		insert into Integrantes (nombre, apellidos, cargo, id_partido) values ('Renée', 'Fominov', 'Software Test Engineer II', 4);
		insert into Integrantes (nombre, apellidos, cargo, id_partido) values ('Marie-oSymmetric_Key', 'Larman', 'Legal Assistant', 4);
		insert into Integrantes (nombre, apellidos, cargo, id_partido) values ('Anaïs', 'Ianetti', 'Staff Scientist', 1);
		insert into Integrantes (nombre, apellidos, cargo, id_partido) values ('Bérénice', 'Schoroder', 'Web Developer I', 2);
		insert into Integrantes (nombre, apellidos, cargo, id_partido) values ('Magdalène', 'Blincoe', 'Research Associate', 1);
		insert into Integrantes (nombre, apellidos, cargo, id_partido) values ('Lyséa', 'OFarrell', 'Professor', 5);
		insert into Integrantes (nombre, apellidos, cargo, id_partido) values ('Kévina', 'Maxstead', 'Software Test Engineer III', 1);
		insert into Integrantes (nombre, apellidos, cargo, id_partido) values ('Göran', 'Ondrasek', 'Data Coordiator', 2);
		insert into Integrantes (nombre, apellidos, cargo, id_partido) values ('Publicité', 'Mawne', 'Internal Auditor', 1);
		insert into Integrantes (nombre, apellidos, cargo, id_partido) values ('Joséphine', 'Sired', 'Social Worker', 3);
		insert into Integrantes (nombre, apellidos, cargo, id_partido) values ('Régine', 'Beardwell', 'Budget/Accounting Analyst III', 1);
		insert into Integrantes (nombre, apellidos, cargo, id_partido) values ('Célia', 'Vasyanin', 'Structural Analysis Engineer', 5);
		insert into Integrantes (nombre, apellidos, cargo, id_partido) values ('Mélina', 'McAusland', 'Geologist I', 5);
		insert into Integrantes (nombre, apellidos, cargo, id_partido) values ('Valérie', 'Pawelke', 'Assistant Professor', 1);
		insert into Integrantes (nombre, apellidos, cargo, id_partido) values ('Mélina', 'Bannerman', 'Paralegal', 4);
		insert into Integrantes (nombre, apellidos, cargo, id_partido) values ('Görel', 'MacGilpatrick', 'Occupational Therapist', 1);
		insert into Integrantes (nombre, apellidos, cargo, id_partido) values ('Liè', 'Skellion', 'Programmer II', 4);
		insert into Integrantes (nombre, apellidos, cargo, id_partido) values ('Léane', 'Bennetto', 'Chemical Engineer', 3);
		insert into Integrantes (nombre, apellidos, cargo, id_partido) values ('Léonore', 'Mold', 'Occupational Therapist', 4);
		insert into Integrantes (nombre, apellidos, cargo, id_partido) values ('Réservés', 'Bellworthy', 'Account Representative IV', 5);
		insert into Integrantes (nombre, apellidos, cargo, id_partido) values ('Lyséa', 'Pennell', 'Software Engineer I', 1);
		insert into Integrantes (nombre, apellidos, cargo, id_partido) values ('Laurélie', 'MacLaren', 'Recruiter', 5);
		insert into Integrantes (nombre, apellidos, cargo, id_partido) values ('Gérald', 'Van rsdall', 'Health Coach III', 2);
		insert into Integrantes (nombre, apellidos, cargo, id_partido) values ('Eléonore', 'Climpson', 'Chief Design Engineer', 4);
		insert into Integrantes (nombre, apellidos, cargo, id_partido) values ('Gösta', 'Stanbridge', 'Graphic Designer', 2);
		insert into Integrantes (nombre, apellidos, cargo, id_partido) values ('Publicité', 'Loutheane', 'VP Sales', 3);
		insert into Integrantes (nombre, apellidos, cargo, id_partido) values ('Mårten', 'Prandi', 'Editor', 1);
		insert into Integrantes (nombre, apellidos, cargo, id_partido) values ('Yú', 'Berringer', 'Software Engineer III', 5);
		insert into Integrantes (nombre, apellidos, cargo, id_partido) values ('Gisèle', 'Durnall', 'Safety Technician IV', 2);
		insert into Integrantes (nombre, apellidos, cargo, id_partido) values ('Åke', 'Acland', 'VP Quality Control', 5);
		insert into Integrantes (nombre, apellidos, cargo, id_partido) values ('Athéna', 'Hamal', 'Assistant Media Planner', 5);
		insert into Integrantes (nombre, apellidos, cargo, id_partido) values ('Yú', 'Hardeman', 'Financial Analyst', 4);
		insert into Integrantes (nombre, apellidos, cargo, id_partido) values ('Françoise', 'Foulstone', 'Design Engineer', 1);
		insert into Integrantes (nombre, apellidos, cargo, id_partido) values ('Anaëlle', 'Berzin', 'VP Quality Control', 2);
		insert into Integrantes (nombre, apellidos, cargo, id_partido) values ('Estève', 'Bramall', 'Civil Engineer', 3);
		insert into Integrantes (nombre, apellidos, cargo, id_partido) values ('Yè', 'Hulk', 'Legal Assistant', 1);
		insert into Integrantes (nombre, apellidos, cargo, id_partido) values ('Maëlann', 'Wincott', 'GIS Technical Architect', 2);
		insert into Integrantes (nombre, apellidos, cargo, id_partido) values ('Renée', 'Scutt', 'VP Product Management', 2);
		insert into Integrantes (nombre, apellidos, cargo, id_partido) values ('Océane', 'Frood', 'Statistician II', 1);
		insert into Integrantes (nombre, apellidos, cargo, id_partido) values ('Séverine', 'Clackson', 'Research Assistant II', 4);
		insert into Integrantes (nombre, apellidos, cargo, id_partido) values ('Mén', 'Hawse', 'Data Coordiator', 1);
		insert into Integrantes (nombre, apellidos, cargo, id_partido) values ('Andrée', 'Coutts', 'Office Assistant II', 4);

		

		--Elecciones nacionales: el 20 de junio a las 00:00 y acaban el 25 de junio a las 00:00
		--Elecciones al senado: el 20 de junio a las 00:00 y acaban el 25 de junio a las 00:00

		--INSERT INTO Elecciones(id_tipo_eleccion, instante_comienzo, instante_final, provincia) VALUES (1, CONVERT(date, '20/06/2021'), CONVERT(date, '25/06/2021'), 'Sevilla');
		--INSERT INTO Elecciones(id_tipo_eleccion, instante_comienzo, instante_final, provincia) VALUES (2, CONVERT(date, '20/06/2021'), CONVERT(date, '25/06/2021'), 'Sevilla');



		--Votos a las elecciones nacionales: 1000 votos

        insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 3, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '21/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 5, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '22/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '20/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 4, NULL, CONVERT(date, '23/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 2, NULL, CONVERT(date, '24/06/2021'));
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (1, 1, NULL, CONVERT(date, '23/06/2021'));

		--Votos a las elecciones al senado
		--Se añaden 1000 votos, cada uno relacionado con el conjunto de candidatos al senado elegido
			
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (41, 39, 8);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '23/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (71, 24, 63);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '24/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (39, 40, 69);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '21/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (49, 44, 58);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '21/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (45, 36, 78);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '21/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (78, 10, 9);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '24/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (60, 39, 8);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '22/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (34, 22, 37);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '22/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (1, 68, 65);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '22/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (37, 54, 9);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '23/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (26, 40, 45);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '24/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (30, 23, 60);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '21/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (8, 71, 46);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '20/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (71, 41, 74);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '23/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (7, 14, 19);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '24/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (38, 10, 30);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '22/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (40, 39, 70);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '24/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (66, 28, 41);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '24/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (66, 46, 12);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '20/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (33, 5, 68);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '20/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (19, 67, 16);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '21/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (11, 23, 22);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '22/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (19, 24, 60);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '22/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (46, 10, 10);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '23/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (50, 73, 43);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '21/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (31, 55, 26);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '22/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (1, 49, 45);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '24/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (56, 54, 11);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '21/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (12, 6, 11);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '22/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (54, 73, 23);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '23/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (22, 4, 80);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '20/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (34, 79, 72);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '21/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (65, 21, 10);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '21/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (61, 54, 58);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '21/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (60, 9, 14);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '21/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (36, 12, 33);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '24/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (42, 6, 75);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '21/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (25, 77, 64);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '21/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (74, 34, 68);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '21/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (53, 21, 2);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '23/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (49, 4, 15);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '21/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (27, 68, 29);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '20/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (67, 8, 63);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '21/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (64, 69, 26);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '24/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (25, 30, 39);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '23/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (65, 23, 70);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '21/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (34, 69, 20);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '22/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (21, 79, 52);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '24/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (63, 2, 77);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '23/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (42, 44, 43);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '21/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (16, 60, 73);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '24/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (66, 33, 72);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '24/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (73, 40, 36);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '21/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (7, 48, 36);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '24/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (38, 39, 66);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '20/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (44, 15, 51);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '23/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (31, 10, 34);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '20/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (16, 32, 36);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '20/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (15, 8, 54);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '21/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (45, 40, 14);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '21/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (16, 35, 27);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '23/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (55, 22, 60);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '21/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (67, 73, 40);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '20/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (39, 58, 50);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '22/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (66, 22, 11);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '20/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (61, 53, 57);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '23/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (20, 73, 59);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '22/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (48, 15, 74);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '20/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (42, 35, 25);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '20/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (36, 60, 70);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '22/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (19, 50, 36);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '21/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (45, 6, 11);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '22/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (25, 64, 4);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '23/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (69, 44, 64);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '22/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (63, 12, 62);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '21/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (3, 17, 28);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '20/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (39, 30, 48);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '24/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (60, 77, 4);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '22/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (28, 47, 47);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '24/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (45, 37, 12);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '22/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (10, 34, 24);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '23/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (28, 31, 59);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '21/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (58, 77, 38);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '24/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (1, 5, 63);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '24/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (22, 22, 46);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '24/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (65, 32, 9);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '20/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (53, 73, 32);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '22/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (70, 52, 55);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '22/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (56, 73, 50);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '23/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (57, 78, 75);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '20/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (35, 26, 14);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '23/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (22, 9, 80);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '20/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (17, 17, 8);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '20/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (70, 62, 67);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '22/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (55, 57, 47);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '22/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (7, 49, 36);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '24/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (46, 70, 61);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '20/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (43, 2, 77);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '24/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (21, 7, 2);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '21/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (40, 47, 59);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '21/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (32, 70, 65);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '21/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (68, 34, 9);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '22/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (73, 58, 30);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '21/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (28, 63, 29);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '24/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (56, 13, 69);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '21/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (1, 67, 36);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '21/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (29, 14, 3);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '21/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (49, 65, 72);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '20/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (63, 36, 9);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '21/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (46, 47, 2);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '20/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (43, 21, 79);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '21/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (44, 51, 24);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '20/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (11, 45, 6);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '24/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (60, 25, 50);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '23/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (35, 3, 9);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '23/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (24, 47, 10);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '20/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (80, 13, 39);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '23/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (27, 19, 20);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '23/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (70, 79, 54);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '23/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (59, 26, 37);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '24/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (60, 35, 73);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '23/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (3, 53, 7);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '24/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (2, 25, 61);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '23/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (27, 54, 38);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '20/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (69, 45, 69);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '20/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (25, 6, 25);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '22/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (41, 49, 48);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '23/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (9, 14, 54);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '20/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (73, 56, 64);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '21/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (29, 9, 79);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '22/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (19, 79, 31);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '21/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (71, 76, 37);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '23/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (19, 15, 4);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '20/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (56, 56, 32);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '22/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (72, 33, 50);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '21/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (2, 44, 31);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '24/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (72, 36, 65);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '21/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (39, 65, 67);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '24/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (25, 71, 14);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '23/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (66, 34, 7);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '22/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (4, 29, 39);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '21/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (70, 30, 71);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '23/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (76, 38, 73);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '21/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (78, 37, 25);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '24/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (20, 74, 60);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '23/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (44, 26, 73);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '21/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (44, 26, 11);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '22/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (59, 14, 59);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '21/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (80, 36, 11);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '24/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (18, 19, 56);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '23/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (22, 66, 18);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '23/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (63, 28, 73);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '22/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (12, 52, 42);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '23/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (57, 71, 11);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '21/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (43, 44, 78);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '23/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (77, 51, 79);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '24/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (67, 9, 23);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '20/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (55, 39, 77);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '22/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (24, 10, 32);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '21/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (39, 38, 65);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '20/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (73, 44, 44);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '21/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (2, 34, 9);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '24/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (52, 8, 74);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '22/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (36, 5, 62);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '20/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (6, 63, 76);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '22/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (60, 36, 13);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '22/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (64, 25, 35);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '22/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (28, 27, 6);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '20/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (40, 19, 41);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '23/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (1, 25, 17);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '21/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (16, 72, 42);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '24/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (41, 71, 78);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '20/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (37, 6, 20);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '21/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (66, 52, 45);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '24/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (43, 61, 24);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '21/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (48, 47, 5);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '24/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (5, 58, 70);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '21/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (27, 15, 6);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '22/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (73, 37, 7);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '20/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (79, 53, 23);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '21/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (6, 54, 47);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '24/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (52, 35, 21);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '21/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (71, 20, 77);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '22/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (1, 7, 17);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '20/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (16, 44, 69);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '22/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (74, 48, 70);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '20/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (45, 50, 22);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '23/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (42, 6, 15);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '22/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (19, 62, 67);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '21/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (7, 1, 49);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '23/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (32, 23, 62);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '24/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (39, 41, 79);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '24/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (25, 56, 30);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '24/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (18, 64, 29);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '23/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (17, 58, 64);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '24/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (13, 44, 34);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '20/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (58, 79, 8);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '20/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (77, 57, 41);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '22/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (8, 5, 55);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '23/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (65, 16, 22);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '22/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (17, 32, 78);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '22/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (36, 64, 3);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '20/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (24, 19, 69);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '24/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (80, 6, 39);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '20/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (24, 59, 29);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '23/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (41, 10, 51);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '20/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (28, 36, 60);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '24/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (61, 25, 77);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '23/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (18, 13, 23);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '23/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (45, 64, 33);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '23/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (59, 80, 75);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '23/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (28, 49, 66);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '22/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (61, 27, 80);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '23/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (13, 14, 32);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '23/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (10, 29, 36);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '20/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (36, 52, 12);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '20/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (7, 46, 34);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '23/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (33, 70, 75);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '24/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (23, 47, 73);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '23/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (79, 48, 44);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '21/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (69, 49, 24);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '21/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (22, 1, 8);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '20/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (60, 60, 43);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '21/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (75, 30, 2);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '23/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (55, 78, 6);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '22/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (73, 15, 54);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '23/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (51, 36, 4);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '21/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (34, 14, 3);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '21/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (47, 51, 64);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '20/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (15, 2, 69);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '20/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (16, 72, 67);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '23/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (8, 30, 65);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '20/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (61, 71, 32);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '21/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (12, 70, 47);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '24/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (36, 64, 75);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '21/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (55, 36, 2);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '23/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (17, 79, 25);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '24/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (44, 52, 35);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '21/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (76, 13, 2);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '21/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (24, 47, 11);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '22/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (36, 32, 23);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '24/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (33, 45, 31);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '24/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (45, 5, 49);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '21/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (27, 65, 18);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '23/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (49, 44, 2);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '21/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (6, 26, 13);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '20/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (5, 15, 62);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '22/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (11, 35, 24);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '21/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (26, 50, 11);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '23/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (66, 66, 4);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '20/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (71, 62, 68);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '23/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (45, 69, 26);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '22/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (63, 32, 56);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '21/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (38, 79, 28);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '20/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (5, 31, 41);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '22/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (57, 70, 49);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '21/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (61, 8, 46);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '23/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (33, 39, 60);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '24/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (77, 19, 79);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '22/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (11, 44, 20);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '23/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (20, 76, 75);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '24/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (25, 28, 22);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '22/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (4, 47, 34);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '22/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (73, 56, 79);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '24/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (45, 50, 14);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '22/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (78, 23, 70);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '24/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (29, 61, 55);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '24/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (69, 52, 58);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '21/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (2, 59, 70);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '23/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (30, 24, 2);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '22/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (12, 51, 50);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '22/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (47, 67, 67);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '24/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (15, 49, 59);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '21/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (70, 9, 66);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '21/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (39, 12, 63);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '24/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (37, 33, 37);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '22/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (63, 22, 10);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '20/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (53, 59, 3);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '23/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (73, 10, 17);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '22/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (38, 77, 70);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '22/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (74, 7, 10);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '22/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (15, 43, 14);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '21/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (44, 36, 26);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '23/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (26, 51, 73);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '21/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (76, 30, 68);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '22/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (75, 54, 51);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '21/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (36, 5, 20);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '21/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (39, 32, 8);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '24/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (1, 42, 35);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '22/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (20, 29, 21);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '24/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (73, 18, 79);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '22/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (23, 35, 6);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '24/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (51, 80, 20);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '20/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (13, 60, 56);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '20/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (9, 66, 6);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '20/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (9, 54, 30);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '20/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (64, 21, 21);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '23/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (20, 56, 75);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '20/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (22, 64, 30);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '22/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (75, 23, 16);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '20/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (38, 4, 20);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '21/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (65, 75, 14);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '24/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (58, 34, 19);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '21/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (20, 50, 41);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '21/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (51, 56, 35);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '20/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (79, 41, 16);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '21/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (49, 62, 48);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '20/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (68, 22, 27);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '24/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (15, 46, 61);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '24/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (57, 37, 54);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '21/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (35, 79, 35);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '22/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (36, 39, 70);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '24/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (35, 59, 30);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '24/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (29, 68, 27);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '22/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (53, 80, 61);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '21/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (21, 15, 79);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '23/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (2, 67, 46);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '20/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (10, 5, 26);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '20/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (19, 4, 63);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '20/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (78, 31, 12);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '24/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (67, 38, 10);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '21/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (76, 6, 12);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '24/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (47, 38, 8);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '20/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (47, 61, 55);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '24/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (40, 67, 59);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '24/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (35, 20, 68);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '23/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (27, 42, 74);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '24/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (61, 50, 38);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '22/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (69, 43, 73);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '20/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (71, 11, 45);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '23/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (20, 22, 40);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '21/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (44, 19, 18);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '21/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (49, 23, 59);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '23/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (9, 64, 63);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '23/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (42, 70, 31);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '23/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (34, 38, 8);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '20/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (20, 54, 38);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '22/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (29, 54, 16);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '24/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (37, 10, 43);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '22/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (12, 15, 63);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '20/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (70, 51, 39);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '23/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (11, 59, 77);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '20/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (36, 47, 65);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '21/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (52, 80, 41);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '22/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (36, 7, 1);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '23/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (66, 4, 55);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '21/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (42, 10, 41);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '22/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (64, 49, 31);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '20/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (26, 65, 60);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '22/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (4, 12, 71);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '22/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (33, 73, 43);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '20/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (53, 68, 63);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '24/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (46, 22, 7);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '22/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (78, 77, 10);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '24/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (75, 80, 67);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '23/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (20, 53, 42);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '23/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (39, 39, 35);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '21/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (31, 80, 43);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '22/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (25, 7, 40);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '23/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (12, 3, 25);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '21/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (51, 80, 65);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '20/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (18, 6, 77);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '23/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (43, 60, 21);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '24/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (80, 19, 33);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '22/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (37, 25, 52);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '20/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (47, 61, 5);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '22/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (34, 32, 33);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '21/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (5, 61, 42);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '21/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (42, 37, 77);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '20/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (18, 31, 15);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '21/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (51, 46, 51);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '22/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (25, 57, 73);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '20/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (45, 31, 29);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '24/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (54, 58, 76);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '22/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (24, 68, 59);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '20/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (7, 45, 9);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '24/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (44, 13, 10);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '23/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (29, 76, 53);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '23/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (42, 43, 44);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '21/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (19, 56, 19);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '22/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (6, 79, 34);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '24/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (6, 57, 72);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '24/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (20, 15, 63);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '22/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (66, 13, 36);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '23/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (50, 6, 48);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '24/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (5, 38, 19);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '23/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (25, 8, 71);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '24/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (59, 34, 47);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '21/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (16, 1, 68);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '22/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (64, 66, 10);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '20/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (61, 13, 78);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '20/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (33, 25, 35);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '24/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (44, 22, 10);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '23/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (16, 79, 50);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '23/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (59, 23, 70);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '24/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (36, 21, 3);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '21/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (71, 15, 22);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '20/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (49, 33, 5);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '24/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (52, 73, 7);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '23/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (50, 10, 79);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '23/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (64, 4, 51);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '21/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (56, 40, 30);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '22/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (67, 46, 76);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '23/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (21, 50, 21);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '20/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (76, 47, 1);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '20/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (12, 11, 11);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '20/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (69, 34, 5);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '23/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (77, 5, 78);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '22/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (66, 8, 42);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '20/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (38, 57, 48);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '20/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (60, 6, 60);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '23/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (64, 8, 25);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '24/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (48, 51, 63);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '20/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (61, 78, 8);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '21/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (6, 79, 39);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '21/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (26, 18, 5);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '21/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (42, 33, 76);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '20/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (23, 6, 5);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '24/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (17, 3, 47);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '21/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (39, 55, 36);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '24/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (50, 32, 16);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '24/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (50, 53, 28);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '20/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (8, 57, 52);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '23/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (6, 53, 15);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '20/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (9, 79, 70);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '20/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (6, 11, 42);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '20/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (18, 76, 13);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '21/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (13, 61, 64);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '23/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (36, 34, 21);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '20/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (4, 23, 23);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '23/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (27, 6, 50);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '23/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (66, 54, 54);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '21/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (53, 6, 38);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '22/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (68, 8, 34);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '21/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (7, 29, 69);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '22/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (76, 16, 69);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '24/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (75, 1, 33);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '22/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (50, 58, 37);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '21/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (27, 56, 12);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '24/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (47, 74, 62);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '21/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (7, 66, 34);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '24/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (30, 16, 6);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '20/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (51, 34, 80);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '20/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (31, 52, 52);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '23/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (13, 24, 63);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '20/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (21, 74, 36);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '20/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (66, 75, 2);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '24/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (50, 16, 66);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '20/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (25, 56, 63);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '20/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (25, 14, 30);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '20/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (46, 1, 42);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '20/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (23, 10, 23);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '22/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (50, 56, 72);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '21/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (39, 77, 73);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '24/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (75, 32, 60);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '21/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (46, 7, 27);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '21/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (54, 44, 61);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '20/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (27, 24, 10);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '20/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (40, 60, 8);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '21/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (54, 63, 70);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '20/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (44, 6, 22);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '23/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (43, 5, 8);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '20/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (42, 71, 6);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '20/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (65, 43, 47);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '23/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (76, 32, 6);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '21/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (30, 52, 31);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '20/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (57, 1, 72);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '24/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (69, 72, 31);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '20/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (50, 33, 26);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '22/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (34, 4, 37);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '23/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (57, 63, 66);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '24/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (55, 61, 14);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '21/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (22, 17, 67);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '22/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (78, 70, 61);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '22/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (55, 62, 65);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '24/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (51, 53, 59);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '21/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (78, 58, 28);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '24/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (23, 57, 21);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '22/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (10, 22, 28);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '22/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (65, 45, 2);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '21/06/2021'));
		insert into Votos_senado (id_senador_1, id_senador_2, id_senador_3) values (30, 42, 73);
		insert into Votos (id_eleccion, id_partido, id_votos_senado, instante_creacion) values (2, NULL, SCOPE_IDENTITY(), CONVERT(date, '24/06/2021'));l
