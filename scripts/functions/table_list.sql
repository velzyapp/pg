set search_path=velzy;
drop function if exists table_list();
create function table_list()
returns table(
	table_name text,
	row_count int
)
as $$
begin
	return query execute format('
	SELECT relname::text as name,n_live_tup::int as rows
  FROM pg_stat_user_tables
	where schemaname=%s',
		'''velzy''');

end;
$$ language plpgsql;
