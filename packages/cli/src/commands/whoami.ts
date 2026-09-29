import { AuthService } from '../auth/auth-service.js';
import { logger } from '../utils/logger.js';
import { ansi } from '../utils/ansi.js';
import { ui } from '../utils/ui.js';

export async function whoamiCommand(): Promise<void> {
  const result = await AuthService.whoami();

  if (!result.loggedIn) {
    logger.warn('Not logged in. Run "clous login" to authenticate with the Web Panel.');
    return;
  }

  const rows: Array<[string, string]> = [
    ['User ID', ansi.bold(result.profile?.id || 'unknown')],
    ['Email', ansi.cyan(result.profile?.email || 'unknown')],
  ];

  if (result.profile?.name) {
    rows.push(['Name', result.profile.name]);
  }
  if (result.profile?.role) {
    rows.push(['Role', result.profile.role]);
  }
  rows.push(['API Endpoint', ansi.dim(result.apiUrl)]);
  rows.push(['Session', ansi.green('Active')]);

  console.log('');
  ui.card('Authenticated Clous Session', rows, {
    borderColor: ansi.cyan,
  });
  console.log('');
}
