import type { SchemaNode, TableNode } from '../ast/types.js';
import { validateSchemaAst } from '../ast/schema.js';
import { TableBuilder } from './table.js';

export interface SchemaConfig {
  version?: string;
  tables: (TableBuilder | TableNode)[];
}

export function schema(config: SchemaConfig): SchemaNode {
  const tableNodes: TableNode[] = config.tables.map((t) =>
    t instanceof TableBuilder ? t.build() : t
  );

  const rawSchema: SchemaNode = {
    version: config.version ?? '1.0.0',
    tables: tableNodes,
  };

  // Validate AST structure against Zod Schema
  const validated = validateSchemaAst(rawSchema);

  // Semantic checks (foreign keys and duplicates)
  const tableMap = new Map<string, TableNode>();
  for (const t of validated.tables) {
    if (tableMap.has(t.name)) {
      throw new Error(`Duplicate table definition found: "${t.name}"`);
    }
    tableMap.set(t.name, t);
  }

  for (const t of validated.tables) {
    for (const col of t.columns) {
      if (col.references) {
        const targetTable = tableMap.get(col.references.table);
        if (!targetTable) {
          throw new Error(
            `Foreign key error in table "${t.name}.${col.name}": referenced table "${col.references.table}" does not exist in schema.`
          );
        }
        const targetCol = targetTable.columns.find(
          (c) => c.name === col.references!.column
        );
        if (!targetCol) {
          throw new Error(
            `Foreign key error in table "${t.name}.${col.name}": referenced column "${col.references.table}.${col.references.column}" does not exist.`
          );
        }
      }
    }
  }

  return validated;
}
