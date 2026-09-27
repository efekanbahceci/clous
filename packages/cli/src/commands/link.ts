import { ProjectConfigManager } from '../config/project.js';
import { CredentialsManager } from '../config/credentials.js';
import { logger } from '../utils/logger.js';
import { ansi } from '../utils/ansi.js';

export interface LinkOptions {
  projectId: string;
  name?: string;
  orgId?: string;
  cwd?: string;
}

export async function linkCommand(options: LinkOptions): Promise<void> {
  if (!options.projectId) {
    throw new Error('Missing required option: --project-id <id>');
  }

  const cwd = options.cwd || process.cwd();
  const token = CredentialsManager.getToken();

  if (!token) {
    logger.warn('You are not currently logged in. Run "npx clous login" to authenticate with the Web Panel.');
  }

  ProjectConfigManager.save(
    {
      projectId: options.projectId,
      projectName: options.name,
      orgId: options.orgId,
    },
    cwd
  );

  logger.success(`Linked current directory to project: ${ansi.bold(options.projectId)}`);
  if (options.name) {
    logger.info(`Project Name: ${options.name}`);
  }
  logger.plain('');
  logger.plain(`Saved configuration to: ${ansi.dim('.clous/project.json')}`);
}
