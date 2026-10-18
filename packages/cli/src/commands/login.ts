import { AuthService, type LoginOptions } from '../auth/auth-service.js';
import { ui } from '../utils/ui.js';
import { ansi } from '../utils/ansi.js';

export async function loginCommand(options: LoginOptions = {}): Promise<void> {
  if (!options.force && !options.token) {
    const current = await AuthService.whoami();
    if (
      current.loggedIn &&
      current.profile &&
      current.profile.id !== 'dev_user' &&
      current.profile.email &&
      current.profile.email !== 'developer@clous.local'
    ) {
      console.log('');
      ui.box({
        title: 'Already Logged In',
        borderColor: ansi.blue,
        lines: [
          `You are already logged in as ${ansi.bold(current.profile.email)}.`,
          `Your session is active across all local projects on this machine.`,
          ``,
          `To switch accounts or re-authenticate, run ${ansi.cyan('clous login --force')} or ${ansi.cyan('clous logout')}.`,
        ],
      });
      console.log('');
      return;
    }
  }

  if (options.token) {
    await ui.animateBanner('0.1.0');
  }
  await AuthService.login(options);
}
