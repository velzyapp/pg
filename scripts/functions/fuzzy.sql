set search_path=velzy;
create function fuzzy(
	collection varchar,
	key varchar,
	term varchar,
	schema varchar default 'velzy'
)
returns table(
	id bigint,
	body jsonb,
	created_at timestamptz
)
as $$
begin
	return query
	execute format('
	select id, body, created_at from %s.%s
	where body ->> %L ~* %L;
',schema,collection, key, term);

end;
$$ language plpgsql;
