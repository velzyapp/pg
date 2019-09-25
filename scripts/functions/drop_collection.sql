set search_path=velzy;
create function drop_collection(
	collection text,
  out res bool
)
as $$
begin
	execute format('drop table %s.%s cascade;','public',collection);
  perform pg_notify('velzy.change',concat(collection, ':table_dropped:',0));
end;
$$ language plpgsql;
