import { getConnections, PgTestClient } from 'pgsql-test';

let pg: PgTestClient;
let teardown: () => Promise<void>;

const database_id = '5b720132-17d5-424d-9bcb-ee7b17c13d43';
const actor_id = 'b9d22af1-62c7-43a5-b8c4-50630bbd4962';
const principal_id = 'd9a8e3c1-5d5c-450d-8a95-95e4f7d9d98c';
const entity_id = 'f12f1f0d-6f62-4f4b-93f2-72ee5d2a5b8e';
const objs: Record<string, any> = {};

describe('scheduled jobs', () => {
  beforeAll(async () => {
    ({ pg, teardown } = await getConnections());
    await pg.any(`SELECT set_config('jwt.strict_attribution', 'false', false)`);
  });

  afterAll(async () => {
    await teardown();
  });

  it('schedule jobs by cron', async () => {
    const result = await pg.one(
      `INSERT INTO app_jobs.scheduled_jobs (database_id, task_identifier, schedule_info)
       VALUES ($1, $2, $3)
       RETURNING *`,
      [
        database_id,
        'my_job',
        {
          hour: Array.from({ length: 23 }, (_, i) => i),
          minute: [0, 15, 30, 45],
          dayOfWeek: Array.from({ length: 6 }, (_, i) => i)
        }
      ]
    );
    objs.scheduled1 = result;
  });

  it('schedule jobs by rule', async () => {
    const start = new Date(Date.now() + 10000); // 10s from now
    const end = new Date(start.getTime() + 180000); // +3min

    const result = await pg.one(
      `INSERT INTO app_jobs.scheduled_jobs (database_id, task_identifier, payload, schedule_info)
       VALUES ($1, $2, $3, $4)
       RETURNING *`,
      [
        database_id,
        'my_job',
        { just: 'run it' },
        { start, end, rule: '*/1 * * * *' }
      ]
    );
    objs.scheduled2 = result;
  });

  it('schedule jobs', async () => {
    const [result] = await pg.any(
      `SELECT * FROM app_jobs.run_scheduled_job($1)`,
      [objs.scheduled2.id]
    );

    const { queue_name, run_at, created_at, updated_at, ...obj } = result;
    expect(obj).toMatchSnapshot();
  });

  it('schedule jobs with keys', async () => {
    const start = new Date(Date.now() + 10000); // 10s
    const end = new Date(start.getTime() + 180000); // +3min

    const [result] = await pg.any(
      `SELECT * FROM app_jobs.add_scheduled_job(
        db_id := $1::uuid,
        identifier := $2::text,
        payload := $3::json,
        schedule_info := $4::json,
        job_key := $5::text,
        queue_name := $6::text,
        max_attempts := $7::integer,
        priority := $8::integer
      )`,
      [
        database_id,
        'my_job',
        { just: 'run it' },
        { start, end, rule: '*/1 * * * *' },
        'new_key',
        null,
        25,
        0
      ]
    );

    const {
      queue_name,
      run_at,
      created_at,
      updated_at,
      schedule_info: sch,
      start: s1,
      end: d1,
      ...obj
    } = result;

    const [result2] = await pg.any(
      `SELECT * FROM app_jobs.add_scheduled_job(
        db_id := $1,
        identifier := $2,
        payload := $3,
        schedule_info := $4,
        job_key := $5,
        queue_name := $6,
        max_attempts := $7,
        priority := $8
      )`,
      [
        database_id,
        'my_job',
        { just: 'run it' },
        { start, end, rule: '*/1 * * * *' },
        'new_key',
        null,
        25,
        0
      ]
    );

    const {
      queue_name: qn,
      created_at: ca,
      updated_at: ua,
      schedule_info: sch2,
      start: s,
      end: e,
      ...obj2
    } = result2;

    console.log('First insert:', obj);
    console.log('Duplicate insert (job_key conflict):', obj2);
  });

  it('add_job stamps explicit db_id', async () => {
    const [job] = await pg.any(
      `SELECT * FROM app_jobs.add_job(
        identifier := 'my_job',
        db_id := $1::uuid,
        actor_id := $2::uuid
      )`,
      [database_id, 'b9d22af1-62c7-43a5-b8c4-50630bbd4962']
    );
    expect(job.database_id).toBe(database_id);
  });

  it('add_job stamps entity attribution from transaction-local claims, but never the organization', async () => {
    const user_id = 'b9d22af1-62c7-43a5-b8c4-50630bbd4962';
    const principal_id = 'd9a8e3c1-5d5c-450d-8a95-95e4f7d9d98c';
    const entity_id = 'f12f1f0d-6f62-4f4b-93f2-72ee5d2a5b8e';
    const organization_id = 'c89b6b6b-ea18-4d98-bd5a-3f3c0c34f872';

    await pg.any(`BEGIN`);
    try {
      await pg.any(
        `SELECT
           set_config('jwt.claims.database_id', $1, true),
           set_config('jwt.claims.user_id', $2, true),
           set_config('jwt.claims.principal_id', $3, true),
           set_config('jwt.claims.entity_id', $4, true),
           set_config('jwt.claims.organization_id', $5, true),
           set_config('jwt.claims.entity_type', $6, true)`,
        [database_id, user_id, principal_id, entity_id, organization_id, 'org']
      );

      const [job] = await pg.any(
        `SELECT * FROM app_jobs.add_job(
          identifier := 'claimed_job',
          job_key := 'claimed_job'
        )`
      );

      expect({
        database_id: job.database_id,
        actor_id: job.actor_id,
        principal_id: job.principal_id,
        entity_id: job.entity_id,
        organization_id: job.organization_id,
        entity_type: job.entity_type
      }).toEqual({
        database_id,
        actor_id: user_id,
        principal_id,
        entity_id,
        // Set as a claim above and deliberately not inherited: the organization
        // is derived from the entity pair where usage is recorded, so a claim
        // asserting one is not an authority add_job trusts.
        organization_id: null,
        entity_type: 'org'
      });
    } finally {
      await pg.any(`ROLLBACK`);
    }
  });

  it('add_job fails the NOT NULL constraint without database attribution', async () => {
    await expect(
      pg.any(`SELECT * FROM app_jobs.add_job(identifier := 'my_job')`)
    ).rejects.toThrow(/database_id/);
  });

  it('add_job rejects claimless attribution at the work boundary', async () => {
    await pg.any(`BEGIN`);
    await pg.any(`SELECT set_config('jwt.strict_attribution', 'true', true)`);
    await expect(
      pg.any(
        `SELECT * FROM app_jobs.add_job(
          identifier := 'claimless_job',
          db_id := $1::uuid
        )`,
        [database_id]
      )
    ).rejects.toThrow('ATTRIBUTION_REQUIRED');
    await pg.any(`ROLLBACK`);
  });

  it('add_job rejects an entity without an entity type', async () => {
    await pg.any(`BEGIN`);
    await pg.any(`SELECT set_config('jwt.strict_attribution', 'true', true)`);
    await expect(
      pg.any(
        `SELECT * FROM app_jobs.add_job(
          identifier := 'missing_entity_type_job',
          db_id := $1::uuid,
          entity_id := $2::uuid
        )`,
        [database_id, 'f12f1f0d-6f62-4f4b-93f2-72ee5d2a5b8e']
      )
    ).rejects.toThrow('ENTITY_TYPE_REQUIRED');
    await pg.any(`ROLLBACK`);
  });

  it('add_job allows actor-only attribution', async () => {
    const actor_id = 'b9d22af1-62c7-43a5-b8c4-50630bbd4962';
    const [job] = await pg.any(
      `SELECT * FROM app_jobs.add_job(
        identifier := 'actor_only_job',
        db_id := $1::uuid,
        actor_id := $2::uuid
      )`,
      [database_id, actor_id]
    );
    expect(job.actor_id).toBe(actor_id);
    expect(job.entity_id).toBeNull();
    expect(job.entity_type).toBeNull();
  });

  it('add_job allows row-derived entity attribution with its type', async () => {
    const entity_id = 'f12f1f0d-6f62-4f4b-93f2-72ee5d2a5b8e';
    const [job] = await pg.any(
      `SELECT * FROM app_jobs.add_job(
        identifier := 'entity_attributed_job',
        db_id := $1::uuid,
        entity_id := $2::uuid,
        entity_type := $3::text
      )`,
      [database_id, entity_id, 'org']
    );
    expect(job.entity_id).toBe(entity_id);
    expect(job.entity_type).toBe('org');
  });

  it('add_scheduled_job fails the NOT NULL constraint without database attribution', async () => {
    await expect(
      pg.any(
        `SELECT * FROM app_jobs.add_scheduled_job(identifier := 'my_job')`
      )
    ).rejects.toThrow('DATABASE_CLAIM_REQUIRED');
  });

  it('add_scheduled_job defaults complete attribution from transaction-local claims', async () => {
    await pg.any(`BEGIN`);
    try {
      await pg.any(
        `SELECT
           set_config('jwt.claims.database_id', $1, true),
           set_config('jwt.claims.user_id', $2, true),
           set_config('jwt.claims.principal_id', $3, true),
           set_config('jwt.claims.entity_id', $4, true),
           set_config('jwt.claims.entity_type', $5, true)`,
        [database_id, actor_id, principal_id, entity_id, 'org']
      );

      const [scheduled] = await pg.any(
        `SELECT * FROM app_jobs.add_scheduled_job(
          identifier := 'claimed_scheduled_job',
          job_key := 'claimed_scheduled_job'
        )`
      );

      expect({
        database_id: scheduled.database_id,
        actor_id: scheduled.actor_id,
        principal_id: scheduled.principal_id,
        entity_id: scheduled.entity_id,
        organization_id: scheduled.organization_id,
        entity_type: scheduled.entity_type
      }).toEqual({
        database_id,
        actor_id,
        principal_id,
        entity_id,
        organization_id: null,
        entity_type: 'org'
      });
    } finally {
      await pg.any(`ROLLBACK`);
    }
  });

  it.each([
    ['entity id without entity type', 'entity_id := $2::uuid, entity_type := NULL', [database_id, entity_id, actor_id]],
    ['entity type without entity id', 'entity_id := NULL, entity_type := $2::text', [database_id, 'org', actor_id]]
  ])('add_scheduled_job warns by default for %s', async (_description, attribution, params) => {
    // The session default is explicitly non-strict in beforeAll.
    await pg.any(`BEGIN`);
    try {
      const [scheduled] = await pg.any(
        `SELECT * FROM app_jobs.add_scheduled_job(
          identifier := 'partial_scheduled_job',
          db_id := $1::uuid,
          actor_id := $3::uuid,
          ${attribution}
        )`,
        params
      );
      expect(scheduled).toBeDefined();
    } finally {
      await pg.any(`ROLLBACK`);
    }
  });

  it.each([
    ['entity id without entity type', 'entity_id := $2::uuid, entity_type := NULL', [database_id, entity_id, actor_id], 'ENTITY_TYPE_REQUIRED'],
    ['entity type without entity id', 'entity_id := NULL, entity_type := $2::text', [database_id, 'org', actor_id], 'ENTITY_ID_REQUIRED']
  ])('add_scheduled_job rejects %s under strict attribution', async (_description, attribution, params, error) => {
    await pg.any(`BEGIN`);
    try {
      await pg.any(`SELECT set_config('jwt.strict_attribution', 'true', true)`);
      await expect(
        pg.any(
          `SELECT * FROM app_jobs.add_scheduled_job(
            identifier := 'strict_partial_scheduled_job',
            db_id := $1::uuid,
            actor_id := $3::uuid,
            ${attribution}
          )`,
          params
        )
      ).rejects.toThrow(error);
    } finally {
      await pg.any(`ROLLBACK`);
    }
  });

  it('add_scheduled_job restamps keyed rows with the caller identity', async () => {
    await pg.any(`BEGIN`);
    try {
      await pg.any(
        `SELECT
           set_config('jwt.claims.database_id', $1, true),
           set_config('jwt.claims.user_id', $2, true),
           set_config('jwt.claims.principal_id', $3, true),
           set_config('jwt.claims.entity_id', $4, true),
           set_config('jwt.claims.entity_type', $5, true)`,
        [database_id, actor_id, principal_id, entity_id, 'org']
      );
      await pg.any(
        `SELECT * FROM app_jobs.add_scheduled_job(
          identifier := 'restamp_scheduled_job',
          job_key := 'restamp_scheduled_job'
        )`
      );

      const next_actor_id = 'f89a41e7-7e41-4c63-b6c7-e99d7a122f70';
      const next_principal_id = '4ae9a4f9-f785-4d4e-8e4b-2aa367ec4d7a';
      const next_entity_id = '8f09e1b0-eae4-4e76-918a-1e916f6f7c4c';
      await pg.any(
        `SELECT
           set_config('jwt.claims.user_id', $1, true),
           set_config('jwt.claims.principal_id', $2, true),
           set_config('jwt.claims.entity_id', $3, true),
           set_config('jwt.claims.entity_type', $4, true)`,
        [next_actor_id, next_principal_id, next_entity_id, 'team']
      );
      const [scheduled] = await pg.any(
        `SELECT * FROM app_jobs.add_scheduled_job(
          identifier := 'restamped_scheduled_job',
          job_key := 'restamp_scheduled_job'
        )`
      );

      expect({
        database_id: scheduled.database_id,
        actor_id: scheduled.actor_id,
        principal_id: scheduled.principal_id,
        entity_id: scheduled.entity_id,
        organization_id: scheduled.organization_id,
        entity_type: scheduled.entity_type
      }).toEqual({
        database_id,
        actor_id: next_actor_id,
        principal_id: next_principal_id,
        entity_id: next_entity_id,
        organization_id: null,
        entity_type: 'team'
      });
    } finally {
      await pg.any(`ROLLBACK`);
    }
  });

  it('run_scheduled_job copies complete attribution to the spawned job', async () => {
    const scheduled = await pg.one(
      `INSERT INTO app_jobs.scheduled_jobs (
         database_id, actor_id, principal_id, entity_id, organization_id,
         entity_type, task_identifier, schedule_info
       ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
       RETURNING *`,
      [
        database_id,
        actor_id,
        principal_id,
        entity_id,
        'c89b6b6b-ea18-4d98-bd5a-3f3c0c34f872',
        'org',
        'attributed_scheduled_job',
        { start: new Date(Date.now() + 10000), end: new Date(Date.now() + 180000) }
      ]
    );
    const [job] = await pg.any(
      `SELECT * FROM app_jobs.run_scheduled_job($1)`,
      [scheduled.id]
    );
    expect({
      database_id: job.database_id,
      actor_id: job.actor_id,
      principal_id: job.principal_id,
      entity_id: job.entity_id,
      organization_id: job.organization_id,
      entity_type: job.entity_type
    }).toEqual({
      database_id,
      actor_id,
      principal_id,
      entity_id,
      organization_id: 'c89b6b6b-ea18-4d98-bd5a-3f3c0c34f872',
      entity_type: 'org'
    });
  });

  it('run_scheduled_job rejects a malformed entity pair under strict attribution', async () => {
    const task_identifier = 'malformed_scheduled_job';
    await pg.any(`BEGIN`);
    try {
      await pg.any(`SELECT set_config('jwt.strict_attribution', 'true', true)`);
      const scheduled = await pg.one(
        `INSERT INTO app_jobs.scheduled_jobs (
           database_id, actor_id, entity_id, task_identifier, schedule_info
         ) VALUES ($1, $2, $3, $4, $5)
         RETURNING id`,
        [database_id, actor_id, entity_id, task_identifier, {}]
      );
      await expect(
        pg.any(`SELECT * FROM app_jobs.run_scheduled_job($1)`, [scheduled.id])
      ).rejects.toThrow('ENTITY_TYPE_REQUIRED');
    } finally {
      await pg.any(`ROLLBACK`);
    }
    const [{ count }] = await pg.any(
      `SELECT count(*)::int AS count FROM app_jobs.jobs
       WHERE task_identifier = $1`,
      [task_identifier]
    );
    expect(count).toBe(0);
  });
});