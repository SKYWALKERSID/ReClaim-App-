const fs = require('fs');
const path = require('path');

try {
  const keyPath = path.join(process.cwd(), 'flutter-a5d95dff-firebase-adminsdk-fbsvc-9e5c82dd0b.json');
  const envPath = path.join(process.cwd(), 'services', 'api', '.env');

  const key = JSON.parse(fs.readFileSync(keyPath, 'utf8'));
  const env = fs.readFileSync(envPath, 'utf8');

  const lines = env.split(/\r?\n/);
  const newLines = lines.map(line => {
    if (line.startsWith('FIREBASE_SERVICE_ACCOUNT=')) {
      return `FIREBASE_SERVICE_ACCOUNT='${JSON.stringify(key)}'`;
    }
    return line;
  });

  // If it didn't exist, add it
  if (!newLines.some(l => l.startsWith('FIREBASE_SERVICE_ACCOUNT='))) {
    newLines.push(`FIREBASE_SERVICE_ACCOUNT='${JSON.stringify(key)}'`);
  }

  fs.writeFileSync(envPath, newLines.join('\n'));
  console.log('Successfully updated .env with minified JSON');
} catch (e) {
  console.error('Error:', e.message);
  process.exit(1);
}
