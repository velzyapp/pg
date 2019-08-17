set search_path=velzy;
create function find(
	collection varchar,
	term jsonb,
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
		select id, body,created_at from %s.%s
		where body @> %L;
',schema,collection, term);

end;
$$ language plpgsql;
