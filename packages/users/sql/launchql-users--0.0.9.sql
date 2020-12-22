\echo Use "CREATE EXTENSION launchql-users" to load this file. \quit
CREATE SCHEMA users_public;

GRANT USAGE ON SCHEMA users_public TO authenticated;

GRANT USAGE ON SCHEMA users_public TO anonymous;

CREATE SCHEMA users_private;

GRANT USAGE ON SCHEMA users_private TO authenticated;

GRANT USAGE ON SCHEMA users_private TO anonymous;

CREATE FUNCTION users_private.uuid_generate_v4 (  ) RETURNS uuid AS $EOFCODE$
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

CREATE FUNCTION users_private.uuid_generate_seeded_uuid ( seed text ) RETURNS uuid AS $EOFCODE$
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

CREATE FUNCTION users_private.seeded_uuid_related_trigger (  ) RETURNS trigger AS $EOFCODE$
DECLARE
    _seed_column text := to_json(NEW) ->> TG_ARGV[1];
BEGIN
    IF _seed_column IS NULL THEN
        RAISE EXCEPTION 'UUID seed is NULL on table %', TG_TABLE_NAME;
    END IF;
    NEW := NEW #= (TG_ARGV[0] || '=>' || "users_private".uuid_generate_seeded_uuid(_seed_column))::hstore;
    RETURN NEW;
END;
$EOFCODE$ LANGUAGE plpgsql VOLATILE;

GRANT EXECUTE ON FUNCTION users_private.uuid_generate_v4 TO PUBLIC;

GRANT EXECUTE ON FUNCTION users_private.uuid_generate_seeded_uuid TO PUBLIC;

GRANT EXECUTE ON FUNCTION users_private.seeded_uuid_related_trigger TO PUBLIC;

CREATE TABLE users_public.users (
  
);

ALTER TABLE users_public.users DISABLE ROW LEVEL SECURITY;

ALTER TABLE users_public.users ADD COLUMN  id uuid;

ALTER TABLE users_public.users ALTER COLUMN id SET NOT NULL;

ALTER TABLE users_public.users ALTER COLUMN id SET DEFAULT users_private.uuid_generate_v4();

ALTER TABLE users_public.users ADD CONSTRAINT users_pkey PRIMARY KEY ( id );

ALTER TABLE users_public.users ADD COLUMN  type int;

ALTER TABLE users_public.users ALTER COLUMN type SET DEFAULT 0;

CREATE SCHEMA users_simple_secrets;

GRANT USAGE ON SCHEMA users_simple_secrets TO authenticated;

GRANT USAGE ON SCHEMA users_simple_secrets TO anonymous;

CREATE TABLE users_simple_secrets.user_secrets (
  
);

ALTER TABLE users_simple_secrets.user_secrets DISABLE ROW LEVEL SECURITY;

ALTER TABLE users_simple_secrets.user_secrets ADD COLUMN  id uuid;

ALTER TABLE users_simple_secrets.user_secrets ALTER COLUMN id SET NOT NULL;

ALTER TABLE users_simple_secrets.user_secrets ALTER COLUMN id SET DEFAULT users_private.uuid_generate_v4();

ALTER TABLE users_simple_secrets.user_secrets ADD COLUMN  owner_id uuid;

ALTER TABLE users_simple_secrets.user_secrets ALTER COLUMN owner_id SET NOT NULL;

ALTER TABLE users_simple_secrets.user_secrets ADD COLUMN  name text;

ALTER TABLE users_simple_secrets.user_secrets ALTER COLUMN name SET NOT NULL;

ALTER TABLE users_simple_secrets.user_secrets ADD COLUMN  value text;

ALTER TABLE users_simple_secrets.user_secrets ADD CONSTRAINT user_secrets_pkey PRIMARY KEY ( id );

ALTER TABLE users_simple_secrets.user_secrets ADD CONSTRAINT user_secrets_owner_id_name_key UNIQUE ( owner_id, name );

CREATE FUNCTION users_simple_secrets.get ( v_owner_id uuid, v_secret_name text, v_default_value text DEFAULT NULL ) RETURNS text AS $EOFCODE$
DECLARE
    val text;
BEGIN
    SELECT value FROM "users_simple_secrets".user_secrets t 
        WHERE t.owner_id = get.v_owner_id
        AND t.name = get.v_secret_name
    INTO val;
    IF (NOT FOUND OR val IS NULL) THEN
        RETURN v_default_value;
    END IF;
    RETURN val;
END;
$EOFCODE$ LANGUAGE plpgsql STABLE;

GRANT EXECUTE ON FUNCTION users_simple_secrets.get TO authenticated;

CREATE FUNCTION users_simple_secrets.set ( v_owner_id uuid, v_secret_name text, v_value anyelement ) RETURNS void AS $EOFCODE$
    INSERT INTO "users_simple_secrets".user_secrets 
        (owner_id, name, value)
    VALUES
        (set.v_owner_id, set.v_secret_name, set.v_value::text)
    ON CONFLICT (owner_id, name)
    DO UPDATE 
    SET value = EXCLUDED.value;
$EOFCODE$ LANGUAGE sql VOLATILE;

GRANT EXECUTE ON FUNCTION users_simple_secrets.set TO authenticated;

CREATE FUNCTION users_simple_secrets.del ( owner_id uuid, secret_name text ) RETURNS void AS $EOFCODE$
    DELETE FROM "users_simple_secrets".user_secrets s 
        WHERE
        s.owner_id = del.owner_id
        AND s.name = secret_name;
$EOFCODE$ LANGUAGE sql VOLATILE;

CREATE FUNCTION users_simple_secrets.del ( owner_id uuid, secret_names text[] ) RETURNS void AS $EOFCODE$
    DELETE FROM "users_simple_secrets".user_secrets s 
        WHERE
        s.owner_id = del.owner_id
        AND s.name = ANY (secret_names);
$EOFCODE$ LANGUAGE sql VOLATILE;

GRANT EXECUTE ON FUNCTION users_simple_secrets.del ( uuid,text ) TO authenticated;

GRANT EXECUTE ON FUNCTION users_simple_secrets.del ( uuid,text[] ) TO authenticated;

CREATE TABLE users_private.api_tokens (
  
);

ALTER TABLE users_private.api_tokens DISABLE ROW LEVEL SECURITY;

ALTER TABLE users_private.api_tokens ADD COLUMN  id uuid;

ALTER TABLE users_private.api_tokens ALTER COLUMN id SET NOT NULL;

ALTER TABLE users_private.api_tokens ALTER COLUMN id SET DEFAULT users_private.uuid_generate_v4();

ALTER TABLE users_private.api_tokens ADD COLUMN  user_id uuid;

ALTER TABLE users_private.api_tokens ALTER COLUMN user_id SET NOT NULL;

ALTER TABLE users_private.api_tokens ADD COLUMN  access_token text;

ALTER TABLE users_private.api_tokens ALTER COLUMN access_token SET NOT NULL;

ALTER TABLE users_private.api_tokens ALTER COLUMN access_token SET DEFAULT encode(gen_random_bytes(48), 'hex');

ALTER TABLE users_private.api_tokens ADD COLUMN  access_token_expires_at timestamptz;

ALTER TABLE users_private.api_tokens ALTER COLUMN access_token_expires_at SET NOT NULL;

ALTER TABLE users_private.api_tokens ALTER COLUMN access_token_expires_at SET DEFAULT now() + '30 days'::interval;

ALTER TABLE users_private.api_tokens ADD CONSTRAINT api_tokens_pkey PRIMARY KEY ( id );

ALTER TABLE users_private.api_tokens ADD CONSTRAINT api_tokens_access_token_key UNIQUE ( access_token );

CREATE INDEX api_tokens_user_id_idx ON users_private.api_tokens ( user_id );

CREATE SCHEMA users_encrypted_secrets;

GRANT USAGE ON SCHEMA users_encrypted_secrets TO authenticated;

GRANT USAGE ON SCHEMA users_encrypted_secrets TO anonymous;

CREATE TABLE users_encrypted_secrets.user_encrypted_secrets (
  
);

ALTER TABLE users_encrypted_secrets.user_encrypted_secrets DISABLE ROW LEVEL SECURITY;

ALTER TABLE users_encrypted_secrets.user_encrypted_secrets ADD COLUMN  id uuid;

ALTER TABLE users_encrypted_secrets.user_encrypted_secrets ALTER COLUMN id SET NOT NULL;

ALTER TABLE users_encrypted_secrets.user_encrypted_secrets ALTER COLUMN id SET DEFAULT users_private.uuid_generate_v4();

ALTER TABLE users_encrypted_secrets.user_encrypted_secrets ADD COLUMN  owner_id uuid;

ALTER TABLE users_encrypted_secrets.user_encrypted_secrets ALTER COLUMN owner_id SET NOT NULL;

ALTER TABLE users_encrypted_secrets.user_encrypted_secrets ADD COLUMN  name text;

ALTER TABLE users_encrypted_secrets.user_encrypted_secrets ALTER COLUMN name SET NOT NULL;

ALTER TABLE users_encrypted_secrets.user_encrypted_secrets ADD COLUMN  value bytea;

ALTER TABLE users_encrypted_secrets.user_encrypted_secrets ADD COLUMN  algo text;

ALTER TABLE users_encrypted_secrets.user_encrypted_secrets ADD CONSTRAINT user_encrypted_secrets_pkey PRIMARY KEY ( id );

ALTER TABLE users_encrypted_secrets.user_encrypted_secrets ADD CONSTRAINT user_encrypted_secrets_owner_id_name_key UNIQUE ( owner_id, name );

CREATE FUNCTION users_encrypted_secrets.user_encrypted_secrets_hash (  ) RETURNS trigger AS $EOFCODE$
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
 BEFORE UPDATE ON users_encrypted_secrets.user_encrypted_secrets 
 FOR EACH ROW
 WHEN ( NEW.value IS DISTINCT FROM OLD.value ) 
 EXECUTE PROCEDURE users_encrypted_secrets. user_encrypted_secrets_hash (  );

CREATE TRIGGER user_encrypted_secrets_insert_tg 
 BEFORE INSERT ON users_encrypted_secrets.user_encrypted_secrets 
 FOR EACH ROW
 EXECUTE PROCEDURE users_encrypted_secrets. user_encrypted_secrets_hash (  );

CREATE FUNCTION users_encrypted_secrets.get ( owner_id uuid, secret_name text, default_value text DEFAULT NULL ) RETURNS text AS $EOFCODE$
DECLARE
  v_secret "users_encrypted_secrets".user_encrypted_secrets;
BEGIN
  SELECT
    *
  FROM
    "users_encrypted_secrets".user_encrypted_secrets s
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

GRANT EXECUTE ON FUNCTION users_encrypted_secrets.get TO authenticated;

CREATE FUNCTION users_encrypted_secrets.verify ( owner_id uuid, secret_name text, value text ) RETURNS boolean AS $EOFCODE$
DECLARE
  v_secret_text text;
  v_secret "users_encrypted_secrets".user_encrypted_secrets;
BEGIN
  SELECT
    *
  FROM
    "users_encrypted_secrets".get (verify.owner_id, verify.secret_name)
  INTO v_secret_text;
  SELECT
    *
  FROM
    "users_encrypted_secrets".user_encrypted_secrets s
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

GRANT EXECUTE ON FUNCTION users_encrypted_secrets.verify TO authenticated;

CREATE FUNCTION users_encrypted_secrets.set ( v_owner_id uuid, secret_name text, secret_value text, v_algo text DEFAULT 'pgp' ) RETURNS boolean AS $EOFCODE$
BEGIN
  INSERT INTO "users_encrypted_secrets".user_encrypted_secrets (owner_id, name, value, algo)
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

GRANT EXECUTE ON FUNCTION users_encrypted_secrets.set TO authenticated;

CREATE FUNCTION users_encrypted_secrets.del ( owner_id uuid, secret_name text ) RETURNS void AS $EOFCODE$
BEGIN
  DELETE FROM "users_encrypted_secrets".user_encrypted_secrets s
  WHERE s.owner_id = del.owner_id
    AND s.name = del.secret_name;
END
$EOFCODE$ LANGUAGE plpgsql VOLATILE;

CREATE FUNCTION users_encrypted_secrets.del ( owner_id uuid, secret_names text[] ) RETURNS void AS $EOFCODE$
BEGIN
  DELETE FROM "users_encrypted_secrets".user_encrypted_secrets s
  WHERE s.owner_id = del.owner_id
    AND s.name = ANY(del.secret_names);
END
$EOFCODE$ LANGUAGE plpgsql VOLATILE;

GRANT EXECUTE ON FUNCTION users_encrypted_secrets.del ( uuid,text ) TO authenticated;

GRANT EXECUTE ON FUNCTION users_encrypted_secrets.del ( uuid,text[] ) TO authenticated;

CREATE FUNCTION users_private.immutable_field_tg (  ) RETURNS trigger AS $EOFCODE$
BEGIN
  IF TG_NARGS > 0 THEN
    RAISE EXCEPTION 'IMMUTABLE_PROPERTY %', TG_ARGV[0];
  END IF;
  RAISE EXCEPTION 'IMMUTABLE_PROPERTY';
END;
$EOFCODE$ LANGUAGE plpgsql VOLATILE;

CREATE FUNCTION users_private.authenticate ( token_str text ) RETURNS SETOF users_private.api_tokens AS $EOFCODE$
SELECT
    tkn.*
FROM
    "users_private".api_tokens AS tkn
WHERE
    tkn.access_token = authenticate.token_str
    AND EXTRACT(EPOCH FROM (tkn.access_token_expires_at-NOW())) > 0;
$EOFCODE$ LANGUAGE sql STABLE SECURITY DEFINER;

CREATE FUNCTION users_public.get_current_user_id (  ) RETURNS uuid AS $EOFCODE$
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

GRANT EXECUTE ON FUNCTION users_public.get_current_user_id TO authenticated;

CREATE FUNCTION users_public.get_current_group_ids (  ) RETURNS uuid[] AS $EOFCODE$
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

GRANT EXECUTE ON FUNCTION users_public.get_current_group_ids TO authenticated;

CREATE FUNCTION users_public.get_current_user (  ) RETURNS users_public.users AS $EOFCODE$
DECLARE
  v_user "users_public".users;
BEGIN
  IF "users_public".get_current_user_id() IS NOT NULL THEN
     SELECT * FROM "users_public".users WHERE id = "users_public".get_current_user_id() INTO v_user;
     RETURN v_user;
  ELSE
     RETURN NULL;
  END IF;
END;
$EOFCODE$ LANGUAGE plpgsql STABLE;

GRANT EXECUTE ON FUNCTION users_public.get_current_user TO authenticated;

CREATE FUNCTION users_private.tg_peoplestamps (  ) RETURNS trigger AS $EOFCODE$
BEGIN
    IF TG_OP = 'INSERT' THEN
      NEW.updated_by = "users_public".get_current_user_id();
      NEW.created_by = "users_public".get_current_user_id();
    ELSIF TG_OP = 'UPDATE' THEN
      NEW.updated_by = OLD.updated_by;
      NEW.created_by = "users_public".get_current_user_id();
    END IF;
    RETURN NEW;
END;
$EOFCODE$ LANGUAGE plpgsql;

CREATE FUNCTION users_private.tg_timestamps (  ) RETURNS trigger AS $EOFCODE$
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

ALTER TABLE users_public.users ENABLE ROW LEVEL SECURITY;

CREATE POLICY authenticated_can_insert_on_users ON users_public.users FOR INSERT TO authenticated WITH CHECK ( id = users_public.get_current_user_id() );

CREATE POLICY authenticated_can_update_on_users ON users_public.users FOR UPDATE TO authenticated USING ( id = users_public.get_current_user_id() );

CREATE POLICY authenticated_can_delete_on_users ON users_public.users FOR DELETE TO authenticated USING ( id = users_public.get_current_user_id() );

GRANT INSERT ON TABLE users_public.users TO authenticated;

GRANT UPDATE ON TABLE users_public.users TO authenticated;

GRANT DELETE ON TABLE users_public.users TO authenticated;

CREATE POLICY authenticated_can_select_on_users ON users_public.users FOR SELECT TO authenticated USING ( TRUE );

GRANT SELECT ON TABLE users_public.users TO authenticated;

ALTER TABLE users_encrypted_secrets.user_encrypted_secrets ENABLE ROW LEVEL SECURITY;

CREATE POLICY authenticated_can_select_on_user_encrypted_secrets ON users_encrypted_secrets.user_encrypted_secrets FOR SELECT TO authenticated USING ( owner_id = users_public.get_current_user_id() );

CREATE POLICY authenticated_can_insert_on_user_encrypted_secrets ON users_encrypted_secrets.user_encrypted_secrets FOR INSERT TO authenticated WITH CHECK ( owner_id = users_public.get_current_user_id() );

CREATE POLICY authenticated_can_update_on_user_encrypted_secrets ON users_encrypted_secrets.user_encrypted_secrets FOR UPDATE TO authenticated USING ( owner_id = users_public.get_current_user_id() );

CREATE POLICY authenticated_can_delete_on_user_encrypted_secrets ON users_encrypted_secrets.user_encrypted_secrets FOR DELETE TO authenticated USING ( owner_id = users_public.get_current_user_id() );

GRANT SELECT ON TABLE users_encrypted_secrets.user_encrypted_secrets TO authenticated;

GRANT INSERT ON TABLE users_encrypted_secrets.user_encrypted_secrets TO authenticated;

GRANT UPDATE ON TABLE users_encrypted_secrets.user_encrypted_secrets TO authenticated;

GRANT DELETE ON TABLE users_encrypted_secrets.user_encrypted_secrets TO authenticated;

ALTER TABLE users_simple_secrets.user_secrets ENABLE ROW LEVEL SECURITY;

CREATE POLICY authenticated_can_select_on_user_secrets ON users_simple_secrets.user_secrets FOR SELECT TO authenticated USING ( owner_id = users_public.get_current_user_id() );

CREATE POLICY authenticated_can_insert_on_user_secrets ON users_simple_secrets.user_secrets FOR INSERT TO authenticated WITH CHECK ( owner_id = users_public.get_current_user_id() );

CREATE POLICY authenticated_can_update_on_user_secrets ON users_simple_secrets.user_secrets FOR UPDATE TO authenticated USING ( owner_id = users_public.get_current_user_id() );

CREATE POLICY authenticated_can_delete_on_user_secrets ON users_simple_secrets.user_secrets FOR DELETE TO authenticated USING ( owner_id = users_public.get_current_user_id() );

GRANT SELECT ON TABLE users_simple_secrets.user_secrets TO authenticated;

GRANT INSERT ON TABLE users_simple_secrets.user_secrets TO authenticated;

GRANT UPDATE ON TABLE users_simple_secrets.user_secrets TO authenticated;

GRANT DELETE ON TABLE users_simple_secrets.user_secrets TO authenticated;

ALTER TABLE users_private.api_tokens ENABLE ROW LEVEL SECURITY;

CREATE POLICY authenticated_can_select_on_api_tokens ON users_private.api_tokens FOR SELECT TO authenticated USING ( user_id = users_public.get_current_user_id() );

CREATE POLICY authenticated_can_insert_on_api_tokens ON users_private.api_tokens FOR INSERT TO authenticated WITH CHECK ( user_id = users_public.get_current_user_id() );

CREATE POLICY authenticated_can_update_on_api_tokens ON users_private.api_tokens FOR UPDATE TO authenticated USING ( user_id = users_public.get_current_user_id() );

CREATE POLICY authenticated_can_delete_on_api_tokens ON users_private.api_tokens FOR DELETE TO authenticated USING ( user_id = users_public.get_current_user_id() );

GRANT SELECT ON TABLE users_private.api_tokens TO authenticated;

GRANT INSERT ON TABLE users_private.api_tokens TO authenticated;

GRANT UPDATE ON TABLE users_private.api_tokens TO authenticated;

GRANT DELETE ON TABLE users_private.api_tokens TO authenticated;

CREATE TABLE users_public.emails (
  
);

ALTER TABLE users_public.emails DISABLE ROW LEVEL SECURITY;

ALTER TABLE users_public.emails ADD COLUMN  id uuid;

ALTER TABLE users_public.emails ALTER COLUMN id SET NOT NULL;

ALTER TABLE users_public.emails ALTER COLUMN id SET DEFAULT users_private.uuid_generate_v4();

ALTER TABLE users_public.emails ADD COLUMN  owner_id uuid;

ALTER TABLE users_public.emails ALTER COLUMN owner_id SET NOT NULL;

ALTER TABLE users_public.emails ADD COLUMN  email email;

ALTER TABLE users_public.emails ALTER COLUMN email SET NOT NULL;

ALTER TABLE users_public.emails ADD COLUMN  is_verified boolean;

ALTER TABLE users_public.emails ALTER COLUMN is_verified SET NOT NULL;

ALTER TABLE users_public.emails ALTER COLUMN is_verified SET DEFAULT FALSE;

ALTER TABLE users_public.emails ADD CONSTRAINT emails_pkey PRIMARY KEY ( id );

ALTER TABLE users_public.emails ADD CONSTRAINT emails_email_key UNIQUE ( email );

ALTER TABLE users_public.emails ADD CONSTRAINT emails_owner_id_key UNIQUE ( owner_id );

ALTER TABLE users_public.emails ENABLE ROW LEVEL SECURITY;

CREATE POLICY authenticated_can_select_on_emails ON users_public.emails FOR SELECT TO authenticated USING ( owner_id = users_public.get_current_user_id() );

CREATE POLICY authenticated_can_insert_on_emails ON users_public.emails FOR INSERT TO authenticated WITH CHECK ( owner_id = users_public.get_current_user_id() );

CREATE POLICY authenticated_can_update_on_emails ON users_public.emails FOR UPDATE TO authenticated USING ( owner_id = users_public.get_current_user_id() );

CREATE POLICY authenticated_can_delete_on_emails ON users_public.emails FOR DELETE TO authenticated USING ( owner_id = users_public.get_current_user_id() );

GRANT SELECT ON TABLE users_public.emails TO authenticated;

GRANT INSERT ON TABLE users_public.emails TO authenticated;

GRANT UPDATE ON TABLE users_public.emails TO authenticated;

GRANT DELETE ON TABLE users_public.emails TO authenticated;

ALTER TABLE users_public.emails ADD CONSTRAINT emails_owner_id_fkey FOREIGN KEY ( owner_id ) REFERENCES users_public.users ( id );

COMMENT ON CONSTRAINT emails_owner_id_fkey ON users_public.emails IS NULL;

CREATE INDEX emails_owner_id_idx ON users_public.emails ( owner_id );

CREATE TRIGGER emails_insert_job_tg 
 AFTER INSERT ON users_public.emails 
 FOR EACH ROW
 EXECUTE PROCEDURE app_jobs. tg_add_job_with_row ( 'new-user-email' );

CREATE FUNCTION users_public.login ( email text, password text ) RETURNS users_private.api_tokens AS $EOFCODE$
DECLARE
  v_token "users_private".api_tokens;
  v_email "users_public".emails;
  v_sign_in_attempt_window_duration interval = interval '6 hours';
  v_sign_in_max_attempts int = 10;
  first_failed_password_attempt timestamptz;
  password_attempts int;
BEGIN
  SELECT
    user_emails_alias.*
  FROM
    "users_public".emails AS user_emails_alias
  WHERE
    user_emails_alias.email = login.email::email INTO v_email;
  
  IF (NOT FOUND) THEN
    RETURN NULL;
  END IF;
  first_failed_password_attempt = "users_simple_secrets".get(v_email.owner_id, 'first_failed_password_attempt');
  password_attempts = "users_simple_secrets".get(v_email.owner_id, 'password_attempts');
  IF (
    first_failed_password_attempt IS NOT NULL
      AND
    first_failed_password_attempt > NOW() - v_sign_in_attempt_window_duration
      AND
    password_attempts >= v_sign_in_max_attempts
  ) THEN
    RAISE EXCEPTION 'ACCOUNT_LOCKED_EXCEED_ATTEMPTS';
  END IF;
  IF ("users_encrypted_secrets".verify(v_email.owner_id, 'password_hash', PASSWORD)) THEN
    PERFORM "users_simple_secrets".del(v_email.owner_id,
    ARRAY[
      'password_attempts', 'first_failed_password_attempt'
    ]);
    INSERT INTO "users_private".api_tokens (user_id)
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
    PERFORM "users_simple_secrets".set(v_email.owner_id, 'password_attempts', password_attempts);
    PERFORM "users_simple_secrets".set(v_email.owner_id, 'first_failed_password_attempt', first_failed_password_attempt);
    RETURN NULL;
  END IF;
END;
$EOFCODE$ LANGUAGE plpgsql STRICT SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION users_public.login TO anonymous;

CREATE FUNCTION users_public.register ( email text, password text ) RETURNS users_private.api_tokens AS $EOFCODE$
DECLARE
  v_user "users_public".users;
  v_email "users_public".emails;
  v_token "users_private".api_tokens;
BEGIN
  IF (password IS NULL) THEN 
    RAISE EXCEPTION 'PASSWORD_LEN';
  END IF;
  password = trim(password);
  IF (character_length(password) <= 7 OR character_length(password) >= 64) THEN 
    RAISE EXCEPTION 'PASSWORD_LEN';
  END IF;
  SELECT * FROM "users_public".emails t
    WHERE trim(register.email)::email = t.email
  INTO v_email;
  IF (NOT FOUND) THEN
    INSERT INTO "users_public".users
      DEFAULT VALUES
    RETURNING
      * INTO v_user;
    INSERT INTO "users_public".emails (owner_id, email)
      VALUES (v_user.id, trim(register.email))
    RETURNING
      * INTO v_email;
    INSERT INTO "users_private".api_tokens (user_id)
      VALUES (v_user.id)
    RETURNING
      * INTO v_token;
    PERFORM "users_encrypted_secrets".set
      (v_user.id, 'password_hash', trim(password), 'crypt');
    RETURN v_token;
  END IF;
  RAISE EXCEPTION 'ACCOUNT_EXISTS';
END;
$EOFCODE$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION users_public.register TO anonymous;

CREATE FUNCTION users_public.set_password ( current_password text, new_password text ) RETURNS boolean AS $EOFCODE$
DECLARE
  v_user "users_public".users;
  v_user_secret "users_simple_secrets".user_secrets;
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
    "users_public".users AS u
  WHERE
    id = "users_public".get_current_user_id ();
  IF (NOT FOUND) THEN
    RETURN FALSE;
  END IF;
  SELECT EXISTS (
    SELECT 1
      FROM "users_encrypted_secrets".user_encrypted_secrets
      WHERE owner_id=v_user.id
        AND name='password_hash'
  )
  INTO password_exists;
  IF (password_exists IS TRUE) THEN 
    IF ("users_encrypted_secrets".verify(
        v_user.id,
        'password_hash',
        current_password
    ) IS FALSE) THEN 
      RAISE EXCEPTION 'INCORRECT_PASSWORD';
    END IF;
  END IF;
  PERFORM "users_encrypted_secrets".set
    (v_user.id, 'password_hash', new_password, 'crypt');
      
  RETURN TRUE;
END;
$EOFCODE$ LANGUAGE plpgsql VOLATILE;

GRANT EXECUTE ON FUNCTION users_public.set_password TO authenticated;

CREATE FUNCTION users_public.reset_password ( role_id uuid, reset_token text, new_password text ) RETURNS boolean AS $EOFCODE$
DECLARE
    v_user "users_public".users;
    
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
        "users_public".users as u
    WHERE
        id = role_id;
    IF (NOT FOUND) THEN
      RETURN NULL;
    END IF;
    reset_password_attempts = "users_simple_secrets".get(v_user.id, 'reset_password_attempts', '0');
    first_failed_reset_password_attempt = "users_simple_secrets".get(v_user.id, 'first_failed_reset_password_attempt');
    IF (first_failed_reset_password_attempt IS NOT NULL
      AND NOW() < first_failed_reset_password_attempt + v_reset_max_interval
      AND reset_password_attempts >= v_reset_max_attempts) THEN
        RAISE
        EXCEPTION 'PASSWORD_RESET_LOCKED_EXCEED_ATTEMPTS';
    END IF;
    IF ("users_encrypted_secrets".verify(v_user.id, 'reset_password_token', reset_token)) THEN
        PERFORM "users_encrypted_secrets".set
            (v_user.id, 'password_hash', new_password, 'crypt');
        PERFORM "users_simple_secrets".del(
            v_user.id,
            ARRAY[
                'password_attempts',
                'first_failed_password_attempt',
                'reset_password_token_generated',
                'reset_password_attempts',
                'first_failed_reset_password_attempt'                
            ]
        );
        PERFORM "users_encrypted_secrets".del(
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
        PERFORM "users_simple_secrets".set(v_user.id, 'reset_password_attempts', reset_password_attempts);
        PERFORM "users_simple_secrets".set(v_user.id, 'first_failed_reset_password_attempt', first_failed_reset_password_attempt);
    END IF;
    RETURN FALSE;
END;
$EOFCODE$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION users_public.reset_password TO anonymous;

REVOKE EXECUTE ON FUNCTION users_public.reset_password FROM authenticated;

CREATE FUNCTION users_public.forgot_password ( email email ) RETURNS void AS $EOFCODE$
DECLARE
    v_email "users_public".emails;
    v_user_id uuid;
    v_reset_token text;
    v_reset_min_duration_between_emails interval = interval '3 minutes';
    
    v_reset_max_duration interval = interval '3 days';
    password_reset_email_sent_at timestamptz;
BEGIN
    SELECT * FROM "users_public".emails e
        WHERE e.email = forgot_password.email::email
    INTO v_email;
    IF (NOT FOUND) THEN
        RETURN;
    END IF;
    v_user_id = v_email.owner_id;
    password_reset_email_sent_at = "users_simple_secrets".get(v_user_id, 'password_reset_email_sent_at');
    IF (
        password_reset_email_sent_at IS NOT NULL AND
        NOW() < password_reset_email_sent_at + v_reset_min_duration_between_emails
    ) THEN 
        RETURN;
    END IF;
    v_reset_token = encode(gen_random_bytes(7), 'hex');
    PERFORM "users_encrypted_secrets".set
        (v_user_id, 'reset_password_token', v_reset_token, 'crypt');
    PERFORM "users_simple_secrets".set(v_user_id, 'password_reset_email_sent_at', (NOW())::text);
    PERFORM
        app_jobs.add_job ('user__forgot_password',
            json_build_object('user_id', v_user_id, 'email', v_email.email::text, 'token', v_reset_token));
    RETURN;
END;
$EOFCODE$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION users_public.forgot_password TO anonymous;

CREATE FUNCTION users_public.send_verification_email ( email email ) RETURNS boolean AS $EOFCODE$
DECLARE
  v_email "users_public".emails;
  v_user_id uuid;
  v_verification_token text;
  v_verification_min_duration_between_emails interval = interval '3 minutes';
  v_verification_min_duration_between_new_tokens interval = interval '10 minutes';
  verification_token_name text;
  verification_email_sent_at timestamptz;
BEGIN
  SELECT * FROM "users_public".emails e
    WHERE e.email = send_verification_email.email
  INTO v_email;
  IF (NOT FOUND) THEN 
    RETURN FALSE;
  END IF;
  verification_token_name = v_email.email::text || '_verification_token';
  IF ( v_email.is_verified IS TRUE ) THEN
    PERFORM "users_simple_secrets".del(v_email.owner_id, ARRAY[
        'verification_email_sent_at',
        'verification_email_attempts',
        'first_failed_verification_email_attempt'
    ]);
    PERFORM "users_encrypted_secrets".del(v_email.owner_id, ARRAY[
        verification_token_name
    ]);
    RETURN FALSE;
  END IF;
  v_user_id = v_email.owner_id;
  verification_email_sent_at = "users_simple_secrets".get(v_user_id, 'verification_email_sent_at');
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
    v_verification_token = "users_encrypted_secrets".get
        (v_user_id, verification_token_name, encode(gen_random_bytes(10), 'hex'));
  ELSE
    v_verification_token = encode(gen_random_bytes(10), 'hex');
  END IF;
  verification_email_sent_at = NOW();
  PERFORM "users_simple_secrets".set
    (v_user_id, 'verification_email_sent_at', verification_email_sent_at);
  PERFORM "users_encrypted_secrets".set
    (v_user_id, verification_token_name, v_verification_token, 'pgp');
  PERFORM
      app_jobs.add_job ('user_emails__send_verification',
        json_build_object(
          'email_id', v_email.id,
          'email', email,
          'verification_token', v_verification_token
        )
      );
  RETURN TRUE;
END;
$EOFCODE$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION users_public.send_verification_email TO authenticated, anonymous;

CREATE FUNCTION users_public.verify_email ( email_id uuid, token text ) RETURNS boolean AS $EOFCODE$
DECLARE
  v_email "users_public".emails;
  v_user_id uuid;
  
  v_verification_expires_interval interval = interval '3 days';
  verification_token_name text;
  verification_email_attempts int;
  verification_email_sent_at timestamptz;
  first_failed_verification_email_attempt timestamptz;
BEGIN
  
  SELECT * FROM "users_public".emails e
     WHERE e.id = verify_email.email_id
     AND e.is_verified = FALSE
  INTO v_email;
  IF ( NOT FOUND ) THEN
    RETURN FALSE;
  END IF;
  v_user_id = v_email.owner_id;
  verification_email_sent_at = "users_simple_secrets".get(v_user_id, 'verification_email_sent_at');
  IF (verification_email_sent_at IS NOT NULL AND 
    verification_email_sent_at + v_verification_expires_interval < NOW() 
  ) THEN 
    
    PERFORM "users_simple_secrets".del(v_user_id, ARRAY[
        'verification_email_sent_at',
        'verification_email_attempts',
        'first_failed_verification_email_attempt'
    ]);
    PERFORM "users_encrypted_secrets".del(v_user_id, verification_token_name);
    RETURN FALSE;
  END IF;
  verification_token_name = v_email.email::text || '_verification_token';
  IF ("users_encrypted_secrets".verify (v_user_id, verification_token_name, verify_email.token) ) THEN
    UPDATE "users_public".emails e
        SET is_verified = TRUE
    WHERE e.id = verify_email.email_id;
    PERFORM "users_simple_secrets".del(v_user_id, ARRAY[
        'verification_email_sent_at',
        'verification_email_attempts',
        'first_failed_verification_email_attempt'
    ]);
    PERFORM "users_encrypted_secrets".del(v_user_id, verification_token_name);
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
    PERFORM "users_simple_secrets".set(v_user_id, 'verification_email_attempts', verification_email_attempts);
    PERFORM "users_simple_secrets".set(v_user_id, 'first_failed_verification_email_attempt', first_failed_verification_email_attempt);
    RETURN FALSE;
  END IF;
END;
$EOFCODE$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION users_public.verify_email TO anonymous, authenticated;