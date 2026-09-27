import fs from 'node:fs';
import path from 'node:path';
import { AuthService } from '../auth/auth-service.js';
import { ProjectConfigManager } from '../config/project.js';
import { resolveSchemaPath } from '../config/paths.js';
import { logger } from '../utils/logger.js';
import { ansi } from '../utils/ansi.js';

export async function statusCommand(options: { cwd?: string } = {}): Promise<void> {
  const cwd = options.cwd || process.cwd();

  logger.plain('');
  logger.plain(ansi.bold('Clous Environment Status:'));
  logger.plain('-------------------------');

  // 1. Auth Status
  const auth = await AuthService.whoami();
  if (auth.loggedIn) {
    logger.plain(`Authentication: ${ansi.green('Active')}`);
    logger.plain(`  User:         ${auth.profile?.email || auth.profile?.id || 'unknown'}`);
    logger.plain(`  API URL:      ${auth.apiUrl}`);
  } else {
    logger.plain(`Authentication: ${ansi.yellow('Not logged in')}`);
    logger.plain(`  Hint:         Run "npx clous login" to authenticate.`);
  }

  logger.plain('');

  // 2. Project Link Status
  const project = ProjectConfigManager.load(cwd);
  if (project) {
    logger.plain(`Linked Project: ${ansi.green('Linked')}`);
    logger.plain(`  Project ID:   ${ansi.bold(project.projectId)}`);
    if (project.projectName) {
      logger.plain(`  Name:         ${project.projectName}`);
    }
    if (project.linkedAt) {
      logger.plain(`  Linked At:    ${project.linkedAt}`);
    }
  } else {
    logger.plain(`Linked Project: ${ansi.dim('Not linked')}`);
    logger.plain(`  Hint:         Run "npx clous link --project-id <id>" to link to Web Panel.`);
  }

  logger.plain('');

  // 3. Schema File Status
  try {
    const schemaPath = resolveSchemaPath(cwd);
    if (fs.existsSync(schemaPath)) {
      logger.plain(`Local Schema:   ${ansi.green('Found')}`);
      logger.plain(`  File:         ${path.relative(cwd, schemaPath) || schemaPath}`);
    } else {
      logger.plain(`Local Schema:   ${ansi.dim('Not found')}`);
      logger.plain(`  Hint:         Run "npx clous init" to create a schema.ts.`);
    }
  } catch {
    logger.plain(`Local Schema:   ${ansi.dim('Not found')}`);
    logger.plain(`  Hint:         Run "npx clous init" to create a schema.ts.`);
  }

  logger.plain('');
}
