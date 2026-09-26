import * as fs from 'node:fs';
import * as path from 'node:path';
import type { SchemaNode } from '../../ast/types.js';
import { TsTypeEmitter, type TsEmitterOptions } from './type-emitter.js';

export interface WriteDtsOptions extends TsEmitterOptions {
  outDir?: string;
  fileName?: string;
}

export class DtsEmitter {
  private readonly typeEmitter: TsTypeEmitter;

  constructor() {
    this.typeEmitter = new TsTypeEmitter();
  }

  emit(schema: SchemaNode, options?: TsEmitterOptions): string {
    return this.typeEmitter.emit(schema, options);
  }

  async writeToFile(
    targetPath: string,
    schema: SchemaNode,
    options?: TsEmitterOptions
  ): Promise<string> {
    const content = this.emit(schema, options);
    const resolvedPath = path.resolve(targetPath);
    const dir = path.dirname(resolvedPath);

    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true });
    }

    fs.writeFileSync(resolvedPath, content, 'utf8');
    return resolvedPath;
  }
}
