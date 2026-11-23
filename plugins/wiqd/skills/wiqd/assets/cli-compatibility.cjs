const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const VERSION =
  /^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-((?:0|[1-9]\d*|[0-9A-Za-z-]*[A-Za-z-][0-9A-Za-z-]*)(?:\.(?:0|[1-9]\d*|[0-9A-Za-z-]*[A-Za-z-][0-9A-Za-z-]*))*))?(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?$/;
// Unlike $, the strict end assertion rejects trailing newlines in both runtime and schema checks.
const RELEASE_LINE = /^~(0|[1-9]\d*)\.(0|[1-9]\d*)\.0(?![\s\S])/;

class CompatibilityError extends Error {}

function compare(left, right) {
  for (let index = 0; index < 3; index++) {
    if (left[index] < right[index]) return -1;
    if (left[index] > right[index]) return 1;
  }
  return 0;
}

function parseRange(range) {
  const match = typeof range === 'string' && RELEASE_LINE.exec(range);
  if (!match)
    throw new CompatibilityError(
      'The compatibility range must be one minor release line in ~X.Y.0 form.',
    );
  const major = BigInt(match[1]);
  const minor = BigInt(match[2]);
  return { lower: [major, minor, 0n], upper: [major, minor + 1n, 0n] };
}

function parseVersion(version) {
  const match = VERSION.exec(version);
  if (!match) throw new CompatibilityError('The CLI did not report one valid SemVer version.');
  return {
    core: match.slice(1, 4).map(BigInt),
    prerelease: match[4] ? match[4].split('.') : null,
  };
}

function compareVersions(left, right) {
  const a = typeof left === 'string' ? parseVersion(left) : left;
  const b = typeof right === 'string' ? parseVersion(right) : right;
  const coreOrder = compare(a.core, b.core);
  if (coreOrder !== 0) return coreOrder;
  if (a.prerelease === null || b.prerelease === null)
    return a.prerelease === b.prerelease ? 0 : a.prerelease === null ? 1 : -1;
  for (let index = 0; index < Math.max(a.prerelease.length, b.prerelease.length); index++) {
    const leftIdentifier = a.prerelease[index];
    const rightIdentifier = b.prerelease[index];
    if (leftIdentifier === undefined || rightIdentifier === undefined)
      return leftIdentifier === rightIdentifier ? 0 : leftIdentifier === undefined ? -1 : 1;
    const leftNumeric = /^\d+$/.test(leftIdentifier);
    const rightNumeric = /^\d+$/.test(rightIdentifier);
    if (leftNumeric && rightNumeric) {
      const order =
        BigInt(leftIdentifier) < BigInt(rightIdentifier)
          ? -1
          : BigInt(leftIdentifier) > BigInt(rightIdentifier)
            ? 1
            : 0;
      if (order !== 0) return order;
    } else if (leftNumeric !== rightNumeric) {
      return leftNumeric ? -1 : 1;
    } else if (leftIdentifier !== rightIdentifier) {
      return leftIdentifier < rightIdentifier ? -1 : 1;
    }
  }
  return 0;
}

function validateDeclaration(declaration, expectedPackage) {
  const keys = ['channel', 'package', 'range', 'schemaVersion'];
  if (
    !['@microsoft/wiqd', '@microsoft/wiqd-1p'].includes(expectedPackage) ||
    !declaration ||
    typeof declaration !== 'object' ||
    Array.isArray(declaration) ||
    JSON.stringify(Object.keys(declaration).sort()) !== JSON.stringify(keys) ||
    declaration.schemaVersion !== 'wiqd-cli-compatibility/v1' ||
    declaration.package !== expectedPackage ||
    declaration.channel !== 'latest'
  )
    throw new CompatibilityError('Invalid compatibility declaration, package, or channel.');
  return parseRange(declaration.range);
}

function absoluteLauncher(launcher, platform = process.platform) {
  const absolute =
    typeof launcher === 'string' &&
    (platform === 'win32'
      ? /^(?:[A-Za-z]:[\\/]|\\\\[^\\]+\\[^\\]+\\)/.test(launcher)
      : path.posix.isAbsolute(launcher));
  if (!absolute || /["\r\n\0]/.test(launcher))
    throw new CompatibilityError('A fully qualified CLI launcher path is required.');
  return launcher;
}

function windowsInvocation(launcher, args, environment) {
  const systemRoot = environment.SystemRoot || environment.SYSTEMROOT;
  if (!systemRoot || !/^[A-Za-z]:[\\/]/.test(systemRoot))
    throw new CompatibilityError('Cannot locate the Windows command processor.');
  // Expanding a quoted environment value avoids re-parsing %, !, ^ and & in the path.
  return {
    command: path.win32.join(systemRoot, 'System32', 'cmd.exe'),
    args: ['/d', '/v:off', '/s', '/c', `""%WIQD_COMPATIBILITY_EXECUTABLE%" ${args.join(' ')}"`],
    env: { ...environment, WIQD_COMPATIBILITY_EXECUTABLE: launcher },
    windowsVerbatimArguments: true,
  };
}

function resolveWindowsNpm(environment) {
  const key = Object.keys(environment).find((name) => name.toUpperCase() === 'PATH');
  for (const entry of (environment[key] || '').split(';')) {
    const directory = entry.replace(/^"|"$/g, '');
    if (!/^(?:[A-Za-z]:[\\/]|\\\\[^\\]+\\[^\\]+\\)/.test(directory)) continue;
    for (const name of ['npm.cmd', 'npm.exe', 'npm.bat']) {
      const candidate = path.win32.join(directory, name);
      try {
        if (fs.statSync(candidate).isFile()) return candidate;
      } catch (error) {
        if (error?.code === 'ENOENT' || error?.code === 'ENOTDIR') continue;
        throw new CompatibilityError(`Cannot inspect the npm launcher (${error.code || 'error'}).`);
      }
    }
  }
  throw new CompatibilityError('Cannot locate npm in an absolute PATH directory.');
}

function registryVersions(
  packageName,
  selector,
  spawn = spawnSync,
  platform = process.platform,
  environment = process.env,
  resolveNpm = resolveWindowsNpm,
) {
  if (!['@microsoft/wiqd', '@microsoft/wiqd-1p'].includes(packageName) || selector !== 'versions')
    throw new CompatibilityError('The npm package or version selector is not supported.');
  const specifier = packageName;
  const field = 'versions';
  let command = 'npm';
  let args = ['view', specifier, field, '--json'];
  let env = environment;
  let windowsVerbatimArguments = false;
  if (platform === 'win32') {
    command = absoluteLauncher(resolveNpm(environment), platform);
    if (/\.(?:cmd|bat)$/i.test(command)) {
      ({ command, args, env, windowsVerbatimArguments } = windowsInvocation(
        command,
        args,
        environment,
      ));
    }
  }
  const result = spawn(command, args, {
    encoding: 'utf8',
    env,
    maxBuffer: 1024 * 1024,
    stdio: ['ignore', 'pipe', 'pipe'],
    timeout: 60000,
    windowsVerbatimArguments,
    windowsHide: true,
  });
  if (result.error)
    throw new CompatibilityError(
      `Cannot query the approved npm source (${result.error.code || 'error'}).`,
    );
  if (result.status !== 0) {
    const authCode = /\b(?:E|HTTP\s+)(401|403)\b/i.exec(result.stderr || '');
    const detail = authCode ? ` (HTTP ${authCode[1]})` : '';
    throw new CompatibilityError(
      `npm view ${specifier} failed with exit code ${result.status}${detail}.`,
    );
  }
  let versions;
  try {
    versions = JSON.parse(result.stdout || '');
  } catch {
    throw new CompatibilityError(`npm view ${specifier} returned invalid JSON.`);
  }
  if (typeof versions === 'string') return [versions];
  if (Array.isArray(versions) && versions.every((version) => typeof version === 'string'))
    return versions;
  throw new CompatibilityError(`npm view ${specifier} returned invalid version data.`);
}

function resolveLatestVersion(packageName, range, query = registryVersions) {
  const bounds = parseRange(range);
  const eligible = [];
  for (const version of query(packageName, 'versions')) {
    const parsed = parseVersion(version);
    if (!parsed.prerelease && satisfies(version, bounds)) eligible.push(version);
  }
  if (!eligible.length)
    throw new CompatibilityError(
      'No published stable CLI version satisfies the declared release line.',
    );
  return eligible.reduce((newest, version) =>
    compareVersions(version, newest) > 0 ? version : newest,
  );
}

function canonicalDeclaration(declaration) {
  return Buffer.from(
    `${JSON.stringify({
      channel: declaration.channel,
      package: declaration.package,
      range: declaration.range,
      schemaVersion: declaration.schemaVersion,
    })}\n`,
    'utf8',
  );
}

function satisfies(version, bounds) {
  const match = VERSION.exec(version);
  if (!match) throw new CompatibilityError('The CLI did not report one valid SemVer version.');
  if (match[4]) return false;
  const actual = match.slice(1, 4).map(BigInt);
  return compare(actual, bounds.lower) >= 0 && compare(actual, bounds.upper) < 0;
}

function readInstalledDeclaration(directory, expectedPackage) {
  let bytes;
  try {
    bytes = fs.readFileSync(path.join(directory, 'cli-compatibility.json'));
  } catch (error) {
    if (error && typeof error.code === 'string')
      throw new CompatibilityError(`Cannot read the compatibility declaration (${error.code}).`);
    throw error;
  }
  let declaration;
  try {
    declaration = JSON.parse(new TextDecoder('utf-8', { fatal: true }).decode(bytes));
  } catch (error) {
    if (error instanceof SyntaxError || error instanceof TypeError)
      throw new CompatibilityError('The compatibility declaration is not valid UTF-8 JSON.');
    throw error;
  }
  const bounds = validateDeclaration(declaration, expectedPackage);
  if (!canonicalDeclaration(declaration).equals(bytes))
    throw new CompatibilityError('The compatibility declaration is not canonical JSON.');
  return { declaration, bounds };
}

function readCheckerDeclaration(expectedPackage) {
  const pluginRoot = path.resolve(__dirname, '..', '..', '..');
  try {
    fs.lstatSync(path.join(pluginRoot, 'plugin.json'));
  } catch (error) {
    if (error?.code === 'ENOENT') return readInstalledDeclaration(__dirname, expectedPackage);
    if (error && typeof error.code === 'string')
      throw new CompatibilityError(`Cannot inspect the plugin root (${error.code}).`);
    throw error;
  }
  const installed = readInstalledDeclaration(pluginRoot, expectedPackage);
  const local = readInstalledDeclaration(__dirname, expectedPackage);
  if (!canonicalDeclaration(installed.declaration).equals(canonicalDeclaration(local.declaration)))
    throw new CompatibilityError('The plugin and skill compatibility declarations differ.');
  return installed;
}

function probe(
  launcher,
  spawn = spawnSync,
  platform = process.platform,
  environment = process.env,
) {
  let command = absoluteLauncher(launcher, platform);
  let args = ['--version', '--no-banner'];
  let env = environment;
  let windowsVerbatimArguments = false;
  if (platform === 'win32' && /\.(?:cmd|bat)$/i.test(command)) {
    ({ command, args, env, windowsVerbatimArguments } = windowsInvocation(
      command,
      args,
      environment,
    ));
  }
  return spawn(command, args, {
    encoding: 'utf8',
    env,
    maxBuffer: 65536,
    stdio: ['ignore', 'pipe', 'pipe'],
    timeout: 30000,
    windowsVerbatimArguments,
    windowsHide: true,
  });
}

function check(expectedPackage, directory, spawn = spawnSync, candidate, launcher) {
  let installed;
  try {
    installed =
      directory === undefined
        ? readCheckerDeclaration(expectedPackage)
        : readInstalledDeclaration(directory, expectedPackage);
  } catch (error) {
    if (error instanceof CompatibilityError)
      return { status: 'invalid-metadata', message: error.message };
    throw error;
  }
  let version = candidate;
  if (candidate === undefined) {
    let result;
    try {
      result = probe(launcher, spawn);
    } catch (error) {
      if (error instanceof CompatibilityError)
        return { status: 'probe-failed', reason: 'unavailable', message: error.message };
      throw error;
    }
    if (result.error)
      return {
        status: 'probe-failed',
        reason: result.error.code === 'ETIMEDOUT' ? 'timeout' : 'unavailable',
        message: result.error.message,
      };
    if (result.status !== 0)
      return {
        status: 'probe-failed',
        reason: 'nonzero-exit',
        exitCode: result.status,
        stderr: result.stderr || '',
      };
    const output = /^(.*?)(?:\r?\n)?$/.exec(result.stdout || '');
    version = output?.[1];
  }
  try {
    if (!version) throw new CompatibilityError('The CLI did not report one valid SemVer version.');
    const compatible = satisfies(version, installed.bounds);
    return {
      status: compatible ? 'compatible' : 'incompatible',
      version,
      range: installed.declaration.range,
    };
  } catch (error) {
    if (error instanceof CompatibilityError)
      return {
        status: candidate === undefined ? 'probe-failed' : 'invalid-version',
        reason: candidate === undefined ? 'invalid-output' : 'invalid-candidate',
        message: error.message,
      };
    throw error;
  }
}

function checkLatest(
  expectedPackage,
  directory,
  spawn = spawnSync,
  query = registryVersions,
  launcher,
) {
  let installed;
  try {
    installed =
      directory === undefined
        ? readCheckerDeclaration(expectedPackage)
        : readInstalledDeclaration(directory, expectedPackage);
  } catch (error) {
    if (error instanceof CompatibilityError)
      return { status: 'invalid-metadata', message: error.message };
    throw error;
  }

  if (launcher !== null) {
    try {
      absoluteLauncher(launcher);
    } catch (error) {
      if (error instanceof CompatibilityError)
        return { status: 'invalid-input', message: error.message };
      throw error;
    }
  }

  let targetVersion;
  try {
    targetVersion = resolveLatestVersion(expectedPackage, installed.declaration.range, query);
  } catch (error) {
    if (error instanceof CompatibilityError)
      return { status: 'registry-failed', message: error.message };
    throw error;
  }

  if (launcher === null)
    return {
      status: 'install-required',
      reason: 'not-found',
      targetVersion,
      message: 'The wiqd CLI is not installed or is not on PATH.',
    };

  let result;
  try {
    result = probe(launcher, spawn);
  } catch (error) {
    if (error instanceof CompatibilityError)
      return {
        status: 'probe-failed',
        reason: 'unavailable',
        targetVersion,
        message: error.message,
      };
    throw error;
  }
  if (result.error) {
    return {
      status: 'probe-failed',
      reason: result.error.code === 'ETIMEDOUT' ? 'timeout' : 'unavailable',
      targetVersion,
      message: result.error.message,
    };
  }
  if (result.status !== 0) {
    return {
      status: 'probe-failed',
      reason: 'nonzero-exit',
      targetVersion,
      exitCode: result.status,
      stderr: result.stderr || '',
    };
  }

  const version = (result.stdout || '').replace(/\r?\n$/, '');
  let order;
  try {
    order = compareVersions(version, targetVersion);
  } catch (error) {
    if (error instanceof CompatibilityError)
      return {
        status: 'probe-failed',
        reason: 'invalid-output',
        targetVersion,
        message: error.message,
      };
    throw error;
  }
  return {
    status: order < 0 ? 'update-required' : order > 0 ? 'newer' : 'compatible',
    version,
    targetVersion,
    range: installed.declaration.range,
    launcher,
  };
}

if (require.main === module) {
  const args = process.argv.slice(2);
  let result;
  if (
    args[0] === '--package' &&
    args[1] &&
    args[2] === '--latest' &&
    ((args.length === 5 && args[3] === '--launcher' && args[4]) ||
      (args.length === 4 && args[3] === '--missing-launcher'))
  )
    result = checkLatest(
      args[1],
      undefined,
      spawnSync,
      registryVersions,
      args[3] === '--missing-launcher' ? null : args[4],
    );
  else if (
    args[0] === '--package' &&
    args[1] &&
    args.length === 4 &&
    (args[2] === '--version' || args[2] === '--launcher') &&
    args[3]
  )
    result = check(
      args[1],
      undefined,
      spawnSync,
      args[2] === '--version' ? args[3] : undefined,
      args[2] === '--launcher' ? args[3] : undefined,
    );
  else
    result = {
      status: 'invalid-input',
      message:
        'Provide --package with --latest and a launcher or --missing-launcher, or --version.',
    };
  process.stdout.write(`${JSON.stringify(result)}\n`);
  process.exitCode =
    result.status === 'compatible' || result.status === 'newer'
      ? 0
      : result.status === 'incompatible'
        ? 1
        : result.status === 'update-required' || result.status === 'install-required'
          ? 3
          : 2;
}

module.exports = {
  CompatibilityError,
  RELEASE_LINE,
  canonicalDeclaration,
  check,
  checkLatest,
  compareVersions,
  parseRange,
  probe,
  resolveLatestVersion,
  registryVersions,
  satisfies,
  validateDeclaration,
};
