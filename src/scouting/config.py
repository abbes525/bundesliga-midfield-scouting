"""One place for project paths and the fixed historical analysis scope."""
import os
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[2]
RAW_DIR = PROJECT_ROOT / 'data' / 'raw' / 'impect'
PROCESSED_DIR = PROJECT_ROOT / 'data' / 'processed'
REPORTS_DIR = PROJECT_ROOT / 'reports'
IMPECT_BASE_URL = 'https://raw.githubusercontent.com/ImpectAPI/open-data/main/data'
ITERATION_ID = 743
MIDFIELD_POSITIONS = ['CENTRAL_MIDFIELD', 'DEFENSE_MIDFIELD', 'ATTACKING_MIDFIELD']
SQL_SERVER = os.getenv('FOOTBALL_SQL_SERVER', r'localhost\SQLEXPRESS')
SQL_DATABASE = os.getenv('FOOTBALL_SQL_DATABASE', 'FootballRecruitmentDW')
