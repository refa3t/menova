// Prints a short-lived Google access token from the local Firebase CLI login.
// Dev tooling only: lets seed scripts write as the project owner (IAM),
// so no service-account key is needed on disk.
const path = require('path');
const lib = path.join(process.env.APPDATA || '', 'npm/node_modules/firebase-tools/lib');
const { configstore } = require(path.join(lib, 'configstore'));
const auth = require(path.join(lib, 'auth'));
const scopes = require(path.join(lib, 'scopes'));

(async () => {
  const tokens = configstore.get('tokens');
  if (!tokens || !tokens.refresh_token) throw new Error('Run `firebase login` first.');
  const t = await auth.getAccessToken(tokens.refresh_token, [scopes.CLOUD_PLATFORM]);
  process.stdout.write(t.access_token);
})().catch((e) => { console.error(e.message); process.exit(1); });
