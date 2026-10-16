import { getConnections, PgTestClient } from 'pgsql-test';

let pg: PgTestClient;
let teardown: () => Promise<void>;

// mod(abs(hashtext(database_id)), 2) = 1: this database falls in slot 1 of a two-shard lane.
const database_id = '5b720132-17d5-424d-9bcb-ee7b17c13d43';
const other_database_id = '0c1f1d0e-6a0e-4b5e-9a62-7c3a4f0a9b11';

const roleType = (value: string) => pg.any(`SELECT set_config('jwt.claims.role_type', $1, false)`, [value]);

const identifiers = async (id: string) =>
  (await pg.any(`SELECT * FROM app_jobs.scheduled_task_identifiers($1::uuid) AS t(task) ORDER BY 1`, [id])).map(
    (row) => row.task as string
  );

describe('app_jobs.scheduled_task_identifiers', () => {
  beforeAll(async () => {
    ({ pg, teardown } = await getConnections());
    await pg.any(
      `INSERT INTO app_jobs.scheduled_jobs (database_id, task_identifier, schedule_info, key, payload)
       VALUES ($1, 'billing:doctor', '{"rule":"0 0 4 * * *"}'::json, 'own', '{}'::json),
              ($2, 'billing:sweep_overdue', '{"rule":"0 0 4 * * *"}'::json, 'other', '{}'::json),
              ($2, 'schedules:fanout', '{"rule":"0 0 4 * * *"}'::json, 'lane',
               '{"task":"billing:sync_usage","shard":0,"shard_count":1}'::json),
              ($2, 'schedules:fanout', '{"rule":"0 0 4 * * *"}'::json, 'slice-1-of-2',
               '{"task":"billing:reconcile","shard":1,"shard_count":2}'::json),
              ($2, 'schedules:fanout', '{"rule":"0 0 4 * * *"}'::json, 'slice-0-of-2',
               '{"task":"billing:monthly_rollup","shard":0,"shard_count":2}'::json)`,
      [database_id, other_database_id]
    );
  }, 120_000);

  /** Lane rows the worker refuses to run (payload.shard_count / payload.shard out of range or not numbers). */
  const malformedLanes = [
    '{"task":"bad:zero","shard":0,"shard_count":0}',
    '{"task":"bad:text","shard":0,"shard_count":"x"}',
    '{"task":"bad:missing","shard":0}',
    '{"task":"bad:fraction","shard":0,"shard_count":1.5}',
    '{"task":"bad:shard_range","shard":1,"shard_count":1}',
    '{"task":"bad:shard_text","shard":"x","shard_count":1}'
  ];

  afterAll(async () => {
    await teardown();
  });

  it("returns a system caller the database's own tasks and its fanout lanes' tasks, not another database's", async () => {
    await roleType('system');
    expect(await identifiers(database_id)).toEqual(['billing:doctor', 'billing:reconcile', 'billing:sync_usage']);
  });

  it('skips fanout lanes whose payload the worker would refuse, instead of failing the call', async () => {
    await roleType('system');
    await pg.any(`BEGIN`);
    try {
      for (const [index, payload] of malformedLanes.entries()) {
        await pg.any(
          `INSERT INTO app_jobs.scheduled_jobs (database_id, task_identifier, schedule_info, key, payload)
           VALUES ($1, 'schedules:fanout', '{"rule":"0 0 4 * * *"}'::json, $2, $3::json)`,
          [other_database_id, `malformed-${index}`, payload]
        );
      }
      expect(await identifiers(database_id)).toEqual(['billing:doctor', 'billing:reconcile', 'billing:sync_usage']);
    } finally {
      await pg.any(`ROLLBACK`);
    }
  });

  it('refuses a caller that is not system', async () => {
    await roleType('user');
    await expect(identifiers(database_id)).rejects.toThrow('FORBIDDEN');
  });
});
