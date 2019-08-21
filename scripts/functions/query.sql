CREATE OR REPLACE FUNCTION query(collection text, criteria jsonb default NULL, limiter int default 100, page int default 0, order_by text default 'id', order_dir text default 'asc')
  RETURNS TABLE("id" int8, "body" jsonb, "created_at" timestamptz, "updated_at" timestamptz) AS $BODY$
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
','velzy',collection, where_clause, order_by, order_dir, limiter, offsetter);

end;
$BODY$
  LANGUAGE plpgsql STABLE
  COST 100
  ROWS 1000
