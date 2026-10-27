const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const { randomUUID } = require('node:crypto');
const path = require('node:path');
const { setTimeout: delay } = require('node:timers/promises');

const manifest = path.join(__dirname, '../apps/money-claims/cmc-mailhog/cmc-mailhog.yaml');
const containers = [];

function command(program, args, { includeStderr = false, ...options } = {}) {
  const result = spawnSync(program, args, {
    encoding: 'utf8',
    stdio: ['pipe', 'pipe', 'pipe'],
    timeout: 30000,
    maxBuffer: 1024 * 1024,
    ...options,
  });
  if (result.error) throw result.error;
  assert.equal(result.status, 0, `${program} failed: ${result.stderr}`);
  return `${result.stdout}${includeStderr ? result.stderr : ''}`.trim();
}

async function request(url) {
  const response = await fetch(url, { signal: AbortSignal.timeout(3000) });
  assert.equal(response.status, 200, `${url} must return HTTP 200`);
  return response;
}

async function waitForStartup(url) {
  const deadline = Date.now() + 30000;
  while (Date.now() < deadline) {
    try {
      await request(url);
      return;
    } catch {
      await delay(250);
    }
  }
  throw new Error('MailHog did not become ready within 30 seconds');
}

function processStatus(container) {
  const status = command('docker', ['exec', container, 'cat', '/proc/1/status']);
  return {
    uid: status.match(/^Uid:\s+(\d+)/m)?.[1],
    noNewPrivileges: status.match(/^NoNewPrivs:\s+(\d+)/m)?.[1],
  };
}

async function verifyMessage(base, smtpPort, sequence) {
  const marker = `dtspo-35033-${sequence}-${randomUUID()}`;
  const sender = 'sender@example.invalid';
  const recipient = 'recipient@example.invalid';
  const content = [
    `From: ${sender}`,
    `To: ${recipient}`,
    `Subject: ${marker}`,
    '',
    `Synthetic MailHog security test ${marker}`,
    '',
  ].join('\r\n');

  command('curl', [
    '--fail', '--silent', '--show-error', '--max-time', '10',
    '--url', `smtp://127.0.0.1:${smtpPort}`,
    '--mail-from', sender, '--mail-rcpt', recipient, '--upload-file', '-',
  ], { input: content });

  const listing = await (await request(`${base}/api/v2/messages`)).json();
  assert.equal(listing.total, sequence, 'Every synthetic message must be captured');
  const message = listing.items.find(item => item.Content.Headers.Subject.includes(marker));
  assert.ok(message, 'SMTP message must be retrievable through the API');
  assert.ok(message.Content.Headers.From.includes(sender));
  assert.ok(message.Content.Headers.To.includes(recipient));
  assert.ok(message.Content.Body.includes(marker));

  const retrieved = await (await request(`${base}/api/v1/messages/${encodeURIComponent(message.ID)}`)).json();
  assert.equal(retrieved.ID, message.ID);
  assert.ok(retrieved.Content.Body.includes(marker));
}

async function verifyContainer(imageId, uid, hardened) {
  const mode = hardened ? 'no-new-privileges' : 'baseline';
  const name = `dtspo-35033-mailhog-${randomUUID()}`;
  const container = command('docker', [
    'run', '--detach', '--rm', '--name', name,
    '--platform', 'linux/amd64', '--user', String(uid),
    '--env', 'MH_HOSTNAME=mailhog-security-test',
    '--publish', '127.0.0.1::1025', '--publish', '127.0.0.1::8025',
    ...(hardened ? ['--security-opt', 'no-new-privileges=true'] : []),
    imageId,
  ]);
  containers.push(container);

  const inspected = JSON.parse(command('docker', ['inspect', container]))[0];
  assert.equal(inspected.Image, imageId);
  assert.equal(inspected.Config.User, String(uid));
  assert.equal(inspected.HostConfig.Privileged, false);
  assert.equal(inspected.HostConfig.ReadonlyRootfs, false);
  assert.deepEqual(inspected.Mounts, []);
  const bindings = inspected.NetworkSettings.Ports;
  for (const port of ['1025/tcp', '8025/tcp']) {
    assert.equal(bindings[port].length, 1);
    assert.equal(bindings[port][0].HostIp, '127.0.0.1');
  }
  const httpPort = bindings['8025/tcp'][0].HostPort;
  const smtpPort = bindings['1025/tcp'][0].HostPort;
  const base = `http://127.0.0.1:${httpPort}`;
  await waitForStartup(`${base}/api/v2/messages`);
  assert.deepEqual(processStatus(container), {
    uid: String(uid),
    noNewPrivileges: hardened ? '1' : '0',
  });
  const initial = await (await request(`${base}/api/v2/messages`)).json();
  assert.equal(initial.total, 0, 'Test must start with an empty disposable mailbox');
  const ui = await (await request(`${base}/`)).text();
  assert.match(ui, /MailHog/i);
  await verifyMessage(base, smtpPort, 1);
  await verifyMessage(base, smtpPort, 2);

  const final = JSON.parse(command('docker', ['inspect', container]))[0];
  assert.equal(final.State.Running, true);
  assert.equal(final.RestartCount, 0);
  const logs = command('docker', ['logs', container], { includeStderr: true });
  assert.doesNotMatch(logs, /permission denied|operation not permitted|panic:|fatal error/i);
  console.log(`PASS ${mode}: UID ${uid}, NoNewPrivs=${hardened ? 1 : 0}, SMTP capture, API contents, UI endpoint, two messages, no restarts`);
  command('docker', ['rm', '--force', container]);
  containers.splice(containers.indexOf(container), 1);
}

async function main() {
  const deployments = JSON.parse(command('yq', [
    'eval-all', '-o=json', '-I=0',
    '[select(.kind == "Deployment" and .metadata.name == "mailhog")]', manifest,
  ]));
  assert.equal(deployments.length, 1);
  const pod = deployments[0].spec.template.spec;
  assert.equal(pod.containers.length, 1);
  const mailhog = pod.containers[0];
  assert.equal(mailhog.name, 'mailhog');
  assert.equal(mailhog.image, 'mailhog/mailhog:v1.0.1');
  assert.equal(mailhog.securityContext?.allowPrivilegeEscalation, false);
  assert.equal(pod.securityContext.runAsUser, 1000);
  assert.deepEqual(mailhog.ports.map(port => port.containerPort).sort((first, second) => first - second), [1025, 8025]);

  command('docker', ['pull', '--platform', 'linux/amd64', mailhog.image], { timeout: 120000 });
  const image = JSON.parse(command('docker', ['image', 'inspect', mailhog.image]))[0];
  assert.equal(image.Os, 'linux');
  assert.equal(image.Architecture, 'amd64');
  console.log(JSON.stringify({ image: mailhog.image, imageId: image.Id, digests: image.RepoDigests, platform: 'linux/amd64' }));
  await verifyContainer(image.Id, pod.securityContext.runAsUser, false);
  await verifyContainer(image.Id, pod.securityContext.runAsUser, true);
}

main().catch(error => {
  console.error(error.message);
  process.exitCode = 1;
}).finally(() => {
  for (const container of containers) {
    try {
      command('docker', ['rm', '--force', container]);
    } catch {
      console.error(`Unable to remove test container ${container}`);
      process.exitCode = 1;
    }
  }
});