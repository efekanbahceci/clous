import { AuthService, type LoginOptions } from '../auth/auth-service.js';
import { ui } from '../utils/ui.js';
import { ansi } from '../utils/ansi.js';

export async function loginCommand(options: LoginOptions = {}): Promise<void> {
  const current = await AuthService.whoami();
  if (current.loggedIn && current.profile) {
    console.log('');
    ui.box({
      title: 'Already Logged In',
      borderColor: ansi.blue,
      lines: [
        `You are already logged in as ${ansi.bold(current.profile.email || 'developer')}.`,
        `There is no need to log in again.`,
        ``,
        `If you want to switch accounts, run ${ansi.cyan('clous logout')} first.`
      ],
    });
    console.log('');
    return;
  }

  if (options.token) {
    await ui.animateBanner('0.1.0');
  }
  await AuthService.login(options);
}
