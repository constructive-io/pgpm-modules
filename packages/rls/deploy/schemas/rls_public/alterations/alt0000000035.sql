-- Deploy: schemas/rls_public/alterations/alt0000000035 to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema
-- requires: schemas/rls_private/schema
-- requires: schemas/rls_public/tables/users/table

BEGIN;

CREATE SCHEMA IF NOT EXISTS "rls_private";
GRANT USAGE ON SCHEMA "rls_private" TO authenticated, anonymous;
ALTER DEFAULT PRIVILEGES IN SCHEMA "rls_private" 
 GRANT EXECUTE ON FUNCTIONS TO authenticated;
CREATE SCHEMA IF NOT EXISTS "rls_public";
GRANT USAGE ON SCHEMA "rls_public" TO authenticated, anonymous;
ALTER DEFAULT PRIVILEGES IN SCHEMA "rls_public" 
 GRANT EXECUTE ON FUNCTIONS TO authenticated;
CREATE TABLE "rls_public".user_achievement (
 	id uuid PRIMARY KEY DEFAULT ( uuid_generate_v4() ),
	name citext NOT NULL,
	UNIQUE ( name ) 
);
CREATE TABLE "rls_public".user_step (
 	id uuid PRIMARY KEY DEFAULT ( uuid_generate_v4() ),
	name citext NOT NULL,
	achievement_id uuid NOT NULL REFERENCES "rls_public".user_achievement ( id ) ON DELETE CASCADE,
	priority int DEFAULT ( 10000 ),
	UNIQUE ( name ) 
);
CREATE TABLE "rls_public".user_step_achievement (
 	id uuid PRIMARY KEY DEFAULT ( uuid_generate_v4() ),
	task_id uuid NOT NULL REFERENCES "rls_public".user_step ( id ) ON DELETE CASCADE,
	user_id uuid NOT NULL REFERENCES "rls_public".users ( id ) ON DELETE CASCADE 
);
CREATE FUNCTION "rls_private".user_completed_task ( task citext, role_id uuid DEFAULT "rls_roles_public".get_current_user_id() ) RETURNS void AS $EOFCODE$
  INSERT INTO "rls_public".user_step_achievement (user_id, task_id)
  VALUES (role_id, (
      SELECT
        t.id
      FROM
        "rls_public".user_step t
      WHERE
        name = task));
$EOFCODE$ LANGUAGE sql VOLATILE SECURITY DEFINER;
CREATE FUNCTION "rls_private".user_incompleted_task ( task citext, role_id uuid DEFAULT "rls_roles_public".get_current_user_id() ) RETURNS void AS $EOFCODE$
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
CREATE FUNCTION "rls_public".tasks_required_for ( achievement citext, role_id uuid DEFAULT "rls_roles_public".get_current_user_id() ) RETURNS SETOF "rls_public".user_step AS $EOFCODE$
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
CREATE FUNCTION "rls_public".user_achieved ( achievement citext, role_id uuid DEFAULT "rls_roles_public".get_current_user_id() ) RETURNS boolean AS $EOFCODE$
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
GRANT SELECT ON TABLE "rls_public".user_achievement TO authenticated;
CREATE INDEX user_id_idx ON "rls_public".user_step_achievement ( user_id );
ALTER TABLE "rls_public".user_step_achievement ENABLE ROW LEVEL SECURITY;
CREATE POLICY can_select_user_step_achievement ON "rls_public".user_step_achievement FOR SELECT TO PUBLIC USING ( "rls_roles_public".get_current_user_id() = user_id );
CREATE POLICY can_insert_user_step_achievement ON "rls_public".user_step_achievement FOR INSERT TO PUBLIC WITH CHECK ( FALSE );
CREATE POLICY can_update_user_step_achievement ON "rls_public".user_step_achievement FOR UPDATE TO PUBLIC USING ( FALSE );
CREATE POLICY can_delete_user_step_achievement ON "rls_public".user_step_achievement FOR DELETE TO PUBLIC USING ( FALSE );
GRANT INSERT ON TABLE "rls_public".user_step_achievement TO authenticated;
GRANT SELECT ON TABLE "rls_public".user_step_achievement TO authenticated;
GRANT UPDATE ON TABLE "rls_public".user_step_achievement TO authenticated;
GRANT DELETE ON TABLE "rls_public".user_step_achievement TO authenticated;
ALTER TABLE "rls_public".user_step_achievement ADD COLUMN  created_at timestamptz;
ALTER TABLE "rls_public".user_step_achievement ALTER COLUMN created_at SET DEFAULT now();
ALTER TABLE "rls_public".user_step_achievement ADD COLUMN  updated_at timestamptz;
ALTER TABLE "rls_public".user_step_achievement ALTER COLUMN updated_at SET DEFAULT now();
CREATE TRIGGER update_user_step_achievement_modtime 
 BEFORE INSERT OR UPDATE ON "rls_public".user_step_achievement 
 FOR EACH ROW
 EXECUTE PROCEDURE "rls_private".tg_timestamps ( );
GRANT SELECT ON TABLE "rls_public".user_step TO authenticated;
CREATE FUNCTION "rls_private".tg_achievement ()
  RETURNS TRIGGER
  AS $$
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
$$
LANGUAGE 'plpgsql'
VOLATILE;
CREATE FUNCTION "rls_private".tg_achievement_toggle ()
  RETURNS TRIGGER
  AS $$
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
$$
LANGUAGE 'plpgsql'
VOLATILE;
CREATE FUNCTION "rls_private".tg_achievement_boolean ()
  RETURNS TRIGGER
  AS $$
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
$$
LANGUAGE 'plpgsql'
VOLATILE;
CREATE FUNCTION "rls_private".tg_achievement_toggle_boolean ()
  RETURNS TRIGGER
  AS $$
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
$$
LANGUAGE 'plpgsql'
VOLATILE;
DO $LQLMIGRATION$
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
  END;
$LQLMIGRATION$;
COMMIT;
