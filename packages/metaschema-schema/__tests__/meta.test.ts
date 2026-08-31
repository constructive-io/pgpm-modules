import { getConnections, PgTestClient } from 'pgsql-test';

let pg: PgTestClient;
let teardown: () => Promise<void>;

describe('metaschema_schema functionality', () => {
  beforeAll(async () => {
    ({ pg, teardown } = await getConnections());
  });

  afterAll(async () => {
    await teardown();
  });

  beforeEach(async () => {
    await pg.beforeEach();
    await pg.any(`GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO public`);
  });

  afterEach(async () => {
    await pg.afterEach();
  });

  it('should create database independently', async () => {
    const owner_id = '07281002-1699-4762-57e3-ab1b92243120';
    
    const [database] = await pg.any(
      `INSERT INTO metaschema_public.database (owner_id, name) 
       VALUES ($1, $2) 
       RETURNING *`,
      [owner_id, 'test-db']
    );
    
    expect(database.owner_id).toBe(owner_id);
    expect(database.name).toBe('test-db');
    expect(database.id).toBeDefined();
  });

  describe('trigger customer attachment shape', () => {
    let database_id: string;
    let table_id: string;
    let function_id: string;

    beforeEach(async () => {
      const owner_id = '07281002-1699-4762-57e3-ab1b92243120';
      ({ id: database_id } = await pg.one(
        `INSERT INTO metaschema_public.database (owner_id, name)
         VALUES ($1, $2) RETURNING id`,
        [owner_id, 'trigger-db']
      ));
      const { id: schema_id } = await pg.one(
        `INSERT INTO metaschema_public.schema (database_id, name, schema_name)
         VALUES ($1, $2, $3) RETURNING id`,
        [database_id, 'app_public', 'trigger_test_app_public']
      );
      ({ id: table_id } = await pg.one(
        `INSERT INTO metaschema_public.table (database_id, schema_id, name)
         VALUES ($1, $2, $3) RETURNING id`,
        [database_id, schema_id, 'orders']
      ));
      ({ id: function_id } = await pg.one(
        `INSERT INTO metaschema_public.function (database_id, schema_id, name, kind, returns, volatility, body_ast)
         VALUES ($1, $2, $3, 'trigger', '{"type":{"name":"trigger"}}', 'VOLATILE', '{}') RETURNING id`,
        [database_id, schema_id, 'orders_audit_tg']
      ));
    });

    const insertTrigger = (name: string, columns: Record<string, unknown>) => {
      const extra = Object.keys(columns);
      const cols = ['database_id', 'table_id', 'name', ...extra];
      const params = [database_id, table_id, name, ...extra.map((k) => columns[k])];
      const placeholders = params.map((_, i) => `$${i + 1}`);
      return pg.one(
        `INSERT INTO metaschema_public.trigger (${cols.join(', ')})
         VALUES (${placeholders.join(', ')}) RETURNING *`,
        params
      );
    };

    it('still accepts existing generated rows unchanged', async () => {
      const row = await insertTrigger('generated_tg', {
        event: 'INSERT',
        function_name: 'app_hidden.some_generated_fn'
      });
      expect(row.kind).toBe('reservation');
      expect(row.function_id).toBeNull();
      expect(row.timing).toBeNull();
      expect(row.events).toBeNull();
      expect(row.for_each_row).toBeNull();
      expect(row.when_ast).toBeNull();
    });

    it('accepts a reservation whose events round-tripped as an empty array', async () => {
      const row = await insertTrigger('seeded_tg', {
        function_name: 'app_hidden.some_generated_fn',
        events: []
      });
      expect(row.kind).toBe('reservation');
      expect(row.events).toEqual([]);
    });

    it('accepts the AFTER ... FOR EACH ROW customer shape', async () => {
      const row = await insertTrigger('customer_tg', {
        kind: 'attachment',
        function_id,
        timing: 'AFTER',
        events: ['INSERT', 'UPDATE', 'DELETE'],
        for_each_row: true
      });
      expect(row.kind).toBe('attachment');
      expect(row.function_id).toBe(function_id);
      expect(row.events).toEqual(['INSERT', 'UPDATE', 'DELETE']);
    });

    it('rejects an attachment kind without a function', async () => {
      await expect(
        insertTrigger('kindless_tg', {
          kind: 'attachment',
          timing: 'AFTER',
          events: ['INSERT'],
          for_each_row: true
        })
      ).rejects.toThrow(/trigger_kind_matches_attachment/);
    });

    it('rejects a function on a reservation row', async () => {
      await expect(
        insertTrigger('reserved_with_fn_tg', {
          function_id,
          timing: 'AFTER',
          events: ['INSERT'],
          for_each_row: true
        })
      ).rejects.toThrow(/trigger_kind_matches_attachment/);
    });

    it('rejects an attachment definition on a reservation row', async () => {
      await expect(
        insertTrigger('reserved_with_timing_tg', {
          timing: 'AFTER',
          events: ['INSERT'],
          for_each_row: true
        })
      ).rejects.toThrow(/trigger_reservation_has_no_definition/);
    });

    it('rejects an unknown kind', async () => {
      await expect(
        insertTrigger('bogus_kind_tg', { kind: 'physical' })
      ).rejects.toThrow(/trigger_kind_valid/);
    });

    it('refuses to delete a function that is still attached', async () => {
      await insertTrigger('attached_tg', {
        kind: 'attachment',
        function_id,
        timing: 'AFTER',
        events: ['INSERT'],
        for_each_row: true
      });
      await expect(
        pg.any(`DELETE FROM metaschema_public.function WHERE id = $1`, [
          function_id
        ])
      ).rejects.toThrow(/function_fkey/);
    });

    it('rejects BEFORE when function_id is set', async () => {
      await expect(
        insertTrigger('before_tg', {
          kind: 'attachment',
          function_id,
          timing: 'BEFORE',
          events: ['INSERT'],
          for_each_row: true
        })
      ).rejects.toThrow(/trigger_customer_attachment_shape/);
    });

    it('rejects statement-level triggers when function_id is set', async () => {
      await expect(
        insertTrigger('stmt_tg', {
          kind: 'attachment',
          function_id,
          timing: 'AFTER',
          events: ['INSERT'],
          for_each_row: false
        })
      ).rejects.toThrow(/trigger_customer_attachment_shape/);
    });

    it('rejects TRUNCATE events when function_id is set', async () => {
      await expect(
        insertTrigger('truncate_tg', {
          kind: 'attachment',
          function_id,
          timing: 'AFTER',
          events: ['TRUNCATE'],
          for_each_row: true
        })
      ).rejects.toThrow(/trigger_customer_attachment_shape/);
    });

    it('rejects empty events when function_id is set', async () => {
      await expect(
        insertTrigger('empty_events_tg', {
          kind: 'attachment',
          function_id,
          timing: 'AFTER',
          events: [],
          for_each_row: true
        })
      ).rejects.toThrow(/trigger_customer_attachment_shape/);
    });

    it('rejects missing events when function_id is set', async () => {
      await expect(
        insertTrigger('null_events_tg', {
          kind: 'attachment',
          function_id,
          timing: 'AFTER',
          events: null,
          for_each_row: true
        })
      ).rejects.toThrow(/trigger_customer_attachment_shape/);
    });
  });
});
