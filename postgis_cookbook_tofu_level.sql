
-- calcular a extensão dos colectores por freguesia

SELECT  row_number() OVER () AS id, 
ST_Intersection(c.the_geom, r.the_geom) as geom,c."EXTENSAO" as extensao, r."Freguesia" as freg
FROM "Rede_Colectora" AS c 
JOIN "riomaior" AS r 
ON ST_Intersects(c.the_geom,r.the_geom)

-- calcular a extensão das condutas de água por freguesia

select 
row_number() over () as id,
st_intersection(a.the_geom, r.the_geom) as geom,
a."compri" as extensao,
r."Freguesia" as freg
from
"condutas_SAA" as a join "riomaior" as r on st_intersects(a.the_geom,r.the_geom)



--calcular dados a uma determinada distância de um ponto
select *, st_distance( the_geom, st_geometryfromtext('POINT(-67769 -37446)',3763)) as distancia
from "tabela" where st_dwithin( the_geom, st_geometryfromtext('POINT(-67769 -37446)',3763),2000)
--3763 SRS • 2000 distância definida


--Calcular o comprimento das linhas da REN dentro do Concelho de Rio Maior em km.
--tabelas "ren_line" e "riomaior"
select
st_length(st_union((st_intersection(a."the_geom", b."the_geom"))))/1000
from "ren_line" a, "riomaior" b
where st_intersects(a."the_geom", b."the_geom")

--selecionar dados within a point, juntamente com buffer e union
select row_number () over () as id, st_union(st_buffer(the_geom,10)) as geom
from "Rede_Viaria_Class" where st_dwithin( the_geom, st_geometryfromtext('POINT(-67178 -35386)',3763),2000)


--clip auto de dados
select c.gid as gid, c."LABEL" as label, c."CHAVE" as chave, b.dicofre as dicofre, st_intersection(c.the_geom, b.the_geom) as geom
from 
"Cadastro" as c,
"CAOP2010" as b
where c."CHAVE" like '141409%' and b.dicofre like '141412'
and st_intersects(c.the_geom,b.the_geom)


-- transformar coordenadas POSTGIS
-- criar tabela nova com o crs definido
SELECT AddGeometryColumn( 'planet_osm_line', 'etrs_tm06', 3763, 'LINESTRING', 2);
  
-- transformar (geometrycol, new EPSG)  
UPDATE planet_osm_line SET etrs_tm06 = transform(way, 3763);  

-- ## OSM + POSTGIS ##

-- criar uma tabela para isolar as estradas
create table roads as
	select osm_id, highway, name, ref, way as geom
	from planet_osm_line
	where highway is not null or ref is not null

-- criar tabela de merge
-- fazer merge às features que se intersectam e tem o mesmo nome
create table roads_merge as
(
select r1.osm_id, r1.highway, r1.name, r1.ref, st_union(r1.geom, r2.geom) as geom from planet_osm_line r1, planet_osm_line r2
where r1.osm_id <> r2.osm_id and st_intersects (st_buffer(r1.geom, 10), st_buffer(r2.geom, 10)) and r1.name = r2.name)

-- fazer o mesmo para as linhas de referencia "r1.ref = r2.ref" and name is not null
-- para que não se misturem as que tem dados no nome
insert into roads_merge (osm_id, highway, name, ref, geom)
	select r1.osm_id, r1.highway, r1.name, r1.ref, st_union(r1.geom, r2.geom)
	from roads r1, roads r2
	where r1.osm_id <> r2.osm_id and st_intersects (st_buffer(r1.geom, 10), st_buffer(r2.geom, 10))
	and r1.ref = r2.ref and r1.name is not null


-- inserir as single feature da BD
insert into roads_merge (osm_id, highway, name, ref, geom)
	select r1.osm_id, r1.highway, r1.name, r1.way as geom
	from roads r1, roads r2
	where r1.osm_id <> r2.osm_id and st_disjoint (r1.way, r2.way) and r1.name <> r2.name


-- comprimento da intersecção com inserção de dados, espero eu :\

insert into polygon (osm_id, highway, name, ref, geom)
	select r.osm_id, r.highway, r.name, r.geom
	from roads r, polygon p
	where st_intersects (r.geom, p.geom) and st_length(st_intersection(r.geom, p.geom)) > 6


-- só falta o código para o edificios, join simples - espero - :|

