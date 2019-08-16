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
