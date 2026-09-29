import fs from 'node:fs';
import path from 'node:path';
import { AuthService } from '../auth/auth-service.js';
import { ProjectConfigManager } from '../config/project.js';
import { resolveSchemaPath } from '../config/paths.js';
import { ansi } from '../utils/ansi.js';
import { ui } from '../utils/ui.js';

export async function statusCommand(options: { cwd?: string } = {}): Promise<void> {
  const cwd = options.cwd || process.cwd();

  const rows: Array<[string, string]> = [];

  // 1. Auth Status
  const auth = await AuthService.whoami();
  if (auth.loggedIn) {
    rows.push(['Authentication', ansi.bold(ansi.green('Active'))]);
    rows.push(['User Account', ansi.cyan(auth.profile?.email || auth.profile?.id || 'unknown')]);
    rows.push(['API Endpoint', ansi.dim(auth.apiUrl)]);
  } else {
    rows.push(['Authentication', ansi.yellow('Not logged in')]);
    rows.push(['Auth Hint', ansi.dim('Run "clous login" to authenticate')]);
  }

  // 2. Project Link Status
  const project = ProjectConfigManager.load(cwd);
  if (project) {
    rows.push(['Linked Project', ansi.bold(project.projectId)]);
    if (project.projectName) {
      rows.push(['Project Name', project.projectName]);
    }
  } else {
    rows.push(['Linked Project', ansi.dim('Not linked')]);
    rows.push(['Link Hint', ansi.dim('Run "clous link --project-id <id>" to link')]);
  }

  // 3. Schema File Status
  try {
    const schemaPath = resolveSchemaPath(cwd);
    if (fs.existsSync(schemaPath)) {
      rows.push(['Local Schema', ansi.green(path.relative(cwd, schemaPath) || schemaPath)]);
    } else {
      rows.push(['Local Schema', ansi.dim('None (Run "clous init" to create)')]);
    }
  } catch {
    rows.push(['Local Schema', ansi.dim('None (Run "clous init" to create)')]);
  }

  console.log('');
  ui.card('Clous Environment Status', rows, {
    borderColor: ansi.dim,
    minWidth: 64,
  });
  console.log('');
}
