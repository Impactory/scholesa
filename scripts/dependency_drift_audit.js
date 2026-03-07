#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');
const cp = require('child_process');

const ROOT = process.cwd();
const REPORT_DIR = path.join(ROOT, 'audit-pack', 'reports');
const REPORT_PATH = path.join(REPORT_DIR, 'dependency-drift.json');
const FLUTTER_APP = path.join(ROOT, 'apps', 'empire_flutter', 'app');
const FUNCTIONS_DIR = path.join(ROOT, 'functions');

function ensureReportDir() {
  fs.mkdirSync(REPORT_DIR, { recursive: true });
}

function runJsonCommand(command, args, cwd, options = {}) {
  try {
    const stdout = cp.execFileSync(command, args, {
      cwd,
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'pipe'],
      ...options,
    });
    return JSON.parse(stdout || '{}');
  } catch (error) {
    const stdout = String(error.stdout || '').trim();
    if (!stdout) {
      const stderr = String(error.stderr || '').trim();
      throw new Error(`${command} ${args.join(' ')} failed: ${stderr || error.message}`);
    }
    return JSON.parse(stdout);
  }
}

function semverType(from, to) {
  if (!from || !to) return 'unknown';
  const parse = (value) => {
    const match = String(value).match(/(\d+)\.(\d+)\.(\d+)/);
    if (!match) return null;
    return match.slice(1).map((part) => Number(part));
  };
  const current = parse(from);
  const next = parse(to);
  if (!current || !next) return 'unknown';
  if (next[0] !== current[0]) return 'major';
  if (next[1] !== current[1]) return 'minor';
  if (next[2] !== current[2]) return 'patch';
  return 'same';
}

function normalizeNpmOutdated(raw) {
  return Object.entries(raw || {}).map(([name, info]) => ({
    name,
    current: info.current,
    wanted: info.wanted,
    latest: info.latest,
    location: info.location,
    dependent: info.dependent,
    wantedUpdateType: semverType(info.current, info.wanted),
    latestUpdateType: semverType(info.current, info.latest),
  })).sort((a, b) => a.name.localeCompare(b.name));
}

function normalizeFlutterOutdated(raw) {
  return (raw.packages || []).map((pkg) => ({
    name: pkg.package,
    kind: pkg.kind,
    current: pkg.current?.version || null,
    upgradable: pkg.upgradable?.version || null,
    resolvable: pkg.resolvable?.version || null,
    latest: pkg.latest?.version || null,
    isDiscontinued: Boolean(pkg.isDiscontinued),
    isCurrentRetracted: Boolean(pkg.isCurrentRetracted),
    isCurrentAffectedByAdvisory: Boolean(pkg.isCurrentAffectedByAdvisory),
    resolvableUpdateType: semverType(pkg.current?.version, pkg.resolvable?.version),
    latestUpdateType: semverType(pkg.current?.version, pkg.latest?.version),
  })).sort((a, b) => a.name.localeCompare(b.name));
}

function summarizeNpm(packages) {
  return {
    outdatedCount: packages.length,
    wantedPatchOrMinorCount: packages.filter((pkg) => pkg.wantedUpdateType === 'patch' || pkg.wantedUpdateType === 'minor').length,
    latestMajorCount: packages.filter((pkg) => pkg.latestUpdateType === 'major').length,
  };
}

function summarizeFlutter(packages) {
  return {
    packageCount: packages.length,
    resolvablePatchOrMinorCount: packages.filter((pkg) => pkg.resolvableUpdateType === 'patch' || pkg.resolvableUpdateType === 'minor').length,
    latestMajorCount: packages.filter((pkg) => pkg.latestUpdateType === 'major').length,
    discontinuedCount: packages.filter((pkg) => pkg.isDiscontinued).length,
    advisoryCount: packages.filter((pkg) => pkg.isCurrentAffectedByAdvisory).length,
  };
}

function topConcerns(rootNpm, functionsNpm, flutter) {
  const concerns = [];
  for (const pkg of functionsNpm.filter((entry) => entry.latestUpdateType === 'major')) {
    concerns.push({ ecosystem: 'functions-npm', name: pkg.name, reason: 'latest-major-available', current: pkg.current, latest: pkg.latest });
  }
  for (const pkg of flutter.filter((entry) => entry.isDiscontinued)) {
    concerns.push({ ecosystem: 'flutter', name: pkg.name, reason: 'discontinued-package', current: pkg.current, latest: pkg.latest });
  }
  for (const pkg of rootNpm.filter((entry) => entry.latestUpdateType === 'major')) {
    concerns.push({ ecosystem: 'root-npm', name: pkg.name, reason: 'latest-major-available', current: pkg.current, latest: pkg.latest });
  }
  return concerns.slice(0, 20);
}

function main() {
  const rootNpm = normalizeNpmOutdated(runJsonCommand('npm', ['outdated', '--json'], ROOT));
  const functionsNpm = normalizeNpmOutdated(runJsonCommand('npm', ['outdated', '--json'], FUNCTIONS_DIR));
  const flutter = normalizeFlutterOutdated(runJsonCommand('flutter', ['pub', 'outdated', '--json'], FLUTTER_APP));

  const report = {
    reportName: 'dependency-drift',
    generatedAt: new Date().toISOString(),
    summary: {
      rootNpm: summarizeNpm(rootNpm),
      functionsNpm: summarizeNpm(functionsNpm),
      flutter: summarizeFlutter(flutter),
    },
    topConcerns: topConcerns(rootNpm, functionsNpm, flutter),
    ecosystems: {
      rootNpm,
      functionsNpm,
      flutter,
    },
  };

  ensureReportDir();
  fs.writeFileSync(REPORT_PATH, `${JSON.stringify(report, null, 2)}\n`);
  console.log(JSON.stringify({ status: 'PASS', report: path.relative(ROOT, REPORT_PATH), summary: report.summary, topConcerns: report.topConcerns }, null, 2));
}

main();
