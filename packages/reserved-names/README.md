# @pgpm/reserved-names

<p align="center" width="100%">
  <img height="250" src="https://raw.githubusercontent.com/constructive-io/constructive/refs/heads/main/assets/outline-logo.svg" />
</p>

<p align="center" width="100%">
  <a href="https://github.com/constructive-io/pgpm-modules/actions/workflows/ci.yml">
    <img height="20" src="https://github.com/constructive-io/pgpm-modules/actions/workflows/ci.yml/badge.svg" />
  </a>
   <a href="https://github.com/constructive-io/pgpm-modules/blob/main/LICENSE"><img height="20" src="https://img.shields.io/badge/license-MIT-blue.svg"/></a>
   <a href="https://www.npmjs.com/package/@pgpm/reserved-names"><img height="20" src="https://img.shields.io/github/package-json/v/constructive-io/pgpm-modules?filename=packages%2Freserved-names%2Fpackage.json"/></a>
</p>

Reserved names that nobody may claim — subdomains, usernames, slugs, or any other kind — kept as rows and checked live by one function.

## Overview

`@pgpm/reserved-names` keeps one shared list in `reserved_names.names`. Callers ask `reserved_names.is_reserved(kind, name)` at the moment someone claims a name, so a new entry takes effect at once for every caller, with no regeneration or redeploy of the callers.

It ships a starter `subdomain` list: hostnames a visitor would read as the platform's own under a shared domain (`login`, `admin`, `www`, `mail`, `ns1`, …), plus a `xn--` prefix entry that blocks punycode lookalikes (`аpple` with a Cyrillic `а`).

## Installation

```bash
pgpm install @pgpm/reserved-names
pgpm deploy
```

## Usage

```sql
SELECT reserved_names.is_reserved('subdomain', 'login');        -- true
SELECT reserved_names.is_reserved('subdomain', 'LOGIN');        -- true (case-insensitive)
SELECT reserved_names.is_reserved('subdomain', 'xn--pple-43d'); -- true (prefix entry)
SELECT reserved_names.is_reserved('subdomain', 'mystore');      -- false
SELECT reserved_names.is_reserved('username', 'login');         -- false (kinds are separate)
```

In a claim function:

```sql
IF reserved_names.is_reserved('subdomain', v_label) THEN
  RAISE EXCEPTION 'SUBDOMAIN_LABEL_RESERVED';
END IF;
```

### Adding names

The list changes only through migrations. Add a pgpm change that inserts rows:

```sql
INSERT INTO reserved_names.names (kind, name, is_prefix, reason) VALUES
  ('subdomain', 'www2', false, 'platform'),
  ('subdomain', 'staff-', true, 'platform'),  -- every name starting with staff-
  ('username', 'support', false, 'staff');
```

## Schema

`reserved_names.names`

| column | type | notes |
| --- | --- | --- |
| `kind` | `text` | what the name is, e.g. `subdomain`, `username`; `^[a-z][a-z0-9_]*$` |
| `name` | `text` | lowercase, non-empty |
| `is_prefix` | `boolean` | when true, every name starting with `name` is reserved |
| `reason` | `text` | why it is reserved |

Primary key `(kind, name)`.

`reserved_names.is_reserved(kind text, name text) RETURNS boolean` — `STABLE`, compares `lower(name)`; a `NULL` name is not reserved.

## Access

Everyone can read the list and call `is_reserved`, so a UI can say "that name is reserved" before submitting. No role is granted `INSERT`, `UPDATE` or `DELETE`: only the module owner (migrations) can change it.

## Testing

```bash
pnpm test
```
