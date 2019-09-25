set search_path=velzy;
drop function if exists delete(varchar,int);
create function delete(collection varchar, id int, out res bool)
as $$

begin
		execute format('delete from public.%s where id=%s returning *',collection, id);
		res := true;
end;

$$ language plpgsql;
