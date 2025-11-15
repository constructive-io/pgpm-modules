# AGENTS.md — pgpm/Sqitch‑style Workflow for SQL Changes

> **Audience:** internal agents and contributors who ship database changes across the Interweb/pgpm workspace.
>
> **Goal:** make safe, testable, reversible SQL changes using a Sqitch‑style plan (`pgpm.plan`) and the `deploy/`, `revert/`, `verify/` folders.

---

## Mental model

pgpm extends the **Sqitch** model to a multi‑package **npm workspace**. Think of it as **Lerna/Yarn workspaces, but for SQL**:

* Each package contains its own `pgpm.plan` plus `deploy/`, `revert/`, `verify/` trees.
* Plans compose **recursively** up the workspace (e.g., an app package depends on a module package). Dependencies are explicit in the plan.
* Every change is a **triple**:

  * `deploy/<namespace>/<change>.sql` — applies the change
  * `verify/<namespace>/<change>.sql` — *proves* the change works
  * `revert/<namespace>/<change>.sql` — removes the change cleanly
* CI runs deploy → verify; rollbacks run revert; local development often runs deploy ↔ revert iteratively.

> **Invariant:** for **every** `deploy/**/*.sql` there must be a **matching** `verify/**/*.sql` and `revert/**/*.sql` at the same relative path (and name).

---

## Repository layout (canonical)

```
packages/
  utils/
    verify/                 # pgpm-verify helpers live here (as a package)
  my-module/
    pgpm.plan
    deploy/
      public/
        create_table_users.sql
        add_index_users_email.sql
    verify/
      public/
        create_table_users.sql
        add_index_users_email.sql
    revert/
      public/
        create_table_users.sql
        add_index_users_email.sql
  my-app/
    pgpm.plan
    ...
```

**Naming rules**

* **Descriptive names only** (no numbers). Example: `create_table_users.sql`, `add_index_users_email.sql`.
* **Namespace** (e.g., `public/`, `auth/`, `feature_x/`) keeps files organized by schema or domain.
* **One change per file** in each folder. If your deploy spans multiple SQL statements, they all live in that one file — see *revert mechanics* below.


## Physical mechanics

### Deploy

* Executed in **plan order**.
* May include DDL (CREATE/ALTER), DML (migrations), grants, comments, etc.
* Prefer **transactional** changes when feasible. For long‑running operations, document the migration strategy.

### Verify (must exist for every deploy)

* The file path must **mirror** its deploy partner:
  `verify/<ns>/<change>.sql` ↔ `deploy/<ns>/<change>.sql`.
* Must **prove** the intended state: table exists, column types, indexes present, grants applied, invariants hold, etc.
* Use **`pgpm-verify`** helpers (lives at `packages/utils/verify`). Examples below.

### Revert (must exist for every deploy)

* The file path must **mirror** its deploy partner:
  `revert/<ns>/<change>.sql` ↔ `deploy/<ns>/<change>.sql`.
* Must **fully revert** all SQL done in deploy.
* If deploy had multiple statements, **undo them in strict reverse order** to safely drop dependents before parents (e.g., drop index → drop constraint → drop table).


## Examples

### Deploy: create table + index

`deploy/public/create_table_users.sql`

```sql
BEGIN;
CREATE TABLE IF NOT EXISTS public.users (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email       citext NOT NULL UNIQUE,
  created_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS users_email_idx ON public.users (email);
COMMIT;
```

### Verify: assert shape & performance helpers

`verify/public/create_table_users.sql`

```sql
-- Helpers are provided by the pgpm-verify extension.
-- Assert table and index exist
SELECT verify_table('public.users');
SELECT verify_index('public.users','users_email_idx');
```

### Revert: reverse the deploy

`revert/public/create_table_users.sql`

```sql
BEGIN;
DROP INDEX IF EXISTS public.users_email_idx;
DROP TABLE IF EXISTS public.users;
COMMIT;
```

### Plan entries

`pgpm.plan`

```
change create_table_users
```

---

## Cross‑package dependencies (recursion)

When a package depends on SQL provided by another package:

* Reference that package’s tagged frontier (or explicit change) in your `pgpm.plan` with `requires pkg:<name>/<module>@<tag>`.
* The workspace runner resolves dependencies in topological order across packages, then executes deploy → verify.
* Keep shared primitives (schemas, types, roles, policies) in foundational packages (e.g., `utils/schema-core`) and depend on them.

## Using `pgpm-verify` in practice

**Common helpers** *(names per your package)*:

* `verify_table(_table text)`
* `verify_index(_table text, _index text)`
* `verify_view(_view text)`
* `verify_role(_user text)` / `verify_membership(_user text, _role text)`
* `verify_function(_name text, _user text default null)`
* `verify_schema(_schema text)` / `verify_type(_type text)` / `verify_domain(_type text)`
* `verify_policy(_policy text, _table text)` / `verify_table_grant(_table text, _privilege text, _role text)`

**Conventions**

* A verify script should **fail fast** when an expectation isn’t met (non‑zero result or raised assertion).
* Prefer **positive** checks (exists/equals) vs free‑form `SELECT` with comments.