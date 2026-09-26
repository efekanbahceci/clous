import type { TableNode } from '@clous/core';
import type { AuthContext } from '../types/context.js';
import type { FindManyQuery, QueryExecutor } from './executor.interface.js';

export class MemoryExecutor implements QueryExecutor {
  private readonly store: Map<string, Map<string, any>> = new Map();
  private _isConnected: boolean = true;

  get isConnected(): boolean {
    return this._isConnected;
  }

  async query<T = any>(
    _sql: string,
    _params?: any[],
    _context?: AuthContext
  ): Promise<T[]> {
    return [];
  }

  async findMany(
    table: TableNode,
    query: FindManyQuery,
    _context?: AuthContext
  ): Promise<{ rows: any[]; total: number }> {
    const tableMap = this.getTableMap(table.name);
    let allRows = Array.from(tableMap.values());

    // 1. Filtering
    if (query.filters) {
      allRows = allRows.filter((row) => {
        for (const [key, value] of Object.entries(query.filters!)) {
          if (value !== undefined && String(row[key]) !== String(value)) {
            return false;
          }
        }
        return true;
      });
    }

    const total = allRows.length;

    // 2. Sorting
    if (query.sort) {
      const sortField = query.sort;
      const desc = query.order === 'desc';
      allRows.sort((a, b) => {
        if (a[sortField] < b[sortField]) return desc ? 1 : -1;
        if (a[sortField] > b[sortField]) return desc ? -1 : 1;
        return 0;
      });
    }

    // 3. Pagination
    const limit = query.limit ?? 20;
    const offset = query.offset ?? ((query.page ?? 1) - 1) * limit;
    const paged = allRows.slice(offset, offset + limit);

    // 4. Select fields
    if (query.select && query.select.length > 0) {
      const selectSet = new Set(query.select);
      const mapped = paged.map((row) => {
        const item: Record<string, any> = {};
        for (const col of selectSet) {
          if (col in row) item[col] = row[col];
        }
        return item;
      });
      return { rows: mapped, total };
    }

    return { rows: paged.map((r) => ({ ...r })), total };
  }

  async findById(
    table: TableNode,
    id: string | number,
    select?: string[],
    _context?: AuthContext
  ): Promise<any | null> {
    const tableMap = this.getTableMap(table.name);
    const row = tableMap.get(String(id));
    if (!row) return null;

    if (select && select.length > 0) {
      const selectSet = new Set(select);
      const filtered: Record<string, any> = {};
      for (const col of selectSet) {
        if (col in row) filtered[col] = row[col];
      }
      return filtered;
    }

    return { ...row };
  }

  async insert(
    table: TableNode,
    data: Record<string, any>,
    _context?: AuthContext
  ): Promise<any> {
    const tableMap = this.getTableMap(table.name);
    const pkCol =
      table.columns.find((c) => c.isPrimaryKey)?.name ?? 'id';

    const rowId = data[pkCol] ?? (typeof crypto !== 'undefined' && crypto.randomUUID ? crypto.randomUUID() : `id_${Date.now()}`);
    const row = {
      ...data,
      [pkCol]: rowId,
    };

    tableMap.set(String(rowId), row);
    return { ...row };
  }

  async update(
    table: TableNode,
    id: string | number,
    data: Record<string, any>,
    _context?: AuthContext
  ): Promise<any | null> {
    const tableMap = this.getTableMap(table.name);
    const existing = tableMap.get(String(id));
    if (!existing) return null;

    const pkCol =
      table.columns.find((c) => c.isPrimaryKey)?.name ?? 'id';
    const updated = {
      ...existing,
      ...data,
      [pkCol]: existing[pkCol], // keep primary key immutable
    };

    tableMap.set(String(id), updated);
    return { ...updated };
  }

  async delete(
    table: TableNode,
    id: string | number,
    _context?: AuthContext
  ): Promise<any | null> {
    const tableMap = this.getTableMap(table.name);
    const existing = tableMap.get(String(id));
    if (!existing) return null;

    tableMap.delete(String(id));
    return { ...existing };
  }

  async close(): Promise<void> {
    this.store.clear();
    this._isConnected = false;
  }

  private getTableMap(tableName: string): Map<string, any> {
    if (!this.store.has(tableName)) {
      this.store.set(tableName, new Map());
    }
    return this.store.get(tableName)!;
  }
}
