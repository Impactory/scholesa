const { runComplianceSuite } = require('./checks/runAllChecks');
const { runRepoScan } = require('./checks/repoScan');

function parseArgs(argv) {
  const args = {
    scanOnly: false,
    trigger: 'manual-cli',
  };

  for (const arg of argv.slice(2)) {
    if (arg === '--scan-only') {
      args.scanOnly = true;
      continue;
    }
    if (arg.startsWith('--trigger=')) {
      args.trigger = arg.slice('--trigger='.length) || args.trigger;
      continue;
    }
  }

  return args;
}

function main() {
  const args = parseArgs(process.argv);

  if (args.scanOnly) {
    const scan = runRepoScan();
    process.stdout.write(JSON.stringify(scan, null, 2) + '\n');
    process.exit(scan.passed ? 0 : 1);
    return;
  }

  const result = runComplianceSuite(args.trigger);
  process.stdout.write(JSON.stringify({
    status: result.passed ? 'PASS' : 'FAIL',
    reportId: result.reportId,
    failures: result.failures,
    reportPath: result.reportPath,
  }, null, 2) + '\n');

  process.exit(result.passed ? 0 : 1);
}

if (require.main === module) {
  main();
}
