set search_path=velzy;
drop function if exists save(text, jsonb,text[],text);
create function save(
	collection text,
	doc jsonb,
	search text[] = array['name','email','first','first_name','last','last_name','description','title','city','state','address','street', 'company'],
	schema text default 'velzy',
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

    --this is dumb, but I need to make sure the key is merged
    --nextval is transactional so it won't be repeated
    --this is so hacky... Craig... HELP>>>
    next_key := nextval(pg_get_serial_sequence(concat(schema,'.', collection), 'id'));

    --merge the new id into the JSON
    select(doc || format('{"id": %s}', next_key::text)::jsonb) into res;

    --save it, making sure the new id is also the actual id :)
		execute format('insert into %s.%s (id, body) values (%s, %L) returning *', schema,collection, next_key, res) into saved;

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
