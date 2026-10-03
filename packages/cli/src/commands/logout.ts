import { AuthService } from '../auth/auth-service.js';
import { ui } from '../utils/ui.js';
import { ansi } from '../utils/ansi.js';

export async function logoutCommand(): Promise<void> {
  const current = await AuthService.whoami();
  
  if (!current.loggedIn) {
    console.log('');
    ui.box({
      title: 'Not Logged In',
      borderColor: ansi.yellow,
      lines: [
        `You are not currently logged in.`,
        `Run ${ansi.cyan('clous login')} to authenticate.`
      ]
    });
    console.log('');
    return;
  }

  await AuthService.logout();
  
  console.log('');
  ui.box({
    title: 'Logged Out',
    borderColor: ansi.green,
    lines: [
      `You have been successfully logged out.`,
      `Your local session credentials have been removed.`,
      ``,
      `Run ${ansi.cyan('clous login')} to authenticate again.`
    ]
  });
  console.log('');
}
