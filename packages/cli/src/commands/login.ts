import { AuthService, type LoginOptions } from '../auth/auth-service.js';

export async function loginCommand(options: LoginOptions = {}): Promise<void> {
  await AuthService.login(options);
}
