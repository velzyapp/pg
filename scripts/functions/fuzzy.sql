set search_path=velzy;
drop function if exists fuzzy(varchar, varchar, varchar,varchar);
create function fuzzy(
	collection varchar,
	key varchar,
	term varchar,
	schema varchar default 'velzy'
)
returns setof jsonb
as $$
begin
	return query
	execute format('
	select body from %s.%s
	where body ->> %L ~* %L;
',schema,collection, key, term);

end;
$$ language plpgsql;
