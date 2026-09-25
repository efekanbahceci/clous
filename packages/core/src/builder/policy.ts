import type { PolicyCommand, PolicyNode } from '../ast/types.js';

export interface PolicyOptions {
  for?: PolicyCommand;
  to?: string;
  using?: string;
  withCheck?: string;
}

export class PolicyBuilder {
  private _node: PolicyNode;

  constructor(name: string, options: PolicyOptions = {}) {
    this._node = {
      name,
      for: options.for ?? 'all',
      to: options.to,
      using: options.using,
      withCheck: options.withCheck,
    };
  }

  for(cmd: PolicyCommand): this {
    this._node.for = cmd;
    return this;
  }

  to(role: string): this {
    this._node.to = role;
    return this;
  }

  using(sqlExpression: string): this {
    this._node.using = sqlExpression;
    return this;
  }

  withCheck(sqlExpression: string): this {
    this._node.withCheck = sqlExpression;
    return this;
  }

  build(): PolicyNode {
    return { ...this._node };
  }
}

export const policy = (name: string, options?: PolicyOptions) =>
  new PolicyBuilder(name, options);
