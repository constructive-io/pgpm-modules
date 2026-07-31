import { getConnections, PgTestClient } from 'pgsql-test';

let pg: PgTestClient;
let teardown: () => Promise<void>;

// Proof-of-concept: the resolver closure (scope chain + function-definition
// resolution + resolver-aware enqueue) installs and runs in a database whose
// dependency closure is ONLY the portable pgpm-modules — NOT packages/ast
// (deparser) and NOT packages/metaschema (metaschema_private.*). This is the
// portability claim behind app-scope + function-resolution.
describe('function-resolution portability', () => {
  beforeAll(async () => {
    ({ pg, teardown } = await getConnections());
  });

  afterAll(async () => {
    await teardown();
  });

  it('installs the new schemas', async () => {
    const rows = await pg.any(
      `SELECT nspname FROM pg_namespace
       WHERE nspname IN ('app_scope','function_resolution')
       ORDER BY nspname`
    );
    expect(rows.map((r: any) => r.nspname)).toEqual([
      'app_scope',
      'function_resolution',
    ]);
  });

  it('does NOT pull in the AST/deparser runtime', async () => {
    // packages/ast ships schema `deparser` (deparser.deparse). If the closure
    // were still AST-dependent this schema would be installed.
    const [{ present }] = await pg.any(
      `SELECT EXISTS (
         SELECT 1 FROM pg_namespace WHERE nspname IN ('deparser','ast','ast_helpers')
       ) AS present`
    );
    expect(present).toBe(false);
  });

  it('does NOT pull in packages/metaschema runtime functions', async () => {
    // The core resolver lives in metaschema_private.* (packages/metaschema),
    // which is NOT a pgpm-module. It must be absent from a portable install.
    const [{ present }] = await pg.any(
      `SELECT EXISTS (
         SELECT 1 FROM pg_proc p
         JOIN pg_namespace n ON n.oid = p.pronamespace
         WHERE n.nspname = 'metaschema_private'
           AND p.proname IN ('enqueue_job','resolve_function_definition','scope_frames')
       ) AS present`
    );
    expect(present).toBe(false);
  });

  it('exposes the portable resolver surface', async () => {
    const rows = await pg.any(
      `SELECT n.nspname, p.proname
       FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
       WHERE (n.nspname = 'app_scope' AND p.proname IN ('frames','platform_database_id','membership_parent','dyn_lookup_uuid'))
          OR (n.nspname = 'function_resolution' AND p.proname IN ('resolve','routing','definitions_location','catalog_location','resolve_invocation','enqueue'))
       ORDER BY n.nspname, p.proname`
    );
    const names = rows.map((r: any) => `${r.nspname}.${r.proname}`);
    expect(names).toEqual([
      'app_scope.dyn_lookup_uuid',
      'app_scope.frames',
      'app_scope.membership_parent',
      'app_scope.platform_database_id',
      'function_resolution.catalog_location',
      'function_resolution.definitions_location',
      'function_resolution.enqueue',
      'function_resolution.resolve',
      'function_resolution.resolve_invocation',
      'function_resolution.routing',
    ]);
  });
});
