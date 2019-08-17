set search_path=velzy;
drop function if exists ends_with(varchar, varchar, varchar, varchar);
create function ends_with(
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
declare
	search_param text := '%' || term;
  query_text text := format('select id, body, created_at from %s.%s where %s ilike %L',schema,collection,'lookup_' || key,search_param);
begin

	-- ensure we have the lookup column created if it doesn't already exist
	perform velzy.create_lookup_column(collection => collection, schema => schema, key => key);

	return query
	execute query_text;
end;
$$ language plpgsql;
