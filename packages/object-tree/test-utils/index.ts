import { PgTestClient } from 'constructive-test';

/**
 * VDOM node structure for tree representation
 */
export interface VDOMNode {
  type: string;
  key: string;
  props: Record<string, unknown>;
  children: VDOMNode[];
}

/**
 * Raw object from the database
 */
interface RawObject {
  id: string;
  scope_id: string;
  data: Record<string, unknown> | null;
  kids: string[];
  ktree: string[];
  frzn: boolean;
  created_at: string;
}

/**
 * Options for creating an ObjectTreeHelper
 */
export interface ObjectTreeHelperOptions {
  scope_id: string;
  store_id: string;
  refname?: string;
}

/**
 * Commit information for time travel
 */
export interface CommitInfo {
  id: string;
  message: string;
  tree_id: string;
  parent_ids: string[];
  date: Date;
}

/**
 * Helper class for object-tree operations in tests
 * Provides a clean API for insertNode, removeNode, setProps
 */
export class ObjectTreeHelper {
  private pg: PgTestClient;
  private scope_id: string;
  private store_id: string;
  private refname: string;
  private initialized: boolean = false;

  constructor(pg: PgTestClient, options: ObjectTreeHelperOptions) {
    this.pg = pg;
    this.scope_id = options.scope_id;
    this.store_id = options.store_id;
    this.refname = options.refname ?? 'main';
  }

  /**
   * Initialize an empty repository (must be called before other operations)
   */
  async init(): Promise<void> {
    await this.pg.any(
      `SELECT * FROM object_tree_public.init_empty_repo(
        s_id := $1::uuid,
        store_id := $2::uuid
      )`,
      [this.scope_id, this.store_id]
    );
    this.initialized = true;
  }

  /**
   * Insert a node at the given path with the provided data
   * The type property in data will become the node's type in VDOM output
   */
  async insertNode(path: string[], data: Record<string, unknown>): Promise<void> {
    if (!this.initialized) {
      await this.init();
    }
    await this.pg.any(
      `SELECT * FROM object_tree_public.set_and_commit(
        s_id := $1::uuid,
        store_id := $2::uuid,
        refname := $3::text,
        path := $4::text[],
        data := $5::jsonb,
        kids := $6::uuid[],
        ktree := $7::text[]
      )`,
      [this.scope_id, this.store_id, this.refname, path, data, [], []]
    );
  }

  /**
   * Set properties on an existing node at the given path
   */
  async setProps(path: string[], data: Record<string, unknown>): Promise<void> {
    if (!this.initialized) {
      await this.init();
    }
    await this.pg.any(
      `SELECT * FROM object_tree_public.set_props_and_commit(
        s_id := $1::uuid,
        store_id := $2::uuid,
        refname := $3::text,
        path := $4::text[],
        data := $5::jsonb
      )`,
      [this.scope_id, this.store_id, this.refname, path, data]
    );
  }

  /**
   * Remove a node at the given path
   * Note: This uses the lower-level remove_node_at_path and creates a commit
   */
  async removeNode(path: string[]): Promise<void> {
    if (!this.initialized) {
      await this.init();
    }
    
    // Get current ref and commit
    const [ref] = await this.pg.any<{ id: string; commit_id: string }>(
      `SELECT id, commit_id FROM object_tree_public.ref 
       WHERE scope_id = $1 AND store_id = $2 AND name = $3 
       LIMIT 1`,
      [this.scope_id, this.store_id, this.refname]
    );

    const [commit] = await this.pg.any<{ id: string; tree_id: string }>(
      `SELECT id, tree_id FROM object_tree_public.commit 
       WHERE id = $1 
       LIMIT 1`,
      [ref.commit_id]
    );

    // Remove the node and get new tree root
    const [result] = await this.pg.any<{ remove_node_at_path: string }>(
      `SELECT object_store_public.remove_node_at_path(
        s_id := $1::uuid,
        root := $2::uuid,
        path := $3::text[]
      )`,
      [this.scope_id, commit.tree_id, path]
    );

    // Create new commit with the updated tree
    const [newCommit] = await this.pg.any<{ id: string }>(
      `INSERT INTO object_tree_public.commit (scope_id, store_id, message, parent_ids, tree_id)
       VALUES ($1, $2, NOW(), ARRAY[$3]::uuid[], $4)
       RETURNING id`,
      [this.scope_id, this.store_id, commit.id, result.remove_node_at_path]
    );

    // Update ref to point to new commit
    await this.pg.any(
      `UPDATE object_tree_public.ref SET commit_id = $1 WHERE id = $2`,
      [newCommit.id, ref.id]
    );
  }

  /**
   * Get the current tree as a VDOM structure
   * Returns a nested tree with type, key, props, and children
   */
  async getVDOM(): Promise<VDOMNode> {
    const [ref] = await this.pg.any<{ commit_id: string }>(
      `SELECT commit_id FROM object_tree_public.ref 
       WHERE scope_id = $1 AND store_id = $2 AND name = $3 
       LIMIT 1`,
      [this.scope_id, this.store_id, this.refname]
    );

    const [commit] = await this.pg.any<{ tree_id: string }>(
      `SELECT tree_id FROM object_tree_public.commit 
       WHERE id = $1 
       LIMIT 1`,
      [ref.commit_id]
    );

    const objects = await this.pg.any<RawObject>(
      `SELECT * FROM object_store_public.get_all_objects_from_root($1::uuid, $2::uuid)`,
      [this.scope_id, commit.tree_id]
    );

    return this.buildVDOM(objects, commit.tree_id);
  }

  /**
   * Get the VDOM at a specific commit (time travel)
   * @param commitId - The commit ID to retrieve the tree from
   */
  async getVDOMAtCommit(commitId: string): Promise<VDOMNode> {
    const [commit] = await this.pg.any<{ tree_id: string }>(
      `SELECT tree_id FROM object_tree_public.commit 
       WHERE id = $1 AND scope_id = $2 AND store_id = $3
       LIMIT 1`,
      [commitId, this.scope_id, this.store_id]
    );

    if (!commit) {
      throw new Error(`Commit ${commitId} not found`);
    }

    const objects = await this.pg.any<RawObject>(
      `SELECT * FROM object_store_public.get_all_objects_from_root($1::uuid, $2::uuid)`,
      [this.scope_id, commit.tree_id]
    );

    return this.buildVDOM(objects, commit.tree_id);
  }

  /**
   * Get the commit history for the current store
   * Returns commits in reverse chronological order (newest first)
   */
  async getCommitHistory(): Promise<CommitInfo[]> {
    const commits = await this.pg.any<{
      id: string;
      message: string;
      tree_id: string;
      parent_ids: string[];
      date: Date;
    }>(
      `SELECT id, message, tree_id, parent_ids, date 
       FROM object_tree_public.commit 
       WHERE scope_id = $1 AND store_id = $2
       ORDER BY date DESC`,
      [this.scope_id, this.store_id]
    );

    return commits.map(c => ({
      id: c.id,
      message: c.message,
      tree_id: c.tree_id,
      parent_ids: c.parent_ids ?? [],
      date: c.date
    }));
  }

  /**
   * Set the message of the most recent commit
   * Useful for adding descriptive messages for time travel demonstration
   */
  async setLastCommitMessage(message: string): Promise<void> {
    const [ref] = await this.pg.any<{ commit_id: string }>(
      `SELECT commit_id FROM object_tree_public.ref 
       WHERE scope_id = $1 AND store_id = $2 AND name = $3 
       LIMIT 1`,
      [this.scope_id, this.store_id, this.refname]
    );

    await this.pg.any(
      `UPDATE object_tree_public.commit 
       SET message = $1 
       WHERE id = $2 AND scope_id = $3`,
      [message, ref.commit_id, this.scope_id]
    );
  }

  /**
   * Get the current commit ID
   */
  async getCurrentCommitId(): Promise<string> {
    const [ref] = await this.pg.any<{ commit_id: string }>(
      `SELECT commit_id FROM object_tree_public.ref 
       WHERE scope_id = $1 AND store_id = $2 AND name = $3 
       LIMIT 1`,
      [this.scope_id, this.store_id, this.refname]
    );
    return ref.commit_id;
  }

  /**
   * Build a VDOM tree from flat objects
   */
  private buildVDOM(objects: RawObject[], rootId: string): VDOMNode {
    const objectMap = new Map<string, RawObject>();
    for (const obj of objects) {
      objectMap.set(obj.id, obj);
    }

    const buildNode = (id: string, key: string): VDOMNode => {
      const obj = objectMap.get(id);
      if (!obj) {
        return {
          type: 'Unknown',
          key,
          props: {},
          children: []
        };
      }

      const { type: nodeType, ...props } = obj.data ?? {};
      const children: VDOMNode[] = [];

      for (let i = 0; i < obj.kids.length; i++) {
        const childId = obj.kids[i];
        const childKey = obj.ktree[i];
        children.push(buildNode(childId, childKey));
      }

      return {
        type: (typeof nodeType === 'string' ? nodeType : 'Fragment'),
        key,
        props,
        children
      };
    };

    const root = objectMap.get(rootId);
    if (!root) {
      return {
        type: 'Fragment',
        key: 'root',
        props: {},
        children: []
      };
    }

    const { type: nodeType, ...props } = root.data ?? {};
    const children: VDOMNode[] = [];

    for (let i = 0; i < root.kids.length; i++) {
      const childId = root.kids[i];
      const childKey = root.ktree[i];
      children.push(buildNode(childId, childKey));
    }

    return {
      type: (typeof nodeType === 'string' ? nodeType : 'Fragment'),
      props,
      children
    } as VDOMNode;
  }
}

/**
 * Create an ObjectTreeHelper with a new database and store
 */
export async function createObjectTreeHelper(
  pg: PgTestClient,
  options?: Partial<ObjectTreeHelperOptions>
): Promise<ObjectTreeHelper> {
  const scope_id = options?.scope_id ?? 'd0f7ab73-356f-4aac-b9cb-d1a4274906d6';
  const store_id = options?.store_id ?? 'a1b2c3d4-e5f6-7890-abcd-ef1234567890';
  const refname = options?.refname ?? 'main';

  return new ObjectTreeHelper(pg, { scope_id, store_id, refname });
}

/**
 * Meta position for nodes
 */
export interface NodeMeta {
  x: number;
  y: number;
}

/**
 * Helper class for flow-graph operations with a cleaner API
 * Wraps ObjectTreeHelper with domain-specific methods for nodes, edges, and boundary nodes
 */
export class FlowGraphHelper {
  private helper: ObjectTreeHelper;
  private basePath: string[];
  private edgeCount: number = 0;

  constructor(helper: ObjectTreeHelper, basePath: string[] = []) {
    this.helper = helper;
    this.basePath = basePath;
  }

  /**
   * Insert a regular processing node
   */
  async insertNode(
    key: string,
    type: string,
    meta?: NodeMeta,
    props?: Array<{ name: string; value: unknown; ref?: boolean }>
  ): Promise<void> {
    const data: Record<string, unknown> = { type };
    if (meta) data.meta = meta;
    if (props) data.props = props;
    await this.helper.insertNode([...this.basePath, 'nodes', key], data);
  }

  /**
   * Insert a graphInput boundary node
   */
  async insertInput(
    key: string,
    portName: string,
    dataType: string,
    meta?: NodeMeta
  ): Promise<void> {
    const data: Record<string, unknown> = {
      type: 'graphInput',
      props: [
        { name: 'portName', value: portName },
        { name: 'dataType', value: dataType }
      ]
    };
    if (meta) data.meta = meta;
    await this.helper.insertNode([...this.basePath, 'nodes', key], data);
  }

  /**
   * Insert a graphOutput boundary node
   */
  async insertOutput(
    key: string,
    portName: string,
    dataType: string,
    meta?: NodeMeta
  ): Promise<void> {
    const data: Record<string, unknown> = {
      type: 'graphOutput',
      props: [
        { name: 'portName', value: portName },
        { name: 'dataType', value: dataType }
      ]
    };
    if (meta) data.meta = meta;
    await this.helper.insertNode([...this.basePath, 'nodes', key], data);
  }

  /**
   * Insert a graphProp boundary node
   */
  async insertProp(
    key: string,
    propName: string,
    dataType: string,
    defaultValue?: unknown,
    meta?: NodeMeta
  ): Promise<void> {
    const props: Array<{ name: string; value: unknown }> = [
      { name: 'propName', value: propName },
      { name: 'dataType', value: dataType }
    ];
    if (defaultValue !== undefined) {
      props.push({ name: 'default', value: defaultValue });
    }
    const data: Record<string, unknown> = {
      type: 'graphProp',
      props
    };
    if (meta) data.meta = meta;
    await this.helper.insertNode([...this.basePath, 'nodes', key], data);
  }

  /**
   * Insert a subnet node (container for nested graph)
   */
  async insertSubnet(key: string, meta?: NodeMeta): Promise<void> {
    const data: Record<string, unknown> = { type: 'subnet' };
    if (meta) data.meta = meta;
    await this.helper.insertNode([...this.basePath, 'nodes', key], data);
  }

  /**
   * Insert an edge (auto-increments the edge index)
   */
  async insertEdge(
    src: { node: string; port: string },
    dst: { node: string; port: string }
  ): Promise<void> {
    await this.helper.insertNode([...this.basePath, 'edges', String(this.edgeCount)], {
      src,
      dst
    });
    this.edgeCount++;
  }

  /**
   * Set graph metadata (name, type, etc.)
   */
  async setGraphMeta(meta: { name?: string; type?: string }): Promise<void> {
    const data: Record<string, unknown> = {};
    if (meta.type) data.type = meta.type;
    if (meta.name) data.name = meta.name;
    await this.helper.setProps(this.basePath, data);
  }

  /**
   * Get a scoped helper for operating within a subnet
   */
  scope(subnetKey: string): FlowGraphHelper {
    return new FlowGraphHelper(this.helper, [...this.basePath, 'nodes', subnetKey]);
  }

  /**
   * Get the underlying ObjectTreeHelper for advanced operations
   */
  getHelper(): ObjectTreeHelper {
    return this.helper;
  }

  /**
   * Get the VDOM tree
   */
  async getVDOM(): Promise<VDOMNode> {
    return this.helper.getVDOM();
  }
}

/**
 * Create a FlowGraphHelper with a new database and store
 */
export async function createFlowGraphHelper(
  pg: PgTestClient,
  options?: Partial<ObjectTreeHelperOptions>
): Promise<FlowGraphHelper> {
  const helper = await createObjectTreeHelper(pg, options);
  return new FlowGraphHelper(helper);
}
