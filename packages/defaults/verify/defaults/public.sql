-- Verify pgpm-defaults:defaults/public on pg

BEGIN;

DO $$
DECLARE
  public_grantee constant oid := 0;
BEGIN
  IF has_database_privilege('public', current_database(), 'CREATE') THEN
    RAISE EXCEPTION 'PUBLIC still holds CREATE on database %', current_database();
  END IF;

  IF has_schema_privilege('public', 'public', 'CREATE') THEN
    RAISE EXCEPTION 'PUBLIC still holds CREATE on schema public';
  END IF;

  -- The database-wide default: PUBLIC must not inherit EXECUTE on functions
  -- created from here on. Only the role-scoped, schema-less form does this;
  -- an IN SCHEMA variant would leave every other schema untouched.
  IF NOT EXISTS (
    SELECT 1
    FROM pg_default_acl
    WHERE defaclnamespace = 0
      AND defaclobjtype = 'f'
      AND current_user::regrole::oid = defaclrole
  ) THEN
    RAISE EXCEPTION 'no database-wide default privileges for functions owned by %', current_user;
  END IF;

  IF EXISTS (
    SELECT 1
    FROM pg_default_acl d, aclexplode(d.defaclacl) a
    WHERE d.defaclnamespace = 0
      AND d.defaclobjtype = 'f'
      AND a.grantee = public_grantee
      AND a.privilege_type = 'EXECUTE'
  ) THEN
    RAISE EXCEPTION 'PUBLIC still holds a database-wide EXECUTE default on functions';
  END IF;

  -- Schema public carries no schema-wide function default at all: a role that
  -- needs a function there is granted that function.
  IF EXISTS (
    SELECT 1
    FROM pg_default_acl d, aclexplode(d.defaclacl) a
    WHERE d.defaclnamespace = 'public'::regnamespace
      AND d.defaclobjtype = 'f'
      AND a.privilege_type = 'EXECUTE'
  ) THEN
    RAISE EXCEPTION 'schema public has a schema-wide EXECUTE default on functions';
  END IF;
END
$$;

ROLLBACK;
