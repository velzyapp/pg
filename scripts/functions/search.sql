set search_path=velzy;
create function search(collection text, term text)
returns table(
	result jsonb,
	rank float4
)
as $$
declare
  schema text :='public';
begin
	return query
	execute format('select body, ts_rank_cd(search,plainto_tsquery(''"%s"'')) as rank
									from %s.%s
									where search @@ plainto_tsquery(''"%s"'')
									order by ts_rank_cd(search,plainto_tsquery(''"%s"'')) desc'
			,term, schema,collection,term, term);
end;

$$ language plpgsql;
