set search_path=velzy;
drop function if exists get(varchar,int);
create function get(collection varchar, id int, out res jsonb)
as $$

begin
		execute format('select body from velzy.%s where id=%s',collection, id) into res;
end;

$$ language plpgsql;
