import type {
  ColumnNode,
  IndexMethod,
  IndexNode,
  PolicyNode,
  TableNode,
} from '../ast/types.js';
import { ColumnBuilder } from './column.js';
import { PolicyBuilder, type PolicyOptions } from './policy.js';

export interface IndexOptions {
  name?: string;
  unique?: boolean;
  method?: IndexMethod;
}

export type ColumnInput = ColumnBuilder | ColumnNode;

export class TableBuilder {
  private _name: string;
  private _columns: Map<string, ColumnNode> = new Map();
  private _policies: PolicyNode[] = [];
  private _indexes: IndexNode[] = [];

  constructor(
    name: string,
    columns?: Record<string, ColumnInput> | ColumnInput[]
  ) {
    this._name = name;
    if (columns) {
      if (Array.isArray(columns)) {
        for (const col of columns) {
          const node = col instanceof ColumnBuilder ? col.build() : col;
          this._columns.set(node.name, node);
        }
      } else {
        for (const [key, col] of Object.entries(columns)) {
          const node = col instanceof ColumnBuilder ? col.build() : col;
          // If the column builder didn't have name specified or key is used as name
          const finalNode: ColumnNode = {
            ...node,
            name: node.name || key,
          };
          this._columns.set(finalNode.name, finalNode);
        }
      }
    }
  }

  addColumn(column: ColumnInput): this {
    const node = column instanceof ColumnBuilder ? column.build() : column;
    this._columns.set(node.name, node);
    return this;
  }

  policy(name: string, options: PolicyOptions = {}): this {
    const builder = new PolicyBuilder(name, options);
    this._policies.push(builder.build());
    return this;
  }

  addPolicy(policy: PolicyBuilder | PolicyNode): this {
    const node = policy instanceof PolicyBuilder ? policy.build() : policy;
    this._policies.push(node);
    return this;
  }

  index(columns: string[], options: IndexOptions = {}): this {
    this._indexes.push({
      name: options.name,
      columns,
      unique: options.unique,
      method: options.method,
    });
    return this;
  }

  build(): TableNode {
    return {
      name: this._name,
      columns: Array.from(this._columns.values()),
      policies: [...this._policies],
      indexes: [...this._indexes],
    };
  }
}

export const table = (
  name: string,
  columns?: Record<string, ColumnInput> | ColumnInput[]
) => new TableBuilder(name, columns);
