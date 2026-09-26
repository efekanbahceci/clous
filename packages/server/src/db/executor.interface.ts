import type { TableNode } from '@clous/core';
import type { AuthContext } from '../types/context.js';

export interface FindManyQuery {
  page?: number;
  limit?: number;
  offset?: number;
  sort?: string;
  order?: 'asc' | 'desc';
  select?: string[];
  filters?: Record<string, any>;
}

export interface QueryExecutor {
  readonly isConnected: boolean;

  query<T = any>(
    sql: string,
    params?: any[],
    context?: AuthContext
  ): Promise<T[]>;

  findMany(
    table: TableNode,
    query: FindManyQuery,
    context?: AuthContext
  ): Promise<{ rows: any[]; total: number }>;

  findById(
    table: TableNode,
    id: string | number,
    select?: string[],
    context?: AuthContext
  ): Promise<any | null>;

  insert(
    table: TableNode,
    data: Record<string, any>,
    context?: AuthContext
  ): Promise<any>;

  update(
    table: TableNode,
    id: string | number,
    data: Record<string, any>,
    context?: AuthContext
  ): Promise<any | null>;

  delete(
    table: TableNode,
    id: string | number,
    context?: AuthContext
  ): Promise<any | null>;

  close(): Promise<void>;
}
