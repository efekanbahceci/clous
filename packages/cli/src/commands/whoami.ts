import { AuthService } from '../auth/auth-service.js';
import { logger } from '../utils/logger.js';
import { ansi } from '../utils/ansi.js';

export async function whoamiCommand(): Promise<void> {
  const result = await AuthService.whoami();

  if (!result.loggedIn) {
    logger.warn('Not logged in. Run "npx clous login" to authenticate with the Web Panel.');
    return;
  }

  logger.plain('');
  logger.plain('Authenticated Clous Session:');
  logger.plain(`  User ID: ${ansi.bold(result.profile?.id || 'unknown')}`);
  logger.plain(`  Email:   ${ansi.cyan(result.profile?.email || 'unknown')}`);
  if (result.profile?.name) {
    logger.plain(`  Name:    ${result.profile.name}`);
  }
  if (result.profile?.role) {
    logger.plain(`  Role:    ${result.profile.role}`);
  }
  logger.plain(`  API URL: ${ansi.dim(result.apiUrl)}`);
}
