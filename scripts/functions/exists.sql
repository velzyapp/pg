set search_path=velzy;
drop function if exists "exists"(varchar, text,varchar);
create function "exists"(
	collection varchar,
	term text,
	schema varchar default 'velzy'
)
returns setof jsonb
as $$
declare
	existence bool := false;
begin
	return query
	execute format('
		select body from %s.%s
		where body ? %L;
',schema,collection, term);

end;
$$ language plpgsql;
