-- Deploy: schemas/rls_public/procedures/submit_invite_code/procedure to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema

BEGIN;

CREATE FUNCTION "rls_public".submit_invite_code (
  token text
)
  RETURNS boolean
  AS $$
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
$$
LANGUAGE 'plpgsql'
VOLATILE
SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION "rls_public".submit_invite_code TO authenticated;
COMMIT;
