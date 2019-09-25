set search_path=velzy;
drop function if exists modify(text, int, jsonb, text);
create function modify(
	collection text,
	id int,
	set jsonb,
	schema text default 'public',
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
