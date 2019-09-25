set search_path=velzy;
drop function if exists ends_with(text, text, text, text);
create function ends_with(
	collection text,
	key text,
	term text,
	schema text default 'public'
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
