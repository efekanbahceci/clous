import { AuthService, type LoginOptions } from '../auth/auth-service.js';
import { ui } from '../utils/ui.js';

export async function loginCommand(options: LoginOptions = {}): Promise<void> {
  if (options.token) {
    await ui.animateBanner('0.1.0');
  }
  await AuthService.login(options);
}
