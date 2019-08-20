drop function if exists find(varchar,jsonb,int,varchar);
set search_path=velzy;
create function find(
	collection varchar,
	term jsonb,
	limiter int default 100,
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
		where body @> %L
		limit %s;
',schema,collection, term, limiter);

end;
$$ language plpgsql;
