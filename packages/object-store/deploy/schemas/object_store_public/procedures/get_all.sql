-- Deploy schemas/object_store_public/procedures/get_all to pg

-- requires: schemas/object_store_public/schema
-- requires: schemas/object_store_public/tables/object/table

BEGIN;

CREATE FUNCTION object_store_public.get_all( s_id uuid, id uuid )
    RETURNS TABLE ( path text[], data jsonb )
AS $$ 
DECLARE
  root object_store_public.object;
  pth text[];
  i int;
  
  cid uuid;
  cname text;
  
  rpath text[];
  rdata jsonb;
BEGIN

		SELECT * from object_store_public.object o WHERE o.scope_id = s_id
				AND o.id = get_all.id
	INTO root;
			
	pth = ARRAY[]::text[];
	
  	FOR i IN
  	SELECT * FROM generate_series(1, cardinality(root.kids))
  	LOOP
  	     cid = root.kids[i];
  	     cname = root.ktree[i];
  	     
  	     FOR rpath, rdata IN
  	     SELECT * FROM object_store_public.get_all(s_id, cid)
  	     LOOP 
		      path := ARRAY[cname] || rpath;	
 	  	    data := rdata;
  	 	  	  RETURN next; 	 	     
  	     END LOOP;
  	     
  	END LOOP;

  path := ARRAY[]::text[];	
 	data := root.data; 		
	RETURN next;	


END;
$$
LANGUAGE plpgsql STABLE;

COMMIT;
