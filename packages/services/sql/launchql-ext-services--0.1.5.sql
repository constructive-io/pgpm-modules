\echo Use "CREATE EXTENSION launchql-ext-services" to load this file. \quit
CREATE SCHEMA services_public;

CREATE TABLE services_public.services (
 	id uuid PRIMARY KEY DEFAULT ( uuid_generate_v4() ),
	database_id uuid,
	type text,
	name text,
	subdomain hostname,
	domain hostname NOT NULL,
	dbname text,
	data jsonb NOT NULL DEFAULT ( '{}'::jsonb ),
	UNIQUE ( subdomain, domain ) 
);

CREATE INDEX ON services_public.services ( type );

CREATE FUNCTION services_public.add_service ( v_subdomain hostname, v_domain hostname, v_dbname text, v_type text, v_name text DEFAULT NULL, v_database_id uuid DEFAULT NULL ) RETURNS services_public.services AS $EOFCODE$
DECLARE
  svc services_public.services;
BEGIN

  IF (v_name IS NULL) THEN 
    IF (v_subdomain IS NULL) THEN 
      v_name = concat(v_domain);
    ELSE
      v_name = concat(v_subdomain, '.', v_domain);
    END IF;
  END IF;

  INSERT INTO services_public.services 
    (subdomain, domain, name, type, dbname, database_id)
  VALUES 
    (v_subdomain, v_domain, v_name, v_type, v_dbname, v_database_id)
  ON CONFLICT (subdomain, domain)
  DO UPDATE SET 
    database_id = EXCLUDED.database_id,
    name = EXCLUDED.name,
    type = EXCLUDED.type,
    dbname = EXCLUDED.dbname
  RETURNING * INTO svc;

  RETURN svc;
END;
$EOFCODE$ LANGUAGE plpgsql VOLATILE;

CREATE FUNCTION services_public.add_plugin ( v_subdomain hostname, v_domain hostname, v_name text, v_data jsonb ) RETURNS services_public.services AS $EOFCODE$
DECLARE
  svc services_public.services;
  newdata jsonb;
BEGIN

  IF (v_subdomain IS NULL) THEN 
    SELECT * FROM services_public.services
    WHERE 
      subdomain IS NULL
      AND domain = v_domain 
    INTO svc;
  ELSE
    SELECT * FROM services_public.services
    WHERE 
      subdomain = v_subdomain
      AND domain = v_domain 
    INTO svc;
  END IF;


  IF (NOT FOUND) THEN 
    RAISE EXCEPTION 'NOT_FOUND';
  END IF;

  newdata = jsonb_set(svc.data, ARRAY[v_name]::text[], v_data);
  
  UPDATE services_public.services 
    SET data = newdata
  WHERE id = svc.id
  RETURNING * INTO svc;

  RETURN svc;
END;
$EOFCODE$ LANGUAGE plpgsql VOLATILE;

CREATE FUNCTION services_public.add_api_service ( v_subdomain hostname, v_domain hostname, v_dbname text, v_role_name text, v_anon_role text, v_schemas text[], v_name text DEFAULT NULL, v_database_id uuid DEFAULT NULL ) RETURNS services_public.services AS $EOFCODE$
DECLARE
  svc services_public.services;
  datum jsonb = '{}'::jsonb;
BEGIN

  svc = services_public.add_service(
    v_subdomain := v_subdomain,
    v_domain := v_domain,
    v_dbname := v_dbname,
    v_type := 'api',
    v_name := v_name,
    v_database_id := v_database_id
  );

  datum = jsonb_set(
    datum,
    ARRAY['role_name']::text[],
    to_jsonb(v_role_name)
  );

  datum = jsonb_set(
    datum,
    ARRAY['anon_role']::text[],
    to_jsonb(v_anon_role)
  );

  datum = jsonb_set(
    datum,
    ARRAY['schemas']::text[],
    to_jsonb(v_schemas)
  );

  svc = services_public.add_plugin(
    v_subdomain := v_subdomain,
    v_domain := v_domain,
    v_name := 'graphile',
    v_data := datum
  );

  RETURN svc;
END;
$EOFCODE$ LANGUAGE plpgsql VOLATILE;

CREATE FUNCTION services_public.add_renderer ( v_subdomain hostname, v_domain hostname, v_dbname text, v_name text DEFAULT NULL, v_database_id uuid DEFAULT NULL ) RETURNS services_public.services AS $EOFCODE$
BEGIN
  RETURN services_public.add_service(
    v_subdomain := v_subdomain,
    v_domain := v_domain,
    v_dbname := v_dbname,
    v_type := 'renderer',
    v_name := v_name,
    v_database_id := v_database_id
  );
END;
$EOFCODE$ LANGUAGE plpgsql VOLATILE;

CREATE FUNCTION services_public.remove_plugin ( v_subdomain hostname, v_domain hostname, v_name text ) RETURNS services_public.services AS $EOFCODE$
DECLARE
  svc services_public.services;
  newdata jsonb;
BEGIN

  SELECT * FROM services_public.services
  WHERE 
    subdomain = v_subdomain
    AND domain = v_domain 
  INTO svc;

  IF (NOT FOUND) THEN 
    RAISE EXCEPTION 'NOT_FOUND';
  END IF;

  newdata = svc.data - v_name;
  
  UPDATE services_public.services 
    SET data = newdata
  WHERE id = svc.id
  RETURNING * INTO svc;

  RETURN svc;
END;
$EOFCODE$ LANGUAGE plpgsql VOLATILE;