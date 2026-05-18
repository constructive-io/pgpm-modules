jest.setTimeout(30000);

import { getConnections, PgTestClient } from 'pgsql-test';
import { ObjectTreeHelper, createObjectTreeHelper, VDOMNode, CommitInfo } from '../../test-utils';

const scope_id = 'd0f7ab73-356f-4aac-b9cb-d1a4274906d6';
const store_id = 'c3d4e5f6-a7b8-9012-cdef-123456789012';

let pg: PgTestClient;
let teardown: () => Promise<void>;

beforeAll(async () => {
  ({ pg, teardown } = await getConnections());
});

afterAll(async () => {
  try {
    await teardown();
  } catch (e) {
    // console.log(e);
  }
});

beforeEach(async () => {
  await pg.beforeEach();
});

afterEach(async () => {
  await pg.afterEach();
});

/**
 * Format VDOM with type first, then key, props, children
 * This ensures consistent snapshot output with type as the first property
 */
function formatVDOM(node: VDOMNode): string {
  const sortKeys = (obj: Record<string, unknown>): Record<string, unknown> => {
    const result: Record<string, unknown> = {};
    const keys = Object.keys(obj).sort();
    for (const key of keys) {
      const value = obj[key];
      if (typeof value === 'object' && value !== null && !Array.isArray(value)) {
        result[key] = sortKeys(value as Record<string, unknown>);
      } else {
        result[key] = value;
      }
    }
    return result;
  };

  const transform = (n: VDOMNode): Record<string, unknown> => {
    const result: Record<string, unknown> = {
      type: n.type
    };
    if ('key' in n && n.key !== undefined) {
      result.key = n.key;
    }
    result.props = sortKeys(n.props);
    result.children = n.children.map(transform);
    return result;
  };

  return JSON.stringify(transform(node), null, 2);
}

/**
 * Format commit history for snapshot
 * Excludes dates and IDs since they change between runs
 * Sorts by message to ensure deterministic output
 */
function formatCommitHistory(commits: CommitInfo[]): string {
  const formatted = commits.map(c => ({
    message: c.message,
    hasParent: c.parent_ids.length > 0
  }));
  // Sort by message for deterministic snapshot output
  formatted.sort((a, b) => a.message.localeCompare(b.message));
  return JSON.stringify(formatted, null, 2);
}

describe('Object Tree Time Travel', () => {
  let helper: ObjectTreeHelper;

  beforeEach(async () => {
    helper = await createObjectTreeHelper(pg, { scope_id, store_id });
  });

  it('demonstrates time travel through 3 periods of page evolution', async () => {
    // ============================================
    // PERIOD 1: Initial page with just a header
    // ============================================
    await helper.insertNode(['page'], {
      type: 'Page',
      title: 'My App'
    });
    await helper.setLastCommitMessage('Period 1: Create initial page');

    await helper.insertNode(['page', 'header'], {
      type: 'Header',
      className: 'bg-white shadow'
    });
    await helper.setLastCommitMessage('Period 1: Add header');

    await helper.insertNode(['page', 'header', 'logo'], {
      type: 'Logo',
      src: '/logo.svg',
      alt: 'My App'
    });
    await helper.setLastCommitMessage('Period 1: Add logo to header');

    // Save Period 1 commit ID
    const period1CommitId = await helper.getCurrentCommitId();

    // ============================================
    // PERIOD 2: Add hero section
    // ============================================
    await helper.insertNode(['page', 'hero'], {
      type: 'Section',
      className: 'bg-gradient-to-r from-blue-500 to-purple-600'
    });
    await helper.setLastCommitMessage('Period 2: Add hero section');

    await helper.insertNode(['page', 'hero', 'title'], {
      type: 'Heading',
      level: 1,
      text: 'Welcome to My App',
      className: 'text-4xl font-bold text-white'
    });
    await helper.setLastCommitMessage('Period 2: Add hero title');

    await helper.insertNode(['page', 'hero', 'cta'], {
      type: 'Button',
      text: 'Get Started',
      className: 'bg-white text-blue-600 px-6 py-3 rounded-lg'
    });
    await helper.setLastCommitMessage('Period 2: Add CTA button');

    // Save Period 2 commit ID
    const period2CommitId = await helper.getCurrentCommitId();

    // ============================================
    // PERIOD 3: Add features section
    // ============================================
    await helper.insertNode(['page', 'features'], {
      type: 'Section',
      className: 'py-16 bg-gray-50'
    });
    await helper.setLastCommitMessage('Period 3: Add features section');

    await helper.insertNode(['page', 'features', 'grid'], {
      type: 'Grid',
      columns: 3,
      gap: 8
    });
    await helper.setLastCommitMessage('Period 3: Add features grid');

    await helper.insertNode(['page', 'features', 'grid', 'feature1'], {
      type: 'FeatureCard',
      icon: 'rocket',
      title: 'Fast',
      description: 'Lightning fast performance'
    });
    await helper.setLastCommitMessage('Period 3: Add first feature');

    await helper.insertNode(['page', 'features', 'grid', 'feature2'], {
      type: 'FeatureCard',
      icon: 'shield',
      title: 'Secure',
      description: 'Enterprise-grade security'
    });
    await helper.setLastCommitMessage('Period 3: Add second feature');

    await helper.insertNode(['page', 'features', 'grid', 'feature3'], {
      type: 'FeatureCard',
      icon: 'heart',
      title: 'Loved',
      description: 'Trusted by thousands'
    });
    await helper.setLastCommitMessage('Period 3: Add third feature');

    // Save Period 3 commit ID (current)
    const period3CommitId = await helper.getCurrentCommitId();

    // ============================================
    // TIME TRAVEL: View each period's state
    // ============================================

    // Get commit history
    const history = await helper.getCommitHistory();
    expect(formatCommitHistory(history)).toMatchSnapshot('commit-history');

    // Time travel to Period 1 (just header with logo)
    const period1VDOM = await helper.getVDOMAtCommit(period1CommitId);
    expect(formatVDOM(period1VDOM)).toMatchSnapshot('period-1-header-only');

    // Time travel to Period 2 (header + hero)
    const period2VDOM = await helper.getVDOMAtCommit(period2CommitId);
    expect(formatVDOM(period2VDOM)).toMatchSnapshot('period-2-with-hero');

    // Time travel to Period 3 (header + hero + features) - current state
    const period3VDOM = await helper.getVDOMAtCommit(period3CommitId);
    expect(formatVDOM(period3VDOM)).toMatchSnapshot('period-3-with-features');

    // Verify current state matches Period 3
    const currentVDOM = await helper.getVDOM();
    expect(formatVDOM(currentVDOM)).toEqual(formatVDOM(period3VDOM));
  });

  it('shows how content changes are tracked through commits', async () => {
    // Create a simple counter component
    await helper.insertNode(['app', 'counter'], {
      type: 'Counter',
      value: 0,
      label: 'Click count'
    });
    await helper.setLastCommitMessage('Initialize counter at 0');
    const commit0 = await helper.getCurrentCommitId();

    // Simulate incrementing the counter
    await helper.setProps(['app', 'counter'], {
      type: 'Counter',
      value: 1,
      label: 'Click count'
    });
    await helper.setLastCommitMessage('Increment counter to 1');
    const commit1 = await helper.getCurrentCommitId();

    await helper.setProps(['app', 'counter'], {
      type: 'Counter',
      value: 5,
      label: 'Click count'
    });
    await helper.setLastCommitMessage('Increment counter to 5');
    const commit5 = await helper.getCurrentCommitId();

    await helper.setProps(['app', 'counter'], {
      type: 'Counter',
      value: 10,
      label: 'Click count'
    });
    await helper.setLastCommitMessage('Increment counter to 10');

    // Time travel to see counter at different values
    const state0 = await helper.getVDOMAtCommit(commit0);
    const state1 = await helper.getVDOMAtCommit(commit1);
    const state5 = await helper.getVDOMAtCommit(commit5);
    const stateCurrent = await helper.getVDOM();

    // Extract counter values from each state
    // The structure is: Fragment -> app -> counter
    const getValue = (vdom: VDOMNode): number => {
      const app = vdom.children.find(c => c.key === 'app');
      const counter = app?.children.find(c => c.key === 'counter');
      return (counter?.props?.value as number) ?? -1;
    };

    expect(getValue(state0)).toBe(0);
    expect(getValue(state1)).toBe(1);
    expect(getValue(state5)).toBe(5);
    expect(getValue(stateCurrent)).toBe(10);

    // Snapshot the commit history
    const history = await helper.getCommitHistory();
    expect(formatCommitHistory(history)).toMatchSnapshot('counter-history');
  });
});
