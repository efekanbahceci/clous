import { exec } from 'node:child_process';

/**
 * Attempts to open a URL in the user's default browser cross-platform (macOS, Windows, Linux).
 */
export function openBrowser(url: string): void {
  const platform = process.platform;
  let command = '';

  if (platform === 'darwin') {
    command = `open "${url}"`;
  } else if (platform === 'win32') {
    command = `start "" "${url}"`;
  } else {
    command = `xdg-open "${url}"`;
  }

  exec(command, (err) => {
    // Silently ignore browser open errors (e.g. headless environments)
    // The CLI already prints the manual URL link in the terminal
    if (err) {
      // noop
    }
  });
}
