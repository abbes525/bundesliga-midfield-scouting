"""SQL Server connection configuration and an explicit load opt-in."""
import os
from .config import SQL_SERVER, SQL_DATABASE

def connection_string():
    import pyodbc
    drivers = pyodbc.drivers()
    driver = next((d for d in ['ODBC Driver 18 for SQL Server','ODBC Driver 17 for SQL Server'] if d in drivers), None)
    if driver is None:
        raise RuntimeError('Install Microsoft ODBC Driver 17 or 18 for SQL Server.')
    # Windows integrated authentication; no password belongs in this repository.
    return (f'DRIVER={{{driver}}};SERVER={SQL_SERVER};DATABASE={SQL_DATABASE};'
            'Trusted_Connection=yes;Encrypt=yes;TrustServerCertificate=yes;')

def require_load_enabled(enabled):
    """The existing importers also refuse nonempty target tables."""
    if not enabled:
        raise RuntimeError('Database loading is disabled. Set RUN_DATABASE_LOAD = True in this notebook only when building empty staging tables. Existing databases need validation, not re-import.')
