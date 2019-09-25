set search_path=velzy;
create function starts_with(
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
	search_param text := term || '%';
begin

	-- ensure we have the lookup column created if it doesn't already exist
	perform velzy.create_lookup_column(collection => collection, schema => schema, key => key);

	return query
	execute format('select id, body, created_at from %s.%s where %s ilike %L',schema,collection,'lookup_' || key,search_param);
end;
$$ language plpgsql;
