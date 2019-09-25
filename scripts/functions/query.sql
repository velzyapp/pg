set search_path=velzy;
create function query(
	collection text,
	criteria jsonb default null,
	limiter int default 100,
	page int default 0,
	order_by text default 'id',
	order_dir text default 'asc'
)
returns table(
	id bigint,
	body jsonb,
	created_at timestamptz,
	updated_at timestamptz
)
as $$
declare
	offsetter int := page * limiter;
	where_clause text default '';
begin

	if(criteria is not null) then
		where_clause = format('where body @> %L', criteria);
	end if;

	return query
	execute format('
		select id, body, created_at, updated_at from %s.%s %s
		order by %s %s
		limit %s
		offset %s
','public',collection, where_clause, order_by, order_dir, limiter, offsetter);

end;
$$ language plpgsql;
