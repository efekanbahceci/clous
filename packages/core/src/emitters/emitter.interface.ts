import type { SchemaNode } from '../ast/types.js';

/**
 * Base interface for all Clous AST Emitters (Visitor pattern).
 */
export interface Emitter<TOutput, TOptions = Record<string, unknown>> {
  readonly name: string;
  emit(schema: SchemaNode, options?: TOptions): TOutput;
}
