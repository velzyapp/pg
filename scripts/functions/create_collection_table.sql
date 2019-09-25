set search_path=velzy;
drop function if exists create_collection(varchar);
create function create_collection(
	collection varchar,
	out res jsonb
)
as $$

begin
	res := '{"created": false, "message": null}';
	-- see if table exists first
  if not exists (select 1 from information_schema.tables where table_schema = 'public' AND table_name = collection) then

		execute format('create table public.%s(
            id bigserial primary key not null,
            body jsonb not null,
            search tsvector,
            created_at timestamptz not null default now(),
            updated_at timestamptz not null default now()
          );',collection);

		--indexing
    execute format('create index idx_search_%s on public.%s using GIN(search)',collection,collection);
    execute format('create index idx_json_%s on public.%s using GIN(body jsonb_path_ops)',collection,collection);

		execute format('create trigger %s_notify_change AFTER INSERT OR UPDATE OR DELETE ON public.%s
		FOR EACH ROW EXECUTE PROCEDURE velzy.notify_change();', collection, collection);

    res := '{"created": true, "message": "Table created"}';

    perform pg_notify('velzy.change',concat(collection, ':table_created:',0));
  else
    res := '{"created": false, "message": "Table exists"}';
    raise debug 'This table already exists';

  end if;

end;
$$
language plpgsql;
