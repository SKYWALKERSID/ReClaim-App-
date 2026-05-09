import { generateKeyPairSync } from 'crypto';
import { writeFileSync } from 'fs';
import path from 'path';

const { publicKey, privateKey } = generateKeyPairSync('rsa', {
  modulusLength: 2048,
  publicKeyEncoding: {
    type: 'spki',
    format: 'pem'
  },
  privateKeyEncoding: {
    type: 'pkcs8',
    format: 'pem'
  }
});

writeFileSync('public.pem', publicKey);
writeFileSync('private.pem', privateKey);

console.log('Keys generated successfully in public.pem and private.pem');
