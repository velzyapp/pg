set client_min_messages TO WARNING;
drop schema if exists velzy cascade;
create schema if not exists velzy;
create extension pg_stat_statements with schema velzy;
create extension pgcrypto with schema velzy;

--add tables for users, permissions and possibly API keys
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
set search_path=velzy;

drop function if exists create_lookup_column(varchar,varchar, varchar);
create function create_lookup_column(collection varchar, key varchar, out res bool)
as $$
declare
	column_exists int;
  lookup_key text := 'lookup_' || key;
  schema text := 'public';
begin
		execute format('SELECT count(1)
										FROM information_schema.columns
										WHERE table_name=%L and table_schema=%L and column_name=%L',
									collection,schema,lookup_key) into column_exists;

		if column_exists < 1 then
			-- add the column
			execute format('alter table %s.%s add column %s text', schema, collection, lookup_key);

			-- fill it
			execute format('update %s.%s set %s = body ->> %L', schema, collection, lookup_key, key);

			-- index it
			execute format('create index on %s.%s(%s)', schema, collection, lookup_key);

      -- TODO: drop a trigger on this!
      execute format('CREATE TRIGGER trigger_update_%s_%s
      after update on %s.%s
      for each row
      when (old.body <> new.body)
      execute procedure velzy.update_lookup();'
      ,collection, lookup_key, schema, collection);
		end if;
		res := true;
end;
$$ language plpgsql;
set search_path=velzy;
drop function if exists delete(varchar,int);
create function delete(collection varchar, id int, out res bool)
as $$

begin
		execute format('delete from public.%s where id=%s returning *',collection, id);
		res := true;
end;

$$ language plpgsql;
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
set search_path=velzy;
drop function if exists drop_lookup_columns(text, text);
create function drop_lookup_columns(
	collection text,
	schema text default 'public',
	out res bool
)
as $$
declare lookup text;
begin
		for lookup in execute format('SELECT column_name
										FROM information_schema.columns
										WHERE table_name=%L AND table_schema=%L AND column_name LIKE %L',
									collection,schema,'lookup%') loop
			execute format('alter table %s.%s drop column %I', schema, collection, lookup);
		end loop;

		res := true;
end;
$$ language plpgsql;
set search_path=velzy;
drop function if exists ends_with(text, text, text, text);
create function ends_with(
	collection text,
	key text,
	term text,
	schema text default 'public'
)
returns table(
	id bigint,
	body jsonb,
	created_at timestamptz
)
as $$
declare
	search_param text := '%' || term;
  query_text text := format('select id, body, created_at from %s.%s where %s ilike %L',schema,collection,'lookup_' || key,search_param);
begin

	-- ensure we have the lookup column created if it doesn't already exist
	perform velzy.create_lookup_column(collection => collection, key => key);

	return query
	execute query_text;
end;
$$ language plpgsql;
set search_path=velzy;
create function find_one(
	collection varchar,
	term jsonb,
	schema text default 'public'
)
returns table(
	id bigint,
	body jsonb,
	created_at timestamptz
)
as $$
begin
	return query
	execute format('
		select id, body,created_at from %s.%s
		where body @> %L limit 1;
',schema,collection, term);

end;
$$ language plpgsql;
set search_path=velzy;
create function fuzzy(
	collection text,
	key text,
	term text,
	schema text default 'public'
)
returns table(
	id bigint,
	body jsonb,
	created_at timestamptz
)
as $$
begin
	return query
	execute format('
	select id, body, created_at from %s.%s
	where body ->> %L ~* %L;
',schema,collection, key, term);

end;
$$ language plpgsql;
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
	set search_path=velzy;
	CREATE FUNCTION notify_change()
	RETURNS trigger as $$
	BEGIN
    if(TG_OP = 'UPDATE' and (OLD.body IS NOT DISTINCT from NEW.body)) THEN
      --ignore this because it's a search field setting from the save function
      --and we don't want it to fire
    ELSIF(TG_OP = 'DELETE') THEN
      -- don't return any kind of ID
      perform(select pg_notify('velzy.change',concat(TG_TABLE_NAME,':DELETE:',OLD.id)));
    ELSE
		  perform(select pg_notify('velzy.change',concat(TG_TABLE_NAME,':',TG_OP,':',NEW.id)));
    END IF;
		RETURN NULL;
	END;
  $$ LANGUAGE plpgsql;
set search_path=velzy;
create function query(
	collection text,
	criteria jsonb default null,
	limiter int default 100,
	page int default 0,
	order_by text default 'id',
	order_dir text default 'asc'
)
returns table(
	id bigint,
	body jsonb,
	created_at timestamptz,
	updated_at timestamptz
)
as $$
declare
	offsetter int := page * limiter;
	where_clause text default '';
begin

	if(criteria is not null) then
		where_clause = format('where body @> %L', criteria);
	end if;

	return query
	execute format('
		select id, body, created_at, updated_at from %s.%s %s
		order by %s %s
		limit %s
		offset %s
','public',collection, where_clause, order_by, order_dir, limiter, offsetter);

end;
$$ language plpgsql;
set search_path=velzy;
drop function if exists save(text, jsonb,text[]);
create function save(
	collection text,
	doc jsonb,
	search text[] = array['name','email','first','first_name','last','last_name','description','title','city','state','address','street', 'company'],
	out res jsonb
)
as $$

declare
	doc_id int := doc -> 'id';
  next_key bigint;
	saved record;
	saved_doc jsonb;
	search_key text;
	search_params text;
  search_term text;
  schema text := 'public';
begin
	-- make sure the table exists
	perform velzy.create_collection(collection => collection);

	if (select doc ? 'id') then

		execute format('insert into %s.%s (id, body)
										values (%L, %L)
										on conflict (id)
										do update set body = excluded.body
										returning *',schema,collection, doc -> 'id', doc) into saved;
    res := saved.body;

	else

    --save it, making sure the new id is also the actual id :)
		execute format('insert into %s.%s (body) values (%L) returning *', schema,collection, doc) into saved;
		select(doc || format('{"id": %s}', saved.id::text)::jsonb) into res;
		execute format('update %s.%s set body=%L where id=%s',schema,collection,res,saved.id);
	end if;

	-- do it automatically MMMMMKKK?
	foreach search_key in array search
	loop
		if(res ? search_key) then
      search_term := (res ->> search_key);

      --reset spurious characters and domains to increase search effectiveness
      search_term := replace(search_term, '@',' ');
      search_term := replace(search_term, '.com',' ');
      search_term := replace(search_term, '.net',' ');
      search_term := replace(search_term, '.org',' ');
      search_term := replace(search_term, '.edu',' ');
      search_term := replace(search_term, '.io',' ');

			search_params :=  concat(search_params,' ', search_term);
		end if;
	end loop;
	if search_params is not null then
		execute format('update %s.%s set search=to_tsvector(%L) where id=%s',schema,collection,search_params,saved.id);
	end if;

  --update the updated_at bits no matter what
  execute format('update %s.%s set updated_at = now() where id=%s',schema,collection, saved.id);

end;

$$ language plpgsql;
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
set search_path=velzy;
create function starts_with(
	collection text,
	key text,
	term text,
	schema text default 'public'
)
returns table(
	id bigint,
	body jsonb,
	created_at timestamptz
)
as $$
declare
	search_param text := term || '%';
begin

	-- ensure we have the lookup column created if it doesn't already exist
	perform velzy.create_lookup_column(collection => collection, key => key);

	return query
	execute format('select id, body, created_at from %s.%s where %s ilike %L',schema,collection,'lookup_' || key,search_param);
end;
$$ language plpgsql;
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
		'''public''');

end;
$$ language plpgsql STABLE;
set search_path=velzy;

drop function if exists update_lookup();
create function update_lookup()
returns trigger 
as $$
declare
  lookup_key text;
	json_key text;
begin
	
	for lookup_key in (select column_name from information_schema.columns
										where table_name=TG_TABLE_NAME and table_schema=TG_TABLE_SCHEMA 
										and column_name like 'lookup_%')
	loop 
		json_key := split_part(lookup_key,'_',2);

    execute format('update %s.%s set %s = %L where id=%s',
                    TG_TABLE_SCHEMA, 
                    TG_TABLE_NAME, 
                    lookup_key, new.body ->> json_key, 
                    new.id
                  );
  end loop;
  return new;
end;
$$ language plpgsql;
set client_min_messages TO WARNING;
drop schema if exists velzy cascade;
create schema if not exists velzy;
create extension pg_stat_statements with schema velzy;
create extension pgcrypto with schema velzy;

--add tables for users, permissions and possibly API keys
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
set search_path=velzy;

drop function if exists create_lookup_column(varchar,varchar, varchar);
create function create_lookup_column(collection varchar, key varchar, out res bool)
as $$
declare
	column_exists int;
  lookup_key text := 'lookup_' || key;
  schema text := 'public';
begin
		execute format('SELECT count(1)
										FROM information_schema.columns
										WHERE table_name=%L and table_schema=%L and column_name=%L',
									collection,schema,lookup_key) into column_exists;

		if column_exists < 1 then
			-- add the column
			execute format('alter table %s.%s add column %s text', schema, collection, lookup_key);

			-- fill it
			execute format('update %s.%s set %s = body ->> %L', schema, collection, lookup_key, key);

			-- index it
			execute format('create index on %s.%s(%s)', schema, collection, lookup_key);

      -- TODO: drop a trigger on this!
      execute format('CREATE TRIGGER trigger_update_%s_%s
      after update on %s.%s
      for each row
      when (old.body <> new.body)
      execute procedure velzy.update_lookup();'
      ,collection, lookup_key, schema, collection);
		end if;
		res := true;
end;
$$ language plpgsql;
set search_path=velzy;
drop function if exists delete(varchar,int);
create function delete(collection varchar, id int, out res bool)
as $$

begin
		execute format('delete from public.%s where id=%s returning *',collection, id);
		res := true;
end;

$$ language plpgsql;
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
set search_path=velzy;
drop function if exists drop_lookup_columns(text, text);
create function drop_lookup_columns(
	collection text,
	schema text default 'public',
	out res bool
)
as $$
declare lookup text;
begin
		for lookup in execute format('SELECT column_name
										FROM information_schema.columns
										WHERE table_name=%L AND table_schema=%L AND column_name LIKE %L',
									collection,schema,'lookup%') loop
			execute format('alter table %s.%s drop column %I', schema, collection, lookup);
		end loop;

		res := true;
end;
$$ language plpgsql;
set search_path=velzy;
drop function if exists ends_with(text, text, text, text);
create function ends_with(
	collection text,
	key text,
	term text,
	schema text default 'public'
)
returns table(
	id bigint,
	body jsonb,
	created_at timestamptz
)
as $$
declare
	search_param text := '%' || term;
  query_text text := format('select id, body, created_at from %s.%s where %s ilike %L',schema,collection,'lookup_' || key,search_param);
begin

	-- ensure we have the lookup column created if it doesn't already exist
	perform velzy.create_lookup_column(collection => collection, key => key);

	return query
	execute query_text;
end;
$$ language plpgsql;
set search_path=velzy;
create function find_one(
	collection varchar,
	term jsonb,
	schema text default 'public'
)
returns table(
	id bigint,
	body jsonb,
	created_at timestamptz
)
as $$
begin
	return query
	execute format('
		select id, body,created_at from %s.%s
		where body @> %L limit 1;
',schema,collection, term);

end;
$$ language plpgsql;
set search_path=velzy;
create function fuzzy(
	collection text,
	key text,
	term text,
	schema text default 'public'
)
returns table(
	id bigint,
	body jsonb,
	created_at timestamptz
)
as $$
begin
	return query
	execute format('
	select id, body, created_at from %s.%s
	where body ->> %L ~* %L;
',schema,collection, key, term);

end;
$$ language plpgsql;
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
	set search_path=velzy;
	CREATE FUNCTION notify_change()
	RETURNS trigger as $$
	BEGIN
    if(TG_OP = 'UPDATE' and (OLD.body IS NOT DISTINCT from NEW.body)) THEN
      --ignore this because it's a search field setting from the save function
      --and we don't want it to fire
    ELSIF(TG_OP = 'DELETE') THEN
      -- don't return any kind of ID
      perform(select pg_notify('velzy.change',concat(TG_TABLE_NAME,':DELETE:',OLD.id)));
    ELSE
		  perform(select pg_notify('velzy.change',concat(TG_TABLE_NAME,':',TG_OP,':',NEW.id)));
    END IF;
		RETURN NULL;
	END;
  $$ LANGUAGE plpgsql;
set search_path=velzy;
create function query(
	collection text,
	criteria jsonb default null,
	limiter int default 100,
	page int default 0,
	order_by text default 'id',
	order_dir text default 'asc'
)
returns table(
	id bigint,
	body jsonb,
	created_at timestamptz,
	updated_at timestamptz
)
as $$
declare
	offsetter int := page * limiter;
	where_clause text default '';
begin

	if(criteria is not null) then
		where_clause = format('where body @> %L', criteria);
	end if;

	return query
	execute format('
		select id, body, created_at, updated_at from %s.%s %s
		order by %s %s
		limit %s
		offset %s
','public',collection, where_clause, order_by, order_dir, limiter, offsetter);

end;
$$ language plpgsql;
set search_path=velzy;
drop function if exists save(text, jsonb,text[]);
create function save(
	collection text,
	doc jsonb,
	search text[] = array['name','email','first','first_name','last','last_name','description','title','city','state','address','street', 'company'],
	out res jsonb
)
as $$

declare
	doc_id int := doc -> 'id';
  next_key bigint;
	saved record;
	saved_doc jsonb;
	search_key text;
	search_params text;
  search_term text;
  schema text := 'public';
begin
	-- make sure the table exists
	perform velzy.create_collection(collection => collection);

	if (select doc ? 'id') then

		execute format('insert into %s.%s (id, body)
										values (%L, %L)
										on conflict (id)
										do update set body = excluded.body
										returning *',schema,collection, doc -> 'id', doc) into saved;
    res := saved.body;

	else

    --save it, making sure the new id is also the actual id :)
		execute format('insert into %s.%s (body) values (%L) returning *', schema,collection, doc) into saved;
		select(doc || format('{"id": %s}', saved.id::text)::jsonb) into res;
		execute format('update %s.%s set body=%L where id=%s',schema,collection,res,saved.id);
	end if;

	-- do it automatically MMMMMKKK?
	foreach search_key in array search
	loop
		if(res ? search_key) then
      search_term := (res ->> search_key);

      --reset spurious characters and domains to increase search effectiveness
      search_term := replace(search_term, '@',' ');
      search_term := replace(search_term, '.com',' ');
      search_term := replace(search_term, '.net',' ');
      search_term := replace(search_term, '.org',' ');
      search_term := replace(search_term, '.edu',' ');
      search_term := replace(search_term, '.io',' ');

			search_params :=  concat(search_params,' ', search_term);
		end if;
	end loop;
	if search_params is not null then
		execute format('update %s.%s set search=to_tsvector(%L) where id=%s',schema,collection,search_params,saved.id);
	end if;

  --update the updated_at bits no matter what
  execute format('update %s.%s set updated_at = now() where id=%s',schema,collection, saved.id);

end;

$$ language plpgsql;
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
set search_path=velzy;
create function starts_with(
	collection text,
	key text,
	term text,
	schema text default 'public'
)
returns table(
	id bigint,
	body jsonb,
	created_at timestamptz
)
as $$
declare
	search_param text := term || '%';
begin

	-- ensure we have the lookup column created if it doesn't already exist
	perform velzy.create_lookup_column(collection => collection, key => key);

	return query
	execute format('select id, body, created_at from %s.%s where %s ilike %L',schema,collection,'lookup_' || key,search_param);
end;
$$ language plpgsql;
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
		'''public''');

end;
$$ language plpgsql STABLE;
set search_path=velzy;

drop function if exists update_lookup();
create function update_lookup()
returns trigger 
as $$
declare
  lookup_key text;
	json_key text;
begin
	
	for lookup_key in (select column_name from information_schema.columns
										where table_name=TG_TABLE_NAME and table_schema=TG_TABLE_SCHEMA 
										and column_name like 'lookup_%')
	loop 
		json_key := split_part(lookup_key,'_',2);

    execute format('update %s.%s set %s = %L where id=%s',
                    TG_TABLE_SCHEMA, 
                    TG_TABLE_NAME, 
                    lookup_key, new.body ->> json_key, 
                    new.id
                  );
  end loop;
  return new;
end;
$$ language plpgsql;
