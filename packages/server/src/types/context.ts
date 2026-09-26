export interface AuthContext {
  sub?: string;
  role: string;
  email?: string;
  claims: Record<string, any>;
}

export interface PaginationQuery {
  page?: number;
  limit?: number;
  offset?: number;
}

export interface SortQuery {
  sort?: string;
  order?: 'asc' | 'desc';
}

export interface SelectQuery {
  select?: string;
}

export interface ClousPagination {
  total: number;
  page: number;
  limit: number;
  totalPages: number;
}

export interface ClousResponse<T> {
  data: T;
  pagination?: ClousPagination;
}

declare module 'fastify' {
  interface FastifyRequest {
    auth: AuthContext;
  }
}
