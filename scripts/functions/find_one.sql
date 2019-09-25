set search_path=velzy;
create function find_one(
	collection varchar,
	term jsonb,
	schema text default 'public'
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
		where body @> %L limit 1;
',schema,collection, term);

end;
$$ language plpgsql;
