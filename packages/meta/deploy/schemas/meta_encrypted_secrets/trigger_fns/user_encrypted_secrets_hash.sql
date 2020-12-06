-- Deploy: schemas/meta_encrypted_secrets/trigger_fns/user_encrypted_secrets_hash to pg
-- made with <3 @ launchql.com

-- requires: schemas/meta_encrypted_secrets/schema

BEGIN;

CREATE FUNCTION "meta_encrypted_secrets".user_encrypted_secrets_hash ()
RETURNS TRIGGER
AS $CODEZ$
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
$CODEZ$
LANGUAGE plpgsql VOLATILE;
COMMIT;
