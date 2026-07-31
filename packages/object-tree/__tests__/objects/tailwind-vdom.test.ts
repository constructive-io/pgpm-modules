jest.setTimeout(30000);

import { getConnections, PgTestClient } from 'constructive-test';
import { ObjectTreeHelper, createObjectTreeHelper, VDOMNode } from '../../test-utils';

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

const scope_id = 'd0f7ab73-356f-4aac-b9cb-d1a4274906d6';
const store_id = 'b2c3d4e5-f6a7-8901-bcde-f12345678901';

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

describe('Tailwind VDOM Home Page', () => {
  let helper: ObjectTreeHelper;

  beforeEach(async () => {
    helper = await createObjectTreeHelper(pg, { scope_id, store_id });
  });

  it('creates a home page with hero, features, and newsletter sections', async () => {
    // Hero section with CTA button
    await helper.insertNode(['home', 'hero', 'container'], {
      type: 'Container',
      className: 'max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-24'
    });

    await helper.insertNode(['home', 'hero', 'container', 'heading'], {
      type: 'Heading',
      className: 'text-5xl font-bold tracking-tight text-gray-900 sm:text-6xl',
      level: 1,
      text: 'Build something amazing'
    });

    await helper.insertNode(['home', 'hero', 'container', 'subheading'], {
      type: 'Text',
      className: 'mt-6 text-lg leading-8 text-gray-600 max-w-2xl',
      text: 'Create stunning web experiences with our modern component system.'
    });

    await helper.insertNode(['home', 'hero', 'container', 'cta'], {
      type: 'Button',
      className: 'mt-10 rounded-md bg-indigo-600 px-6 py-3 text-lg font-semibold text-white shadow-sm hover:bg-indigo-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600',
      text: 'Get Started',
      action: {
        type: 'click',
        handler: '/api/actions/get-started',
        params: { source: 'hero' }
      }
    });

    // Set hero section props
    await helper.setProps(['home', 'hero'], {
      type: 'Section',
      className: 'relative isolate bg-white'
    });

    // Features section
    await helper.insertNode(['home', 'features', 'grid'], {
      type: 'Grid',
      className: 'mx-auto max-w-7xl px-6 lg:px-8 py-24 grid grid-cols-1 gap-8 sm:grid-cols-2 lg:grid-cols-3'
    });

    await helper.insertNode(['home', 'features', 'grid', 'feature1'], {
      type: 'FeatureCard',
      className: 'relative rounded-2xl border border-gray-200 p-8 shadow-sm hover:shadow-md transition-shadow',
      icon: 'lightning-bolt',
      title: 'Lightning Fast',
      description: 'Optimized for performance with minimal bundle size.'
    });

    await helper.insertNode(['home', 'features', 'grid', 'feature2'], {
      type: 'FeatureCard',
      className: 'relative rounded-2xl border border-gray-200 p-8 shadow-sm hover:shadow-md transition-shadow',
      icon: 'code',
      title: 'Developer Experience',
      description: 'Intuitive APIs and comprehensive documentation.'
    });

    await helper.insertNode(['home', 'features', 'grid', 'feature3'], {
      type: 'FeatureCard',
      className: 'relative rounded-2xl border border-gray-200 p-8 shadow-sm hover:shadow-md transition-shadow',
      icon: 'shield-check',
      title: 'Type Safe',
      description: 'Full TypeScript support out of the box.'
    });

    await helper.setProps(['home', 'features'], {
      type: 'Section',
      className: 'bg-gray-50'
    });

    // Newsletter section with form
    await helper.insertNode(['home', 'newsletter', 'container'], {
      type: 'Container',
      className: 'mx-auto max-w-7xl px-6 lg:px-8 py-16 sm:py-24'
    });

    await helper.insertNode(['home', 'newsletter', 'container', 'content'], {
      type: 'Container',
      className: 'mx-auto max-w-2xl text-center'
    });

    await helper.insertNode(['home', 'newsletter', 'container', 'content', 'heading'], {
      type: 'Heading',
      className: 'text-3xl font-bold tracking-tight text-gray-900 sm:text-4xl',
      level: 2,
      text: 'Stay in the loop'
    });

    await helper.insertNode(['home', 'newsletter', 'container', 'content', 'description'], {
      type: 'Text',
      className: 'mt-4 text-lg leading-8 text-gray-600',
      text: 'Get notified about new features and updates. No spam, ever.'
    });

    await helper.insertNode(['home', 'newsletter', 'container', 'form'], {
      type: 'Form',
      className: 'mt-10 flex max-w-md mx-auto gap-x-4',
      action: {
        type: 'submit',
        handler: '/api/actions/newsletter-signup',
        params: { source: 'home-footer' }
      }
    });

    await helper.insertNode(['home', 'newsletter', 'container', 'form', 'email'], {
      type: 'Input',
      className: 'min-w-0 flex-auto rounded-md border-0 bg-white/5 px-3.5 py-2 text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 placeholder:text-gray-400 focus:ring-2 focus:ring-inset focus:ring-indigo-600 sm:text-sm sm:leading-6',
      inputType: 'email',
      name: 'email',
      placeholder: 'Enter your email',
      required: true
    });

    await helper.insertNode(['home', 'newsletter', 'container', 'form', 'submit'], {
      type: 'Button',
      className: 'flex-none rounded-md bg-indigo-600 px-3.5 py-2.5 text-sm font-semibold text-white shadow-sm hover:bg-indigo-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600',
      buttonType: 'submit',
      text: 'Subscribe'
    });

    await helper.setProps(['home', 'newsletter'], {
      type: 'Section',
      className: 'bg-white'
    });

    // Set home page props
    await helper.setProps(['home'], {
      type: 'Page',
      className: 'min-h-screen',
      title: 'Home',
      meta: {
        title: 'Welcome | My App',
        description: 'Build something amazing with our modern component system.'
      }
    });

    // Get the VDOM tree
    const vdom = await helper.getVDOM();
    expect(formatVDOM(vdom)).toMatchSnapshot();
  });

  it('creates a newsletter widget with action bindings', async () => {
    await helper.insertNode(['widget', 'newsletter', 'container'], {
      type: 'Container',
      className: 'relative isolate overflow-hidden bg-indigo-600 py-16 sm:py-24 lg:py-32'
    });

    await helper.insertNode(['widget', 'newsletter', 'container', 'content'], {
      type: 'Container',
      className: 'mx-auto max-w-7xl px-6 lg:px-8'
    });

    await helper.insertNode(['widget', 'newsletter', 'container', 'content', 'heading'], {
      type: 'Heading',
      className: 'mx-auto max-w-2xl text-3xl font-bold tracking-tight text-white sm:text-4xl',
      level: 2,
      text: 'Want product news and updates?'
    });

    await helper.insertNode(['widget', 'newsletter', 'container', 'content', 'description'], {
      type: 'Text',
      className: 'mx-auto mt-2 max-w-xl text-lg leading-8 text-indigo-200',
      text: 'Sign up for our newsletter.'
    });

    await helper.insertNode(['widget', 'newsletter', 'container', 'content', 'form'], {
      type: 'Form',
      className: 'mx-auto mt-10 flex max-w-md gap-x-4',
      action: {
        type: 'submit',
        handler: '/api/actions/newsletter-signup',
        params: { source: 'widget' }
      }
    });

    await helper.insertNode(['widget', 'newsletter', 'container', 'content', 'form', 'emailInput'], {
      type: 'Input',
      className: 'min-w-0 flex-auto rounded-md border-0 bg-white/5 px-3.5 py-2 text-white shadow-sm ring-1 ring-inset ring-white/10 placeholder:text-indigo-200 focus:ring-2 focus:ring-inset focus:ring-white sm:text-sm sm:leading-6',
      inputType: 'email',
      name: 'email',
      placeholder: 'Enter your email',
      required: true
    });

    await helper.insertNode(['widget', 'newsletter', 'container', 'content', 'form', 'submitBtn'], {
      type: 'Button',
      className: 'mt-4 flex w-full items-center justify-center rounded-md bg-white px-3 py-2 text-sm font-semibold text-indigo-600 shadow-sm hover:bg-indigo-50 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-white sm:mt-0 sm:ml-4 sm:w-auto sm:flex-none',
      buttonType: 'submit',
      text: 'Notify me',
      loadingText: 'Subscribing...',
      action: {
        type: 'click',
        handler: '/api/actions/track-click',
        params: { element: 'newsletter-submit' }
      }
    });

    await helper.setProps(['widget', 'newsletter'], {
      type: 'Section',
      className: 'newsletter-widget'
    });

    await helper.setProps(['widget'], {
      type: 'Widget',
      name: 'newsletter-cta'
    });

    const vdom = await helper.getVDOM();
    expect(formatVDOM(vdom)).toMatchSnapshot();
  });
});
