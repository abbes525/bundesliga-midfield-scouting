"""Check the distributable project without downloading data or contacting SQL Server."""
import ast
import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
required = ['README.md','requirements.txt','pyproject.toml','powerbi/bundesliga_midfield_scouting.pbix',
            'docs/AUDIT_REPORT.md','docs/NOTEBOOK_GUIDE.md','docs/DATA_DICTIONARY.md']
missing = [p for p in required if not (root/p).is_file()]
for number in range(1,15):
    if len(list((root/'sql').glob(f'{number:02d}_*.sql'))) != 1:
        missing.append(f'exactly one SQL script numbered {number:02d}')
if missing:
    raise SystemExit('Missing required items: ' + ', '.join(missing))
count = 0
for path in (root/'notebooks').rglob('*.ipynb'):
    notebook = json.loads(path.read_text(encoding='utf-8'))
    if notebook.get('nbformat') != 4:
        raise ValueError(f'Unexpected notebook format: {path}')
    if not any(c['cell_type']=='markdown' for c in notebook['cells']):
        raise ValueError(f'Notebook has no explanations: {path}')
    for cell in notebook['cells']:
        if cell['cell_type']=='code':
            ast.parse(''.join(cell['source']))
    count += 1
for path in list((root/'src').rglob('*.py')) + list((root/'scripts').glob('*.py')):
    ast.parse(path.read_text(encoding='utf-8'))
print(f'PASS: 14 SQL scripts, {count} documented notebooks, shared Python modules and report are present.')
