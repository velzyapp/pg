set search_path=velzy;
drop function if exists modify(varchar, int, jsonb, varchar);
create function modify(
	collection varchar,
	id int,
	set jsonb,
	schema varchar default 'velzy',
	out res jsonb
)
as $$

begin
	-- join it
	execute format('select body || %L from %s.%s where id=%s', set,schema,collection, id) into res;

	-- save it - this will also update the search
	perform velzy.save(collection => collection, doc => res);

end;

$$ language plpgsql;
