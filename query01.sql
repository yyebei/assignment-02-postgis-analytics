/*
  Which bus stop has the largest population within 800 meters? As a rough
  estimation, consider any block group that intersects the buffer as being part
  of the 800 meter buffer.
*/


DROP INDEX IF EXISTS septa_bus_stops_the_geom_idx;
create index septa_bus_stops_the_geom_idx
    on septa_bus_stops
    using GiST(the_geom);

alter table septa_bus_stops
    add column if not exists the_geom geometry(Point, 4326);


update septa_bus_stops
  set the_geom = ST_SetSRID(ST_MakePoint(stop_lon, stop_lat), 4326);


create index if not exists septa_bus_stops__the_geom__32129__idx
    on septa_bus_stops
    using GiST (ST_Transform(the_geom, 32129));


with septa_bus_stop_block_groups as (
  select
     s.stop_id,
     '1500000US' || bg."GEOID10" as geo_id
 from septa_bus_stops as s
 join census_block_groups as bg
     on ST_DWithin(
         ST_Transform(s.the_geom, 32129),
         ST_Transform(bg.the_geom, 32129),
         800
     )
),

septa_bus_stop_surrounding_population as (
    select
        stop_id,
        sum(total) as estimated_pop_800m
    from septa_bus_stop_block_groups as s
    join census_population as p on (s.geo_id = p.id)
    group by stop_id
)

select
    stop_name,
    estimated_pop_800m,
    the_geom
from septa_bus_stop_surrounding_population
join septa_bus_stops using (stop_id)
order by estimated_pop_800m desc
limit 1
