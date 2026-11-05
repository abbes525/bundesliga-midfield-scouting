"""Run the main preparation notebook as a script, using its single source of logic.

Usage from the repository root: python scripts/run_preparation.py
The notebook remains the teaching document; this entry point does not duplicate it.
"""
import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
path = root / 'notebooks' / '01_data_preparation_and_screening.ipynb'
notebook = json.loads(path.read_text(encoding='utf-8'))
namespace = {'__name__': '__main__'}
for index, cell in enumerate(notebook['cells'], start=1):
    if cell['cell_type'] == 'code':
        print(f'Running notebook cell {index}...', flush=True)
        exec(compile(''.join(cell['source']), str(path), 'exec'), namespace)
