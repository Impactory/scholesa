#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const { finish } = require('./vibe_report_utils');

const outDir = path.resolve('audit-pack/reports');
fs.mkdirSync(outDir, { recursive: true });

const fixtures = [
  {
    id: 'th-combining',
    learnerName: 'ก\u0E4D\u0E32หนดเป้าหมาย',
    missionTitleZhCn: '未来任务：分数学习',
    missionTitleZhTw: '未來任務：分數學習',
    reflection: 'วันนี้我学习了 fractions และ比率',
  },
  {
    id: 'cjk-mixed',
    learnerName: '李明',
    missionTitleZhCn: '创意写作工作坊',
    missionTitleZhTw: '創意寫作工作坊',
    reflection: '我今天學會了「自信表達」並且很開心',
  },
];

function toCsv(rows) {
  const headers = Object.keys(rows[0]);
  const escaped = (value) => `"${String(value).replace(/"/g, '""')}"`;
  const lines = [headers.map(escaped).join(',')];
  for (const row of rows) {
    lines.push(headers.map((key) => escaped(row[key])).join(','));
  }
  return lines.join('\n');
}

function parseCsv(csv) {
  const lines = csv.split(/\r?\n/).filter(Boolean);
  if (lines.length < 2) return [];
  const parseLine = (line) => {
    const values = [];
    let current = '';
    let inQuotes = false;
    for (let i = 0; i < line.length; i += 1) {
      const ch = line[i];
      if (ch === '"') {
        const next = line[i + 1];
        if (inQuotes && next === '"') {
          current += '"';
          i += 1;
        } else {
          inQuotes = !inQuotes;
        }
        continue;
      }
      if (ch === ',' && !inQuotes) {
        values.push(current);
        current = '';
        continue;
      }
      current += ch;
    }
    values.push(current);
    return values;
  };

  const headers = parseLine(lines[0]);
  return lines.slice(1).map((line) => {
    const values = parseLine(line);
    const row = {};
    headers.forEach((header, idx) => {
      row[header] = values[idx] || '';
    });
    return row;
  });
}

const failures = [];
const details = {};

const jsonPath = path.join(outDir, 'vibe-utf8-fixture.json');
const csvPath = path.join(outDir, 'vibe-utf8-fixture.csv');

const jsonText = JSON.stringify(fixtures, null, 2);
const csvText = toCsv(fixtures);

fs.writeFileSync(jsonPath, jsonText, 'utf8');
fs.writeFileSync(csvPath, csvText, 'utf8');

const jsonRoundTrip = JSON.parse(fs.readFileSync(jsonPath, 'utf8'));
const csvRoundTrip = parseCsv(fs.readFileSync(csvPath, 'utf8'));

for (let i = 0; i < fixtures.length; i += 1) {
  const source = fixtures[i];
  const fromJson = jsonRoundTrip[i];
  const fromCsv = csvRoundTrip[i];
  for (const key of Object.keys(source)) {
    if (source[key] !== fromJson[key]) {
      failures.push(`json_mismatch:${source.id}:${key}`);
    }
    if (source[key] !== fromCsv[key]) {
      failures.push(`csv_mismatch:${source.id}:${key}`);
    }
    if (source[key].normalize('NFC') !== fromCsv[key].normalize('NFC')) {
      failures.push(`csv_normalization_mismatch:${source.id}:${key}`);
    }
  }
}

const csvBuffer = fs.readFileSync(csvPath);
const hasUtf8Bom = csvBuffer.length >= 3 &&
  csvBuffer[0] === 0xef &&
  csvBuffer[1] === 0xbb &&
  csvBuffer[2] === 0xbf;

details.outputFiles = {
  jsonPath: path.relative(process.cwd(), jsonPath),
  csvPath: path.relative(process.cwd(), csvPath),
};
details.encoding = {
  csvUtf8BomPresent: hasUtf8Bom,
  jsonUtf8RoundTrip: failures.every((f) => !f.startsWith('json_')),
  csvUtf8RoundTrip: failures.every((f) => !f.startsWith('csv_')),
};
details.sampleRows = fixtures;

finish('vibe-data-utf8-report', failures, details);

