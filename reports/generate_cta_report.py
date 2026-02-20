import json
import csv
import pathlib
import re
from collections import Counter

inv_path = pathlib.Path('reports/cta_inventory.json')
items = json.loads(inv_path.read_text())

for index, item in enumerate(items, start=1):
    label = (item.get('label') or '').strip()
    handler = item.get('handler') or ''

    flow = []
    if item.get('isPushOrGo'):
        flow.append('navigate')
    if item.get('isDialog'):
        flow.append('dialog/sheet')
    if item.get('isSnackbar'):
        flow.append('snackbar')
    if item.get('isNavigatorPop') or re.search(r'Navigator\.pop\(', handler):
        flow.append('cancel/close')
    if not flow:
        flow.append('callback/action')

    item['id'] = index
    item['flow'] = ' + '.join(dict.fromkeys(flow))
    item['isCancelCta'] = bool(
        re.search(r'cancel|close|back|dismiss', label, re.I)
        or re.search(r'Navigator\.pop\(', handler)
    )
    item['blocker'] = 'none'

report_dir = pathlib.Path('reports')
report_dir.mkdir(exist_ok=True)

csv_path = report_dir / 'CTA_FULL_INVENTORY.csv'
fields = [
    'id', 'file', 'line', 'event', 'label', 'flow',
    'handler', 'isCancelCta', 'isNoop', 'blocker'
]

with csv_path.open('w', newline='', encoding='utf-8') as file_handle:
    writer = csv.DictWriter(file_handle, fieldnames=fields)
    writer.writeheader()
    for item in items:
        writer.writerow({key: item.get(key, '') for key in fields})

flow_counts = Counter(item['flow'] for item in items)
file_counts = Counter(item['file'] for item in items)
cancel_items = [item for item in items if item['isCancelCta']]
noop_items = [item for item in items if item['isNoop']]

md_path = report_dir / 'CTA_FULL_REGRESSION_REPORT.md'
lines = []
lines.append('# CTA Full Regression Report')
lines.append('')
lines.append('## Scope')
lines.append('- Workspace: scholesa')
lines.append('- Source scanned: apps/empire_flutter/app/lib/**/*.dart')
lines.append(f'- Total CTA handlers found: {len(items)}')
lines.append(f'- Cancel/close CTAs found: {len(cancel_items)}')
lines.append(f'- No-op handler blockers: {len(noop_items)}')
lines.append('')
lines.append('## Flow Type Summary')
for key, value in flow_counts.most_common():
    lines.append(f'- {key}: {value}')
lines.append('')
lines.append('## Top Files by CTA Count')
for file_path, count in file_counts.most_common(25):
    lines.append(f'- {file_path}: {count}')
lines.append('')
lines.append('## Blocker Scan')
if noop_items:
    lines.append('- Blockers detected:')
    for item in noop_items:
        label = item.get('label') or 'unlabeled'
        lines.append(f"  - {item['file']}:{item['line']} ({label})")
else:
    lines.append('- No no-op CTA blockers detected (`onPressed/onTap: () {}` = 0).')
lines.append('- Placeholder CTA text scan is reported by dedicated grep step.')
lines.append('')
lines.append('## Exhaustive CTA Inventory')
lines.append('All CTAs (including cancel/close/back actions) are listed in:')
lines.append(f'- {csv_path.as_posix()}')
lines.append('')
lines.append('### Sample (first 100 CTAs)')
lines.append('| ID | File | Line | Event | Label | Flow | Cancel | Blocker |')
lines.append('|---:|---|---:|---|---|---|---|---|')
for item in items[:100]:
    label = (item.get('label') or '').replace('|', '/')
    cancel = 'yes' if item['isCancelCta'] else 'no'
    lines.append(
        f"| {item['id']} | {item['file']} | {item['line']} | {item['event']} | "
        f"{label} | {item['flow']} | {cancel} | {item['blocker']} |"
    )

md_path.write_text('\n'.join(lines), encoding='utf-8')

print(f'WROTE {csv_path} rows={len(items)}')
print(f'WROTE {md_path}')
print(f'CANCEL_CTAS={len(cancel_items)} NOOP={len(noop_items)}')
