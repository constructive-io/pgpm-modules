import { getConnections } from 'pgsql-test';
import { wrapConn } from './utils';

let db: any, pg: any, teardown: (() => Promise<void>) | undefined, app: any;
const objs: Record<string, any> = {};

describe('scheduled jobs', () => {
  beforeAll(async () => {
    try {
      ({ db, pg, teardown } = await getConnections());
      const [{ u }] = await db.any('select current_user as u');
      await pg.any(`grant usage on schema app_jobs to "${u}"`);
      await pg.any(`grant all privileges on all tables in schema app_jobs to "${u}"`);
      await pg.any(`grant usage, select on all sequences in schema app_jobs to "${u}"`);
      app = wrapConn(db, 'app_jobs');
    } catch (e) {
    }
  });

  beforeEach(async () => {
    if (db && typeof db.beforeEach === 'function') {
      await db.beforeEach();
    }
  });

  afterEach(async () => {
    if (db && typeof db.afterEach === 'function') {
      await db.afterEach();
    }
  });

  afterAll(async () => {
    if (typeof teardown === 'function') {
      await teardown();
    }
  });

  it('schedule jobs by cron', async () => {
    objs.scheduled1 = await app.insertOne(
      'scheduled_jobs',
      {
        task_identifier: 'my_job',
        schedule_info: {
          hour: Array.from({ length: 23 }, (_: unknown, i: number) => i),
          minute: [0, 15, 30, 45],
          dayOfWeek: Array.from({ length: 6 }, (_: unknown, i: number) => i)
        }
      },
      {
        schedule_info: 'json'
      }
    );
  });

  it('schedule jobs by rule', async () => {
    const start = new Date(Date.now() + 10000);
    const end = new Date(start.getTime() + 180000);
    objs.scheduled2 = await app.insertOne(
      'scheduled_jobs',
      {
        task_identifier: 'my_job',
        payload: {
          just: 'run it'
        },
        schedule_info: {
          start,
          end,
          rule: '*/1 * * * *'
        }
      },
      {
        schedule_info: 'json'
      }
    );
  });

  it('schedule jobs', async () => {
    const [result] = await app.callAny('run_scheduled_job', {
      id: objs.scheduled2.id
    });
    const { queue_name, run_at, created_at, updated_at, ...obj } = result;
    expect(obj).toMatchSnapshot();
  });

  it('schedule jobs with keys', async () => {
    const start = new Date(Date.now() + 10000);
    const end = new Date(start.getTime() + 180000);

    const [result] = await app.callAny(
      'add_scheduled_job',
      {
        identifier: 'my_job',
        payload: {
          just: 'run it'
        },
        schedule_info: {
          start,
          end,
          rule: '*/1 * * * *'
        },
        job_key: 'new_key',
        queue_name: null,
        max_attempts: 25,
        priority: 0
      },
      {
        identifier: 'text',
        payload: 'json',
        schedule_info: 'json',
        job_key: 'text',
        queue_name: 'text',
        max_attempts: 'integer',
        priority: 'integer'
      }
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

    const [result2] = await app.callAny(
      'add_scheduled_job',
      {
        identifier: 'my_job',
        payload: {
          just: 'run it'
        },
        schedule_info: {
          start,
          end,
          rule: '*/1 * * * *'
        },
        job_key: 'new_key',
        queue_name: null,
        max_attempts: 25,
        priority: 0
      },
      {
        identifier: 'text',
        payload: 'json',
        schedule_info: 'json',
        job_key: 'text',
        queue_name: 'text',
        max_attempts: 'integer',
        priority: 'integer'
      }
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

    console.log(obj);
    console.log(obj2);
  });
});
