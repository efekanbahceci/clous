import { ProjectConfigManager } from '../config/project.js';
import { CredentialsManager } from '../config/credentials.js';
import { logger } from '../utils/logger.js';
import { ansi } from '../utils/ansi.js';
import { ui } from '../utils/ui.js';

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
    logger.warn('You are not currently logged in. Run "clous login" to authenticate with the Web Panel.');
  }

  ProjectConfigManager.save(
    {
      projectId: options.projectId,
      projectName: options.name,
      orgId: options.orgId,
    },
    cwd
  );

  // Register the link with the backend so the dashboard reflects it instantly.
  if (token) {
    try {
      const apiBase = CredentialsManager.getApiUrl();
      const endpoint = `${apiBase}/api/projects/${options.projectId}/link`;
      await fetch(endpoint, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({}),
      });
    } catch (e) {
      logger.error(`Failed to register link with backend: ${e}`);
    }
  }
  const lines = [
    `Project ID    ${ansi.bold(options.projectId)}`,
  ];
  if (options.name) {
    lines.push(`Project Name  ${options.name}`);
  }
  lines.push(`Config File   ${ansi.dim('.clous/project.json')}`);
  lines.push(`Status        ${ansi.green('Linked to Web Panel workspace')}`);

  console.log('');
  ui.box({
    title: 'Project Linked',
    borderColor: ansi.green,
    minWidth: 60,
    lines,
  });
  console.log('');
}
