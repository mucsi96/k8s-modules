import assert from 'node:assert/strict';
import { test } from 'node:test';
import worker from '../setup_bank_email_worker/worker.js';

const env = { TARGET_URL: 'https://cooking.example.com/api/recipe-emails', API_TOKEN: 'test-token' };
const raw = 'Subject: Recipe\r\n\r\nApfelstrudel';
const message = (authentication) => ({
  from: 'cook@example.com',
  to: 'recipes@example.com',
  raw: new Blob([raw]).stream(),
  headers: new Headers({ subject: 'Recipe', 'authentication-results': authentication }),
});
const passing = 'mx.cloudflare.net; spf=pass; dkim=pass header.d=example.com';

test('forwards authenticated recipe email with raw MIME and the shared token', async (t) => {
  const fetch = t.mock.method(globalThis, 'fetch', async () => new Response('{}'));
  await worker.email(message(passing), env);
  assert.equal(fetch.mock.callCount(), 1);
  const [url, request] = fetch.mock.calls[0].arguments;
  assert.equal(url, env.TARGET_URL);
  assert.equal(request.method, 'POST');
  assert.equal(request.headers.Authorization, 'Bearer test-token');
  assert.deepEqual(JSON.parse(request.body), {
    from: 'cook@example.com', to: 'recipes@example.com', subject: 'Recipe', raw,
  });
});

test('does not forward unauthenticated or misaligned senders', async (t) => {
  const fetch = t.mock.method(globalThis, 'fetch', async () => new Response('{}'));
  t.mock.method(console, 'log', () => {});
  for (const authentication of [
    '', 'untrusted.example; spf=pass; dkim=pass header.d=example.com',
    'mx.cloudflare.net; spf=fail; dkim=pass header.d=example.com',
    'mx.cloudflare.net; spf=pass; dkim=pass header.d=unrelated.com',
    `mx.cloudflare.net; spf=fail; dkim=fail, ${passing}`,
  ]) {
    await worker.email(message(authentication), env);
  }
  assert.equal(fetch.mock.callCount(), 0);
});

test('fails delivery when the API rejects or cannot receive the email', async (t) => {
  const fetch = t.mock.method(globalThis, 'fetch', async () => new Response('', { status: 422 }));
  await assert.rejects(worker.email(message(passing), env), /HTTP 422/);
  fetch.mock.mockImplementation(async () => { throw new Error('network failure'); });
  await assert.rejects(worker.email(message(passing), env), /network failure/);
});
