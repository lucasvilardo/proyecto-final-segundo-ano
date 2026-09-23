if exists(Select * FROM SysDataBases WHERE name='BDPaquetes')
BEGIN
	DROP DATABASE BDPaquetes
END
go

CREATE DATABASE BDPaquetes
															
go

USE BDPaquetes
go

USE master
go
 
CREATE LOGIN [IIS APPPOOL\DefaultAppPool] FROM WINDOWS   
go
 
 
USE BDPaquetes
go
 
CREATE USER [IIS APPPOOL\DefaultAppPool] FOR LOGIN [IIS APPPOOL\DefaultAppPool] 
go

exec sys.sp_addrolemember 'db_owner', [IIS APPPOOL\DefaultAppPool]
go


create table Empleado(
	Usuario varchar(15) primary key,
	Pass varchar(10) not null check(LEN(Pass) between 5 and 10  
						and Pass like '%[a-zA-Z]%'
						and Pass like '%[0-9]%'
						and Pass like '%[^a-zA-Z0-9]%'),
	NomCompleto varchar(30) not null
)

create table Estado(
	Codigo varchar(4) primary key check(Codigo like '[A-Za-z][A-Za-z][A-Za-z][A-Za-z]'),
	NomEstado varchar(30) not null,
	Pais varchar(30) not null,
	ActivoEstado bit not null default(1)
)

create table Vuelo(
	Codigo varchar(10) primary key check (LEN(Codigo) = 10),
	FyHPar datetime not null check(FyHPar > getdate()),
	FyHLleg datetime not null,
	PrecioIndi int not null check(PrecioIndi > 0),
	ActivoVuelo bit not null default(1),
	CodigoPartida varchar(4) not null foreign key references Estado(Codigo),
	CodigoLlegada varchar(4) not null foreign key references Estado(Codigo),
	check(FyHPar < FyHLleg),
	check(CodigoPartida != CodigoLlegada)
)

create table Hospedaje(
	CodigoInterno varchar(10) not null primary key check(LEN(CodigoInterno) <= 10
							and CodigoInterno not like '%[^A-Za-z]%'),
	Nombre varchar(30) not null,
	Calle varchar(30) not null,
	Localidad varchar(30) not null,
	Tipo varchar(13) not null check(Tipo in ('HotelSTD', 'Posada', 'All inclusive')),
	Precio int not null check(Precio > 0),
	ActivoHospedaje bit not null default(1),
	Codigo varchar(4) not null foreign key references Estado(Codigo)
)

create table Paquete(			    
	Codigo int primary key identity (1,1),
	Titulo varchar(30) not null,
	Descripcion varchar(60) not null,
	CantDias int not null check(CantDias > 0),
	Precio1 int not null check(Precio1 > 0),
	Precio2 int not null check(Precio2 > 0),
	Precio3 int not null check(Precio3 > 0),
	Usuario varchar(15) not null foreign key references Empleado(Usuario),
	CodigoVueloIda varchar(10) not null foreign key references Vuelo(Codigo),
	CodigoVueloVuelta varchar(10) not null foreign key references Vuelo(Codigo),
	CodigoEstado varchar(4) not null foreign key references Estado(Codigo)	
)

create table Alojamiento(
	CodigoInterno varchar(10) not null foreign key references Hospedaje(CodigoInterno),
	Codigo int not null foreign key references Paquete(Codigo),
	primary key (CodigoInterno, Codigo),
	NroNoches int not null check(NroNoches > 0)
)


------------------------ SP -------------------------------------

----------------- EMPLEADO -------------------------

go
create proc Logueo
@usuario varchar(15),
@pass varchar(10)
as
begin
		select * from Empleado where Usuario = @usuario and Pass = @pass
end
go

create proc AltaEmpleado 
@usu varchar(15), 
@pass varchar(10),
@nomCompleto varchar(30)

as
Begin
Declare @Sentencia varchar(200)

	if exists (select * from Empleado where Usuario = @usu)
		begin
			return -1
		end


	
	begin tran
	
		insert Empleado(Usuario, Pass, NomCompleto) values(@usu, @pass, @nomCompleto)

		if (@@ERROR <> 0)
		begin
			rollback tran
			return -2
		end

		set @Sentencia = 'CREATE LOGIN [' +  @usu + '] WITH PASSWORD = ' + QUOTENAME(@pass, '''')
		exec (@Sentencia)
		
		if (@@ERROR <> 0)
		begin
			rollback tran
			return -3
		end
		
		set @Sentencia = 'Create User [' +  @usu + '] From Login [' + @usu + ']'
		exec (@Sentencia)
		
		if (@@ERROR <> 0)
		begin
			rollback tran
			return -4
		end

		set @Sentencia = 'GRANT EXECUTE TO [' + @usu + ']'
        exec (@Sentencia)

        if (@@ERROR <> 0)
        begin
            rollback tran
            return -5
        end

	commit tran

		exec sp_addsrvrolemember @loginame=@usu, @rolename='securityAdmin' 
		
		exec sp_addrolemember @rolename='db_securityadmin', @membername=@usu 

end
go
																
														

create proc ModificarEmpleado
@usu varchar(15),
@pass varchar(10),
@nomCompleto varchar(30)

as
begin

	Declare @Sentencia varchar(200)

	if not exists (select * from Empleado where Usuario = @usu)
		begin
			return -1
		end

	
		begin tran
		update Empleado
		set Pass = @pass, NomCompleto = @nomCompleto
		where Usuario = @usu

		if (@@ERROR <> 0)
			begin
				rollback tran
				return -2
			end

		 set @Sentencia = 'ALTER LOGIN [' + @usu + '] WITH PASSWORD = ' + QUOTENAME(@pass, '''')
         exec (@Sentencia)

                if (@@ERROR <> 0)
                begin
                    rollback tran
                    return -3
                end

		commit tran
		return 1
		
end
go



create proc BuscarEmpleado
@usu varchar(15)
as
begin
	select * from Empleado where Usuario = @usu
end
go

create proc ListadoEmpleados
as
begin
	select * from Empleado
end
go

------------------------ ESTADO --------------------------

create proc AltaEstado
@codigo varchar(4),
@nomEstado varchar(30),
@pais varchar(30)
as
begin
	if exists (select * from Estado where Codigo = @codigo and ActivoEstado = 1)
		begin
			return -1
		end

	if exists(select * from Estado where Codigo = @codigo and ActivoEstado = 0)
		begin	
			update Estado
			set ActivoEstado = 1, NomEstado = @nomEstado, Pais = @pais
			where Codigo = @codigo

			return 1 
		end

	else

		
		insert Estado(Codigo, NomEstado, Pais) values(@codigo, @nomEstado, @pais)

		if (@@ERROR = 0)
			return 1
		else
			return -2
end
go

create proc ModificarEstado
@codigo varchar(4),
@nomEstado varchar(30),
@pais varchar(30)
as
begin
	if not exists (select * from Estado where Codigo = @codigo and ActivoEstado = 1)
		begin
			return -1
		end
	else
		begin
		update Estado
		set NomEstado = @nomEstado, Pais = @pais
		where Codigo = @codigo

		if (@@ERROR = 0)
			return 1
		else
			return -2
	    end
end
go

create proc BuscarEstado
@codigo varchar(4)
as
begin
	select * from Estado where Codigo = @codigo and ActivoEstado = 1	
end
go

create proc BuscarTodosEst
@codigo varchar(4)
as
begin
	select * from Estado where Codigo = @codigo 
end
go

create proc ListadoEstados
as
begin
	select * from Estado where ActivoEstado = 1
end
go

create proc BajaEstado
@codigo varchar(4)
as
begin

	if not exists (select * from Estado where Codigo = @codigo and ActivoEstado = 1)
		begin
			return -1 
		end

	if exists (select * from Paquete where CodigoEstado = @codigo) or exists
			  (select * from Hospedaje where Codigo = @codigo) or exists
			  (select * from Vuelo where CodigoPartida = @codigo or CodigoLlegada = @codigo)
		begin
			update Estado
				set ActivoEstado = 0
				where Codigo = @codigo
				return 1 
		end
	else
		begin

			  delete from Estado where Codigo = @codigo

			if (@@ERROR = 0)
				return 2
			else
				return -2
			end	
end
go

----------------- VUELO --------------------

create proc AltaVuelo
@codigo varchar(10),
@fyHLleg datetime,
@fyHPar datetime,
@precioIndi int,
@codigoLlegada varchar(4),
@codigoPartida varchar(4)
as
begin
	if exists (select * from Vuelo where Codigo = @codigo and ActivoVuelo = 1)
		begin
			return -1
		end

	if not exists (select * from Estado where Codigo = @codigoLlegada and ActivoEstado = 1) 
		or not exists (select * from Estado where Codigo = @codigoPartida and ActivoEstado = 1)
		begin
			return -2
		end

	if exists (select * from Vuelo where Codigo = @codigo and ActivoVuelo = 0)
		begin	
			update Vuelo
			set ActivoVuelo = 1, FyHLleg = @fyHLleg, FyHPar = @fyHPar, 
			PrecioIndi = @precioIndi, CodigoLlegada = @codigoLlegada, 
			CodigoPartida = @codigoPartida
			where Codigo = @codigo

			return 1
			
		end

	else
		insert Vuelo(Codigo, FyHPar, FyHLleg, PrecioIndi, CodigoLlegada, CodigoPartida)
		values (@codigo, @fyHPar, @fyHLleg, @precioIndi, @codigoLlegada, @codigoPartida)

		if (@@ERROR = 0)
			return 1
		else
			return -3

end
go

create proc ModificarVuelo
@codigo varchar(10),
@fyHLleg datetime,
@fyHPar datetime,
@precioIndi int,
@codigoLlegada varchar(4),
@codigoPartida varchar(4)
as
begin
	if not exists (select * from Vuelo where Codigo = @codigo and ActivoVuelo = 1)
		begin
			return -1
		end

	if not exists (select * from Estado where Codigo = @codigoLlegada and ActivoEstado = 1)
		begin
			return -2
		end

	if not exists (select * from Estado where Codigo = @codigoPartida and ActivoEstado = 1)
		begin
			return -3
		end

		else
			update Vuelo
			set FyHLleg = @fyHLleg, FyHPar = @fyHPar, PrecioIndi = @precioIndi, CodigoLlegada = @codigoLlegada, CodigoPartida = @codigoPartida
			where Codigo = @codigo

			if (@@ERROR = 0)
			return 1
		else
			return -4
end
go

create proc BuscarVuelo
@codigo varchar(10)
as
begin
	select * from Vuelo where Codigo = @codigo and ActivoVuelo = 1
end
go

create proc BuscarTodoVuelos
@codigo varchar(10)
as
begin
	select * from Vuelo where Codigo = @codigo
end
go

create proc ListadoVuelos
as
begin
	select * from Vuelo where ActivoVuelo = 1
end
go

create proc BajaVuelo
@codigo varchar(10)	
as
begin

	if not exists (select * from Vuelo where Codigo = @codigo and ActivoVuelo = 1)
		begin
			return -1
		end

	if exists (select * from Paquete where CodigoVueloIda = @codigo or CodigoVueloVuelta = @codigo)
		begin
			update Vuelo
				set ActivoVuelo = 0
				where Codigo = @codigo
				return 1 
		end
	else
		begin

			  delete from Vuelo where Codigo = @codigo

			if (@@ERROR = 0)
				return 2
			else
				return -2
			end	
end
go

---------------------- HOSPEDAJE ----------------------

create proc AltaHospedaje
@codigoInterno varchar(10),
@nombre varchar(30),
@calle varchar(30),
@localidad varchar(30),
@tipo varchar(13),
@precio int,
@codigo varchar(4)
as
begin	
	if exists (select * from Hospedaje where CodigoInterno = @codigoInterno and ActivoHospedaje = 1)
		begin
			return -1
		end

		if not exists (select * from Estado where Codigo = @codigo and ActivoEstado = 1)
		begin
			return -2
		end

	if exists (select * from Hospedaje where CodigoInterno = @codigoInterno and ActivoHospedaje = 0)
		begin	
			update Hospedaje 
			set ActivoHospedaje = 1, Nombre = @nombre, Calle = @calle, Localidad = @localidad,
			Tipo = @tipo, Precio = @precio, Codigo = @codigo
			where CodigoInterno = @codigoInterno
			return 1
		end
	else 
		insert Hospedaje(CodigoInterno, Nombre, Calle, Localidad, Tipo, Precio, Codigo)
			values(@codigoInterno, @nombre, @calle, @localidad, @tipo, @precio, @codigo)

			if (@@ERROR = 0)
			return 1
		else
			return -3
end
go

create proc ModificarHospedaje
@codigoInterno varchar(10),
@nombre varchar(30),
@calle varchar(30),
@localidad varchar(30),
@tipo varchar(13),
@precio int,
@codigo varchar(4)
as
begin
	if not exists (select * from Hospedaje where CodigoInterno = @codigoInterno and ActivoHospedaje = 1)
		begin
			return -1
		end

	if not exists (select * from Estado where Codigo = @codigo and ActivoEstado = 1)
		begin
			return -2
		end

	else
		begin
		update Hospedaje
		set Nombre = @nombre, Calle = @calle, Localidad = @localidad, Tipo = @tipo, Precio = @precio, Codigo = @codigo
		where CodigoInterno = @codigoInterno
		
		if (@@ERROR = 0)
			return 1
		else
			return -3
		end
end
go

create proc BuscarHospedaje
@codigoInterno varchar(10)
as
begin
	select * from Hospedaje where CodigoInterno = @codigoInterno and ActivoHospedaje = 1
end
go

create proc BuscarTodosHospedaje
@codigoInterno varchar(10)
as
begin
	select * from Hospedaje where CodigoInterno = @codigoInterno
end
go

create proc ListaHospedajes
as
begin
	select * from Hospedaje where ActivoHospedaje = 1
end
go

create proc BajaHospedaje
@codigo varchar(10)
as
begin

	if not exists (select * from Hospedaje where CodigoInterno = @codigo and ActivoHospedaje = 1)
		begin
			return -1 
		end

	if exists (select * from Alojamiento where CodigoInterno = @codigo)
		begin
			update Hospedaje
				set ActivoHospedaje = 0
				where CodigoInterno = @codigo
				return 1
		end
	else
		begin

			  delete from Hospedaje where CodigoInterno = @codigo

			if (@@ERROR = 0)
				return 2
			else
				return -2
			end	
end 
go

----------------------- PAQUETE -----------------------------

create proc ListarPaquetes
as
begin
	select * from Paquete
end
go

create proc ListarPaXHospe
@codigoInterno varchar(10)
as
begin
	select p.* from Paquete p inner join Alojamiento a on p.Codigo = a.Codigo
							  where a.CodigoInterno = @codigoInterno
							  order by p.Codigo
end
go

create proc BuscarPaquete
@codigo int
as
begin 
	select * from Paquete where Codigo = @codigo
end
go

create proc AltaPaquete
@titulo varchar(30),
@descripcion varchar(60),
@cantDias int,
@precio1 int,
@precio2 int,
@precio3 int,
@usuario varchar(15),
@codigoVueloIda varchar(10),
@codigoVueloVuelta varchar(10),
@codigoEstado varchar(4)
as
begin
	if not exists (select * from Empleado where Usuario = @usuario)
		begin
			return -1
			return
		end

	if not exists (select * from Vuelo where Codigo = @codigoVueloIda and ActivoVuelo = 1)
	   or not exists (select * from Vuelo where Codigo = @codigoVueloVuelta and ActivoVuelo = 1)
		begin
			return -2
		end

	if not exists (select * from Estado where Codigo = @codigoEstado and ActivoEstado = 1)
		begin
			return -3
		end

	else

		insert Paquete(Titulo, Descripcion, CantDias, Precio1, Precio2, Precio3, Usuario, CodigoVueloIda, CodigoVueloVuelta, CodigoEstado) 
		values(@titulo, @descripcion, @cantDias, @precio1, @precio2, @precio3, @usuario, @codigoVueloIda, @codigoVueloVuelta, @codigoEstado)

			declare @codPaquete int

				set @codPaquete = scope_identity()

				if @@ERROR = 0
			return @codPaquete
		else
			return -4
	
end
go

------------------------- ALOJAMIENTO -----------------------

create proc ListarAlojamientosXPaq
@codigo int
as
begin	
	select * from Alojamiento where Codigo = @codigo order by Codigo
	
end
go

create proc AltaAlojamiento
@codigoPaquete int,
@codigoHospedaje varchar(10),
@nroNoches int
as
begin
	if not exists (select * from Paquete where Codigo = @codigoPaquete)
		begin
			return -1
		end

	if not exists (select * from Hospedaje where CodigoInterno = @codigoHospedaje and ActivoHospedaje = 1)
		begin
			return -2
		end

	if exists (select * from Alojamiento where Codigo = @codigoPaquete and CodigoInterno = @codigoHospedaje)
		begin
			return -3
		end

	insert Alojamiento(Codigo, CodigoInterno, NroNoches) values(@codigoPaquete, @codigoHospedaje, @nroNoches)

		if @@ERROR = 0
		begin
			return 1
			
		end 
	else
		begin
			return -4
		end 
end
go


insert into Empleado values ('lvilardo','Luc4s!','Lucas Vilardo')
insert into Empleado values ('jperez','Juan1!','Juan Perez')
insert into Empleado values ('mlopez','Mar1a#','Maria Lopez')
insert into Empleado values ('agarcia','Ana2@','Ana Garcia')
insert into Empleado values ('rrodriguez','Rodo3$','Rodrigo Rodriguez')
insert into Empleado values ('cfernandez','Car4%','Carlos Fernandez')
insert into Empleado values ('sgomez','Sofi5&','Sofia Gomez')
insert into Empleado values ('dmartinez','Die6*','Diego Martinez')
insert into Empleado values ('vtorres','Vale7!','Valentina Torres')
insert into Empleado values ('plemos','Pabl8#','Pablo Lemos')
insert into Empleado values ('nramirez','Nico9@','Nicolas Ramirez')
insert into Empleado values ('bcastro','Beto1$','Beto Castro')
insert into Empleado values ('lortiz','Luci2%','Lucia Ortiz')
insert into Empleado values ('tmedina','Tomi3&','Tomas Medina')
insert into Empleado values ('ggutierrez','Gus4*','Gustavo Gutierrez')


INSERT INTO Estado (Codigo, NomEstado, Pais) VALUES ('FLOR','Florida','Estados Unidos')
INSERT INTO Estado (Codigo, NomEstado, Pais) VALUES ('TEXA','Texas','Estados Unidos')
INSERT INTO Estado (Codigo, NomEstado, Pais) VALUES ('CALI','California','Estados Unidos')
INSERT INTO Estado (Codigo, NomEstado, Pais) VALUES ('NEVA','Nevada','Estados Unidos')
INSERT INTO Estado (Codigo, NomEstado, Pais) VALUES ('UTAH','Utah','Estados Unidos')
INSERT INTO Estado (Codigo, NomEstado, Pais) VALUES ('OHIO','Ohio','Estados Unidos')
INSERT INTO Estado (Codigo, NomEstado, Pais) VALUES ('IOWA','Iowa','Estados Unidos')
INSERT INTO Estado (Codigo, NomEstado, Pais) VALUES ('ALAB','Alabama','Estados Unidos')
INSERT INTO Estado (Codigo, NomEstado, Pais) VALUES ('ALAS','Alaska','Estados Unidos')
INSERT INTO Estado (Codigo, NomEstado, Pais) VALUES ('ARIZ','Arizona','Estados Unidos')
INSERT INTO Estado (Codigo, NomEstado, Pais) VALUES ('BUEN','Buenos Aires','Argentina')
INSERT INTO Estado (Codigo, NomEstado, Pais) VALUES ('CORD','Cordoba','Argentina')
INSERT INTO Estado (Codigo, NomEstado, Pais) VALUES ('SANT','Santa Fe','Argentina')
INSERT INTO Estado (Codigo, NomEstado, Pais) VALUES ('MEND','Mendoza','Argentina')
INSERT INTO Estado (Codigo, NomEstado, Pais) VALUES ('SALU','Salta','Argentina')
INSERT INTO Estado (Codigo, NomEstado, Pais) VALUES ('JUJU','Jujuy','Argentina')
INSERT INTO Estado (Codigo, NomEstado, Pais) VALUES ('CHUB','Chubut','Argentina')
INSERT INTO Estado (Codigo, NomEstado, Pais) VALUES ('FORM','Formosa','Argentina')
INSERT INTO Estado (Codigo, NomEstado, Pais) VALUES ('RINE','Rio Negro','Argentina')
INSERT INTO Estado (Codigo, NomEstado, Pais) VALUES ('TFUE','Tierra del Fuego','Argentina')
INSERT INTO Estado (Codigo, NomEstado, Pais) VALUES ('SAOP','Sao Paulo','Brasil')
INSERT INTO Estado (Codigo, NomEstado, Pais) VALUES ('RIOJ','Rio de Janeiro','Brasil')
INSERT INTO Estado (Codigo, NomEstado, Pais) VALUES ('MINA','Minas Gerais','Brasil')
INSERT INTO Estado (Codigo, NomEstado, Pais) VALUES ('BAHI','Bahia','Brasil')
INSERT INTO Estado (Codigo, NomEstado, Pais) VALUES ('PARA','Parana','Brasil')
INSERT INTO Estado (Codigo, NomEstado, Pais) VALUES ('CEAR','Ceara','Brasil')
INSERT INTO Estado (Codigo, NomEstado, Pais) VALUES ('PERN','Pernambuco','Brasil')
INSERT INTO Estado (Codigo, NomEstado, Pais) VALUES ('AMAP','Amapa','Brasil')
INSERT INTO Estado (Codigo, NomEstado, Pais) VALUES ('RORA','Roraima','Brasil')
INSERT INTO Estado (Codigo, NomEstado, Pais) VALUES ('TOCA','Tocantins','Brasil')
INSERT INTO Estado (Codigo, NomEstado, Pais) VALUES ('COLN','Colonia','Uruguay')
INSERT INTO Estado (Codigo, NomEstado, Pais) VALUES ('MONV','Montevideo','Uruguay')
INSERT INTO Estado (Codigo, NomEstado, Pais) VALUES ('MALD','Maldonado','Uruguay')
INSERT INTO Estado (Codigo, NomEstado, Pais) VALUES ('CANE','Canelones','Uruguay')
INSERT INTO Estado (Codigo, NomEstado, Pais) VALUES ('SALT','Salto','Uruguay')
INSERT INTO Estado (Codigo, NomEstado, Pais) VALUES ('PAYN','Paysandu','Uruguay')
INSERT INTO Estado (Codigo, NomEstado, Pais) VALUES ('ARTI','Artigas','Uruguay')
INSERT INTO Estado (Codigo, NomEstado, Pais) VALUES ('RIVE','Rivera','Uruguay')
INSERT INTO Estado (Codigo, NomEstado, Pais) VALUES ('TACU','Tacuarembo','Uruguay')
INSERT INTO Estado (Codigo, NomEstado, Pais) VALUES ('ROCH','Rocha','Uruguay')
INSERT INTO Estado (Codigo, NomEstado, Pais) VALUES ('ANDL','Andalucia','España')
INSERT INTO Estado (Codigo, NomEstado, Pais) VALUES ('MADR','Madrid','España')
INSERT INTO Estado (Codigo, NomEstado, Pais) VALUES ('CATL','Cataluña','España')
INSERT INTO Estado (Codigo, NomEstado, Pais) VALUES ('VALN','Valencia','España')
INSERT INTO Estado (Codigo, NomEstado, Pais) VALUES ('GALI','Galicia','España')
INSERT INTO Estado (Codigo, NomEstado, Pais) VALUES ('ARAG','Aragon','España')
INSERT INTO Estado (Codigo, NomEstado, Pais) VALUES ('CAST','Castilla','España')
INSERT INTO Estado (Codigo, NomEstado, Pais) VALUES ('MURC','Murcia','España')
INSERT INTO Estado (Codigo, NomEstado, Pais) VALUES ('NAVR','Navarra','España')
INSERT INTO Estado (Codigo, NomEstado, Pais) VALUES ('RIOX','La Rioja','España')
INSERT INTO Estado (Codigo, NomEstado, Pais) VALUES ('ONTI','Ontario','Canada')
INSERT INTO Estado (Codigo, NomEstado, Pais) VALUES ('QUEB','Quebec','Canada')
INSERT INTO Estado (Codigo, NomEstado, Pais) VALUES ('ALBE','Alberta','Canada')
INSERT INTO Estado (Codigo, NomEstado, Pais) VALUES ('BRIT','British Columbia','Canada')
INSERT INTO Estado (Codigo, NomEstado, Pais) VALUES ('MANI','Manitoba','Canada')
INSERT INTO Estado (Codigo, NomEstado, Pais) VALUES ('SASK','Saskatchewan','Canada')
INSERT INTO Estado (Codigo, NomEstado, Pais) VALUES ('NOVA','Nova Scotia','Canada')
INSERT INTO Estado (Codigo, NomEstado, Pais) VALUES ('PRIN','Prince Edward Island','Canada')
INSERT INTO Estado (Codigo, NomEstado, Pais) VALUES ('YUKO','Yukon','Canada')
INSERT INTO Estado (Codigo, NomEstado, Pais) VALUES ('NUNA','Nunavut','Canada')
INSERT INTO Estado (Codigo, NomEstado, Pais) VALUES ('BAVA','Bavaria','Alemania')
INSERT INTO Estado (Codigo, NomEstado, Pais) VALUES ('HESS','Hesse','Alemania')
INSERT INTO Estado (Codigo, NomEstado, Pais) VALUES ('SAXO','Saxony','Alemania')
INSERT INTO Estado (Codigo, NomEstado, Pais) VALUES ('BRAN','Brandenburg','Alemania')
INSERT INTO Estado (Codigo, NomEstado, Pais) VALUES ('BERL','Berlin','Alemania')
INSERT INTO Estado (Codigo, NomEstado, Pais) VALUES ('BREM','Bremen','Alemania')
INSERT INTO Estado (Codigo, NomEstado, Pais) VALUES ('THUR','Thuringia','Alemania')
INSERT INTO Estado (Codigo, NomEstado, Pais) VALUES ('SAAR','Saarland','Alemania')
INSERT INTO Estado (Codigo, NomEstado, Pais) VALUES ('RHIN','Rhineland','Alemania')
INSERT INTO Estado (Codigo, NomEstado, Pais) VALUES ('MECK','Mecklenburg','Alemania')

INSERT INTO Vuelo (Codigo,FyHPar,FyHLleg,PrecioIndi,CodigoPartida,CodigoLlegada) VALUES
('VU00000001','20270101','20270102',150,'FLOR','TEXA'),
('VU00000002','20270102','20270103',160,'TEXA','CALI'),
('VU00000003','20270103','20270104',170,'CALI','NEVA'),
('VU00000004','20270104','20270105',180,'NEVA','UTAH'),
('VU00000005','20270105','20270106',190,'UTAH','FLOR'),
('VU00000006','20270106','20270107',200,'FLOR','TEXA'),
('VU00000007','20270107','20270108',210,'TEXA','CALI'),
('VU00000008','20270108','20270109',220,'CALI','NEVA'),
('VU00000009','20270109','20270110',230,'NEVA','UTAH'),
('VU00000010','20270110','20270111',240,'UTAH','FLOR'),
('VU00000011','20270111','20270112',150,'FLOR','TEXA'),
('VU00000012','20270112','20270113',160,'TEXA','CALI'),
('VU00000013','20270113','20270114',170,'CALI','NEVA'),
('VU00000014','20270114','20270115',180,'NEVA','UTAH'),
('VU00000015','20270115','20270116',190,'UTAH','FLOR'),
('VU00000016','20270116','20270117',200,'FLOR','TEXA'),
('VU00000017','20270117','20270118',210,'TEXA','CALI'),
('VU00000018','20270118','20270119',220,'CALI','NEVA'),
('VU00000019','20270119','20270120',230,'NEVA','UTAH'),
('VU00000020','20270120','20270121',240,'UTAH','FLOR'),
('VU00000021','20270121','20270122',150,'FLOR','TEXA'),
('VU00000022','20270122','20270123',160,'TEXA','CALI'),
('VU00000023','20270123','20270124',170,'CALI','NEVA'),
('VU00000024','20270124','20270125',180,'NEVA','UTAH'),
('VU00000025','20270125','20270126',190,'UTAH','FLOR'),
('VU00000026','20270126','20270127',200,'FLOR','TEXA'),
('VU00000027','20270127','20270128',210,'TEXA','CALI'),
('VU00000028','20270128','20270129',220,'CALI','NEVA'),
('VU00000029','20270129','20270130',230,'NEVA','UTAH'),
('VU00000030','20270130','20270131',240,'UTAH','FLOR'),
('VU00000031','20270131','20270201',150,'FLOR','TEXA'),
('VU00000032','20270201','20270202',160,'TEXA','CALI'),
('VU00000033','20270202','20270203',170,'CALI','NEVA'),
('VU00000034','20270203','20270204',180,'NEVA','UTAH'),
('VU00000035','20270204','20270205',190,'UTAH','FLOR'),
('VU00000036','20270205','20270206',200,'FLOR','TEXA'),
('VU00000037','20270206','20270207',210,'TEXA','CALI'),
('VU00000038','20270207','20270208',220,'CALI','NEVA'),
('VU00000039','20270208','20270209',230,'NEVA','UTAH'),
('VU00000040','20270209','20270210',240,'UTAH','FLOR'),
('VU00000041','20270210','20270211',150,'FLOR','TEXA'),
('VU00000042','20270211','20270212',160,'TEXA','CALI'),
('VU00000043','20270212','20270213',170,'CALI','NEVA'),
('VU00000044','20270213','20270214',180,'NEVA','UTAH'),
('VU00000045','20270214','20270215',190,'UTAH','FLOR'),
('VU00000046','20270215','20270216',200,'FLOR','TEXA'),
('VU00000047','20270216','20270217',210,'TEXA','CALI'),
('VU00000048','20270217','20270218',220,'CALI','NEVA'),
('VU00000049','20270218','20270219',230,'NEVA','UTAH'),
('VU00000050','20270219','20270220',240,'UTAH','FLOR'),

('VU00000051','20270220','20270221',150,'FLOR','TEXA'),
('VU00000052','20270221','20270222',160,'TEXA','CALI'),
('VU00000053','20270222','20270223',170,'CALI','NEVA'),
('VU00000054','20270223','20270224',180,'NEVA','UTAH'),
('VU00000055','20270224','20270225',190,'UTAH','FLOR'),
('VU00000056','20270225','20270226',200,'FLOR','TEXA'),
('VU00000057','20270226','20270227',210,'TEXA','CALI'),
('VU00000058','20270227','20270228',220,'CALI','NEVA'),
('VU00000059','20270228','20270301',230,'NEVA','UTAH'),
('VU00000060','20270301','20270302',240,'UTAH','FLOR'),
('VU00000061','20270302','20270303',150,'FLOR','TEXA'),
('VU00000062','20270303','20270304',160,'TEXA','CALI'),
('VU00000063','20270304','20270305',170,'CALI','NEVA'),
('VU00000064','20270305','20270306',180,'NEVA','UTAH'),
('VU00000065','20270306','20270307',190,'UTAH','FLOR'),
('VU00000066','20270307','20270308',200,'FLOR','TEXA'),
('VU00000067','20270308','20270309',210,'TEXA','CALI'),
('VU00000068','20270309','20270310',220,'CALI','NEVA'),
('VU00000069','20270310','20270311',230,'NEVA','UTAH'),
('VU00000070','20270311','20270312',240,'UTAH','FLOR'),
('VU00000071','20270312','20270313',150,'FLOR','TEXA'),
('VU00000072','20270313','20270314',160,'TEXA','CALI'),
('VU00000073','20270314','20270315',170,'CALI','NEVA'),
('VU00000074','20270315','20270316',180,'NEVA','UTAH'),
('VU00000075','20270316','20270317',190,'UTAH','FLOR'),
('VU00000076','20270317','20270318',200,'FLOR','TEXA'),
('VU00000077','20270318','20270319',210,'TEXA','CALI'),
('VU00000078','20270319','20270320',220,'CALI','NEVA'),
('VU00000079','20270320','20270321',230,'NEVA','UTAH'),
('VU00000080','20270321','20270322',240,'UTAH','FLOR'),
('VU00000081','20270322','20270323',150,'FLOR','TEXA'),
('VU00000082','20270323','20270324',160,'TEXA','CALI'),
('VU00000083','20270324','20270325',170,'CALI','NEVA'),
('VU00000084','20270325','20270326',180,'NEVA','UTAH'),
('VU00000085','20270326','20270327',190,'UTAH','FLOR'),
('VU00000086','20270327','20270328',200,'FLOR','TEXA'),
('VU00000087','20270328','20270329',210,'TEXA','CALI'),
('VU00000088','20270329','20270330',220,'CALI','NEVA'),
('VU00000089','20270330','20270331',230,'NEVA','UTAH'),
('VU00000090','20270331','20270401',240,'UTAH','FLOR'),
('VU00000091','20270401','20270402',150,'FLOR','TEXA'),
('VU00000092','20270402','20270403',160,'TEXA','CALI'),
('VU00000093','20270403','20270404',170,'CALI','NEVA'),
('VU00000094','20270404','20270405',180,'NEVA','UTAH'),
('VU00000095','20270405','20270406',190,'UTAH','FLOR'),
('VU00000096','20270406','20270407',200,'FLOR','TEXA'),
('VU00000097','20270407','20270408',210,'TEXA','CALI'),
('VU00000098','20270408','20270409',220,'CALI','NEVA'),
('VU00000099','20270409','20270410',230,'NEVA','UTAH'),
('VU00000100','20270410','20270411',240,'UTAH','FLOR'),

('VU00000101','20270411','20270412',150,'FLOR','TEXA'),
('VU00000102','20270412','20270413',160,'TEXA','CALI'),
('VU00000103','20270413','20270414',170,'CALI','NEVA'),
('VU00000104','20270414','20270415',180,'NEVA','UTAH'),
('VU00000105','20270415','20270416',190,'UTAH','FLOR'),
('VU00000106','20270416','20270417',200,'FLOR','TEXA'),
('VU00000107','20270417','20270418',210,'TEXA','CALI'),
('VU00000108','20270418','20270419',220,'CALI','NEVA'),
('VU00000109','20270419','20270420',230,'NEVA','UTAH'),
('VU00000110','20270420','20270421',240,'UTAH','FLOR'),
('VU00000111','20270421','20270422',150,'FLOR','TEXA'),
('VU00000112','20270422','20270423',160,'TEXA','CALI'),
('VU00000113','20270423','20270424',170,'CALI','NEVA'),
('VU00000114','20270424','20270425',180,'NEVA','UTAH'),
('VU00000115','20270425','20270426',190,'UTAH','FLOR'),
('VU00000116','20270426','20270427',200,'FLOR','TEXA'),
('VU00000117','20270427','20270428',210,'TEXA','CALI'),
('VU00000118','20270428','20270429',220,'CALI','NEVA'),
('VU00000119','20270429','20270430',230,'NEVA','UTAH'),
('VU00000120','20270430','20270501',240,'UTAH','FLOR'),
('VU00000121','20270501','20270502',150,'FLOR','TEXA'),
('VU00000122','20270502','20270503',160,'TEXA','CALI'),
('VU00000123','20270503','20270504',170,'CALI','NEVA'),
('VU00000124','20270504','20270505',180,'NEVA','UTAH'),
('VU00000125','20270505','20270506',190,'UTAH','FLOR'),
('VU00000126','20270506','20270507',200,'FLOR','TEXA'),
('VU00000127','20270507','20270508',210,'TEXA','CALI'),
('VU00000128','20270508','20270509',220,'CALI','NEVA'),
('VU00000129','20270509','20270510',230,'NEVA','UTAH'),
('VU00000130','20270510','20270511',240,'UTAH','FLOR'),
('VU00000131','20270511','20270512',150,'FLOR','TEXA'),
('VU00000132','20270512','20270513',160,'TEXA','CALI'),
('VU00000133','20270513','20270514',170,'CALI','NEVA'),
('VU00000134','20270514','20270515',180,'NEVA','UTAH'),
('VU00000135','20270515','20270516',190,'UTAH','FLOR'),
('VU00000136','20270516','20270517',200,'FLOR','TEXA'),
('VU00000137','20270517','20270518',210,'TEXA','CALI'),
('VU00000138','20270518','20270519',220,'CALI','NEVA'),
('VU00000139','20270519','20270520',230,'NEVA','UTAH'),
('VU00000140','20270520','20270521',240,'UTAH','FLOR'),
('VU00000141','20270521','20270522',150,'FLOR','TEXA'),
('VU00000142','20270522','20270523',160,'TEXA','CALI'),
('VU00000143','20270523','20270524',170,'CALI','NEVA'),
('VU00000144','20270524','20270525',180,'NEVA','UTAH'),
('VU00000145','20270525','20270526',190,'UTAH','FLOR'),
('VU00000146','20270526','20270527',200,'FLOR','TEXA'),
('VU00000147','20270527','20270528',210,'TEXA','CALI'),
('VU00000148','20270528','20270529',220,'CALI','NEVA'),
('VU00000149','20270529','20270530',230,'NEVA','UTAH'),
('VU00000150','20270530','20270531',240,'UTAH','FLOR'),

('VU00000151','20270531','20270601',150,'FLOR','TEXA'),
('VU00000152','20270601','20270602',160,'TEXA','CALI'),
('VU00000153','20270602','20270603',170,'CALI','NEVA'),
('VU00000154','20270603','20270604',180,'NEVA','UTAH'),
('VU00000155','20270604','20270605',190,'UTAH','FLOR'),
('VU00000156','20270605','20270606',200,'FLOR','TEXA'),
('VU00000157','20270606','20270607',210,'TEXA','CALI'),
('VU00000158','20270607','20270608',220,'CALI','NEVA'),
('VU00000159','20270608','20270609',230,'NEVA','UTAH'),
('VU00000160','20270609','20270610',240,'UTAH','FLOR'),
('VU00000161','20270610','20270611',150,'FLOR','TEXA'),
('VU00000162','20270611','20270612',160,'TEXA','CALI'),
('VU00000163','20270612','20270613',170,'CALI','NEVA'),
('VU00000164','20270613','20270614',180,'NEVA','UTAH'),
('VU00000165','20270614','20270615',190,'UTAH','FLOR'),
('VU00000166','20270615','20270616',200,'FLOR','TEXA'),
('VU00000167','20270616','20270617',210,'TEXA','CALI'),
('VU00000168','20270617','20270618',220,'CALI','NEVA'),
('VU00000169','20270618','20270619',230,'NEVA','UTAH'),
('VU00000170','20270619','20270620',240,'UTAH','FLOR'),
('VU00000171','20270620','20270621',150,'FLOR','TEXA'),
('VU00000172','20270621','20270622',160,'TEXA','CALI'),
('VU00000173','20270622','20270623',170,'CALI','NEVA'),
('VU00000174','20270623','20270624',180,'NEVA','UTAH'),
('VU00000175','20270624','20270625',190,'UTAH','FLOR'),
('VU00000176','20270625','20270626',200,'FLOR','TEXA'),
('VU00000177','20270626','20270627',210,'TEXA','CALI'),
('VU00000178','20270627','20270628',220,'CALI','NEVA'),
('VU00000179','20270628','20270629',230,'NEVA','UTAH'),
('VU00000180','20270629','20270630',240,'UTAH','FLOR'),
('VU00000181','20270630','20270701',150,'FLOR','TEXA'),
('VU00000182','20270701','20270702',160,'TEXA','CALI'),
('VU00000183','20270702','20270703',170,'CALI','NEVA'),
('VU00000184','20270703','20270704',180,'NEVA','UTAH'),
('VU00000185','20270704','20270705',190,'UTAH','FLOR'),
('VU00000186','20270705','20270706',200,'FLOR','TEXA'),
('VU00000187','20270706','20270707',210,'TEXA','CALI'),
('VU00000188','20270707','20270708',220,'CALI','NEVA'),
('VU00000189','20270708','20270709',230,'NEVA','UTAH'),
('VU00000190','20270709','20270710',240,'UTAH','FLOR'),
('VU00000191','20270710','20270711',150,'FLOR','TEXA'),
('VU00000192','20270711','20270712',160,'TEXA','CALI'),
('VU00000193','20270712','20270713',170,'CALI','NEVA'),
('VU00000194','20270713','20270714',180,'NEVA','UTAH'),
('VU00000195','20270714','20270715',190,'UTAH','FLOR'),
('VU00000196','20270715','20270716',200,'FLOR','TEXA'),
('VU00000197','20270716','20270717',210,'TEXA','CALI'),
('VU00000198','20270717','20270718',220,'CALI','NEVA'),
('VU00000199','20270718','20270719',230,'NEVA','UTAH'),
('VU00000200','20270719','20270720',240,'UTAH','FLOR'),

('VU00000201','20270720','20270721',150,'FLOR','TEXA'),
('VU00000202','20270721','20270722',160,'TEXA','CALI'),
('VU00000203','20270722','20270723',170,'CALI','NEVA'),
('VU00000204','20270723','20270724',180,'NEVA','UTAH'),
('VU00000205','20270724','20270725',190,'UTAH','FLOR'),
('VU00000206','20270725','20270726',200,'FLOR','TEXA'),
('VU00000207','20270726','20270727',210,'TEXA','CALI'),
('VU00000208','20270727','20270728',220,'CALI','NEVA'),
('VU00000209','20270728','20270729',230,'NEVA','UTAH'),
('VU00000210','20270729','20270730',240,'UTAH','FLOR'),
('VU00000211','20270730','20270731',150,'FLOR','TEXA'),
('VU00000212','20270731','20270801',160,'TEXA','CALI'),
('VU00000213','20270801','20270802',170,'CALI','NEVA'),
('VU00000214','20270802','20270803',180,'NEVA','UTAH'),
('VU00000215','20270803','20270804',190,'UTAH','FLOR'),
('VU00000216','20270804','20270805',200,'FLOR','TEXA'),
('VU00000217','20270805','20270806',210,'TEXA','CALI'),
('VU00000218','20270806','20270807',220,'CALI','NEVA'),
('VU00000219','20270807','20270808',230,'NEVA','UTAH'),
('VU00000220','20270808','20270809',240,'UTAH','FLOR'),
('VU00000221','20270809','20270810',150,'FLOR','TEXA'),
('VU00000222','20270810','20270811',160,'TEXA','CALI'),
('VU00000223','20270811','20270812',170,'CALI','NEVA'),
('VU00000224','20270812','20270813',180,'NEVA','UTAH'),
('VU00000225','20270813','20270814',190,'UTAH','FLOR'),
('VU00000226','20270814','20270815',200,'FLOR','TEXA'),
('VU00000227','20270815','20270816',210,'TEXA','CALI'),
('VU00000228','20270816','20270817',220,'CALI','NEVA'),
('VU00000229','20270817','20270818',230,'NEVA','UTAH'),
('VU00000230','20270818','20270819',240,'UTAH','FLOR'),
('VU00000231','20270819','20270820',150,'FLOR','TEXA'),
('VU00000232','20270820','20270821',160,'TEXA','CALI'),
('VU00000233','20270821','20270822',170,'CALI','NEVA'),
('VU00000234','20270822','20270823',180,'NEVA','UTAH'),
('VU00000235','20270823','20270824',190,'UTAH','FLOR'),
('VU00000236','20270824','20270825',200,'FLOR','TEXA'),
('VU00000237','20270825','20270826',210,'TEXA','CALI'),
('VU00000238','20270826','20270827',220,'CALI','NEVA'),
('VU00000239','20270827','20270828',230,'NEVA','UTAH'),
('VU00000240','20270828','20270829',240,'UTAH','FLOR'),
('VU00000241','20270829','20270830',150,'FLOR','TEXA'),
('VU00000242','20270830','20270831',160,'TEXA','CALI'),
('VU00000243','20270831','20270901',170,'CALI','NEVA'),
('VU00000244','20270901','20270902',180,'NEVA','UTAH'),
('VU00000245','20270902','20270903',190,'UTAH','FLOR'),
('VU00000246','20270903','20270904',200,'FLOR','TEXA'),
('VU00000247','20270904','20270905',210,'TEXA','CALI'),
('VU00000248','20270905','20270906',220,'CALI','NEVA'),
('VU00000249','20270906','20270907',230,'NEVA','UTAH'),
('VU00000250','20270907','20270908',240,'UTAH','FLOR'),

('VU00000251','20270908','20270909',150,'FLOR','TEXA'),
('VU00000252','20270909','20270910',160,'TEXA','CALI'),
('VU00000253','20270910','20270911',170,'CALI','NEVA'),
('VU00000254','20270911','20270912',180,'NEVA','UTAH'),
('VU00000255','20270912','20270913',190,'UTAH','FLOR'),
('VU00000256','20270913','20270914',200,'FLOR','TEXA'),
('VU00000257','20270914','20270915',210,'TEXA','CALI'),
('VU00000258','20270915','20270916',220,'CALI','NEVA'),
('VU00000259','20270916','20270917',230,'NEVA','UTAH'),
('VU00000260','20270917','20270918',240,'UTAH','FLOR'),
('VU00000261','20270918','20270919',150,'FLOR','TEXA'),
('VU00000262','20270919','20270920',160,'TEXA','CALI'),
('VU00000263','20270920','20270921',170,'CALI','NEVA'),
('VU00000264','20270921','20270922',180,'NEVA','UTAH'),
('VU00000265','20270922','20270923',190,'UTAH','FLOR'),
('VU00000266','20270923','20270924',200,'FLOR','TEXA'),
('VU00000267','20270924','20270925',210,'TEXA','CALI'),
('VU00000268','20270925','20270926',220,'CALI','NEVA'),
('VU00000269','20270926','20270927',230,'NEVA','UTAH'),
('VU00000270','20270927','20270928',240,'UTAH','FLOR'),
('VU00000271','20270928','20270929',150,'FLOR','TEXA'),
('VU00000272','20270929','20270930',160,'TEXA','CALI'),
('VU00000273','20270930','20271001',170,'CALI','NEVA'),
('VU00000274','20271001','20271002',180,'NEVA','UTAH'),
('VU00000275','20271002','20271003',190,'UTAH','FLOR'),
('VU00000276','20271003','20271004',200,'FLOR','TEXA'),
('VU00000277','20271004','20271005',210,'TEXA','CALI'),
('VU00000278','20271005','20271006',220,'CALI','NEVA'),
('VU00000279','20271006','20271007',230,'NEVA','UTAH'),
('VU00000280','20271007','20271008',240,'UTAH','FLOR'),
('VU00000281','20271008','20271009',150,'FLOR','TEXA'),
('VU00000282','20271009','20271010',160,'TEXA','CALI'),
('VU00000283','20271010','20271011',170,'CALI','NEVA'),
('VU00000284','20271011','20271012',180,'NEVA','UTAH'),
('VU00000285','20271012','20271013',190,'UTAH','FLOR'),
('VU00000286','20271013','20271014',200,'FLOR','TEXA'),
('VU00000287','20271014','20271015',210,'TEXA','CALI'),
('VU00000288','20271015','20271016',220,'CALI','NEVA'),
('VU00000289','20271016','20271017',230,'NEVA','UTAH'),
('VU00000290','20271017','20271018',240,'UTAH','FLOR'),
('VU00000291','20271018','20271019',150,'FLOR','TEXA'),
('VU00000292','20271019','20271020',160,'TEXA','CALI'),
('VU00000293','20271020','20271021',170,'CALI','NEVA'),
('VU00000294','20271021','20271022',180,'NEVA','UTAH'),
('VU00000295','20271022','20271023',190,'UTAH','FLOR'),
('VU00000296','20271023','20271024',200,'FLOR','TEXA'),
('VU00000297','20271024','20271025',210,'TEXA','CALI'),									
('VU00000298','20271025','20271026',220,'CALI','NEVA'),
('VU00000299','20271026','20271027',230,'NEVA','UTAH'),
('VU00000300','20271027','20271028',240,'UTAH','FLOR');

INSERT INTO Hospedaje (CodigoInterno,Nombre,Calle,Localidad,Tipo,Precio,Codigo) VALUES
('JKQQKJRTY','Rincón Pradera Dorada','Av. San Martín','Lago Verde','All inclusive',131,'TEXA'),
('SXPEEMWZU','Posada Bosque Claro','Calle Los Tilos','Prado Norte','HotelSTD',218,'UTAH'),
('PZTWKJJ','Portal La Cascada','Av. Central','Santa Rosa','Posada',274,'NEVA'),
('QEFEG','Hostal La Cascada','Calle Los Aromos','Sierra Blanca','HotelSTD',103,'TEXA'),
('NPHRKMPSYG','Portal Sol Naciente','Av. San Martín','Villa Verde','HotelSTD',107,'UTAH'),
('WCAIIA','Refugio Río Claro','Calle Los Tilos','Monte Claro','HotelSTD',144,'NEVA'),
('TEUQLPKIJW','Hotel Colina Verde','Av. del Bosque','Villa Verde','HotelSTD',61,'FLOR'),
('NSPKZ','Suites Valle Escondido','Calle Las Magnolias','Bahía Serena','Posada',74,'CALI'),
('CSMWCZS','Rincón Pradera Dorada','Av. Central','Colonia Alta','HotelSTD',217,'FLOR'),
('ZIOFAAOHP','Rincón Mar Serena','Calle del Mirador','Sierra Blanca','Posada',225,'TEXA'),
('TYWDVP','Rincón Monte Azul','Av. de la Colina','Villa Verde','All inclusive',290,'TEXA'),
('NRASYQ','Estancia Pradera Dorada','Calle Los Tilos','Bahía Serena','HotelSTD',155,'CALI'),
('EPYAQ','Residencial Brisa Marina','Calle Los Tilos','Valle Azul','HotelSTD',131,'UTAH'),
('RCIGCKKYO','Posada Mar Serena','Calle Rivera','Valle Azul','Posada',290,'TEXA'),
('EBPFX','Hostal Mar Serena','Av. Costanera','Puerto Claro','All inclusive',250,'CALI'),
('XNUELCEE','Portal Amanecer','Calle Las Magnolias','Colonia Alta','All inclusive',258,'TEXA'),
('GRBXA','Refugio La Cascada','Calle Los Tilos','Prado Norte','Posada',108,'FLOR'),
('LSLODPQL','Posada Piedra Blanca','Calle Las Magnolias','Colonia Alta','Posada',246,'UTAH'),
('UFKFIPVLZZ','Refugio Monte Azul','Av. del Bosque','Santa Rosa','HotelSTD',221,'UTAH'),
('ZJOYISS','Mirador Bahía Azul','Calle Los Aromos','Sierra Blanca','Posada',117,'UTAH'),
('SUKGWL','Mirador Jardín Secreto','Av. del Bosque','San Ignacio','HotelSTD',131,'CALI'),
('IQTXLH','Hostal Piedra Blanca','Calle Las Magnolias','Santa Rosa','Posada',228,'FLOR'),
('VPZAT','Rincón Pradera Dorada','Calle Los Aromos','Santa Rosa','Posada',147,'FLOR'),
('BGXCI','Suites Colina Verde','Av. Horizonte','Sierra Blanca','HotelSTD',165,'NEVA'),
('XYLXM','Refugio Camino Real','Av. Central','San Ignacio','All inclusive',89,'CALI'),
('UEYODQAB','Residencial Brisa Marina','Av. del Puerto','Costa Dorada','Posada',211,'UTAH'),
('FEESGEYG','Suites Camino Real','Calle Los Aromos','Villa Verde','Posada',203,'UTAH'),
('RLTOVYHDYH','Portal Río Claro','Calle Rivera','Bahía Serena','HotelSTD',285,'FLOR'),
('UNLITIX','Hotel Bosque Claro','Av. Horizonte','Bahía Serena','Posada',267,'UTAH'),
('ZVUBMHB','Suites Luna Clara','Av. Horizonte','Santa Rosa','HotelSTD',130,'CALI'),
('OSOSXH','Rincón Valle Escondido','Calle Los Olivos','Villa Verde','Posada',138,'CALI'),
('ODVHLRLD','Posada Valle Escondido','Av. San Martín','Puerto Claro','HotelSTD',229,'CALI'),
('QBZDHAACK','Mirador Amanecer','Av. Las Palmeras','Lago Verde','Posada',272,'UTAH'),
('NHXLATMCE','Suites Luna Clara','Av. del Bosque','Puerto Claro','HotelSTD',87,'TEXA'),
('IZRMYR','Hotel Valle Escondido','Av. del Bosque','Lago Verde','Posada',180,'FLOR'),
('NGEDYWGTP','Rincón Bosque Claro','Calle del Parque','Costa Dorada','HotelSTD',209,'UTAH'),
('AEGUG','Mirador Camino Real','Av. Las Palmeras','Valle Azul','HotelSTD',139,'NEVA'),
('TRXNGSAH','Hostal Pradera Dorada','Calle Jacarandá','Puerto Claro','HotelSTD',81,'FLOR'),
('VMLCXHPB','Hotel Valle Escondido','Calle Los Tilos','Valle Azul','All inclusive',285,'UTAH'),
('OMKFOJKB','Hostal Río Claro','Av. Central','Monte Claro','All inclusive',162,'NEVA'),
('WVMXVSLUK','Hotel Piedra Blanca','Av. del Bosque','Costa Dorada','Posada',275,'TEXA'),
('NHBEQDQWD','Hotel Camino Real','Calle Las Acacias','Colonia Alta','HotelSTD',99,'NEVA'),
('RDAAHUXC','Suites Amanecer','Calle Jacarandá','Villa Verde','Posada',78,'UTAH'),
('GJPLAYCWA','Mirador Amanecer','Av. del Lago','Costa Dorada','Posada',184,'TEXA'),
('PJSXRSNYVA','Estancia La Cascada','Calle Los Aromos','Colonia Alta','Posada',157,'FLOR'),
('GFWSUTMWW','Residencial Monte Azul','Av. Costanera','Prado Norte','All inclusive',93,'UTAH'),
('SKGSMOJU','Suites Valle Escondido','Av. del Bosque','Colonia Alta','All inclusive',84,'NEVA'),
('MXVCDQBW','Suites Río Claro','Av. de la Colina','Valle Azul','All inclusive',188,'UTAH'),
('IGOSLCBUB','Mirador Valle Escondido','Calle Los Tilos','Bahía Serena','Posada',135,'UTAH'),
('SPCPVEB','Refugio Bahía Azul','Calle Las Magnolias','Costa Dorada','All inclusive',244,'TEXA'),
('ODPBRJ','Suites Colina Verde','Calle del Faro','Villa Verde','All inclusive',85,'CALI'),
('LJQRCCYOYI','Estancia Piedra Blanca','Calle Rivera','Valle Azul','HotelSTD',204,'CALI'),
('KZKMIC','Hostal Sol Naciente','Av. San Martín','Puerto Claro','HotelSTD',169,'UTAH'),
('XFFJWINLK','Portal La Cascada','Calle Rivera','Monte Claro','Posada',150,'NEVA'),
('RZBWZPBFQ','Suites Piedra Blanca','Av. Costanera','Valle Azul','HotelSTD',81,'UTAH'),
('PRZVL','Portal Brisa Marina','Calle Los Olivos','Monte Claro','HotelSTD',73,'FLOR'),
('NYRXRT','Suites Puerto Dorado','Calle Los Aromos','San Ignacio','All inclusive',113,'FLOR'),
('DRNHYSV','Residencial Colina Verde','Calle Las Acacias','Prado Norte','Posada',164,'FLOR'),
('ZINSWZ','Mirador Cumbre Alta','Av. Libertad','Valle Azul','Posada',62,'NEVA'),
('GZOBVZ','Posada Cumbre Alta','Calle Los Aromos','Lago Verde','Posada',95,'NEVA'),
('NIQVCLSD','Hostal Costa Serena','Av. de la Colina','Bahía Serena','Posada',284,'UTAH'),
('RMJTZEY','Residencial Pradera Dorada','Av. Costanera','Monte Claro','HotelSTD',210,'TEXA'),
('LMZQEITVT','Rincón Costa Serena','Av. de la Colina','Prado Norte','All inclusive',244,'FLOR'),
('CJUVYILV','Refugio Bahía Azul','Calle Las Magnolias','Lago Verde','Posada',218,'TEXA'),
('RUCDF','Refugio Valle Escondido','Calle del Faro','Sierra Blanca','All inclusive',190,'FLOR'),
('PLNEZXLSSA','Estancia Puerto Dorado','Calle Jacarandá','San Ignacio','All inclusive',145,'UTAH'),
('UFAFS','Residencial Río Claro','Av. del Lago','Colonia Alta','All inclusive',208,'NEVA'),
('IBRLVWBVQL','Rincón Puerto Dorado','Av. Horizonte','Prado Norte','HotelSTD',292,'UTAH'),
('EXIWAWBQGF','Hostal Piedra Blanca','Calle Los Tilos','Lago Verde','Posada',200,'CALI'),
('UBMMPZBUWJ','Posada Río Claro','Av. Las Palmeras','Prado Norte','HotelSTD',273,'CALI'),
('XLWGUIXIF','Hostal Amanecer','Av. Horizonte','Lago Verde','HotelSTD',158,'UTAH'),
('RUJBRGTKX','Residencial Puerto Dorado','Av. Libertad','San Ignacio','All inclusive',252,'NEVA'),
('DNZXMLMUNM','Refugio Costa Serena','Av. Libertad','Valle Azul','HotelSTD',229,'NEVA'),
('XZMLQRTM','Posada Colina Verde','Calle Las Acacias','Sierra Blanca','All inclusive',175,'UTAH'),
('SYPSYRDIL','Rincón Bahía Azul','Av. del Puerto','Villa Verde','HotelSTD',224,'CALI'),
('LIIMSC','Suites Monte Azul','Av. del Bosque','Prado Norte','All inclusive',201,'UTAH'),
('MNANPBIY','Refugio Río Claro','Calle Las Magnolias','Monte Claro','All inclusive',106,'CALI'),
('TFAZULJXF','Refugio Amanecer','Calle Los Aromos','Valle Azul','HotelSTD',184,'CALI'),
('FDCMWGVGTB','Mirador Camino Real','Calle Las Magnolias','San Ignacio','Posada',216,'UTAH'),
('PVOFMICKR','Mirador Río Claro','Calle Rivera','Lago Verde','Posada',123,'CALI'),
('GOAWYC','Hostal Camino Real','Calle Los Olivos','Colonia Alta','HotelSTD',183,'FLOR'),
('QQJVM','Rincón Bosque Claro','Av. San Martín','Colonia Alta','All inclusive',266,'UTAH'),
('ZXWQD','Estancia Bosque Claro','Calle del Parque','Villa Verde','HotelSTD',272,'TEXA'),
('FEASJ','Estancia Sol Naciente','Av. Costanera','Santa Rosa','Posada',156,'FLOR'),
('JUGXDHX','Rincón Camino Real','Calle Jacarandá','Costa Dorada','HotelSTD',204,'CALI'),
('VGUVNOVS','Suites Cumbre Alta','Av. Central','Colonia Alta','All inclusive',266,'UTAH'),
('CYSWLUPIPF','Residencial Jardín Secreto','Av. Central','Valle Azul','HotelSTD',220,'FLOR'),
('EMZLANJFL','Rincón La Cascada','Av. del Lago','Prado Norte','HotelSTD',115,'UTAH'),
('WHHCFN','Rincón Costa Serena','Av. San Martín','Villa Verde','Posada',211,'CALI'),
('GIVFYAVRGQ','Residencial Puerto Dorado','Calle Jacarandá','Valle Azul','HotelSTD',91,'CALI'),
('OAPMIZ','Residencial del Lago','Calle Los Tilos','Villa Verde','Posada',267,'NEVA'),
('YLXJGTB','Residencial Amanecer','Av. Horizonte','Sierra Blanca','Posada',149,'FLOR'),
('YSXCGL','Posada Mar Serena','Calle Los Tilos','Villa Verde','HotelSTD',191,'FLOR'),
('RJBJKBDXG','Residencial Luna Clara','Calle Los Olivos','Valle Azul','Posada',251,'TEXA'),
('BNVCLOGK','Residencial La Cascada','Calle Los Tilos','Prado Norte','HotelSTD',98,'CALI'),
('MUYPPOLF','Hotel Brisa Marina','Av. del Bosque','Villa Verde','Posada',262,'UTAH'),
('TJELSD','Estancia Brisa Marina','Calle del Parque','Costa Dorada','HotelSTD',177,'FLOR'),
('ZNUHOWNOLA','Hostal Mar Serena','Av. Horizonte','Bahía Serena','HotelSTD',283,'NEVA'),
('KMSSAWAYO','Estancia La Cascada','Calle del Parque','Costa Dorada','HotelSTD',296,'FLOR'),
('BWEFL','Hotel Río Claro','Calle Rivera','Costa Dorada','HotelSTD',116,'NEVA'),
('TPWATRWZ','Rincón Amanecer','Calle del Parque','Prado Norte','All inclusive',298,'FLOR'),
('WHZKHLC','Refugio Brisa Marina','Av. del Lago','Sierra Blanca','All inclusive',227,'TEXA'),
('JLXPYTRLZY','Hostal La Cascada','Calle Los Tilos','Villa Verde','Posada',148,'NEVA'),
('MTGPNNJNT','Mirador Brisa Marina','Calle Las Acacias','Costa Dorada','All inclusive',158,'TEXA'),
('CSWLS','Rincón Sol Naciente','Av. San Martín','Bahía Serena','HotelSTD',81,'UTAH'),
('VTUWMST','Rincón Sol Naciente','Calle Jacarandá','Monte Claro','All inclusive',95,'NEVA'),
('DUKDPMAAQU','Suites Piedra Blanca','Av. del Bosque','Prado Norte','All inclusive',209,'UTAH'),
('AOPVA','Rincón Cumbre Alta','Av. del Lago','Bahía Serena','HotelSTD',146,'UTAH'),
('MHQGUDWH','Residencial Puerto Dorado','Av. del Lago','Monte Claro','Posada',113,'TEXA'),
('FJZZFI','Rincón Colina Verde','Av. del Lago','Bahía Serena','HotelSTD',69,'NEVA'),
('HVAVXOXIL','Portal Río Claro','Calle Los Olivos','Lago Verde','All inclusive',278,'UTAH'),
('ABUTZ','Mirador Brisa Marina','Av. de la Colina','Lago Verde','All inclusive',89,'UTAH'),
('RCVRIYJVVU','Suites La Cascada','Calle Jacarandá','Costa Dorada','All inclusive',69,'TEXA'),
('PWIDFNJCHV','Refugio Bosque Claro','Calle Los Tilos','Santa Rosa','All inclusive',235,'NEVA'),
('FKYSUC','Posada Río Claro','Calle Rivera','Santa Rosa','Posada',259,'UTAH'),
('DCOEB','Portal del Lago','Calle Los Aromos','Santa Rosa','All inclusive',106,'UTAH'),
('EGKVFODU','Suites Bahía Azul','Av. de la Colina','Prado Norte','Posada',151,'CALI'),
('NJIPAYZPEL','Refugio La Cascada','Calle Los Tilos','Villa Verde','Posada',164,'NEVA'),
('FFETQBHTC','Suites Valle Escondido','Av. Central','Colonia Alta','HotelSTD',94,'NEVA'),
('OTFYWFMML','Hostal Pradera Dorada','Calle del Parque','Sierra Blanca','All inclusive',152,'NEVA'),
('XAOEESA','Posada Bahía Azul','Av. Las Palmeras','Colonia Alta','HotelSTD',221,'TEXA'),
('SFMFFX','Mirador Mar Serena','Calle Los Aromos','Puerto Claro','Posada',69,'CALI'),
('QJIHQ','Refugio Colina Verde','Av. San Martín','Costa Dorada','HotelSTD',98,'TEXA'),
('IKBEULS','Posada Sol Naciente','Calle Los Olivos','Prado Norte','Posada',216,'UTAH'),
('UPPRL','Refugio Mar Serena','Av. del Lago','Colonia Alta','Posada',117,'NEVA'),
('QZZNYZPSQ','Suites Bahía Azul','Calle Los Tilos','Santa Rosa','All inclusive',221,'UTAH'),
('DPUYZG','Mirador Mar Serena','Calle Jacarandá','Santa Rosa','All inclusive',140,'FLOR'),
('TWAQNWV','Estancia La Cascada','Av. Horizonte','Villa Verde','Posada',177,'TEXA'),
('AAJUH','Hostal Mar Serena','Av. del Lago','San Ignacio','HotelSTD',246,'UTAH'),
('JFLMSH','Residencial Mar Serena','Av. de la Colina','Valle Azul','Posada',264,'TEXA'),
('ROHHBEBY','Hotel Costa Serena','Calle Los Olivos','Villa Verde','HotelSTD',125,'TEXA'),
('ESTPNA','Portal Bahía Azul','Calle Rivera','Costa Dorada','Posada',246,'FLOR'),
('XOBSPOBCE','Portal Brisa Marina','Calle Rivera','San Ignacio','Posada',126,'FLOR'),
('PDNSYXF','Hostal Jardín Secreto','Av. Horizonte','Monte Claro','HotelSTD',64,'UTAH'),
('JRCDRINKOP','Mirador Pradera Dorada','Calle Los Tilos','Puerto Claro','Posada',121,'TEXA'),
('BXITOUQ','Hotel Luna Clara','Calle del Parque','Colonia Alta','HotelSTD',296,'TEXA'),
('IHUZDVYF','Refugio Monte Azul','Av. del Puerto','Bahía Serena','HotelSTD',114,'NEVA'),
('GCNDRK','Hostal Río Claro','Calle Las Acacias','San Ignacio','All inclusive',261,'FLOR'),
('GVZII','Hostal Puerto Dorado','Av. Costanera','Costa Dorada','All inclusive',185,'CALI'),
('HEIDFFPG','Residencial Piedra Blanca','Calle Los Olivos','San Ignacio','Posada',294,'UTAH'),
('GVUVMF','Refugio Valle Escondido','Av. Libertad','Santa Rosa','HotelSTD',182,'CALI'),
('BVMVOZTKH','Portal La Cascada','Calle Los Olivos','Colonia Alta','HotelSTD',285,'CALI'),
('MASIVQCBBP','Estancia Valle Escondido','Calle Los Tilos','Prado Norte','Posada',123,'UTAH'),
('FPGZR','Hotel Colina Verde','Av. San Martín','Costa Dorada','Posada',97,'NEVA'),
('TYBGIBFIG','Rincón Cumbre Alta','Calle del Mirador','Valle Azul','HotelSTD',268,'TEXA'),
('UVIRYLKRYK','Mirador Río Claro','Calle del Mirador','Costa Dorada','HotelSTD',62,'UTAH'),
('KNVPQPHGQE','Residencial Valle Escondido','Calle Jacarandá','Bahía Serena','Posada',165,'NEVA'),
('LJDGPPG','Rincón Río Claro','Av. Libertad','Villa Verde','Posada',76,'TEXA'),
('KZZJJMVNSO','Refugio Bahía Azul','Av. Las Palmeras','San Ignacio','All inclusive',295,'FLOR'),
('DUHTL','Suites Jardín Secreto','Calle Los Olivos','Lago Verde','HotelSTD',295,'NEVA'),
('FASXWU','Estancia Sol Naciente','Calle del Faro','Colonia Alta','HotelSTD',206,'UTAH'),
('JBGDQXTREG','Refugio Brisa Marina','Calle Las Magnolias','Bahía Serena','HotelSTD',224,'FLOR'),
('VXZKUVCKQ','Estancia Pradera Dorada','Av. San Martín','Bahía Serena','Posada',179,'NEVA'),
('FVJWBFB','Posada Bosque Claro','Calle Rivera','Bahía Serena','Posada',180,'NEVA'),
('AQUTOQL','Suites Colina Verde','Av. del Bosque','Costa Dorada','All inclusive',86,'TEXA'),
('ASRCRYEPKE','Refugio Puerto Dorado','Calle Rivera','Bahía Serena','HotelSTD',159,'NEVA'),
('JDRKU','Hostal Luna Clara','Av. San Martín','Sierra Blanca','All inclusive',153,'UTAH'),
('WZXSKQYKVG','Portal Mar Serena','Av. Central','Costa Dorada','Posada',129,'UTAH'),
('EDHCTIQGKU','Residencial Amanecer','Calle Los Aromos','Lago Verde','Posada',179,'FLOR'),
('ZUFQUVB','Estancia Puerto Dorado','Calle Los Olivos','Colonia Alta','Posada',203,'FLOR'),
('SHHWVP','Suites Jardín Secreto','Av. Horizonte','Colonia Alta','HotelSTD',263,'CALI'),
('RVFRSW','Rincón Amanecer','Calle Jacarandá','Colonia Alta','HotelSTD',95,'TEXA'),
('VAJXQWQZ','Hotel del Lago','Av. de la Colina','Costa Dorada','All inclusive',170,'UTAH'),
('TONQPNGB','Portal La Cascada','Calle Las Acacias','Santa Rosa','HotelSTD',266,'FLOR'),
('IVVJRBVEI','Residencial Sol Naciente','Calle Los Aromos','Prado Norte','All inclusive',103,'NEVA'),
('XVECIKOPWY','Suites Costa Serena','Calle del Faro','Prado Norte','HotelSTD',289,'UTAH'),
('TQSTRV','Portal Costa Serena','Av. Horizonte','Villa Verde','All inclusive',295,'NEVA'),
('YICQKICHS','Mirador Mar Serena','Av. Las Palmeras','Bahía Serena','All inclusive',98,'UTAH'),
('TGFNYJJXO','Hostal Amanecer','Av. del Puerto','Valle Azul','All inclusive',300,'UTAH'),
('MWBCWLQIMY','Refugio Monte Azul','Calle del Faro','Valle Azul','Posada',207,'UTAH'),
('CRSULC','Refugio La Cascada','Calle del Parque','Puerto Claro','All inclusive',192,'UTAH'),
('XYXGBB','Suites Luna Clara','Calle del Parque','Valle Azul','All inclusive',82,'UTAH'),
('OGCWLQZGQN','Hotel Sol Naciente','Calle Las Acacias','Villa Verde','HotelSTD',162,'CALI'),
('MRJMPYISM','Hotel Cumbre Alta','Calle Los Olivos','Sierra Blanca','HotelSTD',81,'UTAH'),
('QYXJRV','Mirador Costa Serena','Calle del Faro','Puerto Claro','HotelSTD',68,'FLOR'),
('OOFUNG','Hostal Mar Serena','Av. Libertad','Valle Azul','HotelSTD',162,'CALI'),
('CNACK','Refugio Costa Serena','Calle Los Olivos','Prado Norte','All inclusive',73,'FLOR'),
('PBELNBWQJ','Hostal Monte Azul','Calle del Parque','Villa Verde','All inclusive',214,'CALI'),
('SMJFDHMTRO','Mirador Colina Verde','Av. Horizonte','San Ignacio','Posada',81,'FLOR'),
('RBQFNADTMD','Estancia Mar Serena','Calle Los Aromos','Sierra Blanca','HotelSTD',172,'CALI'),
('WFHFF','Rincón Costa Serena','Av. Libertad','Costa Dorada','HotelSTD',206,'NEVA'),
('XAFQBTX','Residencial Puerto Dorado','Calle Los Tilos','Lago Verde','Posada',168,'TEXA'),
('XFQWS','Mirador Sol Naciente','Calle Los Olivos','Costa Dorada','HotelSTD',144,'UTAH'),
('DALEXEJFS','Estancia del Lago','Av. Costanera','Colonia Alta','All inclusive',75,'FLOR'),
('HDBPJBV','Portal Brisa Marina','Calle Los Tilos','Puerto Claro','Posada',266,'FLOR'),
('XDOZOCSRW','Residencial Bosque Claro','Calle Jacarandá','Valle Azul','Posada',273,'FLOR'),
('TLWGZUJ','Portal del Lago','Av. San Martín','Prado Norte','Posada',266,'TEXA'),
('CKEACR','Rincón La Cascada','Av. del Puerto','Colonia Alta','All inclusive',105,'UTAH'),
('AGNBZVVB','Suites Mar Serena','Av. de la Colina','Villa Verde','Posada',224,'CALI'),
('UNJFQWG','Posada Bosque Claro','Av. Las Palmeras','Santa Rosa','All inclusive',174,'CALI'),
('MSNKLJEK','Hotel Puerto Dorado','Calle del Parque','Bahía Serena','All inclusive',293,'FLOR'),
('XTNXFH','Mirador del Lago','Av. Libertad','Santa Rosa','HotelSTD',128,'FLOR'),
('PXDGO','Hostal Cumbre Alta','Calle Los Tilos','Monte Claro','Posada',218,'UTAH'),
('TETWPMGZCB','Rincón Sol Naciente','Calle Las Acacias','Lago Verde','Posada',172,'UTAH'),
('RFVBAIVHY','Residencial Jardín Secreto','Av. San Martín','San Ignacio','Posada',270,'FLOR'),
('VEGIJHKOS','Residencial Sol Naciente','Calle Los Tilos','Bahía Serena','Posada',270,'TEXA'),
('BMSQSXSRZ','Hotel Sol Naciente','Calle del Mirador','Bahía Serena','HotelSTD',90,'TEXA'),
('RMMFDB','Refugio Camino Real','Av. Libertad','Colonia Alta','Posada',235,'NEVA'),
('BCGZCXZ','Posada Brisa Marina','Av. Horizonte','San Ignacio','Posada',209,'CALI'),
('XGPCXP','Residencial Sol Naciente','Av. Costanera','Villa Verde','Posada',107,'UTAH'),
('RTFQN','Residencial Monte Azul','Calle Jacarandá','Puerto Claro','HotelSTD',151,'UTAH'),
('OARXNB','Refugio Sol Naciente','Calle del Faro','Puerto Claro','HotelSTD',287,'UTAH'),
('OPKRYI','Posada del Lago','Calle Los Olivos','Lago Verde','All inclusive',119,'UTAH'),
('KLPHROOS','Posada Costa Serena','Av. Las Palmeras','Santa Rosa','All inclusive',243,'CALI'),
('FCYHKAB','Mirador Luna Clara','Calle Jacarandá','San Ignacio','All inclusive',223,'TEXA'),
('YJDCKTXYR','Hostal Río Claro','Calle del Faro','Sierra Blanca','HotelSTD',119,'UTAH'),
('ZMDDE','Portal del Lago','Calle Las Magnolias','Santa Rosa','Posada',261,'FLOR'),
('AJYNQ','Residencial Río Claro','Calle del Faro','Sierra Blanca','All inclusive',170,'NEVA'),
('XWVEDPPPQJ','Hotel Colina Verde','Av. Central','Sierra Blanca','All inclusive',62,'UTAH'),
('ZUFNH','Portal Amanecer','Calle Las Magnolias','Colonia Alta','All inclusive',250,'NEVA'),
('RXQAIYPHAT','Mirador Jardín Secreto','Calle Las Magnolias','Valle Azul','Posada',259,'TEXA'),
('YFTUGYSZU','Hostal Costa Serena','Av. Costanera','Sierra Blanca','All inclusive',179,'TEXA'),
('XLLIKYVYAY','Refugio Costa Serena','Av. del Lago','Prado Norte','All inclusive',100,'TEXA'),
('QQWVEJP','Estancia Valle Escondido','Calle del Faro','Sierra Blanca','HotelSTD',162,'FLOR'),
('UNPKF','Mirador Monte Azul','Av. San Martín','Colonia Alta','Posada',289,'NEVA'),
('MAEVP','Suites Monte Azul','Av. del Lago','Costa Dorada','HotelSTD',268,'UTAH'),
('ILRLV','Posada Río Claro','Calle del Faro','Bahía Serena','Posada',77,'NEVA'),
('COLVEHG','Estancia Colina Verde','Calle Rivera','Colonia Alta','HotelSTD',230,'FLOR'),
('PTWZCW','Portal Colina Verde','Calle Los Olivos','Lago Verde','HotelSTD',119,'CALI'),
('PZBQDNCKZA','Residencial Costa Serena','Calle Los Tilos','Costa Dorada','HotelSTD',221,'CALI'),
('FJSKBDTYN','Hotel Camino Real','Calle del Faro','Valle Azul','HotelSTD',294,'FLOR'),
('IUYIJ','Mirador Monte Azul','Av. San Martín','Prado Norte','HotelSTD',68,'CALI'),
('JMBGCU','Mirador Amanecer','Av. del Puerto','Valle Azul','Posada',216,'TEXA'),
('OQHTZHFR','Refugio Luna Clara','Calle Jacarandá','Valle Azul','HotelSTD',78,'NEVA'),
('YJBTUFSRQ','Rincón Camino Real','Av. Horizonte','Costa Dorada','All inclusive',202,'CALI'),
('GFYOG','Refugio Jardín Secreto','Calle Los Aromos','Costa Dorada','All inclusive',268,'TEXA'),
('FDDVUF','Residencial Monte Azul','Av. San Martín','Puerto Claro','HotelSTD',140,'UTAH'),
('ZBNSHTA','Posada Costa Serena','Calle Jacarandá','Valle Azul','All inclusive',106,'UTAH'),
('AOZKTWKKEQ','Posada del Lago','Av. Libertad','San Ignacio','Posada',206,'TEXA'),
('NPJDQRXR','Estancia La Cascada','Av. Costanera','Sierra Blanca','Posada',178,'UTAH'),
('FAUQZGTS','Suites Bosque Claro','Av. Central','Monte Claro','All inclusive',110,'FLOR'),
('PZBWAIS','Residencial Puerto Dorado','Calle Rivera','Sierra Blanca','Posada',260,'CALI'),
('JKPUNCRA','Estancia Piedra Blanca','Calle Los Olivos','Santa Rosa','All inclusive',202,'FLOR'),
('ZMSIMADF','Refugio Mar Serena','Calle del Parque','Monte Claro','All inclusive',135,'FLOR'),
('ANIGWO','Suites Bosque Claro','Av. de la Colina','Bahía Serena','Posada',255,'FLOR'),
('UUKACRDFWL','Refugio Amanecer','Calle Los Tilos','San Ignacio','HotelSTD',257,'FLOR'),
('OBLOTWM','Portal Costa Serena','Calle Los Tilos','Villa Verde','All inclusive',117,'UTAH'),
('YYKFQ','Residencial La Cascada','Av. Central','Sierra Blanca','All inclusive',175,'NEVA'),
('RKQXJWNRPF','Hotel Puerto Dorado','Calle Los Aromos','Costa Dorada','HotelSTD',93,'FLOR'),
('CEBHEOJHUR','Hostal Amanecer','Calle del Mirador','Prado Norte','All inclusive',113,'NEVA'),
('YGRCAESJ','Mirador Luna Clara','Calle Los Olivos','Villa Verde','Posada',108,'CALI'),
('WODKMUYIKT','Rincón Jardín Secreto','Calle Las Acacias','Monte Claro','Posada',171,'CALI'),
('NRCQO','Hostal Amanecer','Calle del Parque','Costa Dorada','HotelSTD',275,'CALI'),
('EOVRKTL','Rincón Valle Escondido','Av. Costanera','Santa Rosa','All inclusive',100,'CALI'),
('YMZXYPJOE','Posada Luna Clara','Av. Libertad','Lago Verde','HotelSTD',192,'FLOR'),
('GVDBKPG','Refugio Valle Escondido','Av. de la Colina','Lago Verde','Posada',130,'FLOR'),
('CDUEL','Hotel Jardín Secreto','Av. Central','San Ignacio','All inclusive',98,'CALI'),
('AHNQVKDU','Portal Camino Real','Av. Horizonte','Santa Rosa','HotelSTD',283,'UTAH'),
('DDKWXRIC','Rincón Bosque Claro','Calle del Faro','Sierra Blanca','Posada',249,'UTAH'),
('RQIAIFC','Suites La Cascada','Calle Las Magnolias','Colonia Alta','All inclusive',265,'NEVA'),
('AZDJZQYNYC','Hostal Río Claro','Av. del Bosque','Sierra Blanca','All inclusive',141,'CALI'),
('FHSYYT','Suites Río Claro','Av. del Bosque','Valle Azul','Posada',134,'TEXA'),
('PPEBW','Hotel Colina Verde','Av. Libertad','Monte Claro','HotelSTD',273,'NEVA'),
('MODVYFRWPR','Portal Mar Serena','Av. Las Palmeras','Colonia Alta','HotelSTD',105,'NEVA'),
('OAEIGZIO','Portal La Cascada','Av. Horizonte','Santa Rosa','HotelSTD',171,'CALI'),
('HAJNXFKX','Rincón Luna Clara','Calle del Parque','Valle Azul','All inclusive',199,'CALI'),
('FEBBRTBL','Hotel del Lago','Calle Los Olivos','Santa Rosa','HotelSTD',98,'NEVA'),
('EYDGXQHO','Suites Piedra Blanca','Calle del Faro','Bahía Serena','All inclusive',117,'NEVA'),
('JVGCMS','Posada Sol Naciente','Av. San Martín','Puerto Claro','HotelSTD',129,'FLOR'),
('AAPZRLVE','Hostal Mar Serena','Calle Las Acacias','Bahía Serena','All inclusive',234,'TEXA'),
('RMJXFIX','Estancia Monte Azul','Calle Jacarandá','Lago Verde','All inclusive',177,'TEXA'),
('GVCGAUUX','Refugio Bahía Azul','Calle del Faro','Colonia Alta','All inclusive',227,'CALI'),
('GTRDRQAZVC','Portal Amanecer','Av. Las Palmeras','Sierra Blanca','All inclusive',78,'CALI'),
('MPOPNKRL','Estancia Cumbre Alta','Av. Horizonte','San Ignacio','Posada',176,'CALI'),
('DDYPDOMP','Posada Piedra Blanca','Av. Central','Bahía Serena','All inclusive',254,'CALI'),
('DJNYGLEV','Hostal Monte Azul','Calle del Mirador','Monte Claro','Posada',214,'UTAH'),
('ZOSUPRKUWL','Estancia Colina Verde','Av. del Bosque','Monte Claro','HotelSTD',258,'TEXA'),
('SRBZMV','Hotel Río Claro','Calle del Mirador','Prado Norte','Posada',298,'TEXA'),
('GPBSEOGMCI','Hotel Mar Serena','Av. del Lago','Lago Verde','All inclusive',110,'UTAH'),
('UTTBE','Suites Piedra Blanca','Av. del Puerto','San Ignacio','All inclusive',143,'FLOR'),
('OOEYXI','Suites Colina Verde','Av. Costanera','Costa Dorada','HotelSTD',299,'TEXA'),
('OIVWCHCNK','Hostal Luna Clara','Calle Los Tilos','Prado Norte','Posada',227,'UTAH'),
('KHLAJFPWB','Mirador Costa Serena','Calle del Faro','Lago Verde','HotelSTD',183,'NEVA'),
('VWYAKIOQUU','Residencial La Cascada','Calle del Faro','Villa Verde','Posada',134,'FLOR'),
('DNYHUFBI','Mirador Piedra Blanca','Calle Los Aromos','Puerto Claro','All inclusive',147,'NEVA'),
('SRCWHPFDMY','Portal Mar Serena','Calle Rivera','Puerto Claro','Posada',86,'FLOR'),
('NTUSG','Suites La Cascada','Calle Los Tilos','Costa Dorada','HotelSTD',261,'UTAH'),
('JIAET','Posada Colina Verde','Calle Jacarandá','Monte Claro','All inclusive',76,'FLOR'),
('ROPOW','Posada Puerto Dorado','Av. Horizonte','Prado Norte','Posada',220,'NEVA'),
('TNUYHKNPT','Estancia Amanecer','Av. del Bosque','Monte Claro','Posada',288,'FLOR'),
('QUQIAYSVO','Posada Sol Naciente','Calle Los Olivos','Prado Norte','All inclusive',266,'FLOR'),
('MEXNE','Refugio Brisa Marina','Calle del Parque','San Ignacio','HotelSTD',226,'TEXA'),
('IMRCYS','Mirador Camino Real','Av. San Martín','Lago Verde','Posada',62,'TEXA'),
('SWAGB','Refugio Bosque Claro','Av. Las Palmeras','Monte Claro','Posada',236,'FLOR'),
('FQDYNDYR','Posada Camino Real','Calle del Faro','Costa Dorada','Posada',132,'UTAH'),
('WUCGQ','Estancia Sol Naciente','Calle Las Acacias','Colonia Alta','All inclusive',290,'CALI'),
('KZNFO','Mirador Bosque Claro','Av. del Lago','Lago Verde','HotelSTD',98,'TEXA'),
('CEOITLLI','Estancia Pradera Dorada','Av. Costanera','Puerto Claro','HotelSTD',223,'UTAH'),
('BVTDVAXFE','Residencial Luna Clara','Av. Las Palmeras','Prado Norte','All inclusive',62,'TEXA'),
('KHZUZG','Residencial Luna Clara','Calle del Mirador','San Ignacio','All inclusive',153,'CALI'),
('YRWLHRXSZE','Hostal Monte Azul','Calle Las Magnolias','Costa Dorada','Posada',233,'TEXA'),
('IVBFDIBPK','Mirador Bosque Claro','Av. Las Palmeras','Bahía Serena','HotelSTD',272,'NEVA'),
('LUNGVHKMOI','Posada Bahía Azul','Av. del Lago','Villa Verde','Posada',272,'FLOR'),
('TOXCXQGSXE','Mirador Puerto Dorado','Calle del Mirador','Valle Azul','All inclusive',284,'FLOR'),
('QCHZTR','Hotel La Cascada','Calle Rivera','Puerto Claro','All inclusive',288,'TEXA'),
('VMWBYBHHT','Posada Sol Naciente','Av. del Bosque','Lago Verde','Posada',187,'NEVA'),
('VUKBJQARZP','Portal Cumbre Alta','Av. Central','Sierra Blanca','Posada',234,'FLOR'),
('RWVYCOPX','Hostal Luna Clara','Av. del Lago','San Ignacio','All inclusive',175,'FLOR'),
('OJJZK','Rincón Luna Clara','Calle del Faro','Lago Verde','All inclusive',82,'UTAH'),
('HBLWYCMB','Hostal Sol Naciente','Calle Los Aromos','Monte Claro','HotelSTD',286,'CALI'),
('YYQCQWVFZB','Hotel Piedra Blanca','Calle del Parque','Santa Rosa','HotelSTD',210,'FLOR'),
('ONFFGC','Rincón Jardín Secreto','Av. del Lago','Villa Verde','Posada',194,'FLOR'),
('EMCPZVSX','Suites Bahía Azul','Calle Los Tilos','San Ignacio','Posada',277,'FLOR'),
('MYTTQTV','Portal Camino Real','Calle Los Aromos','Lago Verde','HotelSTD',204,'NEVA'),
('GUZXN','Hostal Piedra Blanca','Calle Los Tilos','Santa Rosa','HotelSTD',207,'TEXA'),
('QSAPT','Mirador Mar Serena','Calle Los Olivos','Colonia Alta','HotelSTD',205,'CALI'),
('TECFCL','Hotel Cumbre Alta','Calle del Parque','Lago Verde','All inclusive',280,'UTAH'),
('UDZDV','Rincón Costa Serena','Av. Costanera','Prado Norte','All inclusive',185,'CALI'),
('VMJMIPY','Refugio Costa Serena','Av. Libertad','Bahía Serena','All inclusive',140,'NEVA'),
('WGERXYXSAV','Hotel Brisa Marina','Av. Horizonte','Valle Azul','All inclusive',233,'CALI'),
('SRIJCJXB','Estancia Monte Azul','Calle Los Olivos','Costa Dorada','HotelSTD',162,'UTAH'),
('YWOVD','Hotel Sol Naciente','Calle del Mirador','Prado Norte','HotelSTD',93,'UTAH'),
('IRXGXSTM','Rincón Bahía Azul','Calle Rivera','Puerto Claro','All inclusive',276,'FLOR'),
('TTZITRZL','Rincón Bosque Claro','Calle Los Aromos','Colonia Alta','All inclusive',196,'FLOR'),
('GNLBVGSTNS','Hostal del Lago','Av. Costanera','Colonia Alta','HotelSTD',139,'UTAH'),
('HFVWZXLEF','Residencial Costa Serena','Calle Las Magnolias','Sierra Blanca','All inclusive',250,'TEXA'),
('BORGJX','Hostal Bahía Azul','Av. San Martín','Santa Rosa','Posada',90,'FLOR'),
('AQCZDI','Residencial Costa Serena','Calle del Parque','Villa Verde','All inclusive',143,'TEXA'),
('KNVWPL','Residencial Cumbre Alta','Av. Libertad','Colonia Alta','HotelSTD',70,'TEXA'),
('VPSXSOO','Posada Sol Naciente','Calle del Faro','Monte Claro','Posada',115,'UTAH'),
('ZOBVV','Posada del Lago','Av. Horizonte','Monte Claro','HotelSTD',173,'NEVA'),
('EVBBZGO','Posada Monte Azul','Av. Las Palmeras','Sierra Blanca','All inclusive',193,'NEVA'),
('CAFAUWFYL','Hotel Puerto Dorado','Calle Jacarandá','Santa Rosa','HotelSTD',277,'FLOR'),
('ILSTQGPDT','Residencial Bosque Claro','Av. San Martín','Valle Azul','HotelSTD',250,'FLOR'),
('XXDQUVGQMW','Estancia Valle Escondido','Calle Los Aromos','Lago Verde','All inclusive',234,'FLOR'),
('CWVQUZB','Residencial Luna Clara','Av. San Martín','Monte Claro','HotelSTD',229,'UTAH'),
('UPKZHNO','Residencial Jardín Secreto','Calle Los Tilos','Lago Verde','All inclusive',234,'NEVA'),
('HXEJORJEGY','Hotel Luna Clara','Calle Rivera','San Ignacio','Posada',286,'CALI'),
('XQNQD','Residencial Luna Clara','Calle del Parque','San Ignacio','HotelSTD',145,'NEVA'),
('SQIYJASXWH','Refugio Río Claro','Calle Rivera','Villa Verde','All inclusive',156,'CALI'),
('FHHWVU','Rincón Jardín Secreto','Av. Horizonte','Sierra Blanca','All inclusive',68,'CALI'),
('OCRVEB','Refugio Pradera Dorada','Av. Horizonte','Villa Verde','All inclusive',254,'NEVA'),
('RPIXMJ','Suites del Lago','Calle Los Tilos','Costa Dorada','HotelSTD',187,'CALI'),
('HAYOMCI','Mirador Piedra Blanca','Av. del Puerto','Prado Norte','HotelSTD',182,'FLOR'),
('CWNAMN','Estancia Costa Serena','Av. del Puerto','Costa Dorada','HotelSTD',91,'FLOR'),
('JCDLJTASM','Hostal Bahía Azul','Calle Los Tilos','Sierra Blanca','HotelSTD',252,'UTAH'),
('AJHFIWC','Suites Costa Serena','Calle del Mirador','Santa Rosa','All inclusive',226,'FLOR'),
('DNNRZLABHT','Estancia Sol Naciente','Av. del Bosque','Prado Norte','All inclusive',84,'CALI'),
('MLBQCPK','Mirador Brisa Marina','Calle del Parque','Valle Azul','HotelSTD',284,'UTAH'),
('QEGVHE','Hotel Pradera Dorada','Calle del Mirador','Valle Azul','All inclusive',292,'FLOR'),
('XXYEXM','Estancia Brisa Marina','Calle Las Magnolias','Colonia Alta','Posada',181,'NEVA'),
('MCVWVFAOE','Residencial La Cascada','Calle del Parque','Santa Rosa','HotelSTD',271,'NEVA'),
('LCJGI','Residencial Pradera Dorada','Av. San Martín','Puerto Claro','All inclusive',230,'CALI'),
('ERNELSRFFA','Rincón Camino Real','Calle Los Tilos','Santa Rosa','HotelSTD',130,'UTAH'),
('TQYKTK','Refugio Pradera Dorada','Calle Rivera','Prado Norte','All inclusive',65,'TEXA'),
('HZVTKB','Estancia Río Claro','Calle del Mirador','Prado Norte','Posada',274,'CALI'),
('ICCNPGASG','Suites Amanecer','Calle del Mirador','Costa Dorada','HotelSTD',195,'CALI'),
('ZFWSDCNQN','Mirador Cumbre Alta','Calle Las Acacias','San Ignacio','All inclusive',289,'FLOR'),
('ZDWBKQXKA','Mirador Río Claro','Av. Costanera','Colonia Alta','Posada',98,'NEVA'),
('EIURK','Refugio Cumbre Alta','Av. Las Palmeras','Santa Rosa','HotelSTD',241,'NEVA');