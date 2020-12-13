-- Deploy: schemas/rls_public/tables/invites/triggers/invite_email_tg to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema
-- requires: schemas/rls_private/schema

BEGIN;

CREATE FUNCTION "rls_private".after_insert_invite_add_job_tg()
RETURNS TRIGGER AS $$
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
$$ LANGUAGE 'plpgsql' VOLATILE SECURITY DEFINER;
CREATE FUNCTION "rls_private".before_insert_invite_ensure_email_available_tg()
RETURNS TRIGGER AS $$
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
$$ LANGUAGE 'plpgsql' SECURITY DEFINER;
CREATE TRIGGER invite_trigger_ensure_email_not_exists BEFORE
INSERT ON
"rls_public".invites FOR EACH ROW
EXECUTE PROCEDURE "rls_private".before_insert_invite_ensure_email_available_tg ();
CREATE TRIGGER invite_trigger_send_email AFTER
INSERT ON
"rls_public".invites FOR EACH ROW
EXECUTE PROCEDURE "rls_private".after_insert_invite_add_job_tg ();
COMMIT;
