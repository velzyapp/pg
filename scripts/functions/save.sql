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
