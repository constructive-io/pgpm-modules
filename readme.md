# deployment

1. run the introspection test in pg

2. `lql export` inside of a sandbox lql repo

* name extension `rls`
* uncheck the `collections_public` during cli
* delete the `svc` extension when outputs

3. 

```
cd packages/rls
# lql plan  # DO NOT RUN PLAN!!!!
lql package
```

* Then copy/paste the code from extension `sql/*.sql` into `rls-export`'s rls.sql
* leave the table rls alone

4. test it

```
lql deploy --recursive --yes --createdb --project launchql-rls
```