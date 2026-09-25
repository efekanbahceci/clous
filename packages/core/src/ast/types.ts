export type DataType =
  | 'uuid'
  | 'text'
  | 'varchar'
  | 'integer'
  | 'bigint'
  | 'boolean'
  | 'timestamp'
  | 'timestamptz'
  | 'jsonb'
  | 'float'
  | 'serial';

export type ForeignKeyAction = 'cascade' | 'set null' | 'restrict' | 'no action';

export interface ForeignKeyReference {
  table: string;
  column: string;
  onDelete?: ForeignKeyAction;
  onUpdate?: ForeignKeyAction;
}

export type DefaultValue =
  | string
  | number
  | boolean
  | { kind: 'raw'; expression: string };

export interface ColumnNode {
  name: string;
  type: DataType;
  length?: number;
  isPrimaryKey: boolean;
  isNullable: boolean;
  isUnique: boolean;
  defaultValue?: DefaultValue;
  references?: ForeignKeyReference;
}

export type PolicyCommand = 'all' | 'select' | 'insert' | 'update' | 'delete';

export interface PolicyNode {
  name: string;
  for: PolicyCommand;
  to?: string; // Role name, e.g. 'public', 'authenticated', 'anon', etc.
  using?: string; // SQL expression evaluated for existing rows
  withCheck?: string; // SQL expression evaluated for new/updated rows
}

export type IndexMethod = 'btree' | 'hash' | 'gin' | 'gist';

export interface IndexNode {
  name?: string;
  columns: string[];
  unique?: boolean;
  method?: IndexMethod;
}

export interface TableNode {
  name: string;
  columns: ColumnNode[];
  policies: PolicyNode[];
  indexes: IndexNode[];
}

export interface SchemaNode {
  version: string;
  tables: TableNode[];
}
