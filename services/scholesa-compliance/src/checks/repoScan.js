const cp = require('child_process');
const { reportPath, writeJson, nowIso } = require('../utils');

const COMMANDS = [
  'pwd && git rev-parse --show-toplevel',
  'git status',
  'ls -la',
  'find . -maxdepth 3 -name "firebase.json" -o -name "firestore.rules" -o -name "Dockerfile" -o -name "cloudbuild.yaml" -o -name ".github" -o -name "package.json" -o -name "pnpm-lock.yaml" -o -name "yarn.lock" -o -name "requirements.txt" -o -name "pyproject.toml" -o -name "go.mod"',
  'find . -maxdepth 4 -type d -iname "*service*" -o -iname "*api*" -o -iname "*ai*" -o -iname "*cloudrun*"',
  'grep -RIn --exclude-dir=node_modules --exclude-dir=.git "Cloud Run\\|cloudrun\\|firebase\\|firestore\\|Secret Manager\\|IAM\\|service account" . | head -n 200',
];

function runCommand(command) {
  try {
    const stdout = cp.execSync(command, {
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'pipe'],
      maxBuffer: 1024 * 1024 * 32,
      shell: '/bin/zsh',
    });
    const lines = stdout.split(/\r?\n/).filter(Boolean);
    return {
      command,
      exitCode: 0,
      lineCount: lines.length,
      stdoutHead: lines.slice(0, 120),
      stdoutTail: lines.slice(-40),
    };
  } catch (error) {
    const stderr = String(error.stderr || '');
    const stdout = String(error.stdout || '');
    return {
      command,
      exitCode: typeof error.status === 'number' ? error.status : 1,
      lineCount: stdout.split(/\r?\n/).filter(Boolean).length,
      stdoutHead: stdout.split(/\r?\n/).filter(Boolean).slice(0, 120),
      stdoutTail: stdout.split(/\r?\n/).filter(Boolean).slice(-40),
      stderr: stderr.split(/\r?\n/).filter(Boolean).slice(0, 80),
    };
  }
}

function runRepoScan() {
  const startedAt = nowIso();
  const commandResults = COMMANDS.map(runCommand);
  const failed = commandResults.filter((result) => result.exitCode !== 0);
  const passed = failed.length === 0;

  const report = {
    report: 'repo-structure-scan',
    generatedAt: nowIso(),
    startedAt,
    passed,
    commandCount: commandResults.length,
    failedCommands: failed.map((result) => ({ command: result.command, exitCode: result.exitCode })),
    commands: commandResults,
  };

  const outputPath = reportPath('repo-structure-scan');
  writeJson(outputPath, report);

  return {
    checkId: 'repo_structure_scan',
    passed,
    findings: failed.map((result) => `${result.command} failed with exit ${result.exitCode}`),
    evidencePath: outputPath,
    details: {
      commandCount: commandResults.length,
      failedCount: failed.length,
    },
  };
}

module.exports = {
  runRepoScan,
};
