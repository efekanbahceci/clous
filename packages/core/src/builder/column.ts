import type {
  ColumnNode,
  DataType,
  DefaultValue,
  ForeignKeyAction,
  ForeignKeyReference,
} from '../ast/types.js';

export class ColumnBuilder {
  private _node: ColumnNode;

  constructor(name: string, type: DataType, length?: number) {
    this._node = {
      name,
      type,
      length,
      isPrimaryKey: false,
      isNullable: true,
      isUnique: false,
    };
  }

  primaryKey(): this {
    this._node.isPrimaryKey = true;
    this._node.isNullable = false;
    return this;
  }

  notNull(): this {
    this._node.isNullable = false;
    return this;
  }

  nullable(): this {
    this._node.isNullable = true;
    return this;
  }

  unique(): this {
    this._node.isUnique = true;
    return this;
  }

  default(val: DefaultValue): this {
    this._node.defaultValue = val;
    return this;
  }

  defaultNow(): this {
    this._node.defaultValue = { kind: 'raw', expression: 'now()' };
    return this;
  }

  defaultRandom(): this {
    if (this._node.type === 'uuid') {
      this._node.defaultValue = { kind: 'raw', expression: 'gen_random_uuid()' };
    }
    return this;
  }

  references(
    table: string,
    column: string,
    options?: { onDelete?: ForeignKeyAction; onUpdate?: ForeignKeyAction }
  ): this {
    this._node.references = {
      table,
      column,
      onDelete: options?.onDelete,
      onUpdate: options?.onUpdate,
    };
    return this;
  }

  build(): ColumnNode {
    return { ...this._node };
  }
}

// Fluent factory helpers
export const uuid = (name: string) => new ColumnBuilder(name, 'uuid');
export const text = (name: string) => new ColumnBuilder(name, 'text');
export const varchar = (name: string, length?: number) =>
  new ColumnBuilder(name, 'varchar', length);
export const integer = (name: string) => new ColumnBuilder(name, 'integer');
export const bigint = (name: string) => new ColumnBuilder(name, 'bigint');
export const boolean = (name: string) => new ColumnBuilder(name, 'boolean');
export const timestamp = (name: string) => new ColumnBuilder(name, 'timestamp');
export const timestamptz = (name: string) =>
  new ColumnBuilder(name, 'timestamptz');
export const jsonb = (name: string) => new ColumnBuilder(name, 'jsonb');
export const float = (name: string) => new ColumnBuilder(name, 'float');
export const serial = (name: string) => new ColumnBuilder(name, 'serial');
