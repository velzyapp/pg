create function get(collection text, did int)
returns table(
id bigint,
body jsonb,
created_at timestamptz,
updated_at timestamptz
)
as $$

begin
	return query
	execute format('select id, body, created_at, updated_at from public.%s where id=%s limit 1',collection, did);
end;

$$ language plpgsql;
