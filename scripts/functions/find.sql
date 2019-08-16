set search_path=velzy;
drop function if exists find(varchar, jsonb,varchar);
create function find(
	collection varchar,
	term jsonb,
	schema varchar default 'velzy'
)
returns setof jsonb
as $$
begin
	return query
	execute format('
		select id, body from %s.%s
		where body @> %L;
',schema,collection, term);

end;
$$ language plpgsql;
