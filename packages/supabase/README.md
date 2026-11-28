# @pgpm/supabase

Bridge Supabase PostgREST requests to Constructive's transaction-local RLS claims.

## Supabase setup

1. Run `pgpm admin-users bootstrap --yes` against the Supabase database to create
   Constructive's `anonymous` role (and the other base roles).
2. Ensure Supabase's `anon` and `authenticated` roles already exist. Outside
   Supabase, create `anon` with `CREATE ROLE anon NOINHERIT NOLOGIN;` before deployment.
3. Install `@pgpm/supabase` and deploy `pgpm-supabase` with `pgpm deploy`.
4. As the database administrator, configure PostgREST:

   ```sql
   ALTER ROLE authenticator SET pgrst.db_pre_request = 'supabase_integration.pre_request';
   NOTIFY pgrst, 'reload config';
   ```

Schema USAGE and hook EXECUTE are available to PUBLIC so PostgREST can also
invoke the hook as `service_role` without requiring that role at deploy time.
The hook is a no-op for roles other than `anon` and `authenticated`.

The security-invoker hook switches `anon` to `anonymous`. It does not grant
automatic inheritance: `anon` cannot use `anonymous` grants without switching.
On PostgreSQL 16+ the membership explicitly disables inheritance and allows SET;
on PostgreSQL 15 it relies on Supabase's `anon` being NOINHERIT.

For `authenticated`, the hook copies the verified `request.jwt.claims` JSON `sub`
to both `jwt.claims.user_id` and `jwt.claims.principal_id`, transaction-locally.
The subject must correspond to Constructive's `users.id`. Missing/empty claims
or subjects leave the claims unset; malformed JSON raises an error. Other roles
are unchanged. Only use this hook behind PostgREST's verified JWT boundary;
it does not verify JWTs. Each request must use a fresh transaction.

### Sync new Supabase users

In an `auth:supabase` export, call the installer as the module owner in a
migration **after** creating the Constructive users table. Pass the actual
schema-qualified table name from the export:

```sql
SELECT supabase_integration.sync_users('my_app_users_public.users'::regclass);
```

The installer uses the `auth.users` table provided by Supabase; do not import
or deploy a separate Supabase schema on a hosted project. After installation,
each signup creates a Constructive user with the same UUID as `auth.users.id`
(the JWT subject). An existing Constructive row with that UUID is left unchanged.
Calling the installer again replaces the trigger. It does not backfill existing
Supabase accounts, assign memberships, or delete Constructive users.

RLS policies must treat empty claim strings as absent, for example
`nullif(current_setting('jwt.claims.user_id', true), '')::uuid`. PostgreSQL can
return an empty string for a custom GUC after its transaction-local value is
rolled back; a direct UUID cast would then raise on a later unauthenticated request.

## Development

```sh
eval "$(pgpm env)"
pnpm test
pgpm package
```

The tests create a missing `anon` role before deploying the module and use a
local `auth.users` fixture. Reverting revokes the membership and drops the
hook, any installed user-sync trigger, and the schema, but does not drop
roles, remove synced users, or change PostgREST configuration. Remove the
pre-request setting before reverting.
