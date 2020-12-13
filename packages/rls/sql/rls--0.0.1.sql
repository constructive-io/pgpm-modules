\echo Use "CREATE EXTENSION rls" to load this file. \quit
CREATE SCHEMA rls_public;

GRANT USAGE ON SCHEMA rls_public TO authenticated;

GRANT USAGE ON SCHEMA rls_public TO anonymous;

CREATE SCHEMA rls_private;

GRANT USAGE ON SCHEMA rls_private TO authenticated;

GRANT USAGE ON SCHEMA rls_private TO anonymous;

CREATE FUNCTION rls_private.uuid_generate_v4 (  ) RETURNS uuid AS $EOFCODE$
DECLARE
    new_uuid char(36);
    md5_str char(32);
    md5_str2 char(32);
    uid text;
BEGIN
    md5_str := md5(concat(random(), now()));
    md5_str2 := md5(concat(random(), now()));
    
    new_uuid := concat(
        LEFT (md5('launchql'), 2),
        LEFT (md5(concat(extract(year FROM now()), extract(week FROM now()))), 2),
        substring(md5_str, 1, 4),
        '-',
        substring(md5_str, 5, 4),
        '-4',
        substring(md5_str2, 9, 3),
        '-',
        substring(md5_str, 13, 4),
        '-', 
        substring(md5_str2, 17, 12)
    );
    RETURN new_uuid;
END;
$EOFCODE$ LANGUAGE plpgsql;

CREATE FUNCTION rls_private.uuid_generate_seeded_uuid ( seed text ) RETURNS uuid AS $EOFCODE$
DECLARE
    new_uuid char(36);
    md5_str char(32);
    md5_str2 char(32);
    uid text;
BEGIN
    md5_str := md5(concat(random(), now()));
    md5_str2 := md5(concat(random(), now()));
    
    new_uuid := concat(
        LEFT (md5(seed), 2),
        LEFT (md5(concat(extract(year FROM now()), extract(week FROM now()))), 2),
        substring(md5_str, 1, 4),
        '-',
        substring(md5_str, 5, 4),
        '-4',
        substring(md5_str2, 9, 3),
        '-',
        substring(md5_str, 13, 4),
        '-', 
        substring(md5_str2, 17, 12)
    );
    RETURN new_uuid;
END;
$EOFCODE$ LANGUAGE plpgsql VOLATILE;

CREATE FUNCTION rls_private.seeded_uuid_related_trigger (  ) RETURNS trigger AS $EOFCODE$
DECLARE
    _seed_column text := to_json(NEW) ->> TG_ARGV[1];
BEGIN
    IF _seed_column IS NULL THEN
        RAISE EXCEPTION 'UUID seed is NULL on table %', TG_TABLE_NAME;
    END IF;
    NEW := NEW #= (TG_ARGV[0] || '=>' || "rls_private".uuid_generate_seeded_uuid(_seed_column))::hstore;
    RETURN NEW;
END;
$EOFCODE$ LANGUAGE plpgsql VOLATILE;

GRANT EXECUTE ON FUNCTION rls_private.uuid_generate_v4 TO PUBLIC;

GRANT EXECUTE ON FUNCTION rls_private.uuid_generate_seeded_uuid TO PUBLIC;

GRANT EXECUTE ON FUNCTION rls_private.seeded_uuid_related_trigger TO PUBLIC;

CREATE TABLE rls_public.users (
  
);

ALTER TABLE rls_public.users DISABLE ROW LEVEL SECURITY;

ALTER TABLE rls_public.users ADD COLUMN  id uuid;

ALTER TABLE rls_public.users ALTER COLUMN id SET NOT NULL;

ALTER TABLE rls_public.users ALTER COLUMN id SET DEFAULT rls_private.uuid_generate_v4();

ALTER TABLE rls_public.users ADD CONSTRAINT users_pkey PRIMARY KEY ( id );

ALTER TABLE rls_public.users ADD COLUMN  type int;

ALTER TABLE rls_public.users ALTER COLUMN type SET DEFAULT 0;

CREATE SCHEMA rls_simple_secrets;

GRANT USAGE ON SCHEMA rls_simple_secrets TO authenticated;

GRANT USAGE ON SCHEMA rls_simple_secrets TO anonymous;

CREATE TABLE rls_simple_secrets.user_secrets (
  
);

ALTER TABLE rls_simple_secrets.user_secrets DISABLE ROW LEVEL SECURITY;

ALTER TABLE rls_simple_secrets.user_secrets ADD COLUMN  id uuid;

ALTER TABLE rls_simple_secrets.user_secrets ALTER COLUMN id SET NOT NULL;

ALTER TABLE rls_simple_secrets.user_secrets ALTER COLUMN id SET DEFAULT rls_private.uuid_generate_v4();

ALTER TABLE rls_simple_secrets.user_secrets ADD COLUMN  owner_id uuid;

ALTER TABLE rls_simple_secrets.user_secrets ALTER COLUMN owner_id SET NOT NULL;

ALTER TABLE rls_simple_secrets.user_secrets ADD COLUMN  name text;

ALTER TABLE rls_simple_secrets.user_secrets ALTER COLUMN name SET NOT NULL;

ALTER TABLE rls_simple_secrets.user_secrets ADD COLUMN  value text;

ALTER TABLE rls_simple_secrets.user_secrets ADD CONSTRAINT user_secrets_pkey PRIMARY KEY ( id );

ALTER TABLE rls_simple_secrets.user_secrets ADD CONSTRAINT user_secrets_owner_id_name_key UNIQUE ( owner_id, name );

CREATE FUNCTION rls_simple_secrets.get ( v_owner_id uuid, v_secret_name text, v_default_value text DEFAULT NULL ) RETURNS text AS $EOFCODE$
DECLARE
    val text;
BEGIN
    SELECT value FROM "rls_simple_secrets".user_secrets t 
        WHERE t.owner_id = get.v_owner_id
        AND t.name = get.v_secret_name
    INTO val;
    IF (NOT FOUND OR val IS NULL) THEN
        RETURN v_default_value;
    END IF;
    RETURN val;
END;
$EOFCODE$ LANGUAGE plpgsql STABLE;

GRANT EXECUTE ON FUNCTION rls_simple_secrets.get TO authenticated;

CREATE FUNCTION rls_simple_secrets.set ( v_owner_id uuid, v_secret_name text, v_value anyelement ) RETURNS void AS $EOFCODE$
    INSERT INTO "rls_simple_secrets".user_secrets 
        (owner_id, name, value)
    VALUES
        (set.v_owner_id, set.v_secret_name, set.v_value::text)
    ON CONFLICT (owner_id, name)
    DO UPDATE 
    SET value = EXCLUDED.value;
$EOFCODE$ LANGUAGE sql VOLATILE;

GRANT EXECUTE ON FUNCTION rls_simple_secrets.set TO authenticated;

CREATE FUNCTION rls_simple_secrets.del ( owner_id uuid, secret_name text ) RETURNS void AS $EOFCODE$
    DELETE FROM "rls_simple_secrets".user_secrets s 
        WHERE
        s.owner_id = del.owner_id
        AND s.name = secret_name;
$EOFCODE$ LANGUAGE sql VOLATILE;

CREATE FUNCTION rls_simple_secrets.del ( owner_id uuid, secret_names text[] ) RETURNS void AS $EOFCODE$
    DELETE FROM "rls_simple_secrets".user_secrets s 
        WHERE
        s.owner_id = del.owner_id
        AND s.name = ANY (secret_names);
$EOFCODE$ LANGUAGE sql VOLATILE;

GRANT EXECUTE ON FUNCTION rls_simple_secrets.del ( uuid,text ) TO authenticated;

GRANT EXECUTE ON FUNCTION rls_simple_secrets.del ( uuid,text[] ) TO authenticated;

CREATE SCHEMA rls_roles_private;

GRANT USAGE ON SCHEMA rls_roles_private TO authenticated;

GRANT USAGE ON SCHEMA rls_roles_private TO anonymous;

CREATE TABLE rls_roles_private.api_tokens (
  
);

ALTER TABLE rls_roles_private.api_tokens DISABLE ROW LEVEL SECURITY;

ALTER TABLE rls_roles_private.api_tokens ADD COLUMN  id uuid;

ALTER TABLE rls_roles_private.api_tokens ALTER COLUMN id SET NOT NULL;

ALTER TABLE rls_roles_private.api_tokens ALTER COLUMN id SET DEFAULT rls_private.uuid_generate_v4();

ALTER TABLE rls_roles_private.api_tokens ADD COLUMN  user_id uuid;

ALTER TABLE rls_roles_private.api_tokens ALTER COLUMN user_id SET NOT NULL;

ALTER TABLE rls_roles_private.api_tokens ADD COLUMN  access_token text;

ALTER TABLE rls_roles_private.api_tokens ALTER COLUMN access_token SET NOT NULL;

ALTER TABLE rls_roles_private.api_tokens ALTER COLUMN access_token SET DEFAULT encode(gen_random_bytes(48), 'hex');

ALTER TABLE rls_roles_private.api_tokens ADD COLUMN  access_token_expires_at timestamptz;

ALTER TABLE rls_roles_private.api_tokens ALTER COLUMN access_token_expires_at SET NOT NULL;

ALTER TABLE rls_roles_private.api_tokens ALTER COLUMN access_token_expires_at SET DEFAULT now() + '30 days'::interval;

ALTER TABLE rls_roles_private.api_tokens ADD CONSTRAINT api_tokens_pkey PRIMARY KEY ( id );

ALTER TABLE rls_roles_private.api_tokens ADD CONSTRAINT api_tokens_access_token_key UNIQUE ( access_token );

CREATE INDEX api_tokens_user_id_idx ON rls_roles_private.api_tokens ( user_id );

CREATE SCHEMA rls_encrypted_secrets;

GRANT USAGE ON SCHEMA rls_encrypted_secrets TO authenticated;

GRANT USAGE ON SCHEMA rls_encrypted_secrets TO anonymous;

CREATE TABLE rls_encrypted_secrets.user_encrypted_secrets (
  
);

ALTER TABLE rls_encrypted_secrets.user_encrypted_secrets DISABLE ROW LEVEL SECURITY;

ALTER TABLE rls_encrypted_secrets.user_encrypted_secrets ADD COLUMN  id uuid;

ALTER TABLE rls_encrypted_secrets.user_encrypted_secrets ALTER COLUMN id SET NOT NULL;

ALTER TABLE rls_encrypted_secrets.user_encrypted_secrets ALTER COLUMN id SET DEFAULT rls_private.uuid_generate_v4();

ALTER TABLE rls_encrypted_secrets.user_encrypted_secrets ADD COLUMN  owner_id uuid;

ALTER TABLE rls_encrypted_secrets.user_encrypted_secrets ALTER COLUMN owner_id SET NOT NULL;

ALTER TABLE rls_encrypted_secrets.user_encrypted_secrets ADD COLUMN  name text;

ALTER TABLE rls_encrypted_secrets.user_encrypted_secrets ALTER COLUMN name SET NOT NULL;

ALTER TABLE rls_encrypted_secrets.user_encrypted_secrets ADD COLUMN  value bytea;

ALTER TABLE rls_encrypted_secrets.user_encrypted_secrets ADD COLUMN  algo text;

ALTER TABLE rls_encrypted_secrets.user_encrypted_secrets ADD CONSTRAINT user_encrypted_secrets_pkey PRIMARY KEY ( id );

ALTER TABLE rls_encrypted_secrets.user_encrypted_secrets ADD CONSTRAINT user_encrypted_secrets_owner_id_name_key UNIQUE ( owner_id, name );

CREATE FUNCTION rls_encrypted_secrets.user_encrypted_secrets_hash (  ) RETURNS trigger AS $EOFCODE$
BEGIN
   
IF (NEW.algo = 'crypt') THEN
    NEW.value = crypt(NEW.value::text, gen_salt('bf'));
ELSIF (NEW.algo = 'pgp') THEN
    NEW.value = pgp_sym_encrypt(encode(NEW.value::bytea, 'hex'), NEW.owner_id::text, 'compress-algo=1, cipher-algo=aes256');
ELSE
    NEW.algo = 'none';
END IF;
RETURN NEW;
END;
$EOFCODE$ LANGUAGE plpgsql VOLATILE;

CREATE TRIGGER user_encrypted_secrets_update_tg 
 BEFORE UPDATE ON rls_encrypted_secrets.user_encrypted_secrets 
 FOR EACH ROW
 WHEN ( NEW.value IS DISTINCT FROM OLD.value ) 
 EXECUTE PROCEDURE rls_encrypted_secrets. user_encrypted_secrets_hash (  );

CREATE TRIGGER user_encrypted_secrets_insert_tg 
 BEFORE INSERT ON rls_encrypted_secrets.user_encrypted_secrets 
 FOR EACH ROW
 EXECUTE PROCEDURE rls_encrypted_secrets. user_encrypted_secrets_hash (  );

CREATE FUNCTION rls_encrypted_secrets.get ( owner_id uuid, secret_name text, default_value text DEFAULT NULL ) RETURNS text AS $EOFCODE$
DECLARE
  v_secret "rls_encrypted_secrets".user_encrypted_secrets;
BEGIN
  SELECT
    *
  FROM
    "rls_encrypted_secrets".user_encrypted_secrets s
  WHERE
    s.name = get.secret_name
    AND s.owner_id = get.owner_id
  INTO v_secret;
  IF (NOT FOUND OR v_secret IS NULL) THEN
    RETURN get.default_value;
  END IF;
  
  IF (v_secret.algo = 'crypt') THEN
    RETURN convert_from(v_secret.value, 'SQL_ASCII');
  ELSIF (v_secret.algo = 'pgp') THEN
    RETURN convert_from(decode(pgp_sym_decrypt(v_secret.value, v_secret.owner_id::text), 'hex'), 'SQL_ASCII');
  END IF;
  RETURN convert_from(v_secret.value, 'SQL_ASCII');
END
$EOFCODE$ LANGUAGE plpgsql STABLE;

GRANT EXECUTE ON FUNCTION rls_encrypted_secrets.get TO authenticated;

CREATE FUNCTION rls_encrypted_secrets.verify ( owner_id uuid, secret_name text, value text ) RETURNS boolean AS $EOFCODE$
DECLARE
  v_secret_text text;
  v_secret "rls_encrypted_secrets".user_encrypted_secrets;
BEGIN
  SELECT
    *
  FROM
    "rls_encrypted_secrets".get (verify.owner_id, verify.secret_name)
  INTO v_secret_text;
  SELECT
    *
  FROM
    "rls_encrypted_secrets".user_encrypted_secrets s
  WHERE
    s.name = verify.secret_name
    AND s.owner_id = verify.owner_id INTO v_secret;
  IF (v_secret.algo = 'crypt') THEN
    RETURN v_secret_text = crypt(verify.value::bytea::text, v_secret_text);
  ELSIF (v_secret.algo = 'pgp') THEN
    RETURN verify.value = v_secret_text;
  END IF;
  RETURN verify.value = v_secret_text;
END
$EOFCODE$ LANGUAGE plpgsql STABLE;

GRANT EXECUTE ON FUNCTION rls_encrypted_secrets.verify TO authenticated;

CREATE FUNCTION rls_encrypted_secrets.set ( v_owner_id uuid, secret_name text, secret_value text, v_algo text DEFAULT 'pgp' ) RETURNS boolean AS $EOFCODE$
BEGIN
  INSERT INTO "rls_encrypted_secrets".user_encrypted_secrets (owner_id, name, value, algo)
    VALUES (v_owner_id, set.secret_name, set.secret_value::bytea, set.v_algo)
    ON CONFLICT (owner_id, name)
    DO
    UPDATE
    SET
      value = set.secret_value::bytea,
      algo = EXCLUDED.algo;
  RETURN TRUE;
END
$EOFCODE$ LANGUAGE plpgsql VOLATILE;

GRANT EXECUTE ON FUNCTION rls_encrypted_secrets.set TO authenticated;

CREATE FUNCTION rls_encrypted_secrets.del ( owner_id uuid, secret_name text ) RETURNS void AS $EOFCODE$
BEGIN
  DELETE FROM "rls_encrypted_secrets".user_encrypted_secrets s
  WHERE s.owner_id = del.owner_id
    AND s.name = del.secret_name;
END
$EOFCODE$ LANGUAGE plpgsql VOLATILE;

CREATE FUNCTION rls_encrypted_secrets.del ( owner_id uuid, secret_names text[] ) RETURNS void AS $EOFCODE$
BEGIN
  DELETE FROM "rls_encrypted_secrets".user_encrypted_secrets s
  WHERE s.owner_id = del.owner_id
    AND s.name = ANY(del.secret_names);
END
$EOFCODE$ LANGUAGE plpgsql VOLATILE;

GRANT EXECUTE ON FUNCTION rls_encrypted_secrets.del ( uuid,text ) TO authenticated;

GRANT EXECUTE ON FUNCTION rls_encrypted_secrets.del ( uuid,text[] ) TO authenticated;

CREATE FUNCTION rls_private.immutable_field_tg (  ) RETURNS trigger AS $EOFCODE$
BEGIN
  IF TG_NARGS > 0 THEN
    RAISE EXCEPTION 'IMMUTABLE_PROPERTY %', TG_ARGV[0];
  END IF;
  RAISE EXCEPTION 'IMMUTABLE_PROPERTY';
END;
$EOFCODE$ LANGUAGE plpgsql VOLATILE;

CREATE SCHEMA rls_roles_public;

GRANT USAGE ON SCHEMA rls_roles_public TO authenticated;

GRANT USAGE ON SCHEMA rls_roles_public TO anonymous;

CREATE FUNCTION rls_roles_private.authenticate ( token_str text ) RETURNS SETOF rls_roles_private.api_tokens AS $EOFCODE$
SELECT
    tkn.*
FROM
    "rls_roles_private".api_tokens AS tkn
WHERE
    tkn.access_token = authenticate.token_str
    AND EXTRACT(EPOCH FROM (tkn.access_token_expires_at-NOW())) > 0;
$EOFCODE$ LANGUAGE sql STABLE SECURITY DEFINER;

CREATE FUNCTION rls_roles_public.get_current_user_id (  ) RETURNS uuid AS $EOFCODE$
DECLARE
  v_identifier_id uuid;
BEGIN
  IF current_setting('jwt.claims.user_id', TRUE)
    IS NOT NULL THEN
    BEGIN
      v_identifier_id = current_setting('jwt.claims.user_id', TRUE)::uuid;
    EXCEPTION
      WHEN OTHERS THEN
      RAISE NOTICE 'Invalid UUID value';
    RETURN NULL;
    END;
    RETURN v_identifier_id;
  ELSE
    RETURN NULL;
  END IF;
END;
$EOFCODE$ LANGUAGE plpgsql STABLE;

GRANT EXECUTE ON FUNCTION rls_roles_public.get_current_user_id TO authenticated;

CREATE FUNCTION rls_roles_public.get_current_group_ids (  ) RETURNS uuid[] AS $EOFCODE$
DECLARE
  v_identifier_ids uuid[];
BEGIN
  IF current_setting('jwt.claims.group_ids', TRUE)
    IS NOT NULL THEN
    BEGIN
      v_identifier_ids = current_setting('jwt.claims.group_ids', TRUE)::uuid[];
    EXCEPTION
      WHEN OTHERS THEN
      RAISE NOTICE 'Invalid UUID value';
    RETURN ARRAY[]::uuid[];
    END;
    RETURN v_identifier_ids;
  ELSE
    RETURN ARRAY[]::uuid[];
  END IF;
END;
$EOFCODE$ LANGUAGE plpgsql STABLE;

GRANT EXECUTE ON FUNCTION rls_roles_public.get_current_group_ids TO authenticated;

CREATE FUNCTION rls_roles_public.get_current_user (  ) RETURNS rls_public.users AS $EOFCODE$
DECLARE
  v_user "rls_public".users;
BEGIN
  IF "rls_roles_public".get_current_user_id() IS NOT NULL THEN
     SELECT * FROM "rls_public".users WHERE id = "rls_roles_public".get_current_user_id() INTO v_user;
     RETURN v_user;
  ELSE
     RETURN NULL;
  END IF;
END;
$EOFCODE$ LANGUAGE plpgsql STABLE;

GRANT EXECUTE ON FUNCTION rls_roles_public.get_current_user TO authenticated;

CREATE FUNCTION rls_private.tg_peoplestamps (  ) RETURNS trigger AS $EOFCODE$
BEGIN
    IF TG_OP = 'INSERT' THEN
      NEW.updated_by = "rls_roles_public".get_current_user_id();
      NEW.created_by = "rls_roles_public".get_current_user_id();
    ELSIF TG_OP = 'UPDATE' THEN
      NEW.updated_by = OLD.updated_by;
      NEW.created_by = "rls_roles_public".get_current_user_id();
    END IF;
    RETURN NEW;
END;
$EOFCODE$ LANGUAGE plpgsql;

CREATE FUNCTION rls_private.tg_timestamps (  ) RETURNS trigger AS $EOFCODE$
BEGIN
    IF TG_OP = 'INSERT' THEN
      NEW.created_at = NOW();
      NEW.updated_at = NOW();
    ELSIF TG_OP = 'UPDATE' THEN
      NEW.created_at = OLD.created_at;
      NEW.updated_at = NOW();
    END IF;
    RETURN NEW;
END;
$EOFCODE$ LANGUAGE plpgsql;

CREATE SCHEMA IF NOT EXISTS rls_private;

GRANT USAGE ON SCHEMA rls_private TO authenticated, anonymous;

ALTER DEFAULT PRIVILEGES IN SCHEMA rls_private 
 GRANT EXECUTE ON FUNCTIONS  TO authenticated;

CREATE SCHEMA IF NOT EXISTS rls_public;

GRANT USAGE ON SCHEMA rls_public TO authenticated, anonymous;

ALTER DEFAULT PRIVILEGES IN SCHEMA rls_public 
 GRANT EXECUTE ON FUNCTIONS  TO authenticated;

CREATE TABLE rls_public.user_achievement (
 	id uuid PRIMARY KEY DEFAULT ( uuid_generate_v4() ),
	name citext NOT NULL,
	UNIQUE ( name ) 
);

CREATE TABLE rls_public.user_step (
 	id uuid PRIMARY KEY DEFAULT ( uuid_generate_v4() ),
	name citext NOT NULL,
	achievement_id uuid NOT NULL REFERENCES rls_public.user_achievement ( id ) ON DELETE CASCADE,
	priority int DEFAULT ( 10000 ),
	UNIQUE ( name ) 
);

CREATE TABLE rls_public.user_step_achievement (
 	id uuid PRIMARY KEY DEFAULT ( uuid_generate_v4() ),
	task_id uuid NOT NULL REFERENCES rls_public.user_step ( id ) ON DELETE CASCADE,
	user_id uuid NOT NULL REFERENCES rls_public.users ( id ) ON DELETE CASCADE 
);

CREATE FUNCTION rls_private.user_completed_task ( task citext, role_id uuid DEFAULT rls_roles_public.get_current_user_id() ) RETURNS void AS $EOFCODE$
  INSERT INTO "rls_public".user_step_achievement (user_id, task_id)
  VALUES (role_id, (
      SELECT
        t.id
      FROM
        "rls_public".user_step t
      WHERE
        name = task));
$EOFCODE$ LANGUAGE sql VOLATILE SECURITY DEFINER;

CREATE FUNCTION rls_private.user_incompleted_task ( task citext, role_id uuid DEFAULT rls_roles_public.get_current_user_id() ) RETURNS void AS $EOFCODE$
  DELETE FROM "rls_public".user_step_achievement
  WHERE user_id = role_id
    AND task_id = (
      SELECT
        t.id
      FROM
        "rls_public".user_step t
      WHERE
        name = task);
$EOFCODE$ LANGUAGE sql VOLATILE SECURITY DEFINER;

CREATE FUNCTION rls_public.tasks_required_for ( achievement citext, role_id uuid DEFAULT rls_roles_public.get_current_user_id() ) RETURNS SETOF rls_public.user_step AS $EOFCODE$
BEGIN
  RETURN QUERY
    SELECT
      t.*
    FROM
      "rls_public".user_step t
    FULL OUTER JOIN "rls_public".user_step_achievement u ON (
      u.task_id = t.id
      AND u.user_id = role_id
    )
    JOIN "rls_public".user_achievement f ON (t.achievement_id = f.id)
  WHERE
    u.user_id IS NULL
    AND f.name = achievement
  ORDER BY t.priority ASC
;
END;
$EOFCODE$ LANGUAGE plpgsql STABLE;

CREATE FUNCTION rls_public.user_achieved ( achievement citext, role_id uuid DEFAULT rls_roles_public.get_current_user_id() ) RETURNS boolean AS $EOFCODE$
DECLARE
  v_achievement "rls_public".user_achievement;
  v_task "rls_public".user_step;
  v_value boolean = TRUE;
BEGIN
  SELECT * FROM "rls_public".user_achievement
    WHERE name = achievement
    INTO v_achievement;
  IF (NOT FOUND) THEN
    RETURN FALSE;
  END IF;
  FOR v_task IN
  SELECT * FROM
    "rls_public".user_step
    WHERE achievement_id = v_achievement.id
  LOOP
    SELECT EXISTS(
      SELECT 1
      FROM "rls_public".user_step_achievement
      WHERE 
        user_id = role_id
        AND task_id = v_task.id
    ) AND v_value
      INTO v_value;
    
  END LOOP;
  RETURN v_value;
END;
$EOFCODE$ LANGUAGE plpgsql STABLE;

GRANT SELECT ON TABLE rls_public.user_achievement TO authenticated;

CREATE INDEX user_id_idx ON rls_public.user_step_achievement ( user_id );

ALTER TABLE rls_public.user_step_achievement ENABLE ROW LEVEL SECURITY;

CREATE POLICY can_select_user_step_achievement ON rls_public.user_step_achievement FOR SELECT TO PUBLIC USING ( rls_roles_public.get_current_user_id() = user_id );

CREATE POLICY can_insert_user_step_achievement ON rls_public.user_step_achievement FOR INSERT TO PUBLIC WITH CHECK ( FALSE );

CREATE POLICY can_update_user_step_achievement ON rls_public.user_step_achievement FOR UPDATE TO PUBLIC USING ( FALSE );

CREATE POLICY can_delete_user_step_achievement ON rls_public.user_step_achievement FOR DELETE TO PUBLIC USING ( FALSE );

GRANT INSERT ON TABLE rls_public.user_step_achievement TO authenticated;

GRANT SELECT ON TABLE rls_public.user_step_achievement TO authenticated;

GRANT UPDATE ON TABLE rls_public.user_step_achievement TO authenticated;

GRANT DELETE ON TABLE rls_public.user_step_achievement TO authenticated;

ALTER TABLE rls_public.user_step_achievement ADD COLUMN  created_at timestamptz;

ALTER TABLE rls_public.user_step_achievement ALTER COLUMN created_at SET DEFAULT now();

ALTER TABLE rls_public.user_step_achievement ADD COLUMN  updated_at timestamptz;

ALTER TABLE rls_public.user_step_achievement ALTER COLUMN updated_at SET DEFAULT now();

CREATE TRIGGER update_user_step_achievement_modtime 
 BEFORE INSERT OR UPDATE ON rls_public.user_step_achievement 
 FOR EACH ROW
 EXECUTE PROCEDURE rls_private. tg_timestamps (  );

GRANT SELECT ON TABLE rls_public.user_step TO authenticated;

CREATE FUNCTION rls_private.tg_achievement (  ) RETURNS trigger AS $EOFCODE$
DECLARE
  is_null boolean;
  task_name citext;
BEGIN
    IF (TG_OP = 'INSERT' OR TG_OP = 'UPDATE') THEN
        task_name = TG_ARGV[1]::citext;
        EXECUTE format('SELECT ($1).%s IS NULL', TG_ARGV[0])
        USING NEW INTO is_null;
        IF (is_null IS FALSE) THEN
            PERFORM "rls_private".user_completed_task(task_name);
        END IF;
        RETURN NEW;
    END IF;
END;
$EOFCODE$ LANGUAGE plpgsql VOLATILE;

CREATE FUNCTION rls_private.tg_achievement_toggle (  ) RETURNS trigger AS $EOFCODE$
DECLARE
  is_null boolean;
  task_name citext;
BEGIN
    IF (TG_OP = 'INSERT' OR TG_OP = 'UPDATE') THEN
        task_name = TG_ARGV[1]::citext;
        EXECUTE format('SELECT ($1).%s IS NULL', TG_ARGV[0])
        USING NEW INTO is_null;
        IF (is_null IS TRUE) THEN
            PERFORM "rls_private".user_incompleted_task(task_name);
        ELSE
            PERFORM "rls_private".user_completed_task(task_name);
        END IF;
        RETURN NEW;
    END IF;
END;
$EOFCODE$ LANGUAGE plpgsql VOLATILE;

CREATE FUNCTION rls_private.tg_achievement_boolean (  ) RETURNS trigger AS $EOFCODE$
DECLARE
  is_true boolean;
  task_name citext;
BEGIN
    IF (TG_OP = 'INSERT' OR TG_OP = 'UPDATE') THEN
        task_name = TG_ARGV[1]::citext;
        EXECUTE format('SELECT ($1).%s IS TRUE', TG_ARGV[0])
        USING NEW INTO is_true;
        IF (is_true IS TRUE) THEN
            PERFORM "rls_private".user_completed_task(task_name);
        END IF;
        RETURN NEW;
    END IF;
END;
$EOFCODE$ LANGUAGE plpgsql VOLATILE;

CREATE FUNCTION rls_private.tg_achievement_toggle_boolean (  ) RETURNS trigger AS $EOFCODE$
DECLARE
  is_true boolean;
  task_name citext;
BEGIN
    IF (TG_OP = 'INSERT' OR TG_OP = 'UPDATE') THEN
        task_name = TG_ARGV[1]::citext;
        EXECUTE format('SELECT ($1).%s IS TRUE', TG_ARGV[0])
        USING NEW INTO is_true;
        IF (is_true IS TRUE) THEN
            PERFORM "rls_private".user_completed_task(task_name);
        ELSE
            PERFORM "rls_private".user_incompleted_task(task_name);
        END IF;
        RETURN NEW;
    END IF;
END;
$EOFCODE$ LANGUAGE plpgsql VOLATILE;

DO $$
  DECLARE
  beginner uuid;
  verifier uuid;
  BEGIN
    INSERT INTO "rls_public".user_achievement (name)
      VALUES ('profile_complete')
    RETURNING id INTO beginner;
    INSERT INTO "rls_public".user_achievement (name)
      VALUES ('verifier')
    RETURNING id INTO verifier;
    INSERT INTO "rls_public".user_step (achievement_id, name)
      VALUES 
      (beginner, 'accept_privacy'),
      (beginner, 'agree_to_terms'),
      (beginner, 'set_password'),
      (beginner, 'upload_profile_picture'),
      (beginner, 'email_verified');
    INSERT INTO "rls_public".user_step (achievement_id, name)
      VALUES 
      (verifier, 'complete_action'),
      (verifier, 'send_invite'), -- would be cool to specify numbers too, if it's more than one!
      (verifier, 'submit_application'),
      (verifier, 'create_action')
    ;
  END; $$;

ALTER TABLE rls_public.users ENABLE ROW LEVEL SECURITY;

CREATE POLICY authenticated_can_insert_on_users ON rls_public.users FOR INSERT TO authenticated WITH CHECK ( id = rls_roles_public.get_current_user_id() );

CREATE POLICY authenticated_can_update_on_users ON rls_public.users FOR UPDATE TO authenticated USING ( id = rls_roles_public.get_current_user_id() );

CREATE POLICY authenticated_can_delete_on_users ON rls_public.users FOR DELETE TO authenticated USING ( id = rls_roles_public.get_current_user_id() );

GRANT INSERT ON TABLE rls_public.users TO authenticated;

GRANT UPDATE ON TABLE rls_public.users TO authenticated;

GRANT DELETE ON TABLE rls_public.users TO authenticated;

CREATE POLICY authenticated_can_select_on_users ON rls_public.users FOR SELECT TO authenticated USING ( TRUE );

GRANT SELECT ON TABLE rls_public.users TO authenticated;

ALTER TABLE rls_encrypted_secrets.user_encrypted_secrets ENABLE ROW LEVEL SECURITY;

CREATE POLICY authenticated_can_select_on_user_encrypted_secrets ON rls_encrypted_secrets.user_encrypted_secrets FOR SELECT TO authenticated USING ( owner_id = rls_roles_public.get_current_user_id() );

CREATE POLICY authenticated_can_insert_on_user_encrypted_secrets ON rls_encrypted_secrets.user_encrypted_secrets FOR INSERT TO authenticated WITH CHECK ( owner_id = rls_roles_public.get_current_user_id() );

CREATE POLICY authenticated_can_update_on_user_encrypted_secrets ON rls_encrypted_secrets.user_encrypted_secrets FOR UPDATE TO authenticated USING ( owner_id = rls_roles_public.get_current_user_id() );

CREATE POLICY authenticated_can_delete_on_user_encrypted_secrets ON rls_encrypted_secrets.user_encrypted_secrets FOR DELETE TO authenticated USING ( owner_id = rls_roles_public.get_current_user_id() );

GRANT SELECT ON TABLE rls_encrypted_secrets.user_encrypted_secrets TO authenticated;

GRANT INSERT ON TABLE rls_encrypted_secrets.user_encrypted_secrets TO authenticated;

GRANT UPDATE ON TABLE rls_encrypted_secrets.user_encrypted_secrets TO authenticated;

GRANT DELETE ON TABLE rls_encrypted_secrets.user_encrypted_secrets TO authenticated;

ALTER TABLE rls_simple_secrets.user_secrets ENABLE ROW LEVEL SECURITY;

CREATE POLICY authenticated_can_select_on_user_secrets ON rls_simple_secrets.user_secrets FOR SELECT TO authenticated USING ( owner_id = rls_roles_public.get_current_user_id() );

CREATE POLICY authenticated_can_insert_on_user_secrets ON rls_simple_secrets.user_secrets FOR INSERT TO authenticated WITH CHECK ( owner_id = rls_roles_public.get_current_user_id() );

CREATE POLICY authenticated_can_update_on_user_secrets ON rls_simple_secrets.user_secrets FOR UPDATE TO authenticated USING ( owner_id = rls_roles_public.get_current_user_id() );

CREATE POLICY authenticated_can_delete_on_user_secrets ON rls_simple_secrets.user_secrets FOR DELETE TO authenticated USING ( owner_id = rls_roles_public.get_current_user_id() );

GRANT SELECT ON TABLE rls_simple_secrets.user_secrets TO authenticated;

GRANT INSERT ON TABLE rls_simple_secrets.user_secrets TO authenticated;

GRANT UPDATE ON TABLE rls_simple_secrets.user_secrets TO authenticated;

GRANT DELETE ON TABLE rls_simple_secrets.user_secrets TO authenticated;

ALTER TABLE rls_roles_private.api_tokens ENABLE ROW LEVEL SECURITY;

CREATE POLICY authenticated_can_select_on_api_tokens ON rls_roles_private.api_tokens FOR SELECT TO authenticated USING ( user_id = rls_roles_public.get_current_user_id() );

CREATE POLICY authenticated_can_insert_on_api_tokens ON rls_roles_private.api_tokens FOR INSERT TO authenticated WITH CHECK ( user_id = rls_roles_public.get_current_user_id() );

CREATE POLICY authenticated_can_update_on_api_tokens ON rls_roles_private.api_tokens FOR UPDATE TO authenticated USING ( user_id = rls_roles_public.get_current_user_id() );

CREATE POLICY authenticated_can_delete_on_api_tokens ON rls_roles_private.api_tokens FOR DELETE TO authenticated USING ( user_id = rls_roles_public.get_current_user_id() );

GRANT SELECT ON TABLE rls_roles_private.api_tokens TO authenticated;

GRANT INSERT ON TABLE rls_roles_private.api_tokens TO authenticated;

GRANT UPDATE ON TABLE rls_roles_private.api_tokens TO authenticated;

GRANT DELETE ON TABLE rls_roles_private.api_tokens TO authenticated;

CREATE TABLE rls_public.emails (
  
);

ALTER TABLE rls_public.emails DISABLE ROW LEVEL SECURITY;

ALTER TABLE rls_public.emails ADD COLUMN  id uuid;

ALTER TABLE rls_public.emails ALTER COLUMN id SET NOT NULL;

ALTER TABLE rls_public.emails ALTER COLUMN id SET DEFAULT rls_private.uuid_generate_v4();

ALTER TABLE rls_public.emails ADD COLUMN  owner_id uuid;

ALTER TABLE rls_public.emails ALTER COLUMN owner_id SET NOT NULL;

ALTER TABLE rls_public.emails ADD COLUMN  email email;

ALTER TABLE rls_public.emails ALTER COLUMN email SET NOT NULL;

ALTER TABLE rls_public.emails ADD COLUMN  is_verified boolean;

ALTER TABLE rls_public.emails ALTER COLUMN is_verified SET NOT NULL;

ALTER TABLE rls_public.emails ALTER COLUMN is_verified SET DEFAULT FALSE;

ALTER TABLE rls_public.emails ADD CONSTRAINT emails_pkey PRIMARY KEY ( id );

ALTER TABLE rls_public.emails ADD CONSTRAINT emails_email_key UNIQUE ( email );

ALTER TABLE rls_public.emails ADD CONSTRAINT emails_owner_id_key UNIQUE ( owner_id );

ALTER TABLE rls_public.emails ENABLE ROW LEVEL SECURITY;

CREATE POLICY authenticated_can_select_on_emails ON rls_public.emails FOR SELECT TO authenticated USING ( owner_id = rls_roles_public.get_current_user_id() );

CREATE POLICY authenticated_can_insert_on_emails ON rls_public.emails FOR INSERT TO authenticated WITH CHECK ( owner_id = rls_roles_public.get_current_user_id() );

CREATE POLICY authenticated_can_update_on_emails ON rls_public.emails FOR UPDATE TO authenticated USING ( owner_id = rls_roles_public.get_current_user_id() );

CREATE POLICY authenticated_can_delete_on_emails ON rls_public.emails FOR DELETE TO authenticated USING ( owner_id = rls_roles_public.get_current_user_id() );

GRANT SELECT ON TABLE rls_public.emails TO authenticated;

GRANT INSERT ON TABLE rls_public.emails TO authenticated;

GRANT UPDATE ON TABLE rls_public.emails TO authenticated;

GRANT DELETE ON TABLE rls_public.emails TO authenticated;

ALTER TABLE rls_public.emails ADD CONSTRAINT emails_owner_id_fkey FOREIGN KEY ( owner_id ) REFERENCES rls_public.users ( id );

COMMENT ON CONSTRAINT emails_owner_id_fkey ON rls_public.emails IS NULL;

CREATE INDEX emails_owner_id_idx ON rls_public.emails ( owner_id );

CREATE TABLE rls_public.invites (
  
);

ALTER TABLE rls_public.invites ENABLE ROW LEVEL SECURITY;

ALTER TABLE rls_public.invites ADD COLUMN  id uuid;

ALTER TABLE rls_public.invites ALTER COLUMN id SET NOT NULL;

ALTER TABLE rls_public.invites ALTER COLUMN id SET DEFAULT rls_private.uuid_generate_v4();

ALTER TABLE rls_public.invites ADD CONSTRAINT invites_pkey PRIMARY KEY ( id );

ALTER TABLE rls_public.invites ADD COLUMN  email email;

ALTER TABLE rls_public.invites ADD COLUMN  sender_id uuid;

ALTER TABLE rls_public.invites ALTER COLUMN sender_id SET NOT NULL;

ALTER TABLE rls_public.invites ALTER COLUMN sender_id SET DEFAULT rls_roles_public.get_current_user_id();

ALTER TABLE rls_public.invites ADD COLUMN  invite_token text;

ALTER TABLE rls_public.invites ALTER COLUMN invite_token SET NOT NULL;

ALTER TABLE rls_public.invites ALTER COLUMN invite_token SET DEFAULT encode(gen_random_bytes(16), 'hex');

ALTER TABLE rls_public.invites ADD COLUMN  invite_valid boolean;

ALTER TABLE rls_public.invites ALTER COLUMN invite_valid SET NOT NULL;

ALTER TABLE rls_public.invites ALTER COLUMN invite_valid SET DEFAULT TRUE;

ALTER TABLE rls_public.invites ADD COLUMN  invite_limit int;

ALTER TABLE rls_public.invites ALTER COLUMN invite_limit SET NOT NULL;

ALTER TABLE rls_public.invites ALTER COLUMN invite_limit SET DEFAULT (-1);

ALTER TABLE rls_public.invites ADD COLUMN  invite_count int;

ALTER TABLE rls_public.invites ALTER COLUMN invite_count SET NOT NULL;

ALTER TABLE rls_public.invites ALTER COLUMN invite_count SET DEFAULT 0;

ALTER TABLE rls_public.invites ADD COLUMN  multiple boolean;

ALTER TABLE rls_public.invites ALTER COLUMN multiple SET NOT NULL;

ALTER TABLE rls_public.invites ALTER COLUMN multiple SET DEFAULT FALSE;

ALTER TABLE rls_public.invites ADD COLUMN  data jsonb;

ALTER TABLE rls_public.invites ADD COLUMN  expires_at timestamptz;

ALTER TABLE rls_public.invites ALTER COLUMN expires_at SET NOT NULL;

ALTER TABLE rls_public.invites ALTER COLUMN expires_at SET DEFAULT now() + '6 months'::interval;

ALTER TABLE rls_public.invites ADD COLUMN  created_at timestamptz;

ALTER TABLE rls_public.invites ALTER COLUMN created_at SET NOT NULL;

ALTER TABLE rls_public.invites ALTER COLUMN created_at SET DEFAULT now();

ALTER TABLE rls_public.invites ADD CONSTRAINT invites_email_sender_id_key UNIQUE ( email, sender_id );

ALTER TABLE rls_public.invites ADD CONSTRAINT invites_invite_token_key UNIQUE ( invite_token );

CREATE INDEX invites_expires_at_idx ON rls_public.invites ( expires_at );

CREATE INDEX invites_invite_valid_idx ON rls_public.invites ( invite_valid );

CREATE INDEX invites_sender_id_idx ON rls_public.invites ( sender_id );

ALTER TABLE rls_public.invites ADD CONSTRAINT invites_sender_id_fkey FOREIGN KEY ( sender_id ) REFERENCES rls_public.users ( id ) ON DELETE CASCADE;

CREATE POLICY authenticated_can_insert_on_invites ON rls_public.invites FOR INSERT TO authenticated WITH CHECK ( sender_id = rls_roles_public.get_current_user_id() );

GRANT INSERT ( email, invite_limit, multiple, expires_at ) ON TABLE rls_public.invites TO authenticated;

CREATE POLICY authenticated_can_update_on_invites ON rls_public.invites FOR UPDATE TO authenticated USING ( sender_id = rls_roles_public.get_current_user_id() );

GRANT UPDATE ( expires_at ) ON TABLE rls_public.invites TO authenticated;

CREATE POLICY authenticated_can_select_on_invites ON rls_public.invites FOR SELECT TO authenticated USING ( sender_id = rls_roles_public.get_current_user_id() );

GRANT SELECT ON TABLE rls_public.invites TO authenticated;

CREATE POLICY authenticated_can_delete_on_invites ON rls_public.invites FOR DELETE TO authenticated USING ( sender_id = rls_roles_public.get_current_user_id() );

GRANT DELETE ON TABLE rls_public.invites TO authenticated;

CREATE TABLE rls_public.claimed_invites (
  
);

ALTER TABLE rls_public.claimed_invites ENABLE ROW LEVEL SECURITY;

ALTER TABLE rls_public.claimed_invites ADD COLUMN  id uuid;

ALTER TABLE rls_public.claimed_invites ALTER COLUMN id SET NOT NULL;

ALTER TABLE rls_public.claimed_invites ALTER COLUMN id SET DEFAULT rls_private.uuid_generate_v4();

ALTER TABLE rls_public.claimed_invites ADD CONSTRAINT claimed_invites_pkey PRIMARY KEY ( id );

ALTER TABLE rls_public.claimed_invites ADD COLUMN  data jsonb;

ALTER TABLE rls_public.claimed_invites ADD COLUMN  sender_id uuid;

ALTER TABLE rls_public.claimed_invites ALTER COLUMN sender_id SET NOT NULL;

ALTER TABLE rls_public.claimed_invites ADD COLUMN  receiver_id uuid;

ALTER TABLE rls_public.claimed_invites ALTER COLUMN receiver_id SET NOT NULL;

ALTER TABLE rls_public.claimed_invites ADD COLUMN  created_at timestamptz;

ALTER TABLE rls_public.claimed_invites ALTER COLUMN created_at SET NOT NULL;

ALTER TABLE rls_public.claimed_invites ALTER COLUMN created_at SET DEFAULT now();

ALTER TABLE rls_public.claimed_invites ADD CONSTRAINT claimed_invites_sender_id_fkey FOREIGN KEY ( sender_id ) REFERENCES rls_public.users ( id ) ON DELETE CASCADE;

ALTER TABLE rls_public.claimed_invites ADD CONSTRAINT claimed_invites_receiver_id_fkey FOREIGN KEY ( receiver_id ) REFERENCES rls_public.users ( id ) ON DELETE CASCADE;

CREATE INDEX claimed_invites_sender_id_idx ON rls_public.claimed_invites ( sender_id );

CREATE INDEX claimed_invites_receiver_id_idx ON rls_public.claimed_invites ( receiver_id );

CREATE POLICY authenticated_can_select_on_claimed_invites ON rls_public.claimed_invites FOR SELECT TO authenticated USING ( sender_id = rls_roles_public.get_current_user_id() OR receiver_id = rls_roles_public.get_current_user_id() );

GRANT SELECT ON TABLE rls_public.claimed_invites TO authenticated;

CREATE FUNCTION rls_public.submit_invite_code ( token text ) RETURNS boolean AS $EOFCODE$
DECLARE
  v_user "rls_public".users;
  v_email "rls_public".emails;
  v_invite "rls_public".invites;
BEGIN
  SELECT * FROM "rls_public".users
  WHERE id = "rls_roles_public".get_current_user_id ()
  INTO v_user;
  IF (NOT FOUND) THEN
    RAISE EXCEPTION 'OBJECT_NOT_FOUND';
  END IF;
  
  SELECT * FROM "rls_public".invites i
    WHERE i.invite_token = token
    AND EXTRACT(EPOCH FROM (i.expires_at - NOW())) > 0
    AND i.invite_valid = TRUE
  INTO v_invite;
  IF (NOT FOUND) THEN
    RAISE EXCEPTION 'INVITE_NOT_FOUND';
  END IF;
  IF (v_invite.invite_limit > 0 AND v_invite.invite_count >= v_invite.invite_limit) THEN
    RAISE EXCEPTION 'INVITE_LIMIT';
  END IF;
  IF (v_invite.email IS NOT NULL) THEN 
    SELECT * FROM "rls_public".emails e
    WHERE e.email = v_invite.email
      AND e.owner_id = v_user.id
    INTO v_email;
    
    IF (NOT FOUND) THEN
      RAISE EXCEPTION 'INVITE_EMAIL_NOT_FOUND';
    END IF;
  END IF;
  IF (v_email.email IS NOT NULL OR v_invite.multiple IS FALSE) THEN 
    UPDATE "rls_public".invites 
    SET invite_valid = FALSE
    WHERE id = v_invite.id;
  END IF;
  UPDATE "rls_public".invites 
    SET invite_count = invite_count + 1
  WHERE id = v_invite.id;
  INSERT INTO "rls_public".claimed_invites 
    (sender_id, receiver_id, data)
  VALUES (v_invite.sender_id, v_user.id, v_invite.data);
  RETURN TRUE;
END;
$EOFCODE$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION rls_public.submit_invite_code TO authenticated;

CREATE FUNCTION rls_private.after_insert_invite_add_job_tg (  ) RETURNS trigger AS $EOFCODE$
BEGIN
    IF (NEW.email IS NOT NULL) THEN 
        PERFORM
            app_jobs.add_job ('send_email_link',
                json_build_object(
                'email_type', 'invite_email',
                'email', NEW.email,
                'sender_id', NEW.sender_id,
                'invite_code', NEW.invite_code
                )
            );
    END IF;
    RETURN NEW;
END;
$EOFCODE$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER;

CREATE FUNCTION rls_private.before_insert_invite_ensure_email_available_tg (  ) RETURNS trigger AS $EOFCODE$
DECLARE
    email_exists boolean;
BEGIN
    IF (NEW.email IS NOT NULL) THEN 
        SELECT EXISTS( SELECT 
                    1 
                FROM 
                    "rls_public".emails e
                WHERE 
                    e.email = NEW.email)
        INTO email_exists;
        IF (email_exists IS TRUE) THEN 
            RAISE EXCEPTION 'ACCOUNT_EXISTS';
        END IF;
    END IF;
    RETURN NEW;
END;
$EOFCODE$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER invite_trigger_ensure_email_not_exists 
 BEFORE INSERT ON rls_public.invites 
 FOR EACH ROW
 EXECUTE PROCEDURE rls_private. before_insert_invite_ensure_email_available_tg (  );

CREATE TRIGGER invite_trigger_send_email 
 AFTER INSERT ON rls_public.invites 
 FOR EACH ROW
 EXECUTE PROCEDURE rls_private. after_insert_invite_add_job_tg (  );

CREATE FUNCTION rls_roles_public.login ( email text, password text ) RETURNS rls_roles_private.api_tokens AS $EOFCODE$
DECLARE
  v_token "rls_roles_private".api_tokens;
  v_email "rls_public".emails;
  v_sign_in_attempt_window_duration interval = interval '6 hours';
  v_sign_in_max_attempts int = 10;
  first_failed_password_attempt timestamptz;
  password_attempts int;
BEGIN
  SELECT
    user_emails_alias.*
  FROM
    "rls_public".emails AS user_emails_alias
  WHERE
    user_emails_alias.email = login.email::email INTO v_email;
  
  IF (NOT FOUND) THEN
    RETURN NULL;
  END IF;
  first_failed_password_attempt = "rls_simple_secrets".get(v_email.owner_id, 'first_failed_password_attempt');
  password_attempts = "rls_simple_secrets".get(v_email.owner_id, 'password_attempts');
  IF (
    first_failed_password_attempt IS NOT NULL
      AND
    first_failed_password_attempt > NOW() - v_sign_in_attempt_window_duration
      AND
    password_attempts >= v_sign_in_max_attempts
  ) THEN
    RAISE EXCEPTION 'ACCOUNT_LOCKED_EXCEED_ATTEMPTS';
  END IF;
  IF ("rls_encrypted_secrets".verify(v_email.owner_id, 'password_hash', PASSWORD)) THEN
    PERFORM "rls_simple_secrets".del(v_email.owner_id,
    ARRAY[
      'password_attempts', 'first_failed_password_attempt'
    ]);
    INSERT INTO "rls_roles_private".api_tokens (user_id)
      VALUES (v_email.owner_id)
    RETURNING
      * INTO v_token;
    RETURN v_token;
  ELSE
    IF (password_attempts IS NULL) THEN
      password_attempts = 0;
    END IF;
    IF (
      first_failed_password_attempt IS NULL
        OR
      first_failed_password_attempt < NOW() - v_sign_in_attempt_window_duration
    ) THEN
      password_attempts = 1;
      first_failed_password_attempt = NOW();
    ELSE 
      password_attempts = password_attempts + 1;
    END IF;
    PERFORM "rls_simple_secrets".set(v_email.owner_id, 'password_attempts', password_attempts);
    PERFORM "rls_simple_secrets".set(v_email.owner_id, 'first_failed_password_attempt', first_failed_password_attempt);
    RETURN NULL;
  END IF;
END;
$EOFCODE$ LANGUAGE plpgsql STRICT SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION rls_roles_public.login TO anonymous;

CREATE FUNCTION rls_roles_public.register ( email text, password text ) RETURNS rls_roles_private.api_tokens AS $EOFCODE$
DECLARE
  v_user "rls_public".users;
  v_email "rls_public".emails;
  v_token "rls_roles_private".api_tokens;
BEGIN
  IF (password IS NULL) THEN 
    RAISE EXCEPTION 'PASSWORD_LEN';
  END IF;
  password = trim(password);
  IF (character_length(password) <= 7 OR character_length(password) >= 64) THEN 
    RAISE EXCEPTION 'PASSWORD_LEN';
  END IF;
  SELECT * FROM "rls_public".emails t
    WHERE trim(register.email)::email = t.email
  INTO v_email;
  IF (NOT FOUND) THEN
    INSERT INTO "rls_public".users
      DEFAULT VALUES
    RETURNING
      * INTO v_user;
    INSERT INTO "rls_public".emails (owner_id, email)
      VALUES (v_user.id, trim(register.email))
    RETURNING
      * INTO v_email;
    INSERT INTO "rls_roles_private".api_tokens (user_id)
      VALUES (v_user.id)
    RETURNING
      * INTO v_token;
    PERFORM "rls_encrypted_secrets".set
      (v_user.id, 'password_hash', trim(password), 'crypt');
    RETURN v_token;
  END IF;
  RAISE EXCEPTION 'ACCOUNT_EXISTS';
END;
$EOFCODE$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION rls_roles_public.register TO anonymous;

CREATE FUNCTION rls_roles_public.set_password ( current_password text, new_password text ) RETURNS boolean AS $EOFCODE$
DECLARE
  v_user "rls_public".users;
  v_user_secret "rls_simple_secrets".user_secrets;
  password_exists boolean;
BEGIN
  IF (new_password IS NULL) THEN 
    RAISE EXCEPTION 'PASSWORD_LEN';
  END IF;
  new_password = trim(new_password);
  IF (character_length(new_password) <= 7 OR character_length(new_password) >= 64) THEN 
    RAISE EXCEPTION 'PASSWORD_LEN';
  END IF;
  SELECT
    u.* INTO v_user
  FROM
    "rls_public".users AS u
  WHERE
    id = "rls_roles_public".get_current_user_id ();
  IF (NOT FOUND) THEN
    RETURN FALSE;
  END IF;
  SELECT EXISTS (
    SELECT 1
      FROM "rls_encrypted_secrets".user_encrypted_secrets
      WHERE owner_id=v_user.id
        AND name='password_hash'
  )
  INTO password_exists;
  IF (password_exists IS TRUE) THEN 
    IF ("rls_encrypted_secrets".verify(
        v_user.id,
        'password_hash',
        current_password
    ) IS FALSE) THEN 
      RAISE EXCEPTION 'INCORRECT_PASSWORD';
    END IF;
  END IF;
  PERFORM "rls_encrypted_secrets".set
    (v_user.id, 'password_hash', new_password, 'crypt');
      
  RETURN TRUE;
END;
$EOFCODE$ LANGUAGE plpgsql VOLATILE;

GRANT EXECUTE ON FUNCTION rls_roles_public.set_password TO authenticated;

CREATE FUNCTION rls_roles_public.reset_password ( role_id uuid, reset_token text, new_password text ) RETURNS boolean AS $EOFCODE$
DECLARE
    v_user "rls_public".users;
    
    v_reset_max_interval interval = interval '3 days';
    v_reset_max_attempts int = 10;
    reset_password_attempts int;
    first_failed_reset_password_attempt timestamptz;
BEGIN
    IF (role_id IS NULL OR reset_token IS NULL OR new_password IS NULL) THEN
        RAISE EXCEPTION 'NULL_VALUES_DISALLOWED';
    END IF;
    SELECT
        u.* INTO v_user
    FROM
        "rls_public".users as u
    WHERE
        id = role_id;
    IF (NOT FOUND) THEN
      RETURN NULL;
    END IF;
    reset_password_attempts = "rls_simple_secrets".get(v_user.id, 'reset_password_attempts', '0');
    first_failed_reset_password_attempt = "rls_simple_secrets".get(v_user.id, 'first_failed_reset_password_attempt');
    IF (first_failed_reset_password_attempt IS NOT NULL
      AND NOW() < first_failed_reset_password_attempt + v_reset_max_interval
      AND reset_password_attempts >= v_reset_max_attempts) THEN
        RAISE
        EXCEPTION 'PASSWORD_RESET_LOCKED_EXCEED_ATTEMPTS';
    END IF;
    IF ("rls_encrypted_secrets".verify(v_user.id, 'reset_password_token', reset_token)) THEN
        PERFORM "rls_encrypted_secrets".set
            (v_user.id, 'password_hash', new_password, 'crypt');
        PERFORM "rls_simple_secrets".del(
            v_user.id,
            ARRAY[
                'password_attempts',
                'first_failed_password_attempt',
                'reset_password_token_generated',
                'reset_password_attempts',
                'first_failed_reset_password_attempt'                
            ]
        );
        PERFORM "rls_encrypted_secrets".del(
            v_user.id,
            'reset_password_token'
        );
        RETURN TRUE;
    ELSE
        IF (
            first_failed_reset_password_attempt IS NULL OR
            first_failed_reset_password_attempt + v_reset_max_interval < NOW() 
        ) THEN
            reset_password_attempts = 1;
            first_failed_reset_password_attempt = NOW();
        ELSE 
            reset_password_attempts = reset_password_attempts + 1;
        END IF;
        PERFORM "rls_simple_secrets".set(v_user.id, 'reset_password_attempts', reset_password_attempts);
        PERFORM "rls_simple_secrets".set(v_user.id, 'first_failed_reset_password_attempt', first_failed_reset_password_attempt);
    END IF;
    RETURN FALSE;
END;
$EOFCODE$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION rls_roles_public.reset_password TO anonymous;

REVOKE EXECUTE ON FUNCTION rls_roles_public.reset_password FROM authenticated;

CREATE FUNCTION rls_roles_public.forgot_password ( email email ) RETURNS void AS $EOFCODE$
DECLARE
    v_email "rls_public".emails;
    v_user_id uuid;
    v_reset_token text;
    v_reset_min_duration_between_emails interval = interval '3 minutes';
    
    v_reset_max_duration interval = interval '3 days';
    password_reset_email_sent_at timestamptz;
BEGIN
    SELECT * FROM "rls_public".emails e
        WHERE e.email = forgot_password.email::email
    INTO v_email;
    IF (NOT FOUND) THEN
        RETURN;
    END IF;
    v_user_id = v_email.owner_id;
    password_reset_email_sent_at = "rls_simple_secrets".get(v_user_id, 'password_reset_email_sent_at');
    IF (
        password_reset_email_sent_at IS NOT NULL AND
        NOW() < password_reset_email_sent_at + v_reset_min_duration_between_emails
    ) THEN 
        RETURN;
    END IF;
    v_reset_token = encode(gen_random_bytes(7), 'hex');
    PERFORM "rls_encrypted_secrets".set
        (v_user_id, 'reset_password_token', v_reset_token, 'crypt');
    PERFORM "rls_simple_secrets".set(v_user_id, 'password_reset_email_sent_at', (NOW())::text);
    PERFORM
        app_jobs.add_job ('send_email_link',
            json_build_object(
                'email_type', 'forgot_password',
                'user_id', v_user_id,
                'email', v_email.email::text,
                'reset_token', v_reset_token
            ));
    RETURN;
END;
$EOFCODE$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION rls_roles_public.forgot_password TO anonymous;

CREATE FUNCTION rls_roles_public.send_verification_email ( email email ) RETURNS boolean AS $EOFCODE$
DECLARE
  v_email "rls_public".emails;
  v_user_id uuid;
  v_verification_token text;
  v_verification_min_duration_between_emails interval = interval '3 minutes';
  v_verification_min_duration_between_new_tokens interval = interval '10 minutes';
  verification_token_name text;
  verification_email_sent_at timestamptz;
BEGIN
  SELECT * FROM "rls_public".emails e
    WHERE e.email = send_verification_email.email
  INTO v_email;
  IF (NOT FOUND) THEN 
    RETURN FALSE;
  END IF;
  verification_token_name = v_email.email::text || '_verification_token';
  IF ( v_email.is_verified IS TRUE ) THEN
    PERFORM "rls_simple_secrets".del(v_email.owner_id, ARRAY[
        'verification_email_sent_at',
        'verification_email_attempts',
        'first_failed_verification_email_attempt'
    ]);
    PERFORM "rls_encrypted_secrets".del(v_email.owner_id, ARRAY[
        verification_token_name
    ]);
    RETURN FALSE;
  END IF;
  v_user_id = v_email.owner_id;
  verification_email_sent_at = "rls_simple_secrets".get(v_user_id, 'verification_email_sent_at');
    IF (
      verification_email_sent_at IS NOT NULL AND
      NOW() < verification_email_sent_at + v_verification_min_duration_between_emails
    ) THEN 
        RETURN NULL;
    END IF;
  
  IF (
    verification_email_sent_at IS NOT NULL AND
    NOW() < verification_email_sent_at + v_verification_min_duration_between_new_tokens 
  ) THEN 
    v_verification_token = "rls_encrypted_secrets".get
        (v_user_id, verification_token_name, encode(gen_random_bytes(10), 'hex'));
  ELSE
    v_verification_token = encode(gen_random_bytes(10), 'hex');
  END IF;
  verification_email_sent_at = NOW();
  PERFORM "rls_simple_secrets".set
    (v_user_id, 'verification_email_sent_at', verification_email_sent_at);
  PERFORM "rls_encrypted_secrets".set
    (v_user_id, verification_token_name, v_verification_token, 'pgp');
  PERFORM
      app_jobs.add_job ('send_email_link',
        json_build_object(
          'email_type', 'email_verification',
          'email_id', v_email.id,
          'email', email,
          'verification_token', v_verification_token
        )
      );
  RETURN TRUE;
END;
$EOFCODE$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION rls_roles_public.send_verification_email TO authenticated, anonymous;

CREATE FUNCTION rls_roles_public.verify_email ( email_id uuid, token text ) RETURNS boolean AS $EOFCODE$
DECLARE
  v_email "rls_public".emails;
  v_user_id uuid;
  
  v_verification_expires_interval interval = interval '3 days';
  verification_token_name text;
  verification_email_attempts int;
  verification_email_sent_at timestamptz;
  first_failed_verification_email_attempt timestamptz;
BEGIN
  
  SELECT * FROM "rls_public".emails e
     WHERE e.id = verify_email.email_id
     AND e.is_verified = FALSE
  INTO v_email;
  IF ( NOT FOUND ) THEN
    RETURN FALSE;
  END IF;
  v_user_id = v_email.owner_id;
  verification_email_sent_at = "rls_simple_secrets".get(v_user_id, 'verification_email_sent_at');
  IF (verification_email_sent_at IS NOT NULL AND 
    verification_email_sent_at + v_verification_expires_interval < NOW() 
  ) THEN 
    
    PERFORM "rls_simple_secrets".del(v_user_id, ARRAY[
        'verification_email_sent_at',
        'verification_email_attempts',
        'first_failed_verification_email_attempt'
    ]);
    PERFORM "rls_encrypted_secrets".del(v_user_id, verification_token_name);
    RETURN FALSE;
  END IF;
  verification_token_name = v_email.email::text || '_verification_token';
  IF ("rls_encrypted_secrets".verify (v_user_id, verification_token_name, verify_email.token) ) THEN
    UPDATE "rls_public".emails e
        SET is_verified = TRUE
    WHERE e.id = verify_email.email_id;
    PERFORM "rls_simple_secrets".del(v_user_id, ARRAY[
        'verification_email_sent_at',
        'verification_email_attempts',
        'first_failed_verification_email_attempt'
    ]);
    PERFORM "rls_encrypted_secrets".del(v_user_id, verification_token_name);
    RETURN TRUE;
  ELSE
    IF (
        first_failed_verification_email_attempt IS NULL OR
        first_failed_verification_email_attempt + v_verification_expires_interval < NOW()
    ) THEN
        verification_email_attempts = 1;
        first_failed_verification_email_attempt = NOW();
    ELSE 
        verification_email_attempts = verification_email_attempts + 1;
    END IF;
    PERFORM "rls_simple_secrets".set(v_user_id, 'verification_email_attempts', verification_email_attempts);
    PERFORM "rls_simple_secrets".set(v_user_id, 'first_failed_verification_email_attempt', first_failed_verification_email_attempt);
    RETURN FALSE;
  END IF;
END;
$EOFCODE$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION rls_roles_public.verify_email TO anonymous, authenticated;

CREATE TABLE rls_public.user_profiles (
  
);

ALTER TABLE rls_public.user_profiles DISABLE ROW LEVEL SECURITY;

ALTER TABLE rls_public.user_profiles ADD COLUMN  id uuid;

ALTER TABLE rls_public.user_profiles ALTER COLUMN id SET NOT NULL;

ALTER TABLE rls_public.user_profiles ALTER COLUMN id SET DEFAULT rls_private.uuid_generate_v4();

ALTER TABLE rls_public.user_profiles ADD CONSTRAINT user_profiles_pkey PRIMARY KEY ( id );

ALTER TABLE rls_public.user_profiles ADD COLUMN  profile_picture image;

ALTER TABLE rls_public.user_profiles ADD COLUMN  bio text;

ALTER TABLE rls_public.user_profiles ADD COLUMN  display_name text;

ALTER TABLE rls_public.user_profiles ADD COLUMN  created_by uuid;

ALTER TABLE rls_public.user_profiles ADD COLUMN  updated_by uuid;

CREATE TRIGGER tg_peoplestamps 
 BEFORE INSERT OR UPDATE ON rls_public.user_profiles 
 FOR EACH ROW
 EXECUTE PROCEDURE rls_private. tg_peoplestamps (  );

ALTER TABLE rls_public.user_profiles ADD COLUMN  created_at timestamptz;

ALTER TABLE rls_public.user_profiles ALTER COLUMN created_at SET DEFAULT now();

ALTER TABLE rls_public.user_profiles ADD COLUMN  updated_at timestamptz;

ALTER TABLE rls_public.user_profiles ALTER COLUMN updated_at SET DEFAULT now();

CREATE TRIGGER tg_timestamps 
 BEFORE INSERT OR UPDATE ON rls_public.user_profiles 
 FOR EACH ROW
 EXECUTE PROCEDURE rls_private. tg_timestamps (  );

ALTER TABLE rls_public.user_profiles ADD COLUMN  user_id uuid;

ALTER TABLE rls_public.user_profiles ALTER COLUMN user_id SET NOT NULL;

ALTER TABLE rls_public.user_profiles ADD CONSTRAINT user_profiles_user_id_fkey FOREIGN KEY ( user_id ) REFERENCES rls_public.users ( id );

COMMENT ON CONSTRAINT user_profiles_user_id_fkey ON rls_public.user_profiles IS NULL;

CREATE INDEX user_profiles_user_id_idx ON rls_public.user_profiles ( user_id );

ALTER TABLE rls_public.user_profiles ADD CONSTRAINT user_profiles_user_id_key UNIQUE ( user_id );

COMMENT ON CONSTRAINT user_profiles_user_id_key ON rls_public.user_profiles IS NULL;

ALTER TABLE rls_public.user_profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY authenticated_can_insert_on_user_profiles ON rls_public.user_profiles FOR INSERT TO authenticated WITH CHECK ( user_id = rls_roles_public.get_current_user_id() );

CREATE POLICY authenticated_can_update_on_user_profiles ON rls_public.user_profiles FOR UPDATE TO authenticated USING ( user_id = rls_roles_public.get_current_user_id() );

CREATE POLICY authenticated_can_delete_on_user_profiles ON rls_public.user_profiles FOR DELETE TO authenticated USING ( user_id = rls_roles_public.get_current_user_id() );

GRANT INSERT ON TABLE rls_public.user_profiles TO authenticated;

GRANT UPDATE ON TABLE rls_public.user_profiles TO authenticated;

GRANT DELETE ON TABLE rls_public.user_profiles TO authenticated;

CREATE POLICY authenticated_can_select_on_user_profiles ON rls_public.user_profiles FOR SELECT TO authenticated USING ( TRUE );

GRANT SELECT ON TABLE rls_public.user_profiles TO authenticated;

CREATE TABLE rls_public.addresses (
  
);

ALTER TABLE rls_public.addresses DISABLE ROW LEVEL SECURITY;

ALTER TABLE rls_public.addresses ADD COLUMN  id uuid;

ALTER TABLE rls_public.addresses ALTER COLUMN id SET NOT NULL;

ALTER TABLE rls_public.addresses ALTER COLUMN id SET DEFAULT rls_private.uuid_generate_v4();

ALTER TABLE rls_public.addresses ADD CONSTRAINT addresses_pkey PRIMARY KEY ( id );

ALTER TABLE rls_public.addresses ADD COLUMN  address_line_1 text;

ALTER TABLE rls_public.addresses ADD CONSTRAINT addresses_address_line_1_chk CHECK ( character_length(address_line_1) <= 120 );

ALTER TABLE rls_public.addresses ADD COLUMN  address_line_2 text;

ALTER TABLE rls_public.addresses ADD CONSTRAINT addresses_address_line_2_chk CHECK ( character_length(address_line_2) <= 120 );

ALTER TABLE rls_public.addresses ADD COLUMN  address_line_3 text;

ALTER TABLE rls_public.addresses ADD CONSTRAINT addresses_address_line_3_chk CHECK ( character_length(address_line_3) <= 120 );

ALTER TABLE rls_public.addresses ADD COLUMN  city text;

ALTER TABLE rls_public.addresses ADD CONSTRAINT addresses_city_chk CHECK ( character_length(city) <= 120 );

ALTER TABLE rls_public.addresses ADD COLUMN  state text;

ALTER TABLE rls_public.addresses ADD CONSTRAINT addresses_state_chk CHECK ( character_length(state) <= 120 );

ALTER TABLE rls_public.addresses ADD COLUMN  county_province text;

ALTER TABLE rls_public.addresses ADD CONSTRAINT addresses_county_province_chk CHECK ( character_length(county_province) <= 120 );

ALTER TABLE rls_public.addresses ADD COLUMN  postcode text;

ALTER TABLE rls_public.addresses ADD CONSTRAINT addresses_postcode_chk CHECK ( character_length(postcode) <= 24 );

ALTER TABLE rls_public.addresses ADD COLUMN  other text;

ALTER TABLE rls_public.addresses ADD CONSTRAINT addresses_other_chk CHECK ( character_length(other) <= 120 );

ALTER TABLE rls_public.addresses ADD COLUMN  created_by uuid;

ALTER TABLE rls_public.addresses ADD COLUMN  updated_by uuid;

CREATE TRIGGER tg_peoplestamps 
 BEFORE INSERT OR UPDATE ON rls_public.addresses 
 FOR EACH ROW
 EXECUTE PROCEDURE rls_private. tg_peoplestamps (  );

ALTER TABLE rls_public.addresses ADD COLUMN  created_at timestamptz;

ALTER TABLE rls_public.addresses ALTER COLUMN created_at SET DEFAULT now();

ALTER TABLE rls_public.addresses ADD COLUMN  updated_at timestamptz;

ALTER TABLE rls_public.addresses ALTER COLUMN updated_at SET DEFAULT now();

CREATE TRIGGER tg_timestamps 
 BEFORE INSERT OR UPDATE ON rls_public.addresses 
 FOR EACH ROW
 EXECUTE PROCEDURE rls_private. tg_timestamps (  );

ALTER TABLE rls_public.addresses ADD COLUMN  owner_id uuid;

ALTER TABLE rls_public.addresses ALTER COLUMN owner_id SET NOT NULL;

ALTER TABLE rls_public.addresses ADD CONSTRAINT addresses_owner_id_fkey FOREIGN KEY ( owner_id ) REFERENCES rls_public.users ( id );

COMMENT ON CONSTRAINT addresses_owner_id_fkey ON rls_public.addresses IS E'@omit manyToMany';

CREATE INDEX addresses_owner_id_idx ON rls_public.addresses ( owner_id );

CREATE TABLE rls_public.organization_settings (
  
);

ALTER TABLE rls_public.organization_settings DISABLE ROW LEVEL SECURITY;

ALTER TABLE rls_public.organization_settings ADD COLUMN  id uuid;

ALTER TABLE rls_public.organization_settings ALTER COLUMN id SET NOT NULL;

ALTER TABLE rls_public.organization_settings ALTER COLUMN id SET DEFAULT rls_private.uuid_generate_v4();

ALTER TABLE rls_public.organization_settings ADD CONSTRAINT organization_settings_pkey PRIMARY KEY ( id );

ALTER TABLE rls_public.organization_settings ADD COLUMN  legal_name text;

ALTER TABLE rls_public.organization_settings ADD COLUMN  address_line_one text;

ALTER TABLE rls_public.organization_settings ADD COLUMN  address_line_two text;

ALTER TABLE rls_public.organization_settings ADD COLUMN  state text;

ALTER TABLE rls_public.organization_settings ADD COLUMN  city text;

ALTER TABLE rls_public.organization_settings ADD COLUMN  created_by uuid;

ALTER TABLE rls_public.organization_settings ADD COLUMN  updated_by uuid;

CREATE TRIGGER tg_peoplestamps 
 BEFORE INSERT OR UPDATE ON rls_public.organization_settings 
 FOR EACH ROW
 EXECUTE PROCEDURE rls_private. tg_peoplestamps (  );

ALTER TABLE rls_public.organization_settings ADD COLUMN  created_at timestamptz;

ALTER TABLE rls_public.organization_settings ALTER COLUMN created_at SET DEFAULT now();

ALTER TABLE rls_public.organization_settings ADD COLUMN  updated_at timestamptz;

ALTER TABLE rls_public.organization_settings ALTER COLUMN updated_at SET DEFAULT now();

CREATE TRIGGER tg_timestamps 
 BEFORE INSERT OR UPDATE ON rls_public.organization_settings 
 FOR EACH ROW
 EXECUTE PROCEDURE rls_private. tg_timestamps (  );

ALTER TABLE rls_public.organization_settings ADD COLUMN  organization_id uuid;

ALTER TABLE rls_public.organization_settings ALTER COLUMN organization_id SET NOT NULL;

ALTER TABLE rls_public.organization_settings ADD CONSTRAINT organization_settings_organization_id_fkey FOREIGN KEY ( organization_id ) REFERENCES rls_public.users ( id );

COMMENT ON CONSTRAINT organization_settings_organization_id_fkey ON rls_public.organization_settings IS E'@omit manyToMany';

CREATE INDEX organization_settings_organization_id_idx ON rls_public.organization_settings ( organization_id );

ALTER TABLE rls_public.organization_settings ADD CONSTRAINT organization_settings_organization_id_key UNIQUE ( organization_id );

COMMENT ON CONSTRAINT organization_settings_organization_id_key ON rls_public.organization_settings IS E'@omit';

ALTER TABLE rls_public.organization_settings ENABLE ROW LEVEL SECURITY;

CREATE POLICY authenticated_can_select_on_organization_settings ON rls_public.organization_settings FOR SELECT TO authenticated USING ( organization_id = rls_roles_public.get_current_user_id() );

CREATE POLICY authenticated_can_insert_on_organization_settings ON rls_public.organization_settings FOR INSERT TO authenticated WITH CHECK ( organization_id = rls_roles_public.get_current_user_id() );

CREATE POLICY authenticated_can_update_on_organization_settings ON rls_public.organization_settings FOR UPDATE TO authenticated USING ( organization_id = rls_roles_public.get_current_user_id() );

CREATE POLICY authenticated_can_delete_on_organization_settings ON rls_public.organization_settings FOR DELETE TO authenticated USING ( organization_id = rls_roles_public.get_current_user_id() );

GRANT SELECT ON TABLE rls_public.organization_settings TO authenticated;

GRANT INSERT ON TABLE rls_public.organization_settings TO authenticated;

GRANT UPDATE ON TABLE rls_public.organization_settings TO authenticated;

GRANT DELETE ON TABLE rls_public.organization_settings TO authenticated;

CREATE TABLE rls_public.user_settings (
  
);

ALTER TABLE rls_public.user_settings DISABLE ROW LEVEL SECURITY;

ALTER TABLE rls_public.user_settings ADD COLUMN  id uuid;

ALTER TABLE rls_public.user_settings ALTER COLUMN id SET NOT NULL;

ALTER TABLE rls_public.user_settings ALTER COLUMN id SET DEFAULT rls_private.uuid_generate_v4();

ALTER TABLE rls_public.user_settings ADD CONSTRAINT user_settings_pkey PRIMARY KEY ( id );

ALTER TABLE rls_public.user_settings ADD COLUMN  first_name text;

ALTER TABLE rls_public.user_settings ADD CONSTRAINT user_settings_first_name_chk CHECK ( character_length(first_name) <= 64 );

ALTER TABLE rls_public.user_settings ADD COLUMN  last_name text;

ALTER TABLE rls_public.user_settings ADD CONSTRAINT user_settings_last_name_chk CHECK ( character_length(last_name) <= 64 );

ALTER TABLE rls_public.user_settings ADD COLUMN  created_by uuid;

ALTER TABLE rls_public.user_settings ADD COLUMN  updated_by uuid;

CREATE TRIGGER tg_peoplestamps 
 BEFORE INSERT OR UPDATE ON rls_public.user_settings 
 FOR EACH ROW
 EXECUTE PROCEDURE rls_private. tg_peoplestamps (  );

ALTER TABLE rls_public.user_settings ADD COLUMN  created_at timestamptz;

ALTER TABLE rls_public.user_settings ALTER COLUMN created_at SET DEFAULT now();

ALTER TABLE rls_public.user_settings ADD COLUMN  updated_at timestamptz;

ALTER TABLE rls_public.user_settings ALTER COLUMN updated_at SET DEFAULT now();

CREATE TRIGGER tg_timestamps 
 BEFORE INSERT OR UPDATE ON rls_public.user_settings 
 FOR EACH ROW
 EXECUTE PROCEDURE rls_private. tg_timestamps (  );

ALTER TABLE rls_public.user_settings ADD COLUMN  user_id uuid;

ALTER TABLE rls_public.user_settings ALTER COLUMN user_id SET NOT NULL;

ALTER TABLE rls_public.user_settings ADD CONSTRAINT user_settings_user_id_fkey FOREIGN KEY ( user_id ) REFERENCES rls_public.users ( id );

COMMENT ON CONSTRAINT user_settings_user_id_fkey ON rls_public.user_settings IS NULL;

CREATE INDEX user_settings_user_id_idx ON rls_public.user_settings ( user_id );

ALTER TABLE rls_public.user_settings ADD CONSTRAINT user_settings_user_id_key UNIQUE ( user_id );

COMMENT ON CONSTRAINT user_settings_user_id_key ON rls_public.user_settings IS NULL;

ALTER TABLE rls_public.user_settings ENABLE ROW LEVEL SECURITY;

CREATE POLICY authenticated_can_select_on_user_settings ON rls_public.user_settings FOR SELECT TO authenticated USING ( user_id = rls_roles_public.get_current_user_id() );

CREATE POLICY authenticated_can_insert_on_user_settings ON rls_public.user_settings FOR INSERT TO authenticated WITH CHECK ( user_id = rls_roles_public.get_current_user_id() );

CREATE POLICY authenticated_can_update_on_user_settings ON rls_public.user_settings FOR UPDATE TO authenticated USING ( user_id = rls_roles_public.get_current_user_id() );

CREATE POLICY authenticated_can_delete_on_user_settings ON rls_public.user_settings FOR DELETE TO authenticated USING ( user_id = rls_roles_public.get_current_user_id() );

GRANT SELECT ON TABLE rls_public.user_settings TO authenticated;

GRANT INSERT ON TABLE rls_public.user_settings TO authenticated;

GRANT UPDATE ON TABLE rls_public.user_settings TO authenticated;

GRANT DELETE ON TABLE rls_public.user_settings TO authenticated;

CREATE TABLE rls_public.user_characteristics (
  
);

ALTER TABLE rls_public.user_characteristics DISABLE ROW LEVEL SECURITY;

ALTER TABLE rls_public.user_characteristics ADD COLUMN  id uuid;

ALTER TABLE rls_public.user_characteristics ALTER COLUMN id SET NOT NULL;

ALTER TABLE rls_public.user_characteristics ALTER COLUMN id SET DEFAULT rls_private.uuid_generate_v4();

ALTER TABLE rls_public.user_characteristics ADD CONSTRAINT user_characteristics_pkey PRIMARY KEY ( id );

ALTER TABLE rls_public.user_characteristics ADD COLUMN  income numeric;

ALTER TABLE rls_public.user_characteristics ADD COLUMN  gender char(1);

ALTER TABLE rls_public.user_characteristics ADD COLUMN  race text;

ALTER TABLE rls_public.user_characteristics ADD COLUMN  dob date;

ALTER TABLE rls_public.user_characteristics ADD COLUMN  created_by uuid;

ALTER TABLE rls_public.user_characteristics ADD COLUMN  updated_by uuid;

CREATE TRIGGER tg_peoplestamps 
 BEFORE INSERT OR UPDATE ON rls_public.user_characteristics 
 FOR EACH ROW
 EXECUTE PROCEDURE rls_private. tg_peoplestamps (  );

ALTER TABLE rls_public.user_characteristics ADD COLUMN  created_at timestamptz;

ALTER TABLE rls_public.user_characteristics ALTER COLUMN created_at SET DEFAULT now();

ALTER TABLE rls_public.user_characteristics ADD COLUMN  updated_at timestamptz;

ALTER TABLE rls_public.user_characteristics ALTER COLUMN updated_at SET DEFAULT now();

CREATE TRIGGER tg_timestamps 
 BEFORE INSERT OR UPDATE ON rls_public.user_characteristics 
 FOR EACH ROW
 EXECUTE PROCEDURE rls_private. tg_timestamps (  );

ALTER TABLE rls_public.user_characteristics ADD COLUMN  user_id uuid;

ALTER TABLE rls_public.user_characteristics ALTER COLUMN user_id SET NOT NULL;

ALTER TABLE rls_public.user_characteristics ADD CONSTRAINT user_characteristics_user_id_fkey FOREIGN KEY ( user_id ) REFERENCES rls_public.users ( id );

COMMENT ON CONSTRAINT user_characteristics_user_id_fkey ON rls_public.user_characteristics IS NULL;

CREATE INDEX user_characteristics_user_id_idx ON rls_public.user_characteristics ( user_id );

ALTER TABLE rls_public.user_characteristics ADD CONSTRAINT user_characteristics_user_id_key UNIQUE ( user_id );

COMMENT ON CONSTRAINT user_characteristics_user_id_key ON rls_public.user_characteristics IS NULL;

ALTER TABLE rls_public.user_characteristics ENABLE ROW LEVEL SECURITY;

CREATE POLICY authenticated_can_select_on_user_characteristics ON rls_public.user_characteristics FOR SELECT TO authenticated USING ( user_id = rls_roles_public.get_current_user_id() );

CREATE POLICY authenticated_can_insert_on_user_characteristics ON rls_public.user_characteristics FOR INSERT TO authenticated WITH CHECK ( user_id = rls_roles_public.get_current_user_id() );

CREATE POLICY authenticated_can_update_on_user_characteristics ON rls_public.user_characteristics FOR UPDATE TO authenticated USING ( user_id = rls_roles_public.get_current_user_id() );

CREATE POLICY authenticated_can_delete_on_user_characteristics ON rls_public.user_characteristics FOR DELETE TO authenticated USING ( user_id = rls_roles_public.get_current_user_id() );

GRANT SELECT ON TABLE rls_public.user_characteristics TO authenticated;

GRANT INSERT ON TABLE rls_public.user_characteristics TO authenticated;

GRANT UPDATE ON TABLE rls_public.user_characteristics TO authenticated;

GRANT DELETE ON TABLE rls_public.user_characteristics TO authenticated;

CREATE TABLE rls_public.user_contacts (
  
);

ALTER TABLE rls_public.user_contacts DISABLE ROW LEVEL SECURITY;

ALTER TABLE rls_public.user_contacts ADD COLUMN  id uuid;

ALTER TABLE rls_public.user_contacts ALTER COLUMN id SET NOT NULL;

ALTER TABLE rls_public.user_contacts ALTER COLUMN id SET DEFAULT rls_private.uuid_generate_v4();

ALTER TABLE rls_public.user_contacts ADD CONSTRAINT user_contacts_pkey PRIMARY KEY ( id );

ALTER TABLE rls_public.user_contacts ADD COLUMN  vcf jsonb;

ALTER TABLE rls_public.user_contacts ADD COLUMN  full_name text;

ALTER TABLE rls_public.user_contacts ADD CONSTRAINT user_contacts_full_name_chk CHECK ( character_length(full_name) <= 120 );

COMMENT ON COLUMN rls_public.user_contacts.full_name IS E'full name of the person or business';

ALTER TABLE rls_public.user_contacts ADD COLUMN  emails email[];

ALTER TABLE rls_public.user_contacts ADD COLUMN  device text;

COMMENT ON COLUMN rls_public.user_contacts.device IS E'originating device type or id';

ALTER TABLE rls_public.user_contacts ADD COLUMN  created_by uuid;

ALTER TABLE rls_public.user_contacts ADD COLUMN  updated_by uuid;

CREATE TRIGGER tg_peoplestamps 
 BEFORE INSERT OR UPDATE ON rls_public.user_contacts 
 FOR EACH ROW
 EXECUTE PROCEDURE rls_private. tg_peoplestamps (  );

ALTER TABLE rls_public.user_contacts ADD COLUMN  created_at timestamptz;

ALTER TABLE rls_public.user_contacts ALTER COLUMN created_at SET DEFAULT now();

ALTER TABLE rls_public.user_contacts ADD COLUMN  updated_at timestamptz;

ALTER TABLE rls_public.user_contacts ALTER COLUMN updated_at SET DEFAULT now();

CREATE TRIGGER tg_timestamps 
 BEFORE INSERT OR UPDATE ON rls_public.user_contacts 
 FOR EACH ROW
 EXECUTE PROCEDURE rls_private. tg_timestamps (  );

ALTER TABLE rls_public.user_contacts ADD COLUMN  user_id uuid;

ALTER TABLE rls_public.user_contacts ALTER COLUMN user_id SET NOT NULL;

ALTER TABLE rls_public.user_contacts ADD CONSTRAINT user_contacts_user_id_fkey FOREIGN KEY ( user_id ) REFERENCES rls_public.users ( id );

COMMENT ON CONSTRAINT user_contacts_user_id_fkey ON rls_public.user_contacts IS NULL;

CREATE INDEX user_contacts_user_id_idx ON rls_public.user_contacts ( user_id );

ALTER TABLE rls_public.user_contacts ENABLE ROW LEVEL SECURITY;

CREATE POLICY authenticated_can_select_on_user_contacts ON rls_public.user_contacts FOR SELECT TO authenticated USING ( user_id = rls_roles_public.get_current_user_id() );

CREATE POLICY authenticated_can_insert_on_user_contacts ON rls_public.user_contacts FOR INSERT TO authenticated WITH CHECK ( user_id = rls_roles_public.get_current_user_id() );

CREATE POLICY authenticated_can_update_on_user_contacts ON rls_public.user_contacts FOR UPDATE TO authenticated USING ( user_id = rls_roles_public.get_current_user_id() );

CREATE POLICY authenticated_can_delete_on_user_contacts ON rls_public.user_contacts FOR DELETE TO authenticated USING ( user_id = rls_roles_public.get_current_user_id() );

GRANT SELECT ON TABLE rls_public.user_contacts TO authenticated;

GRANT INSERT ON TABLE rls_public.user_contacts TO authenticated;

GRANT UPDATE ON TABLE rls_public.user_contacts TO authenticated;

GRANT DELETE ON TABLE rls_public.user_contacts TO authenticated;

CREATE TABLE rls_public.user_connections (
  
);

ALTER TABLE rls_public.user_connections DISABLE ROW LEVEL SECURITY;

ALTER TABLE rls_public.user_connections ADD COLUMN  id uuid;

ALTER TABLE rls_public.user_connections ALTER COLUMN id SET NOT NULL;

ALTER TABLE rls_public.user_connections ALTER COLUMN id SET DEFAULT rls_private.uuid_generate_v4();

ALTER TABLE rls_public.user_connections ADD CONSTRAINT user_connections_pkey PRIMARY KEY ( id );

ALTER TABLE rls_public.user_connections ADD COLUMN  accepted bool;

ALTER TABLE rls_public.user_connections ADD COLUMN  created_by uuid;

ALTER TABLE rls_public.user_connections ADD COLUMN  updated_by uuid;

CREATE TRIGGER tg_peoplestamps 
 BEFORE INSERT OR UPDATE ON rls_public.user_connections 
 FOR EACH ROW
 EXECUTE PROCEDURE rls_private. tg_peoplestamps (  );

ALTER TABLE rls_public.user_connections ADD COLUMN  created_at timestamptz;

ALTER TABLE rls_public.user_connections ALTER COLUMN created_at SET DEFAULT now();

ALTER TABLE rls_public.user_connections ADD COLUMN  updated_at timestamptz;

ALTER TABLE rls_public.user_connections ALTER COLUMN updated_at SET DEFAULT now();

CREATE TRIGGER tg_timestamps 
 BEFORE INSERT OR UPDATE ON rls_public.user_connections 
 FOR EACH ROW
 EXECUTE PROCEDURE rls_private. tg_timestamps (  );

ALTER TABLE rls_public.user_connections ADD COLUMN  requester_id uuid;

ALTER TABLE rls_public.user_connections ALTER COLUMN requester_id SET NOT NULL;

ALTER TABLE rls_public.user_connections ADD CONSTRAINT user_connections_requester_id_fkey FOREIGN KEY ( requester_id ) REFERENCES rls_public.users ( id );

COMMENT ON CONSTRAINT user_connections_requester_id_fkey ON rls_public.user_connections IS NULL;

CREATE INDEX user_connections_requester_id_idx ON rls_public.user_connections ( requester_id );

ALTER TABLE rls_public.user_connections ADD COLUMN  responder_id uuid;

ALTER TABLE rls_public.user_connections ALTER COLUMN responder_id SET NOT NULL;

ALTER TABLE rls_public.user_connections ADD CONSTRAINT user_connections_responder_id_fkey FOREIGN KEY ( responder_id ) REFERENCES rls_public.users ( id );

COMMENT ON CONSTRAINT user_connections_responder_id_fkey ON rls_public.user_connections IS NULL;

CREATE INDEX user_connections_responder_id_idx ON rls_public.user_connections ( responder_id );

ALTER TABLE rls_public.user_connections ADD CONSTRAINT user_connections_requester_id_responder_id_key UNIQUE ( requester_id, responder_id );

COMMENT ON CONSTRAINT user_connections_requester_id_responder_id_key ON rls_public.user_connections IS NULL;

ALTER TABLE rls_public.user_connections ENABLE ROW LEVEL SECURITY;

CREATE POLICY authenticated_can_select_on_user_connections ON rls_public.user_connections FOR SELECT TO authenticated USING ( responder_id = rls_roles_public.get_current_user_id() OR requester_id = rls_roles_public.get_current_user_id() );

CREATE POLICY authenticated_can_delete_on_user_connections ON rls_public.user_connections FOR DELETE TO authenticated USING ( responder_id = rls_roles_public.get_current_user_id() OR requester_id = rls_roles_public.get_current_user_id() );

GRANT SELECT ON TABLE rls_public.user_connections TO authenticated;

GRANT DELETE ON TABLE rls_public.user_connections TO authenticated;

CREATE POLICY authenticated_can_update_on_user_connections ON rls_public.user_connections FOR UPDATE TO authenticated USING ( responder_id = rls_roles_public.get_current_user_id() );

GRANT UPDATE ( accepted ) ON TABLE rls_public.user_connections TO authenticated;

CREATE POLICY authenticated_can_insert_on_user_connections ON rls_public.user_connections FOR INSERT TO authenticated WITH CHECK ( requester_id = rls_roles_public.get_current_user_id() );

GRANT INSERT ON TABLE rls_public.user_connections TO authenticated;

CREATE TABLE rls_public.organization_profiles (
  
);

ALTER TABLE rls_public.organization_profiles DISABLE ROW LEVEL SECURITY;

ALTER TABLE rls_public.organization_profiles ADD COLUMN  id uuid;

ALTER TABLE rls_public.organization_profiles ALTER COLUMN id SET NOT NULL;

ALTER TABLE rls_public.organization_profiles ALTER COLUMN id SET DEFAULT rls_private.uuid_generate_v4();

ALTER TABLE rls_public.organization_profiles ADD CONSTRAINT organization_profiles_pkey PRIMARY KEY ( id );

ALTER TABLE rls_public.organization_profiles ADD COLUMN  name text;

ALTER TABLE rls_public.organization_profiles ADD COLUMN  profile_picture image;

ALTER TABLE rls_public.organization_profiles ADD COLUMN  description text;

ALTER TABLE rls_public.organization_profiles ADD COLUMN  created_by uuid;

ALTER TABLE rls_public.organization_profiles ADD COLUMN  updated_by uuid;

CREATE TRIGGER tg_peoplestamps 
 BEFORE INSERT OR UPDATE ON rls_public.organization_profiles 
 FOR EACH ROW
 EXECUTE PROCEDURE rls_private. tg_peoplestamps (  );

ALTER TABLE rls_public.organization_profiles ADD COLUMN  created_at timestamptz;

ALTER TABLE rls_public.organization_profiles ALTER COLUMN created_at SET DEFAULT now();

ALTER TABLE rls_public.organization_profiles ADD COLUMN  updated_at timestamptz;

ALTER TABLE rls_public.organization_profiles ALTER COLUMN updated_at SET DEFAULT now();

CREATE TRIGGER tg_timestamps 
 BEFORE INSERT OR UPDATE ON rls_public.organization_profiles 
 FOR EACH ROW
 EXECUTE PROCEDURE rls_private. tg_timestamps (  );

ALTER TABLE rls_public.organization_profiles ADD COLUMN  organization_id uuid;

ALTER TABLE rls_public.organization_profiles ALTER COLUMN organization_id SET NOT NULL;

ALTER TABLE rls_public.organization_profiles ADD CONSTRAINT organization_profiles_organization_id_fkey FOREIGN KEY ( organization_id ) REFERENCES rls_public.users ( id );

COMMENT ON CONSTRAINT organization_profiles_organization_id_fkey ON rls_public.organization_profiles IS NULL;

CREATE INDEX organization_profiles_organization_id_idx ON rls_public.organization_profiles ( organization_id );

ALTER TABLE rls_public.organization_profiles ADD CONSTRAINT organization_profiles_organization_id_key UNIQUE ( organization_id );

COMMENT ON CONSTRAINT organization_profiles_organization_id_key ON rls_public.organization_profiles IS NULL;

ALTER TABLE rls_public.organization_profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY authenticated_can_insert_on_organization_profiles ON rls_public.organization_profiles FOR INSERT TO authenticated WITH CHECK ( organization_id = rls_roles_public.get_current_user_id() );

CREATE POLICY authenticated_can_update_on_organization_profiles ON rls_public.organization_profiles FOR UPDATE TO authenticated USING ( organization_id = rls_roles_public.get_current_user_id() );

CREATE POLICY authenticated_can_delete_on_organization_profiles ON rls_public.organization_profiles FOR DELETE TO authenticated USING ( organization_id = rls_roles_public.get_current_user_id() );

GRANT INSERT ON TABLE rls_public.organization_profiles TO authenticated;

GRANT UPDATE ON TABLE rls_public.organization_profiles TO authenticated;

GRANT DELETE ON TABLE rls_public.organization_profiles TO authenticated;

CREATE POLICY authenticated_can_select_on_organization_profiles ON rls_public.organization_profiles FOR SELECT TO authenticated USING ( TRUE );

GRANT SELECT ON TABLE rls_public.organization_profiles TO authenticated;

CREATE TRIGGER user_profiles_insert_status_achievement_profile_picture_tg 
 BEFORE INSERT ON rls_public.user_profiles 
 FOR EACH ROW
 EXECUTE PROCEDURE rls_private. tg_achievement_toggle ( 'profile_picture','upload_profile_picture' );

CREATE TRIGGER user_profiles_update_status_achievement_profile_picture_tg 
 BEFORE UPDATE ON rls_public.user_profiles 
 FOR EACH ROW
 WHEN ( OLD.profile_picture IS DISTINCT FROM NEW.profile_picture ) 
 EXECUTE PROCEDURE rls_private. tg_achievement_toggle ( 'profile_picture','upload_profile_picture' );

CREATE TRIGGER emails_insert_status_achievement_is_verified_tg 
 BEFORE INSERT ON rls_public.emails 
 FOR EACH ROW
 EXECUTE PROCEDURE rls_private. tg_achievement_boolean ( 'is_verified','email_verified' );

CREATE TRIGGER emails_update_status_achievement_is_verified_tg 
 BEFORE UPDATE ON rls_public.emails 
 FOR EACH ROW
 WHEN ( OLD.is_verified IS DISTINCT FROM NEW.is_verified ) 
 EXECUTE PROCEDURE rls_private. tg_achievement_boolean ( 'is_verified','email_verified' );

ALTER TABLE collections_public.database ENABLE ROW LEVEL SECURITY;

CREATE POLICY authenticated_can_select_on_database ON collections_public.database FOR SELECT TO authenticated USING ( owner_id = rls_roles_public.get_current_user_id() );

CREATE POLICY authenticated_can_insert_on_database ON collections_public.database FOR INSERT TO authenticated WITH CHECK ( owner_id = rls_roles_public.get_current_user_id() );

CREATE POLICY authenticated_can_update_on_database ON collections_public.database FOR UPDATE TO authenticated USING ( owner_id = rls_roles_public.get_current_user_id() );

CREATE POLICY authenticated_can_delete_on_database ON collections_public.database FOR DELETE TO authenticated USING ( owner_id = rls_roles_public.get_current_user_id() );

GRANT SELECT ON TABLE collections_public.database TO authenticated;

GRANT INSERT ON TABLE collections_public.database TO authenticated;

GRANT UPDATE ON TABLE collections_public.database TO authenticated;

GRANT DELETE ON TABLE collections_public.database TO authenticated;

ALTER TABLE collections_public.schema ENABLE ROW LEVEL SECURITY;

CREATE POLICY authenticated_can_select_on_schema ON collections_public.schema FOR SELECT TO authenticated USING ( (SELECT p.owner_id = ANY (rls_roles_public.get_current_group_ids()) FROM collections_public.database AS p WHERE p.id = database_id) );

CREATE POLICY authenticated_can_insert_on_schema ON collections_public.schema FOR INSERT TO authenticated WITH CHECK ( (SELECT p.owner_id = ANY (rls_roles_public.get_current_group_ids()) FROM collections_public.database AS p WHERE p.id = database_id) );

CREATE POLICY authenticated_can_update_on_schema ON collections_public.schema FOR UPDATE TO authenticated USING ( (SELECT p.owner_id = ANY (rls_roles_public.get_current_group_ids()) FROM collections_public.database AS p WHERE p.id = database_id) );

CREATE POLICY authenticated_can_delete_on_schema ON collections_public.schema FOR DELETE TO authenticated USING ( (SELECT p.owner_id = ANY (rls_roles_public.get_current_group_ids()) FROM collections_public.database AS p WHERE p.id = database_id) );

GRANT SELECT ON TABLE collections_public.schema TO authenticated;

GRANT INSERT ON TABLE collections_public.schema TO authenticated;

GRANT UPDATE ON TABLE collections_public.schema TO authenticated;

GRANT DELETE ON TABLE collections_public.schema TO authenticated;

ALTER TABLE collections_public.foreign_key_constraint ENABLE ROW LEVEL SECURITY;

CREATE POLICY authenticated_can_select_on_foreign_key_constraint ON collections_public.foreign_key_constraint FOR SELECT TO authenticated USING ( (SELECT p.owner_id = ANY (rls_roles_public.get_current_group_ids()) FROM collections_public.database AS p WHERE p.id = database_id) );

CREATE POLICY authenticated_can_insert_on_foreign_key_constraint ON collections_public.foreign_key_constraint FOR INSERT TO authenticated WITH CHECK ( (SELECT p.owner_id = ANY (rls_roles_public.get_current_group_ids()) FROM collections_public.database AS p WHERE p.id = database_id) );

CREATE POLICY authenticated_can_update_on_foreign_key_constraint ON collections_public.foreign_key_constraint FOR UPDATE TO authenticated USING ( (SELECT p.owner_id = ANY (rls_roles_public.get_current_group_ids()) FROM collections_public.database AS p WHERE p.id = database_id) );

CREATE POLICY authenticated_can_delete_on_foreign_key_constraint ON collections_public.foreign_key_constraint FOR DELETE TO authenticated USING ( (SELECT p.owner_id = ANY (rls_roles_public.get_current_group_ids()) FROM collections_public.database AS p WHERE p.id = database_id) );

GRANT SELECT ON TABLE collections_public.foreign_key_constraint TO authenticated;

GRANT INSERT ON TABLE collections_public.foreign_key_constraint TO authenticated;

GRANT UPDATE ON TABLE collections_public.foreign_key_constraint TO authenticated;

GRANT DELETE ON TABLE collections_public.foreign_key_constraint TO authenticated;

ALTER TABLE collections_public.full_text_search ENABLE ROW LEVEL SECURITY;

CREATE POLICY authenticated_can_select_on_full_text_search ON collections_public.full_text_search FOR SELECT TO authenticated USING ( (SELECT p.owner_id = ANY (rls_roles_public.get_current_group_ids()) FROM collections_public.database AS p WHERE p.id = database_id) );

CREATE POLICY authenticated_can_insert_on_full_text_search ON collections_public.full_text_search FOR INSERT TO authenticated WITH CHECK ( (SELECT p.owner_id = ANY (rls_roles_public.get_current_group_ids()) FROM collections_public.database AS p WHERE p.id = database_id) );

CREATE POLICY authenticated_can_update_on_full_text_search ON collections_public.full_text_search FOR UPDATE TO authenticated USING ( (SELECT p.owner_id = ANY (rls_roles_public.get_current_group_ids()) FROM collections_public.database AS p WHERE p.id = database_id) );

CREATE POLICY authenticated_can_delete_on_full_text_search ON collections_public.full_text_search FOR DELETE TO authenticated USING ( (SELECT p.owner_id = ANY (rls_roles_public.get_current_group_ids()) FROM collections_public.database AS p WHERE p.id = database_id) );

GRANT SELECT ON TABLE collections_public.full_text_search TO authenticated;

GRANT INSERT ON TABLE collections_public.full_text_search TO authenticated;

GRANT UPDATE ON TABLE collections_public.full_text_search TO authenticated;

GRANT DELETE ON TABLE collections_public.full_text_search TO authenticated;

ALTER TABLE collections_public.index ENABLE ROW LEVEL SECURITY;

CREATE POLICY authenticated_can_select_on_index ON collections_public.index FOR SELECT TO authenticated USING ( (SELECT p.owner_id = ANY (rls_roles_public.get_current_group_ids()) FROM collections_public.database AS p WHERE p.id = database_id) );

CREATE POLICY authenticated_can_insert_on_index ON collections_public.index FOR INSERT TO authenticated WITH CHECK ( (SELECT p.owner_id = ANY (rls_roles_public.get_current_group_ids()) FROM collections_public.database AS p WHERE p.id = database_id) );

CREATE POLICY authenticated_can_update_on_index ON collections_public.index FOR UPDATE TO authenticated USING ( (SELECT p.owner_id = ANY (rls_roles_public.get_current_group_ids()) FROM collections_public.database AS p WHERE p.id = database_id) );

CREATE POLICY authenticated_can_delete_on_index ON collections_public.index FOR DELETE TO authenticated USING ( (SELECT p.owner_id = ANY (rls_roles_public.get_current_group_ids()) FROM collections_public.database AS p WHERE p.id = database_id) );

GRANT SELECT ON TABLE collections_public.index TO authenticated;

GRANT INSERT ON TABLE collections_public.index TO authenticated;

GRANT UPDATE ON TABLE collections_public.index TO authenticated;

GRANT DELETE ON TABLE collections_public.index TO authenticated;

ALTER TABLE collections_public.rls_function ENABLE ROW LEVEL SECURITY;

CREATE POLICY authenticated_can_select_on_rls_function ON collections_public.rls_function FOR SELECT TO authenticated USING ( (SELECT p.owner_id = ANY (rls_roles_public.get_current_group_ids()) FROM collections_public.database AS p WHERE p.id = database_id) );

CREATE POLICY authenticated_can_insert_on_rls_function ON collections_public.rls_function FOR INSERT TO authenticated WITH CHECK ( (SELECT p.owner_id = ANY (rls_roles_public.get_current_group_ids()) FROM collections_public.database AS p WHERE p.id = database_id) );

CREATE POLICY authenticated_can_update_on_rls_function ON collections_public.rls_function FOR UPDATE TO authenticated USING ( (SELECT p.owner_id = ANY (rls_roles_public.get_current_group_ids()) FROM collections_public.database AS p WHERE p.id = database_id) );

CREATE POLICY authenticated_can_delete_on_rls_function ON collections_public.rls_function FOR DELETE TO authenticated USING ( (SELECT p.owner_id = ANY (rls_roles_public.get_current_group_ids()) FROM collections_public.database AS p WHERE p.id = database_id) );

GRANT SELECT ON TABLE collections_public.rls_function TO authenticated;

GRANT INSERT ON TABLE collections_public.rls_function TO authenticated;

GRANT UPDATE ON TABLE collections_public.rls_function TO authenticated;

GRANT DELETE ON TABLE collections_public.rls_function TO authenticated;

ALTER TABLE collections_public.policy ENABLE ROW LEVEL SECURITY;

CREATE POLICY authenticated_can_select_on_policy ON collections_public.policy FOR SELECT TO authenticated USING ( (SELECT p.owner_id = ANY (rls_roles_public.get_current_group_ids()) FROM collections_public.database AS p WHERE p.id = database_id) );

CREATE POLICY authenticated_can_insert_on_policy ON collections_public.policy FOR INSERT TO authenticated WITH CHECK ( (SELECT p.owner_id = ANY (rls_roles_public.get_current_group_ids()) FROM collections_public.database AS p WHERE p.id = database_id) );

CREATE POLICY authenticated_can_update_on_policy ON collections_public.policy FOR UPDATE TO authenticated USING ( (SELECT p.owner_id = ANY (rls_roles_public.get_current_group_ids()) FROM collections_public.database AS p WHERE p.id = database_id) );

CREATE POLICY authenticated_can_delete_on_policy ON collections_public.policy FOR DELETE TO authenticated USING ( (SELECT p.owner_id = ANY (rls_roles_public.get_current_group_ids()) FROM collections_public.database AS p WHERE p.id = database_id) );

GRANT SELECT ON TABLE collections_public.policy TO authenticated;

GRANT INSERT ON TABLE collections_public.policy TO authenticated;

GRANT UPDATE ON TABLE collections_public.policy TO authenticated;

GRANT DELETE ON TABLE collections_public.policy TO authenticated;

ALTER TABLE collections_public.primary_key_constraint ENABLE ROW LEVEL SECURITY;

CREATE POLICY authenticated_can_select_on_primary_key_constraint ON collections_public.primary_key_constraint FOR SELECT TO authenticated USING ( (SELECT p.owner_id = ANY (rls_roles_public.get_current_group_ids()) FROM collections_public.database AS p WHERE p.id = database_id) );

CREATE POLICY authenticated_can_insert_on_primary_key_constraint ON collections_public.primary_key_constraint FOR INSERT TO authenticated WITH CHECK ( (SELECT p.owner_id = ANY (rls_roles_public.get_current_group_ids()) FROM collections_public.database AS p WHERE p.id = database_id) );

CREATE POLICY authenticated_can_update_on_primary_key_constraint ON collections_public.primary_key_constraint FOR UPDATE TO authenticated USING ( (SELECT p.owner_id = ANY (rls_roles_public.get_current_group_ids()) FROM collections_public.database AS p WHERE p.id = database_id) );

CREATE POLICY authenticated_can_delete_on_primary_key_constraint ON collections_public.primary_key_constraint FOR DELETE TO authenticated USING ( (SELECT p.owner_id = ANY (rls_roles_public.get_current_group_ids()) FROM collections_public.database AS p WHERE p.id = database_id) );

GRANT SELECT ON TABLE collections_public.primary_key_constraint TO authenticated;

GRANT INSERT ON TABLE collections_public.primary_key_constraint TO authenticated;

GRANT UPDATE ON TABLE collections_public.primary_key_constraint TO authenticated;

GRANT DELETE ON TABLE collections_public.primary_key_constraint TO authenticated;

ALTER TABLE collections_public.procedure ENABLE ROW LEVEL SECURITY;

CREATE POLICY authenticated_can_select_on_procedure ON collections_public.procedure FOR SELECT TO authenticated USING ( (SELECT p.owner_id = ANY (rls_roles_public.get_current_group_ids()) FROM collections_public.database AS p WHERE p.id = database_id) );

CREATE POLICY authenticated_can_insert_on_procedure ON collections_public.procedure FOR INSERT TO authenticated WITH CHECK ( (SELECT p.owner_id = ANY (rls_roles_public.get_current_group_ids()) FROM collections_public.database AS p WHERE p.id = database_id) );

CREATE POLICY authenticated_can_update_on_procedure ON collections_public.procedure FOR UPDATE TO authenticated USING ( (SELECT p.owner_id = ANY (rls_roles_public.get_current_group_ids()) FROM collections_public.database AS p WHERE p.id = database_id) );

CREATE POLICY authenticated_can_delete_on_procedure ON collections_public.procedure FOR DELETE TO authenticated USING ( (SELECT p.owner_id = ANY (rls_roles_public.get_current_group_ids()) FROM collections_public.database AS p WHERE p.id = database_id) );

GRANT SELECT ON TABLE collections_public.procedure TO authenticated;

GRANT INSERT ON TABLE collections_public.procedure TO authenticated;

GRANT UPDATE ON TABLE collections_public.procedure TO authenticated;

GRANT DELETE ON TABLE collections_public.procedure TO authenticated;

ALTER TABLE collections_public.schema_grant ENABLE ROW LEVEL SECURITY;

CREATE POLICY authenticated_can_select_on_schema_grant ON collections_public.schema_grant FOR SELECT TO authenticated USING ( (SELECT p.owner_id = ANY (rls_roles_public.get_current_group_ids()) FROM collections_public.database AS p WHERE p.id = database_id) );

CREATE POLICY authenticated_can_insert_on_schema_grant ON collections_public.schema_grant FOR INSERT TO authenticated WITH CHECK ( (SELECT p.owner_id = ANY (rls_roles_public.get_current_group_ids()) FROM collections_public.database AS p WHERE p.id = database_id) );

CREATE POLICY authenticated_can_update_on_schema_grant ON collections_public.schema_grant FOR UPDATE TO authenticated USING ( (SELECT p.owner_id = ANY (rls_roles_public.get_current_group_ids()) FROM collections_public.database AS p WHERE p.id = database_id) );

CREATE POLICY authenticated_can_delete_on_schema_grant ON collections_public.schema_grant FOR DELETE TO authenticated USING ( (SELECT p.owner_id = ANY (rls_roles_public.get_current_group_ids()) FROM collections_public.database AS p WHERE p.id = database_id) );

GRANT SELECT ON TABLE collections_public.schema_grant TO authenticated;

GRANT INSERT ON TABLE collections_public.schema_grant TO authenticated;

GRANT UPDATE ON TABLE collections_public.schema_grant TO authenticated;

GRANT DELETE ON TABLE collections_public.schema_grant TO authenticated;

ALTER TABLE collections_public.table_grant ENABLE ROW LEVEL SECURITY;

CREATE POLICY authenticated_can_select_on_table_grant ON collections_public.table_grant FOR SELECT TO authenticated USING ( (SELECT p.owner_id = ANY (rls_roles_public.get_current_group_ids()) FROM collections_public.database AS p WHERE p.id = database_id) );

CREATE POLICY authenticated_can_insert_on_table_grant ON collections_public.table_grant FOR INSERT TO authenticated WITH CHECK ( (SELECT p.owner_id = ANY (rls_roles_public.get_current_group_ids()) FROM collections_public.database AS p WHERE p.id = database_id) );

CREATE POLICY authenticated_can_update_on_table_grant ON collections_public.table_grant FOR UPDATE TO authenticated USING ( (SELECT p.owner_id = ANY (rls_roles_public.get_current_group_ids()) FROM collections_public.database AS p WHERE p.id = database_id) );

CREATE POLICY authenticated_can_delete_on_table_grant ON collections_public.table_grant FOR DELETE TO authenticated USING ( (SELECT p.owner_id = ANY (rls_roles_public.get_current_group_ids()) FROM collections_public.database AS p WHERE p.id = database_id) );

GRANT SELECT ON TABLE collections_public.table_grant TO authenticated;

GRANT INSERT ON TABLE collections_public.table_grant TO authenticated;

GRANT UPDATE ON TABLE collections_public.table_grant TO authenticated;

GRANT DELETE ON TABLE collections_public.table_grant TO authenticated;

ALTER TABLE collections_public.trigger ENABLE ROW LEVEL SECURITY;

CREATE POLICY authenticated_can_select_on_trigger ON collections_public.trigger FOR SELECT TO authenticated USING ( (SELECT p.owner_id = ANY (rls_roles_public.get_current_group_ids()) FROM collections_public.database AS p WHERE p.id = database_id) );

CREATE POLICY authenticated_can_insert_on_trigger ON collections_public.trigger FOR INSERT TO authenticated WITH CHECK ( (SELECT p.owner_id = ANY (rls_roles_public.get_current_group_ids()) FROM collections_public.database AS p WHERE p.id = database_id) );

CREATE POLICY authenticated_can_update_on_trigger ON collections_public.trigger FOR UPDATE TO authenticated USING ( (SELECT p.owner_id = ANY (rls_roles_public.get_current_group_ids()) FROM collections_public.database AS p WHERE p.id = database_id) );

CREATE POLICY authenticated_can_delete_on_trigger ON collections_public.trigger FOR DELETE TO authenticated USING ( (SELECT p.owner_id = ANY (rls_roles_public.get_current_group_ids()) FROM collections_public.database AS p WHERE p.id = database_id) );

GRANT SELECT ON TABLE collections_public.trigger TO authenticated;

GRANT INSERT ON TABLE collections_public.trigger TO authenticated;

GRANT UPDATE ON TABLE collections_public.trigger TO authenticated;

GRANT DELETE ON TABLE collections_public.trigger TO authenticated;

ALTER TABLE collections_public.trigger_function ENABLE ROW LEVEL SECURITY;

CREATE POLICY authenticated_can_select_on_trigger_function ON collections_public.trigger_function FOR SELECT TO authenticated USING ( (SELECT p.owner_id = ANY (rls_roles_public.get_current_group_ids()) FROM collections_public.database AS p WHERE p.id = database_id) );

CREATE POLICY authenticated_can_insert_on_trigger_function ON collections_public.trigger_function FOR INSERT TO authenticated WITH CHECK ( (SELECT p.owner_id = ANY (rls_roles_public.get_current_group_ids()) FROM collections_public.database AS p WHERE p.id = database_id) );

CREATE POLICY authenticated_can_update_on_trigger_function ON collections_public.trigger_function FOR UPDATE TO authenticated USING ( (SELECT p.owner_id = ANY (rls_roles_public.get_current_group_ids()) FROM collections_public.database AS p WHERE p.id = database_id) );

CREATE POLICY authenticated_can_delete_on_trigger_function ON collections_public.trigger_function FOR DELETE TO authenticated USING ( (SELECT p.owner_id = ANY (rls_roles_public.get_current_group_ids()) FROM collections_public.database AS p WHERE p.id = database_id) );

GRANT SELECT ON TABLE collections_public.trigger_function TO authenticated;

GRANT INSERT ON TABLE collections_public.trigger_function TO authenticated;

GRANT UPDATE ON TABLE collections_public.trigger_function TO authenticated;

GRANT DELETE ON TABLE collections_public.trigger_function TO authenticated;

ALTER TABLE collections_public.unique_constraint ENABLE ROW LEVEL SECURITY;

CREATE POLICY authenticated_can_select_on_unique_constraint ON collections_public.unique_constraint FOR SELECT TO authenticated USING ( (SELECT p.owner_id = ANY (rls_roles_public.get_current_group_ids()) FROM collections_public.database AS p WHERE p.id = database_id) );

CREATE POLICY authenticated_can_insert_on_unique_constraint ON collections_public.unique_constraint FOR INSERT TO authenticated WITH CHECK ( (SELECT p.owner_id = ANY (rls_roles_public.get_current_group_ids()) FROM collections_public.database AS p WHERE p.id = database_id) );

CREATE POLICY authenticated_can_update_on_unique_constraint ON collections_public.unique_constraint FOR UPDATE TO authenticated USING ( (SELECT p.owner_id = ANY (rls_roles_public.get_current_group_ids()) FROM collections_public.database AS p WHERE p.id = database_id) );

CREATE POLICY authenticated_can_delete_on_unique_constraint ON collections_public.unique_constraint FOR DELETE TO authenticated USING ( (SELECT p.owner_id = ANY (rls_roles_public.get_current_group_ids()) FROM collections_public.database AS p WHERE p.id = database_id) );

GRANT SELECT ON TABLE collections_public.unique_constraint TO authenticated;

GRANT INSERT ON TABLE collections_public.unique_constraint TO authenticated;

GRANT UPDATE ON TABLE collections_public.unique_constraint TO authenticated;

GRANT DELETE ON TABLE collections_public.unique_constraint TO authenticated;

ALTER TABLE collections_public.field ENABLE ROW LEVEL SECURITY;

CREATE POLICY authenticated_can_select_on_field ON collections_public.field FOR SELECT TO authenticated USING ( (SELECT p.owner_id = ANY (rls_roles_public.get_current_group_ids()) FROM collections_public.database AS p WHERE p.id = database_id) );

CREATE POLICY authenticated_can_insert_on_field ON collections_public.field FOR INSERT TO authenticated WITH CHECK ( (SELECT p.owner_id = ANY (rls_roles_public.get_current_group_ids()) FROM collections_public.database AS p WHERE p.id = database_id) );

CREATE POLICY authenticated_can_update_on_field ON collections_public.field FOR UPDATE TO authenticated USING ( (SELECT p.owner_id = ANY (rls_roles_public.get_current_group_ids()) FROM collections_public.database AS p WHERE p.id = database_id) );

CREATE POLICY authenticated_can_delete_on_field ON collections_public.field FOR DELETE TO authenticated USING ( (SELECT p.owner_id = ANY (rls_roles_public.get_current_group_ids()) FROM collections_public.database AS p WHERE p.id = database_id) );

GRANT SELECT ON TABLE collections_public.field TO authenticated;

GRANT INSERT ON TABLE collections_public.field TO authenticated;

GRANT UPDATE ON TABLE collections_public.field TO authenticated;

GRANT DELETE ON TABLE collections_public.field TO authenticated;