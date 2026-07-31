jest.setTimeout(30000);

import { getConnections, PgTestClient } from 'constructive-test';
import { FlowGraphHelper, createFlowGraphHelper, VDOMNode } from '../../test-utils';

/**
 * Transform VDOM tree (storage format) into RuntimeGraph (renderer format)
 * 
 * Storage model:
 * - Boundary nodes (graphInput, graphOutput, graphProp) use normal keys (e.g., 'input_a', 'output_result')
 * - The port/prop name is stored as a property: { name: 'portName', value: 'a' }
 * - The node's `type` property identifies it as a boundary node
 * 
 * RuntimeGraph types (for reference):
 * - PortDef: { name: string, type?: string }
 * - PropDef: { name: string, type?: string, default?: unknown }
 * - Edge: { src: { node: string, port: string }, dst: { node: string, port: string } }
 * - RuntimeNode: { name, type, meta?, props?, nodes?, edges?, inputs?, outputs?, properties? }
 * - RuntimeGraph: { name?, nodes, edges, inputs?, outputs?, properties? }
 */
function transformToRuntimeGraph(vdom: VDOMNode) {
  const graph = {
    name: vdom.props.name,
    nodes: [] as any[],
    edges: [] as any[],
    inputs: [] as any[],
    outputs: [] as any[],
    properties: [] as any[]
  };

  // Process children to extract nodes and edges
  for (const child of vdom.children) {
    if (child.key === 'nodes') {
      // Process nodes container
      for (const nodeChild of child.children) {
        const node = transformNode(nodeChild);
        
        // Check if this is a boundary node by its type
        const nodeType = nodeChild.type;
        if (nodeType === 'graphInput') {
          graph.inputs.push({
            name: getPortName(nodeChild.props),
            type: getDataType(nodeChild.props)
          });
        } else if (nodeType === 'graphOutput') {
          graph.outputs.push({
            name: getPortName(nodeChild.props),
            type: getDataType(nodeChild.props)
          });
        } else if (nodeType === 'graphProp') {
          graph.properties.push({
            name: getPropName(nodeChild.props),
            type: getDataType(nodeChild.props),
            default: getPropDefault(nodeChild.props)
          });
        }
        
        graph.nodes.push(node);
      }
    } else if (child.key === 'edges') {
      // Process edges container
      for (const edgeChild of child.children) {
        graph.edges.push({
          src: edgeChild.props.src,
          dst: edgeChild.props.dst
        });
      }
    }
  }

  return graph;
}

/**
 * Transform a VDOM node into a RuntimeNode
 * Recursively handles subnets with their own nodes/edges
 */
function transformNode(vdom: VDOMNode) {
  const node: any = {
    name: vdom.key,
    type: vdom.type,
    meta: vdom.props.meta,
    props: vdom.props.props
  };

  // Check if this node has children (subnet)
  const nodesChild = vdom.children.find(c => c.key === 'nodes');
  const edgesChild = vdom.children.find(c => c.key === 'edges');

  if (nodesChild || edgesChild) {
    node.nodes = [];
    node.edges = [];
    node.inputs = [];
    node.outputs = [];
    node.properties = [];

    // Process subnet nodes
    if (nodesChild) {
      for (const childNode of nodesChild.children) {
        const subNode = transformNode(childNode);
        
        // Derive ports from boundary nodes by their type
        const childType = childNode.type;
        if (childType === 'graphInput') {
          node.inputs.push({
            name: getPortName(childNode.props),
            type: getDataType(childNode.props)
          });
        } else if (childType === 'graphOutput') {
          node.outputs.push({
            name: getPortName(childNode.props),
            type: getDataType(childNode.props)
          });
        } else if (childType === 'graphProp') {
          node.properties.push({
            name: getPropName(childNode.props),
            type: getDataType(childNode.props),
            default: getPropDefault(childNode.props)
          });
        }
        
        node.nodes.push(subNode);
      }
    }

    // Process subnet edges
    if (edgesChild) {
      for (const edgeChild of edgesChild.children) {
        node.edges.push({
          src: edgeChild.props.src,
          dst: edgeChild.props.dst
        });
      }
    }
  }

  return node;
}

function getPortName(props: Record<string, unknown>) {
  const propsArray = props.props as any[] | undefined;
  if (propsArray) {
    const portNameEntry = propsArray.find(p => p.name === 'portName');
    return portNameEntry?.value;
  }
  return undefined;
}

function getPropName(props: Record<string, unknown>) {
  const propsArray = props.props as any[] | undefined;
  if (propsArray) {
    const propNameEntry = propsArray.find(p => p.name === 'propName');
    return propNameEntry?.value;
  }
  return undefined;
}

function getDataType(props: Record<string, unknown>) {
  const propsArray = props.props as any[] | undefined;
  if (propsArray) {
    const typeEntry = propsArray.find(p => p.name === 'dataType');
    return typeEntry?.value;
  }
  return undefined;
}

function getPropDefault(props: Record<string, unknown>) {
  const propsArray = props.props as any[] | undefined;
  if (propsArray) {
    const defaultEntry = propsArray.find(p => p.name === 'default');
    return defaultEntry?.value;
  }
  return undefined;
}

/**
 * Format RuntimeGraph for snapshot with consistent key ordering and array sorting
 */
function formatRuntimeGraph(graph: any) {
  const sortKeys = (obj: Record<string, unknown>): Record<string, unknown> => {
    const result: Record<string, unknown> = {};
    const keys = Object.keys(obj).sort();
    for (const key of keys) {
      const value = obj[key];
      if (Array.isArray(value)) {
        // Sort arrays of objects by 'name' property if they have one
        let sortedArray = value.map(item => 
          typeof item === 'object' && item !== null 
            ? sortKeys(item as Record<string, unknown>) 
            : item
        );
        // Sort by 'name' property if all items have one
        if (sortedArray.length > 0 && sortedArray.every(item => typeof item === 'object' && item !== null && 'name' in item)) {
          sortedArray = sortedArray.sort((a: any, b: any) => {
            const nameA = String(a.name || '');
            const nameB = String(b.name || '');
            return nameA.localeCompare(nameB);
          });
        }
        result[key] = sortedArray;
      } else if (typeof value === 'object' && value !== null) {
        result[key] = sortKeys(value as Record<string, unknown>);
      } else if (value !== undefined) {
        result[key] = value;
      }
    }
    return result;
  };

  return JSON.stringify(sortKeys(graph), null, 2);
}

const scope_id = 'f1a2b3c4-d5e6-7890-abcd-ef1234567890';
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

describe('flow-graph', () => {
  let helper: FlowGraphHelper;

  beforeEach(async () => {
    helper = await createFlowGraphHelper(pg, { scope_id, store_id });
  });

  it('creates a simple math graph with derived ports', async () => {
    // Create boundary input nodes - these define the graph's interface
    await helper.insertInput('input_a', 'a', 'number', { x: 0, y: 0 });
    await helper.insertInput('input_b', 'b', 'number', { x: 0, y: 100 });

    // Create the processing node
    await helper.insertNode('add1', 'math/add', { x: 200, y: 50 });

    // Create boundary output node
    await helper.insertOutput('output_result', 'result', 'number', { x: 400, y: 50 });

    // Create edges
    await helper.insertEdge(
      { node: 'input_a', port: 'value' },
      { node: 'add1', port: 'a' }
    );
    await helper.insertEdge(
      { node: 'input_b', port: 'value' },
      { node: 'add1', port: 'b' }
    );
    await helper.insertEdge(
      { node: 'add1', port: 'result' },
      { node: 'output_result', port: 'value' }
    );

    // Set graph metadata
    await helper.setGraphMeta({ type: 'Graph', name: 'simple-add' });

    // Get VDOM and transform to RuntimeGraph
    const vdom = await helper.getVDOM();
    const runtimeGraph = transformToRuntimeGraph(vdom);
    
    // Snapshot the renderer-friendly format with derived ports
    expect(formatRuntimeGraph(runtimeGraph)).toMatchSnapshot();
  });

  it('creates a nested subgraph with boundary nodes and properties', async () => {
    // Root-level input and property
    await helper.insertInput('input_data', 'data', 'number', { x: 0, y: 100 });
    await helper.insertProp('prop_scale', 'scale', 'number', 1.0, { x: 0, y: 0 });

    // Create a "processor" subnet with its own boundary nodes
    await helper.insertSubnet('processor', { x: 200, y: 100 });

    // Use scope() to work within the subnet
    const processor = helper.scope('processor');
    await processor.insertInput('input_x', 'x', 'number', { x: 0, y: 0 });
    await processor.insertProp('prop_mode', 'mode', 'string', 'normal', { x: 0, y: 50 });
    await processor.insertNode('normalize', 'math/normalize', { x: 100, y: 0 });
    await processor.insertNode('transform', 'math/transform', { x: 200, y: 0 }, [
      { name: 'mode', value: 'prop_mode', ref: true }
    ]);
    await processor.insertOutput('output_result', 'result', 'number', { x: 300, y: 0 });

    // Subnet's internal edges
    await processor.insertEdge(
      { node: 'input_x', port: 'value' },
      { node: 'normalize', port: 'input' }
    );
    await processor.insertEdge(
      { node: 'normalize', port: 'output' },
      { node: 'transform', port: 'input' }
    );
    await processor.insertEdge(
      { node: 'transform', port: 'output' },
      { node: 'output_result', port: 'value' }
    );

    // Root-level output
    await helper.insertOutput('output_processed', 'processed', 'number', { x: 400, y: 100 });

    // Root-level edges
    await helper.insertEdge(
      { node: 'input_data', port: 'value' },
      { node: 'processor', port: 'x' }
    );
    await helper.insertEdge(
      { node: 'processor', port: 'result' },
      { node: 'output_processed', port: 'value' }
    );

    // Set graph metadata
    await helper.setGraphMeta({ type: 'Graph', name: 'nested-processor' });

    const vdom = await helper.getVDOM();
    const runtimeGraph = transformToRuntimeGraph(vdom);
    expect(formatRuntimeGraph(runtimeGraph)).toMatchSnapshot();
  });

  it('creates a deeply nested subgraph (subnet within subnet)', async () => {
    // Root input
    await helper.insertInput('input_value', 'value', 'number', { x: 0, y: 50 });

    // Outer subnet: "pipeline"
    await helper.insertSubnet('pipeline', { x: 150, y: 50 });

    // Pipeline's boundary nodes using scope()
    const pipeline = helper.scope('pipeline');
    await pipeline.insertInput('input_input', 'input', 'number', { x: 0, y: 0 });
    await pipeline.insertProp('prop_iterations', 'iterations', 'number', 3, { x: 0, y: 50 });

    // Inner subnet: "stage" (nested inside pipeline)
    await pipeline.insertSubnet('stage', { x: 100, y: 0 });

    // Stage's boundary nodes using nested scope()
    const stage = pipeline.scope('stage');
    await stage.insertInput('input_data', 'data', 'number', { x: 0, y: 0 });
    await stage.insertProp('prop_factor', 'factor', 'number', 2, { x: 0, y: 50 });
    await stage.insertNode('multiply', 'math/multiply', { x: 100, y: 0 }, [
      { name: 'b', value: 'prop_factor', ref: true }
    ]);
    await stage.insertOutput('output_result', 'result', 'number', { x: 200, y: 0 });

    // Stage's internal edges
    await stage.insertEdge(
      { node: 'input_data', port: 'value' },
      { node: 'multiply', port: 'a' }
    );
    await stage.insertEdge(
      { node: 'multiply', port: 'result' },
      { node: 'output_result', port: 'value' }
    );

    // Pipeline's output
    await pipeline.insertOutput('output_output', 'output', 'number', { x: 200, y: 0 });

    // Pipeline's edges (connecting to nested stage)
    await pipeline.insertEdge(
      { node: 'input_input', port: 'value' },
      { node: 'stage', port: 'data' }
    );
    await pipeline.insertEdge(
      { node: 'stage', port: 'result' },
      { node: 'output_output', port: 'value' }
    );

    // Root output
    await helper.insertOutput('output_final', 'final', 'number', { x: 300, y: 50 });

    // Root edges
    await helper.insertEdge(
      { node: 'input_value', port: 'value' },
      { node: 'pipeline', port: 'input' }
    );
    await helper.insertEdge(
      { node: 'pipeline', port: 'output' },
      { node: 'output_final', port: 'value' }
    );

    await helper.setGraphMeta({ type: 'Graph', name: 'deeply-nested-pipeline' });

    const vdom = await helper.getVDOM();
    const runtimeGraph = transformToRuntimeGraph(vdom);
    expect(formatRuntimeGraph(runtimeGraph)).toMatchSnapshot();
  });

  it('creates a graph with multiple subnets and shared properties', async () => {
    // Root-level shared property and inputs
    await helper.insertProp('prop_precision', 'precision', 'number', 2, { x: 200, y: 0 });
    await helper.insertInput('input_x', 'x', 'number', { x: 0, y: 50 });
    await helper.insertInput('input_y', 'y', 'number', { x: 0, y: 150 });

    // First subnet: "adder"
    await helper.insertSubnet('adder', { x: 150, y: 50 });

    const adder = helper.scope('adder');
    await adder.insertInput('input_a', 'a', 'number', { x: 0, y: 0 });
    await adder.insertInput('input_b', 'b', 'number', { x: 0, y: 50 });
    await adder.insertNode('add', 'math/add', { x: 100, y: 25 });
    await adder.insertOutput('output_sum', 'sum', 'number', { x: 200, y: 25 });

    await adder.insertEdge(
      { node: 'input_a', port: 'value' },
      { node: 'add', port: 'a' }
    );
    await adder.insertEdge(
      { node: 'input_b', port: 'value' },
      { node: 'add', port: 'b' }
    );
    await adder.insertEdge(
      { node: 'add', port: 'result' },
      { node: 'output_sum', port: 'value' }
    );

    // Second subnet: "rounder"
    await helper.insertSubnet('rounder', { x: 300, y: 50 });

    const rounder = helper.scope('rounder');
    await rounder.insertInput('input_value', 'value', 'number', { x: 0, y: 0 });
    await rounder.insertProp('prop_decimals', 'decimals', 'number', 0, { x: 0, y: 50 });
    await rounder.insertNode('round', 'math/round', { x: 100, y: 0 }, [
      { name: 'decimals', value: 'prop_decimals', ref: true }
    ]);
    await rounder.insertOutput('output_rounded', 'rounded', 'number', { x: 200, y: 0 });

    await rounder.insertEdge(
      { node: 'input_value', port: 'value' },
      { node: 'round', port: 'input' }
    );
    await rounder.insertEdge(
      { node: 'round', port: 'output' },
      { node: 'output_rounded', port: 'value' }
    );

    // Root output
    await helper.insertOutput('output_result', 'result', 'number', { x: 450, y: 50 });

    // Root edges - chain: inputs -> adder -> rounder -> output
    await helper.insertEdge(
      { node: 'input_x', port: 'value' },
      { node: 'adder', port: 'a' }
    );
    await helper.insertEdge(
      { node: 'input_y', port: 'value' },
      { node: 'adder', port: 'b' }
    );
    await helper.insertEdge(
      { node: 'adder', port: 'sum' },
      { node: 'rounder', port: 'value' }
    );
    await helper.insertEdge(
      { node: 'rounder', port: 'rounded' },
      { node: 'output_result', port: 'value' }
    );

    await helper.setGraphMeta({ type: 'Graph', name: 'multi-subnet-pipeline' });

    const vdom = await helper.getVDOM();
    const runtimeGraph = transformToRuntimeGraph(vdom);
    expect(formatRuntimeGraph(runtimeGraph)).toMatchSnapshot();
  });
});
